class ReconnectMessageService
  # Maps month ranges to season names (northern hemisphere).
  SEASONS = {
    (3..5)  => "spring",
    (6..8)  => "summer",
    (9..11) => "autumn"
  }.freeze

  # Fixed-date holidays checked within a 14-day look-ahead.
  HOLIDAYS = [
    [1,  1,  "New Year's Day"],
    [2,  14, "Valentine's Day"],
    [3,  17, "St Patrick's Day"],
    [7,  4,  "Independence Day"],
    [10, 31, "Halloween"],
    [12, 24, "Christmas Eve"],
    [12, 25, "Christmas"],
    [12, 31, "New Year's Eve"]
  ].freeze

  def initialize(person, user)
    @person = person
    @user   = user
  end

  def call
    response = OpenRouterChat.completion(
      messages:   [ { role: "user", content: prompt } ],
      max_tokens: 200
    )
    draft = response.dig("choices", 0, "message", "content")&.strip
    store_draft(draft) if draft.present?
    draft
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

    if (notes = recent_event_notes).present?
      parts << "Our recent conversation notes: #{notes}."
    end

    if (facts = person_facts_summary).present?
      parts << "What I know about them: #{facts}."
    end

    parts << "Current context: #{seasonal_context}."

    if (past = past_draft_summaries).present?
      parts << "Previous messages I've sent this person (do not repeat these ideas): #{past}."
    end

    parts << "Keep it under 3 sentences. No subject line or sign-off. Make it feel genuinely personal, not templated."
    parts.join(" ")
  end

  def recent_event_notes
    @person.events
           .order(occurred_at: :desc)
           .limit(5)
           .pluck(:notes)
           .compact
           .reject(&:blank?)
           .join("; ")
           .truncate(600)
  end

  def person_facts_summary
    parts  = [ @person.notes.presence&.truncate(300) ]
    parts += @person.person_facts.order(created_at: :desc).limit(8).pluck(:body)
    parts.compact.join("; ").truncate(500)
  end

  def seasonal_context
    month  = Date.current.month
    season = SEASONS.find { |range, _| range.include?(month) }&.last || "winter"
    holiday = upcoming_holiday
    holiday ? "#{season}, #{holiday} coming up soon" : season
  end

  def upcoming_holiday
    today = Date.current
    HOLIDAYS.filter_map do |(m, d, name)|
      candidate = Date.new(today.year, m, d)
      candidate = candidate.next_year if candidate < today
      days_away = (candidate - today).to_i
      days_away <= 14 ? [ days_away, name ] : nil
    end.min_by(&:first)&.last
  end

  def past_draft_summaries
    @user.outreach_drafts
         .where(person: @person)
         .order(created_at: :desc)
         .limit(3)
         .pluck(:body)
         .map { |b| b.truncate(120) }
         .join(" | ")
  end

  def store_draft(body)
    @user.outreach_drafts.create!(person: @person, body: body)
  rescue StandardError => e
    Rails.logger.warn("ReconnectMessageService: could not store draft: #{e.message}")
  end
end
