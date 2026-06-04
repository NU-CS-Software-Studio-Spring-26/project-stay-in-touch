class TopicSuggestionService
  MODEL = "openai/gpt-4o-mini"

  def initialize(person)
    @person = person
  end

  def call
    return [] unless ENV["OPENROUTER_API_KEY"].present?

    client = OpenAI::Client.new(
      access_token: ENV["OPENROUTER_API_KEY"],
      uri_base:     "https://openrouter.ai/api/v1"
    )
    response = client.chat(
      parameters: {
        model:      MODEL,
        messages:   [{ role: "user", content: prompt }],
        max_tokens: 200
      }
    )
    raw = response.dig("choices", 0, "message", "content")&.strip
    parse_topics(raw)
  rescue StandardError
    []
  end

  private

  def prompt
    prior_notes = @person.events
      .order(occurred_at: :desc)
      .limit(5)
      .pluck(:notes)
      .compact
      .reject(&:blank?)
      .join(" | ")

    parts = ["Suggest 2-3 short conversation topic starters for a catch-up with #{@person.name}."]
    parts << "Previous conversation notes: #{prior_notes.truncate(500)}." if prior_notes.present?
    parts << "About them: #{@person.notes.truncate(300)}." if @person.notes.present?
    parts << "Return ONLY a numbered list, one topic per line, under 10 words each. No explanations."
    parts.join(" ")
  end

  def parse_topics(raw)
    return [] if raw.blank?
    raw.lines
       .map { |l| l.gsub(/\A\s*\d+[\.\)]\s*/, "").strip }
       .reject(&:blank?)
       .first(3)
  end
end
