class NudgeNotificationJob < ApplicationJob
  queue_as :default

  # Only nudge for contacts this many days overdue (avoids spamming on every run).
  OVERDUE_THRESHOLD_DAYS = 7
  # Warn about birthdays this many days in advance.
  BIRTHDAY_LOOKAHEAD_DAYS = 7
  # Cap notifications per user per run to avoid overwhelming them.
  MAX_NUDGES_PER_USER = 3

  def perform
    return if vapid_keys_missing?

    User.find_each do |user|
      next if user.push_subscriptions.none?
      send_nudges(user)
    rescue StandardError => e
      Rails.logger.warn("NudgeNotificationJob: user #{user.id}: #{e.message}")
    end
  end

  private

  def send_nudges(user)
    nudges = overdue_nudges(user) + birthday_nudges(user)
    nudges.first(MAX_NUDGES_PER_USER).each do |payload|
      user.push_subscriptions.each do |sub|
        deliver(sub, payload)
      rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription
        sub.destroy
      rescue StandardError => e
        Rails.logger.warn("NudgeNotificationJob: push to sub #{sub.id} failed: #{e.message}")
      end
    end
  end

  def overdue_nudges(user)
    user.people
        .includes(:events)
        .reject(&:snoozed?)
        .filter_map do |person|
          days = person.days_until_due
          next unless days && days <= -OVERDUE_THRESHOLD_DAYS
          weeks_overdue = (-days / 7.0).round
          {
            title: "Time to reach out",
            body:  "You haven't talked to #{person.name} in #{weeks_overdue} #{"week".pluralize(weeks_overdue)}.",
            url:   "/people/#{person.id}"
          }
        end
        .sort_by { |n| n[:body] }
  end

  def birthday_nudges(user)
    today = Date.current
    user.people
        .includes(:events)
        .filter_map do |person|
          next unless person.birthday.present?
          days = days_until_birthday(person.birthday, today)
          next unless days && days <= BIRTHDAY_LOOKAHEAD_DAYS && days >= 0
          label = days == 0 ? "today" : "in #{days} #{"day".pluralize(days)}"
          {
            title: "Upcoming birthday",
            body:  "#{person.name}'s birthday is #{label}.",
            url:   "/people/#{person.id}"
          }
        end
  end

  # Returns days until next birthday occurrence from today (0 = today, 1 = tomorrow …).
  def days_until_birthday(birthday, today)
    this_year = birthday.change(year: today.year)
    candidate = this_year < today ? this_year.next_year : this_year
    (candidate - today).to_i
  end

  def deliver(subscription, payload)
    Webpush.payload_send(
      message:     JSON.generate(payload),
      endpoint:    subscription.endpoint,
      p256dh:      subscription.p256dh_key,
      auth:        subscription.auth_key,
      vapid:       {
        subject:     "mailto:#{ENV.fetch("VAPID_CONTACT_EMAIL", "hello@example.com")}",
        public_key:  ENV.fetch("VAPID_PUBLIC_KEY"),
        private_key: ENV.fetch("VAPID_PRIVATE_KEY")
      },
      ttl: 24 * 60 * 60
    )
  end

  def vapid_keys_missing?
    ENV["VAPID_PUBLIC_KEY"].blank? || ENV["VAPID_PRIVATE_KEY"].blank?
  end
end
