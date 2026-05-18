class DashboardController < ApplicationController
  def index
    @catchups_this_month = current_user.events
      .where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month)
      .count

    @catchups_last_month = current_user.events
      .where(occurred_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
      .count

    @streak = calculate_streak

    @overdue_people = current_user.people
      .includes(:events)
      .select { |p| p.days_until_due&.negative? }
      .sort_by { |p| p.days_until_due }

    @avg_frequency_weeks = current_user.people
      .where.not(frequency_weeks: nil)
      .average(:frequency_weeks)
      &.round(1)

    @top_contacts = current_user.people
      .joins(:events)
      .group("people.id")
      .select("people.*, COUNT(events.id) AS event_count")
      .order("event_count DESC")
      .limit(20)

    @total_catchups = current_user.events.count
    @total_people   = current_user.people.count
  end

  private

  def calculate_streak
    event_weeks = current_user.events
      .pluck(:occurred_at)
      .map { |t| t.beginning_of_week.to_date }
      .to_set

    streak = 0
    check_week = Date.current.beginning_of_week
    # Grace period: if nothing logged this week yet, start counting from last week
    check_week -= 1.week unless event_weeks.include?(check_week)

    while event_weeks.include?(check_week)
      streak += 1
      check_week -= 1.week
    end

    streak
  end
end
