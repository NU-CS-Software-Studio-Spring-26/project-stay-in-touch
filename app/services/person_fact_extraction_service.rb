class PersonFactExtractionService
  MODEL = "google/gemma-4-26b-a4b-it:free"

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
        model:    MODEL,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user",   content: user_prompt }
        ],
        max_tokens: 500
      }
    )
    parse(response.dig("choices", 0, "message", "content"))
  rescue StandardError => e
    Rails.logger.error("PersonFactExtractionService failed for person=#{@person.id}: #{e.class}: #{e.message}")
    []
  end

  private

  def parse(content)
    return [] if content.blank?

    json_str = content[/\[.*\]/m]
    return [] if json_str.blank?

    data = JSON.parse(json_str)
    return [] unless data.is_a?(Array)

    data.filter_map do |item|
      next unless item.is_a?(Hash)
      category = item["category"].to_s.downcase.strip
      body     = item["body"].to_s.strip
      next if body.blank?
      category = "other" unless PersonFact::CATEGORIES.include?(category)
      { category: category, body: body }
    end
  rescue JSON::ParserError
    []
  end

  def system_prompt
    "You extract memorable personal facts from conversation notes. Reply ONLY with a JSON array, no other text."
  end

  def user_prompt
    event_notes = @person.events
      .order(occurred_at: :desc)
      .limit(10)
      .pluck(:notes)
      .compact
      .reject(&:blank?)
      .join("\n---\n")

    parts = ["Extract memorable facts about #{@person.name} from these notes."]
    parts << "Event notes:\n#{event_notes.truncate(1500)}" if event_notes.present?
    parts << "General notes: #{@person.notes.truncate(300)}" if @person.notes.present?
    parts << <<~PROMPT

      Return ONLY a JSON array (max 5 items), no other text. Each object:
        "category": one of "work", "personal", "interests", "life_event", "other"
        "body": a short, specific fact under 100 words

      Example: [{"category":"work","body":"Switched to a senior PM role at Google in March"},{"category":"personal","body":"Has a dog named Luna"}]

      Only include specific, memorable details. Skip generic or vague observations.
    PROMPT
    parts.join("\n")
  end
end
