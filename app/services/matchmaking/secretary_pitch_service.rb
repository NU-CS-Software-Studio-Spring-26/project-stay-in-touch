module Matchmaking
  # The requester's "AI secretary": given the requester's profile and a list of
  # candidate users, picks ONE target and writes a persuasive invitation pitch.
  # Returns a PitchResult, or nil when there's nothing usable (no candidates,
  # unparseable model output, out-of-range/self choice, or any API error).
  class SecretaryPitchService
    MODEL             = "google/gemma-4-26b-a4b-it:free"
    MAX_CANDIDATES    = 25
    INTEREST_TRUNCATE = 300

    PitchResult = Struct.new(:target_user, :pitch_text)

    def initialize(requester, candidates)
      @requester  = requester
      @candidates = candidates.first(MAX_CANDIDATES)
    end

    def call
      return nil if @candidates.empty?

      client = OpenAI::Client.new(
        access_token: ENV["OPENROUTER_API_KEY"],
        uri_base:     "https://openrouter.ai/api/v1"
      )
      response = RateLimitedChat.with_retry do
        client.chat(
          parameters: {
            model:    MODEL,
            messages: [
              { role: "system", content: system_prompt },
              { role: "user",   content: user_prompt }
            ],
            max_tokens: 400
          }
        )
      end
      parse(response.dig("choices", 0, "message", "content"))
    rescue StandardError => e
      Rails.logger.error(
        "SecretaryPitchService: requester=#{@requester.id} failed with " \
        "#{e.class}: #{e.message}"
      )
      nil
    end

    private

    def parse(content)
      data = extract_json(content)
      unless data
        Rails.logger.warn(
          "SecretaryPitchService: requester=#{@requester.id} returned " \
          "unparseable output (no JSON object found): #{content.to_s.truncate(200)}"
        )
        return nil
      end

      choice = data["choice"]
      pitch  = data["pitch"].to_s.strip
      if choice.blank? || pitch.blank?
        Rails.logger.warn(
          "SecretaryPitchService: requester=#{@requester.id} returned JSON " \
          "with missing choice/pitch: #{data.inspect.truncate(200)}"
        )
        return nil
      end

      index = choice.to_i - 1
      unless index.between?(0, @candidates.size - 1)
        Rails.logger.warn(
          "SecretaryPitchService: requester=#{@requester.id} picked " \
          "out-of-range choice=#{choice.inspect} (candidates=#{@candidates.size})"
        )
        return nil
      end

      PitchResult.new(@candidates[index], pitch)
    end

    # Small free models don't reliably emit clean JSON: try the whole string, then
    # the first {...} block embedded in any surrounding prose.
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
        You are an AI secretary acting on behalf of your client. Your job is to get
        your client meetings that benefit them. You are persuasive and a little pushy:
        you may angle for a meeting even when the other person might not obviously want
        it, as long as there is a plausible mutual benefit. Reply with ONLY a JSON
        object and no other prose.
      PROMPT
    end

    def user_prompt
      <<~PROMPT.strip
        Your client is "#{@requester.display_label}".
        Your client wants to get/receive from meetings: "#{@requester.meeting_interests}".

        Here is a numbered list of available people and what each wants from meetings:
        #{candidate_list}

        Pick the ONE person your client should meet, and write a short, warm,
        persuasive 1-2 sentence invitation pitch written from your client's perspective.

        Respond with ONLY this JSON, no other text:
        {"choice": <the number of the person you picked>, "pitch": "<the invitation text>"}
      PROMPT
    end

    def candidate_list
      @candidates.each_with_index.map do |user, i|
        interests = user.meeting_interests.to_s.truncate(INTEREST_TRUNCATE)
        "#{i + 1}. #{user.display_label}: #{interests}"
      end.join("\n")
    end
  end
end
