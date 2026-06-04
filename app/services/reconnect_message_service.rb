class ReconnectMessageService
  def initialize(person, user)
    @person = person
    @user   = user
  end

  def call
    response = OpenRouterChat.completion(
      messages:   [{ role: "user", content: prompt }],
      max_tokens: 150
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
