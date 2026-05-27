# Development/test-only seed script. Re-runnable: wipes every row in the tables
# below and re-creates demo users plus Faker-generated example data.
#
# Refuse to run against production: the script is destructive (User.delete_all
# would wipe every real account) and creates demo accounts whose passwords are
# committed to this public repo. Both behaviors are intentional for local dev
# and unsafe for prod. See GitHub issues #23 and #24.
if Rails.env.production?
  abort "db/seeds.rb is development-only — refusing to run in #{Rails.env}. " \
        "If you really need to seed prod, do it from the rails console with explicit data."
end

require "faker"

puts "Clearing existing data..."
EventParticipant.delete_all
Event.delete_all
Person.delete_all
Session.delete_all
User.delete_all

TIMEZONES  = %w[America/Chicago America/New_York America/Los_Angeles America/Denver
                Europe/London Europe/Paris Asia/Tokyo Asia/Singapore].freeze
MEDIUMS    = Event::MEDIA.freeze
FREQ_OPTS  = [1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0].freeze

# ── Demo user (known credentials for easy dev login) ──────────────────────────
seed_email    = ENV.fetch("SEED_USER_EMAIL",    "demo@example.com")
seed_password = ENV.fetch("SEED_USER_PASSWORD", "Demo1!password")

puts "Creating demo user (#{seed_email})..."
demo_user = User.create!(
  email: seed_email,
  password: seed_password,
  password_confirmation: seed_password
)

# ── Extra users (to test multi-user isolation) ────────────────────────────────
puts "Creating extra users..."
extra_users = 9.times.map do |i|
  User.create!(
    email: "user#{i + 2}@example.com",
    password: "Demo1!password",
    password_confirmation: "Demo1!password"
  )
end

all_users = [demo_user] + extra_users

# ── Helper: seed people + events for one user ─────────────────────────────────
def seed_people_and_events(user, people_count:, events_count:)
  people = people_count.times.map do
    user.people.create!(
      name:                 Faker::Name.unique.name,
      email:                Faker::Internet.unique.email,
      timezone:             TIMEZONES.sample,
      preferred_start_hour: [8, 9, 10].sample,
      preferred_end_hour:   [20, 21, 22].sample,
      frequency_weeks:      FREQ_OPTS.sample,
      notes:                Faker::Lorem.sentence(word_count: 6)
    )
  end
  Faker::Name.unique.clear
  Faker::Internet.unique.clear

  events_count.times do
    participants = people.sample(rand(1..4))
    user.events.create!(
      occurred_at: Faker::Time.between(from: 2.years.ago, to: Time.current),
      medium:      MEDIUMS.sample,
      title:       rand < 0.6 ? Faker::Lorem.words(number: rand(2..4)).join(" ").capitalize : nil,
      notes:       rand < 0.5 ? Faker::Lorem.sentence(word_count: 8) : nil,
      people:      participants
    )
  end
end

puts "Seeding demo user with 100 people and 300 events..."
seed_people_and_events(demo_user, people_count: 100, events_count: 300)

puts "Seeding extra users (50 people, 150 events each)..."
extra_users.each_with_index do |user, i|
  seed_people_and_events(user, people_count: 50, events_count: 150)
  print "  user #{i + 2} done\n"
end

puts ""
puts "Seed complete:"
puts "  #{User.count} users (login: #{seed_email} / #{seed_password})"
puts "  #{Person.count} people"
puts "  #{Event.count} events"
