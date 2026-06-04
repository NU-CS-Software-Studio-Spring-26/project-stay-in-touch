class ReconnectMessageService
  MODEL = "openai/gpt-4o-mini"

  def initialize(person, user)
    @person = person
    @user   = user
  end

  def call
    client = OpenAI::Client.new(
      access_token: ENV["OPENROUTER_API_KEY"],
      uri_base:     "https://openrouter.ai/api/v1"
    )
    response = client.chat(
      parameters: {
        model:      MODEL,
        messages:   [{ role: "user", content: prompt }],
        max_tokens: 150
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue StandardError
    nil
  end

  private

  def prompt
    parts = [ "Write a short, warm, casual reconnect message to #{@person.name}." ]

    if (event = @person.latest_event)
      days_ago = ((Time.current - event.occurred_at) / 1.day).round
      parts << "We last spoke #{days_ago} days ago."
    end

    parts << "Notes about them: #{@person.notes}." if @person.notes.present?
    parts << "Keep it under 3 sentences. Do not include a subject line or sign-off."
    parts.join(" ")
  end
end
