# Changelog

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
