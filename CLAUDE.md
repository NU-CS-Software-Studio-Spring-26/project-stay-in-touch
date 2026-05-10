# CLAUDE.md — Stay In Touch

Personal CRM for tracking catch-ups with friends and contacts. Built with Rails 8.1, deployed on Heroku. Northwestern CS Software Studio, Spring 2026.

## Common commands

```bash
bin/rails server          # start dev server on localhost:3000
bundle exec rspec         # run all tests
bin/rails db:seed         # seed 12 people + 15 events
bin/rails db:reset        # drop, recreate, migrate, seed
bin/brakeman --no-pager   # security scan
bin/bundler-audit         # gem vulnerability scan
bin/importmap audit       # JS dependency scan
```

## Tech stack

- **Rails 8.1** — API + views (no Node, no webpack)
- **SQLite** in dev/test, **PostgreSQL** on Heroku (via `pg` gem)
- **Bootstrap 5** via CDN + custom CSS at `app/assets/stylesheets/app.css`
- **Bootstrap Icons** via CDN for the envelope icon
- **Plus Jakarta Sans** via Google Fonts
- **Hotwire** (Turbo Frames for sort-without-reload, no Stimulus yet)
- **RSpec + FactoryBot + Shoulda Matchers** for testing
- **Propshaft** asset pipeline (no preprocessing — plain CSS only)

## Data model

```
Person
  name, email (unique), timezone (IANA), frequency_weeks,
  preferred_start_hour, preferred_end_hour, notes
  has_many :events, through: :event_participants
  #days_until_due  → nil (no events) | negative (overdue) | positive (days left)
  #latest_event    → most recent Event, works with preloaded associations

Event
  occurred_at, medium (call/coffee/text/video/in_person/other), title, notes
  has_many :people, through: :event_participants
  #display_title   → title.presence || "<medium> on <date>"
  scope :recent    → order by occurred_at desc

EventParticipant  (join table)
  person_id, event_id  — unique composite index
```

## Key files

| Path | Purpose |
|------|---------|
| `app/models/person.rb` | `days_until_due`, `latest_event` |
| `app/models/event.rb` | validations, `display_title`, `recent` scope |
| `app/controllers/people_controller.rb` | sort by name/frequency/status (Ruby sort for status) |
| `app/controllers/events_controller.rb` | sort by date/title/medium/participants |
| `app/controllers/application_controller.rb` | `rescue_from RecordNotFound` → redirect with flash |
| `app/helpers/application_helper.rb` | `days_until_due_badge`, `medium_badge_class`, `flash_bootstrap_class` |
| `app/views/people/index.html.erb` | Turbo Frame `people-table`, sort links, initials avatars, ⋯ dropdown |
| `app/views/events/index.html.erb` | sort links, ⋯ dropdown |
| `app/views/shared/_navbar.html.erb` | white navbar, primary CTA = Log Event |
| `app/assets/stylesheets/app.css` | all custom styles — Bootstrap variable overrides, badge classes, avatar |
| `config/routes.rb` | `resources :people`, `resources :events`, root → `people#index` |
| `.github/workflows/ci.yml` | test + security scans → deploy to Heroku on merge to main |

## Sorting

**People index** — `?sort=name|frequency|status&direction=asc|desc`
- `name`, `frequency` → DB `ORDER BY`
- `status` → Ruby sort on `days_until_due` (nil sorts last via `-Float::INFINITY`)
- Turbo Frame `people-table` wraps the table so sort is a partial swap

**Events index** — `?sort=date|title|medium|participants&direction=asc|desc`
- `date`, `medium` → DB `ORDER BY`
- `title` → `COALESCE(NULLIF(title, ''), medium)` SQL sort
- `participants` → Ruby sort on first participant name (events preloaded with `:people`)

## Styling conventions

Custom badge classes (defined in `app.css`, returned by helpers):
- `badge-overdue` — red tint
- `badge-due-today` — amber tint
- `badge-upcoming` — green tint
- `badge-none` — gray (no events yet)
- `badge-medium-{call,video,coffee,text,in-person,other}` — per-type tints

Avatar colors are deterministic: `avatar_colors[person.name.bytes.sum % avatar_colors.length]`.

## Deployment

- **Heroku app**: `stay-in-touch-cs396`
- Push to `main` → CI runs → if all pass, `git push heroku HEAD:main --force`
- Secrets required in GitHub: `HEROKU_API_KEY`, `HEROKU_EMAIL`
- Production uses `memory_store` cache and `:async` job adapter (no Solid Queue)
- `Procfile`: `web` starts Rails, `release` runs `db:migrate`

## Test setup

Factories in `spec/factories/`. RSpec config in `spec/rails_helper.rb`.
Run a single spec: `bundle exec rspec spec/models/event_spec.rb`.
