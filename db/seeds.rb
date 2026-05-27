# Idempotent seed script for development only.
# NEVER run db:seed in production — it wipes all data.
if Rails.env.production?
  puts "Skipping seeds in production."
  return
end

require "faker"
require "bcrypt"

# ── Scale knobs ───────────────────────────────────────────────────────────────
# Defaults are sized to make pagination and performance issues visible during
# development (1000+ users, 1000+ people/events). Override any of them to seed a
# lighter or heavier dataset, e.g.  SEED_USERS=50 bin/rails db:seed
TOTAL_USERS  = Integer(ENV.fetch("SEED_USERS",        "1000"))  # incl. demo + rich users
RICH_USERS   = Integer(ENV.fetch("SEED_RICH_USERS",   "9"))     # users with full people+events
DEMO_PEOPLE  = Integer(ENV.fetch("SEED_DEMO_PEOPLE",  "200"))   # 8 pages at 25/page
DEMO_EVENTS  = Integer(ENV.fetch("SEED_DEMO_EVENTS",  "800"))
RICH_PEOPLE  = Integer(ENV.fetch("SEED_RICH_PEOPLE",  "40"))
RICH_EVENTS  = Integer(ENV.fetch("SEED_RICH_EVENTS",  "80"))

TIMEZONES = %w[America/Chicago America/New_York America/Los_Angeles America/Denver
               Europe/London Europe/Paris Asia/Tokyo Asia/Singapore].freeze
MEDIUMS   = Event::MEDIA.freeze
FREQ_OPTS = [1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0].freeze

# ── Clear existing data ───────────────────────────────────────────────────────
# Order matters: delete_all does not fire association callbacks, so children
# (and FK-referencing rows like tags) must go before their parents or the
# foreign keys will reject the delete.
puts "Clearing existing data..."
[ EventParticipant, Event, PersonTag, Tag, GoogleCredential, Session, Person, User ].each(&:delete_all)

# ── Demo user (known credentials for easy dev login) ──────────────────────────
seed_email    = ENV.fetch("SEED_USER_EMAIL",    "demo@example.com")
seed_password = ENV.fetch("SEED_USER_PASSWORD", "Demo1!password")

puts "Creating demo user (#{seed_email})..."
demo_user = User.create!(
  email: seed_email,
  password: seed_password,
  password_confirmation: seed_password
)

# ── Rich users (full people + events, to test multi-user isolation) ───────────
puts "Creating #{RICH_USERS} rich users..."
rich_users = RICH_USERS.times.map do |i|
  User.create!(
    email: "user#{i + 2}@example.com",
    password: "Demo1!password",
    password_confirmation: "Demo1!password"
  )
end

# ── Helper: seed people + events for one user ─────────────────────────────────
def seed_people_and_events(user, people_count:, events_count:)
  people = people_count.times.map do
    user.people.create!(
      name:                 Faker::Name.unique.name,
      email:                Faker::Internet.unique.email,
      timezone:             TIMEZONES.sample,
      preferred_start_hour: [ 8, 9, 10 ].sample,
      preferred_end_hour:   [ 20, 21, 22 ].sample,
      frequency_weeks:      FREQ_OPTS.sample,
      favorite:             rand < 0.15,
      birthday:             (rand < 0.3 ? Faker::Date.birthday(min_age: 18, max_age: 75) : nil),
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

# One transaction around all the create! work — on SQLite this turns thousands
# of per-row commits into a single commit and cuts seed time dramatically.
ActiveRecord::Base.transaction do
  puts "Seeding demo user with #{DEMO_PEOPLE} people and #{DEMO_EVENTS} events..."
  seed_people_and_events(demo_user, people_count: DEMO_PEOPLE, events_count: DEMO_EVENTS)

  puts "Seeding rich users (#{RICH_PEOPLE} people, #{RICH_EVENTS} events each)..."
  rich_users.each_with_index do |user, i|
    seed_people_and_events(user, people_count: RICH_PEOPLE, events_count: RICH_EVENTS)
    print "  user #{i + 2} done\n"
  end
end

# ── Bulk "scale" users (to populate the users table to 1000+) ─────────────────
# These exist purely to exercise table scale and cross-tenant isolation, so we
# skip the per-record cost of bcrypt + the default-tags callback: every row
# shares one precomputed password digest and is written in a single insert_all.
bulk_count = TOTAL_USERS - 1 - rich_users.size
if bulk_count.positive?
  puts "Bulk-inserting #{bulk_count} scale users (shared password digest)..."
  shared_digest = BCrypt::Password.create("Demo1!password")
  now = Time.current
  rows = (1..bulk_count).map do |n|
    {
      email:           "scale_user_#{n}@example.com",
      password_digest: shared_digest,
      timezone:        TIMEZONES.sample,
      created_at:      now,
      updated_at:      now
    }
  end
  rows.each_slice(1_000) { |slice| User.insert_all(slice) }
end

puts ""
puts "Seed complete:"
puts "  #{User.count} users (login: #{seed_email} / #{seed_password})"
puts "  #{Person.count} people"
puts "  #{Event.count} events"
puts "  #{Tag.count} tags, #{EventParticipant.count} event participants"
