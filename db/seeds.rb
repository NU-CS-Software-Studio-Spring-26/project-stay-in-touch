# Idempotent seed script for development/test only.
# NEVER run db:seed in production — it wipes all data.
if Rails.env.production?
  puts "Skipping seeds in production."
  return
end

# Delete order respects the foreign-key graph: join rows first, then Events,
# then People, then Sessions, then Users.
puts "Clearing existing data..."
EventParticipant.delete_all
Event.delete_all
Person.delete_all
Session.delete_all
User.delete_all

seed_email    = ENV.fetch("SEED_USER_EMAIL",    "demo@example.com")
seed_password = ENV.fetch("SEED_USER_PASSWORD", "Demo1!password")

puts "Creating demo user (#{seed_email})..."
demo_user = User.create!(
  email: seed_email,
  password: seed_password,
  password_confirmation: seed_password
)

puts "Seeding people..."

people_data = [
  { name: "Alice Chen",      email: "alice.chen@example.com",    tz: "America/Chicago",     hours: [9, 21],  freq: 2.0, notes: "College roommate. Loves hiking." },
  { name: "Bob Martinez",    email: "bob.martinez@example.com",  tz: "America/Los_Angeles", hours: [8, 20],  freq: 4.0, notes: "Works in film. Prefers mornings." },
  { name: "Carla Okafor",    email: "carla.okafor@example.com",  tz: "America/New_York",    hours: [10, 22], freq: 3.0, notes: "Former coworker. Just had a kid." },
  { name: "Devon Park",      email: "devon.park@example.com",    tz: "America/Chicago",     hours: [17, 22], freq: 1.5, notes: "Grad school friend." },
  { name: "Emi Tanaka",      email: "emi.tanaka@example.com",    tz: "Asia/Tokyo",          hours: [20, 23], freq: 6.0, notes: "Met at conference in Kyoto." },
  { name: "Farah Hassan",    email: "farah.hassan@example.com",  tz: "Europe/London",       hours: [18, 22], freq: 8.0, notes: "Distant cousin. Email only." },
  { name: "Gavin O'Neill",   email: "gavin.oneill@example.com",  tz: "America/New_York",    hours: [9, 17],  freq: 4.0, notes: "Mentor from first internship." },
  { name: "Hana Patel",      email: "hana.patel@example.com",    tz: "America/Los_Angeles", hours: [10, 20], freq: 2.0, notes: "Climbing partner." },
  { name: "Ivan Kowalski",   email: "ivan.kowalski@example.com", tz: "Europe/Warsaw",       hours: [19, 23], freq: 5.0, notes: "Exchange-program friend." },
  { name: "Jamie Rivera",    email: "jamie.rivera@example.com",  tz: "America/Chicago",     hours: [12, 22], freq: 1.0, notes: "Best friend since high school." },
  { name: "Kavi Singh",      email: "kavi.singh@example.com",    tz: "America/New_York",    hours: [9, 19],  freq: 3.0, notes: "Worked together at first job." },
  { name: "Luna Ferreira",   email: "luna.ferreira@example.com", tz: "America/Sao_Paulo",   hours: [18, 23], freq: 6.0, notes: "Met while backpacking in Peru." }
]

people = people_data.map do |row|
  demo_user.people.create!(
    name: row[:name],
    email: row[:email],
    timezone: row[:tz],
    preferred_start_hour: row[:hours][0],
    preferred_end_hour: row[:hours][1],
    frequency_weeks: row[:freq],
    notes: row[:notes]
  )
end

by_name = people.index_by(&:name)

puts "Seeding events..."

events_data = [
  { title: "Phone catch-up",           medium: "call",      days_ago: 3,  participants: ["Jamie Rivera"],                                                    notes: "Talked about new apartment." },
  { title: "Coffee at Intelligentsia", medium: "coffee",    days_ago: 8,  participants: ["Alice Chen"],                                                      notes: "She's thinking of grad school." },
  { title: "Birthday dinner",          medium: "in_person", days_ago: 12, participants: ["Devon Park", "Jamie Rivera", "Alice Chen"],                        notes: "Went to the new ramen spot." },
  { title: "Quick text",               medium: "text",      days_ago: 2,  participants: ["Hana Patel"],                                                      notes: "Sent her a climbing gym link." },
  { title: "Video call with Emi",      medium: "video",     days_ago: 21, participants: ["Emi Tanaka"],                                                      notes: "She's visiting Chicago in May." },
  { title: "Lunch meeting",            medium: "in_person", days_ago: 14, participants: ["Gavin O'Neill"],                                                   notes: "Discussed career advice." },
  { title: "Conference call",          medium: "call",      days_ago: 30, participants: ["Carla Okafor", "Kavi Singh"],                                      notes: "Three-way to plan reunion." },
  { title: "Holiday group chat",       medium: "text",      days_ago: 45, participants: ["Bob Martinez", "Hana Patel", "Jamie Rivera", "Devon Park"],        notes: "Usual end-of-year check-in." },
  { title: nil,                        medium: "call",      days_ago: 9,  participants: ["Ivan Kowalski"],                                                   notes: nil },
  { title: "Hiking trip",              medium: "in_person", days_ago: 60, participants: ["Alice Chen", "Devon Park"],                                        notes: "Starved Rock. Rained but worth it." },
  { title: "Email thread",             medium: "other",     days_ago: 25, participants: ["Farah Hassan"],                                                    notes: "Sent photos from wedding." },
  { title: "Coffee with Luna",         medium: "coffee",    days_ago: 18, participants: ["Luna Ferreira"],                                                   notes: "She's in town for a week." },
  { title: "Quick call",               medium: "call",      days_ago: 5,  participants: ["Carla Okafor"],                                                    notes: "Baby photo update." },
  { title: "Group video call",         medium: "video",     days_ago: 40, participants: ["Emi Tanaka", "Ivan Kowalski", "Farah Hassan"],                     notes: "International friends check-in." },
  { title: "Drinks after work",        medium: "in_person", days_ago: 7,  participants: ["Kavi Singh", "Gavin O'Neill"],                                     notes: "Downtown happy hour." }
]

events_data.each do |row|
  participants = row[:participants].map { |name| by_name.fetch(name) }
  demo_user.events.create!(
    occurred_at: row[:days_ago].days.ago,
    medium: row[:medium],
    title: row[:title],
    notes: row[:notes],
    people: participants
  )
end

puts "Seeded 1 user (#{seed_email}), #{Person.count} people, #{Event.count} events."
