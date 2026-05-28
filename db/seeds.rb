# Idempotent seed script for development only.
# NEVER run db:seed in production — it wipes all data.
if Rails.env.production?
  puts "Skipping seeds in production."
  return
end

require "faker"

puts "Clearing existing data..."
# Delete child rows before the users they reference so re-running db:seed on an
# already-populated dev database doesn't trip foreign-key constraints.
PersonTag.delete_all
EventParticipant.delete_all
Event.delete_all
MeetingProposal.delete_all
GoogleCredential.delete_all
Tag.delete_all
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

# ── AI matchmaking demo profiles ──────────────────────────────────────────────
# Give a handful of users opted-in matchmaking profiles so the "your AI talks to
# my AI" feature can be demoed end to end. The demo user is the natural initiator:
# log in as the demo user and click "Run matchmaking now" on the Matches page
# (requires OPENROUTER_API_KEY to be set).
#
# The pool is designed to show both outcomes:
#   • Priya and Marcus complement Maya's interests → expect an ACCEPT.
#   • Otto's interests don't overlap with anyone's → expect a DECLINE.
puts "Adding AI matchmaking demo profiles..."

demo_user.update!(
  display_name:        "Maya (demo)",
  meeting_interests:   "Final-year CS undergrad trying to break into machine " \
                       "learning research. I'd love to meet people who have done " \
                       "ML research internships or published papers and can share " \
                       "how they got started. In return I can offer hands-on help " \
                       "with Rails / full-stack web development and code review.",
  matchmaking_enabled: true
)

matchmaking_profiles = {
  extra_users[0] => { # user2@example.com — strong mutual match with Maya
    display_name:      "Priya (ML PhD)",
    meeting_interests: "Third-year machine learning PhD student. Happy to mentor " \
                       "undergrads who want to get into research and walk them " \
                       "through the paper-publishing process. In return I'm looking " \
                       "for someone who can help me build a polished web demo " \
                       "(Rails or similar) for my research project."
  },
  extra_users[1] => { # user3@example.com — also a good match for Maya
    display_name:      "Marcus (SWE)",
    meeting_interests: "Software engineer who did two ML research internships before " \
                       "moving into industry. Glad to give career and grad-school " \
                       "advice to students. Keen to sharpen my web-dev skills and " \
                       "learn modern Rails."
  },
  extra_users[2] => { # user4@example.com — deliberate mismatch; expect a decline
    display_name:      "Otto (off-topic)",
    meeting_interests: "Retired pastry chef. Looking to swap sourdough starters, " \
                       "talk competitive vegetable gardening, and find a doubles " \
                       "partner for weekend tennis."
  }
}

matchmaking_profiles.each do |user, attrs|
  user.update!(attrs.merge(matchmaking_enabled: true))
end

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
puts ""
puts "AI matchmaking demo (all use password '#{seed_password}'):"
puts "  initiator:  #{seed_email}            (Maya — run matchmaking from the Matches page)"
puts "  matches:    user2@example.com (Priya), user3@example.com (Marcus)"
puts "  mismatch:   user4@example.com (Otto)"
puts "  Requires OPENROUTER_API_KEY to be set."
