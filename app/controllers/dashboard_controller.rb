class DashboardController < ApplicationController
  def index
    @catchups_this_month = current_user.events
      .where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month)
      .count

    @catchups_last_month = current_user.events
      .where(occurred_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
      .count

    @streak = calculate_streak

    all_people = current_user.people.includes(:events)

    @overdue_people  = all_people.select(&:overdue?).sort_by(&:days_until_due)
    @slipping_people = all_people.select { |p| (d = p.days_until_due) && d >= 0 && d <= 7 }
                                 .sort_by { |p| p.days_until_due }
    @on_track_people = all_people.select { |p| (d = p.days_until_due) && d > 7 }
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

    @upcoming_birthdays = current_user.people.where.not(birthday: nil)
      .select(&:birthday_within?)
      .sort_by(&:days_until_birthday)

    @catchups_by_month = current_user.events
      .group_by_month(:occurred_at, last: 6)
      .count
      .transform_keys { |d| d.strftime("%b %Y") }

    @catchups_by_week = current_user.events
      .group_by_week(:occurred_at, last: 12)
      .count
      .transform_keys { |d| d.strftime("%-m/%-d") }

    @catchups_by_medium = current_user.events
      .group(:medium)
      .count
      .transform_keys { |k| k.titleize }
  end

  def timeline
    @events = current_user.events.includes(:people).recent
    @weeks  = @events.group_by { |e| e.occurred_at.beginning_of_week.to_date }
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
