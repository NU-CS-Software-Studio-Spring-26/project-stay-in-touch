# Stay In Touch

[![CI](https://github.com/NU-CS-Software-Studio-Spring-26/project-stay-in-touch/actions/workflows/ci.yml/badge.svg)](https://github.com/NU-CS-Software-Studio-Spring-26/project-stay-in-touch/actions/workflows/ci.yml)

A Rails web app that helps you intentionally maintain friendships by tracking the people who matter to you, how often you'd like to reach out, and your history of catch-ups with them.

## MVP

Stay In Touch lets a user record the people they care about (with timezone, preferred call hours, and a target catch-up frequency) and log actual events (calls, coffee, group dinners, etc.) against one or more of those people. The app surfaces a "days until due" status for each person so it's obvious who you're overdue to reach out to.

The long-term vision (see `wiki.md`) builds on top of this foundation: mutual opt-in pairing, automated scheduling against Google Calendar, and gentle nudges so neither party bears the social cost of initiating a catch-up.

## Team

| Name | GitHub |
|---|---|
| Matthew Khoriaty | [@AMindToThink](https://github.com/AMindToThink) |
| Andre | [@akurdia](https://github.com/akurdia) |
| Jos Yao | [@josyao1](https://github.com/josyao1) |
| MJ Gaughan | [@mjgaughan](https://github.com/mjgaughan) |

## Live app

> Heroku URL: _TODO — add once `heroku create` is run_

## Local development

Requirements: Ruby (see `.ruby-version`), Bundler, SQLite.

```bash
bundle install
bin/rails db:setup   # creates dev + test DBs and runs seeds
bin/rails server
```

Open <http://localhost:3000>.

## Running tests

```bash
bundle exec rspec
```

Tests cover model validations, associations, helper methods, and the full CRUD request flow for both resources. The same command runs in CI on every push and pull request.

## Deployment (Heroku)

First-time setup from the project root:

```bash
heroku create stay-in-touch-<team-suffix>        # pick a unique suffix
heroku addons:create heroku-postgresql:essential-0
git push heroku claude/m0-rails-foundation:main   # or main once merged
heroku run rails db:seed
heroku open
```

The `Procfile` runs `rails db:migrate` automatically in the release phase, so subsequent deploys just need `git push heroku main`.

## Project layout

- `app/models/` - `Person`, `Event`, `EventParticipant` (join model enabling group events).
- `app/controllers/` - Thin controllers with strong params and the seven REST actions.
- `app/views/people/` and `app/views/events/` - Bootstrap 5 index, show, new, edit, and `_form` partials.
- `app/views/shared/` - Navbar and flash partials used across the app.
- `db/seeds.rb` - 12 people + 15 events, idempotent.
- `spec/` - RSpec model and request specs.
- `claude-initial-files/` - Original Python prototype and product vision for Serendipity (historical reference only).

## Communication

The team has agreed on these ground rules for the rest of the class:

- **Primary channel:** Group chat (set at project kickoff) for day-to-day coordination; GitHub Issues for tracked work.
- **Decision rule:** Lazy consensus within 24 hours. If nobody objects to a proposal in chat or on the relevant PR within 24 h, it's approved. Anything contentious moves to a majority vote in chat.
- **Response-time expectation:** Messages acknowledged within 24 h on weekdays. Urgent items (blocking a teammate) tagged `@channel` and expected sooner.
- **Standups:** Short async status update in chat every Monday and Thursday: what I shipped, what I'm working on next, anything I'm blocked on.
- **Work assignment:** Each milestone's tasks are filed as GitHub Issues and self-assigned. No issue should go more than 48 h without a "working on it" comment once assigned.
- **Code review:** At least one teammate reviews every PR before it merges to `main`. Squash-merge by default.
- **Meetings:** One 30-minute weekly sync (day/time TBD at kickoff); ad-hoc calls as needed.
