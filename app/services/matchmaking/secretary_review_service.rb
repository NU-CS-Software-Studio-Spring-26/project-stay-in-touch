module Matchmaking
  # The recipient's "AI secretary": given the recipient's profile and an incoming
  # pitch, decides whether to accept. Returns a ReviewResult. This side is
  # fail-safe: any error, blank, or unparseable response DECLINES, so we never
  # auto-schedule a meeting off ambiguous model output.
  class SecretaryReviewService
    # Shown when the secretary couldn't actually evaluate the pitch (the call
    # raised, came back blank, or was unparseable). This is an ERROR, not a real
    # "no" — ReviewResult#error is set so the orchestrator can surface it loudly
    # instead of as a normal decline.
    FALLBACK_REASON = "The recipient's AI secretary couldn't evaluate this pitch — the AI " \
                      "service was unreachable, rate-limited, or returned unreadable output, " \
                      "so no decision was made. Try again; check the server logs if it persists."

    # error: true marks the fail-safe path (couldn't evaluate) as distinct from a
    # genuine accept/decline so the UI can treat it as an error rather than a "no".
    ReviewResult = Struct.new(:accepted, :reason, :error, keyword_init: true)

    def initialize(recipient, requester_label, pitch_text)
      @recipient       = recipient
      @requester_label = requester_label
      @pitch_text      = pitch_text
    end

    def call
      response = OpenRouterChat.completion(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user",   content: user_prompt }
        ],
        max_tokens: 250
      )
      parse(response.dig("choices", 0, "message", "content"))
    rescue StandardError => e
      Rails.logger.error(
        "SecretaryReviewService: recipient=#{@recipient.id} failed with " \
        "#{e.class}: #{e.message}; recording an evaluation error"
      )
      unevaluable
    end

    private

    def parse(content)
      return unevaluable if content.blank?

      data = extract_json(content)
      if data
        decision = data["decision"].to_s.downcase
        reason   = data["reason"].to_s.strip.presence
        return accept(reason || "Accepted.")  if decision.include?("accept")
        return decline(reason || "Declined.") if decision.include?("decline")
      end

      # Keyword fallback when JSON is missing/garbled: only accept on a clear,
      # unambiguous "accept"; otherwise decline (fail-safe).
      lowered = content.downcase
      if lowered.include?("accept") && !lowered.include?("decline")
        accept(content.strip.truncate(200))
      else
        unevaluable
      end
    end

    def accept(reason)
      ReviewResult.new(accepted: true, reason: reason, error: false)
    end

    def decline(reason)
      ReviewResult.new(accepted: false, reason: reason, error: false)
    end

    # The secretary couldn't actually evaluate the pitch. Not a real decline —
    # flagged as an error so the round surfaces it as a failure, not a "no".
    def unevaluable
      ReviewResult.new(accepted: false, reason: FALLBACK_REASON, error: true)
    end

    def extract_json(content)
      parse_json(content) || parse_json(content.to_s[/\{.*\}/m])
    end

    def parse_json(str)
      return nil if str.blank?
      data = JSON.parse(str)
      data.is_a?(Hash) ? data : nil
    rescue JSON::ParserError
      nil
    end

    def system_prompt
      <<~PROMPT.strip
        You are an AI secretary acting on behalf of your client. You protect your
        client's time. You are skeptical and screen requests hard: decline meetings
        that are vague, spammy, off-topic, or that only benefit the requester. Accept
        only when there is a clear, specific benefit to YOUR client given what they
        want from meetings. Reply with ONLY a JSON object and no other prose.
      PROMPT
    end

    def user_prompt
      <<~PROMPT.strip
        Your client is "#{@recipient.display_label}".
        Your client wants to get/receive from meetings: "#{@recipient.meeting_interests}".

        Another person's secretary, on behalf of "#{@requester_label}", sent this
        meeting request:
        "#{@pitch_text}"

        Decide whether your client should accept. Be willing to decline bad matches.

        Respond with ONLY this JSON, no other text:
        {"decision": "accept" or "decline", "reason": "<one short sentence explaining why>"}
      PROMPT
    end
  end
end
