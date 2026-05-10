# Changelog

## [Unreleased]

### Changed
- RuboCop added to CI pipeline as a `lint` job; deploy gate now requires lint to pass
- Configured `.rubocop.yml` to allow `%i[ ]` / `%w[ ]` bracket style produced by Rails generators

## [v1.2.0] — 2026-05-10 — Pagination & Large Dataset Support

### Added
- Pagy pagination (25 per page) on People and Events index pages — both DB-sorted and Ruby-sorted columns work correctly
- Bootstrap pagination nav renders only when there is more than one page; empty-state messages still display correctly with zero records
- Large seed dataset: 10 demo users, 550 people, 1650 events (demo login: `demo@example.com` / `Demo1!password`; extra users `user2–10@example.com` same password)
- Faker gem added to dev/test for realistic generated names and emails

## [v1.1.0] — 2026-04-27 — User Authentication & Per-User Data

### Added
- User accounts: sign-up, login, and logout via Rails 8 session-based authentication
- All People and Events are now scoped per-user — each user sees only their own data
- IDOR prevention in EventsController: participant IDs are validated against the current user's people before saving
- Email uniqueness for People is now scoped per user (two users can each have a contact with the same email)
- Demo seed user created automatically on `db:seed`

### Changed
- People and Events tables gained a non-nullable `user_id` foreign key (added nullable in the first deploy, constraint tightened after production backfill via a follow-up migration)
- Navbar shows Login / Sign Up when logged out, and a Logout link when authenticated

## [v1.0.0] — 2026-04-22 — MVP Release

### Added
- Rails 8.1 app scaffold with RSpec testing harness and CI pipeline
- `Person`, `Event`, `EventParticipant` models with full validations and specs
- Full CRUD UI for People and Events using Bootstrap 5
- Heroku deployment config (`Procfile`, `release` step for migrations)
- GitHub Actions workflow: runs tests + security scans on every push; auto-deploys to Heroku on merge to `main`
- Realistic seed data — 12 people and 15 events with relationships
- Sortable columns on People index (name, frequency, status) and Events index (date, title, medium, participants) with ascending/descending toggle; Turbo Frame swap for no-page-reload sorting
- Initials avatars with deterministic per-person color on the People list
- Triple-dot dropdown for row actions (View / Edit / Delete) on both index pages
- Mail icon next to each email address that opens the device's default mail client
- Events can be scheduled for future dates (removed past-only restriction)
- `rescue_from ActiveRecord::RecordNotFound` — redirects with a flash alert instead of a raw error page
- Custom 404/500 static pages; production stack traces suppressed

### Changed
- Navbar restyled: white background with border, indigo accent, Log Event as primary CTA
- Status badges restyled as soft pill badges (overdue red, due-today amber, upcoming green)
- Medium badges given per-type tint colors (call, video, coffee, text, in-person, other)
- Tables use hover-only highlight instead of stripes; card borders thinned
- Font upgraded to Plus Jakarta Sans via Google Fonts
