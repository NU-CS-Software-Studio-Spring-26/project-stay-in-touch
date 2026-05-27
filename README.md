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
| Rohit Katakam | [@rohitkatakam](https://github.com/rohitkatakam) |
| Joshua Yao | [@josyao1](https://github.com/josyao1) |
| Tais Martinez | [@taismartinezz](https://github.com/taismartinezz) |

## Live app
> Heroku URL: https://rocky-cove-15980-acbcac59777d.herokuapp.com/

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

## Google Calendar integration

Users can optionally connect their Google Calendar so that every new catch-up Event is automatically pushed as a calendar event. The feature is fully optional — if a user hasn't connected, the app works exactly as before.

### How it works

1. User clicks **Connect Google Calendar** on the People page.
2. They are redirected to Google's OAuth consent screen and grant the `calendar.events` scope.
3. The resulting tokens are stored in the `google_credentials` table (one record per user).
4. On every successful `Event#create`, `GoogleCalendarService#push_event` fires and creates a matching Google Calendar event using the person's timezone.

### Local setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → Create credentials → OAuth 2.0 Client ID → Web application.
2. Add `http://localhost:3000/google/oauth/callback` as an **Authorized redirect URI**.
3. Copy the credentials and set them in your environment:

```bash
cp .env.example .env
# then fill in GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI
```

4. Load them before starting the server (e.g. via `dotenv-rails`, `direnv`, or your shell profile).

### Heroku setup

```bash
heroku config:set GOOGLE_CLIENT_ID=...
heroku config:set GOOGLE_CLIENT_SECRET=...
heroku config:set GOOGLE_REDIRECT_URI=https://<your-app>.herokuapp.com/google/oauth/callback
```

Add the production redirect URI in the Google Cloud Console as well.

## AI meeting matchmaking ("your AI talks to my AI")

An opt-in feature where each user's "AI secretary" negotiates meetings with other users' secretaries. It is additive — the private per-user CRM is unchanged — and degrades gracefully when `OPENROUTER_API_KEY` is absent.

### How it works

1. On the **Settings** page a user writes what they want to get/receive from meetings and toggles **matchmaking on**. Their interests are read by other opted-in members' AI secretaries (disclosed in the UI).
2. A matchmaking round gives each opted-in user an AI secretary that is shown the other opted-in users + profiles, picks one target, and writes an invitation pitch (`Matchmaking::SecretaryPitchService`).
3. The target's AI secretary — told to screen out bad matches — accepts or declines with a reason (`Matchmaking::SecretaryReviewService`).
4. The exchange is recorded as a `MeetingProposal` on the **Matches** page for both users. On acceptance, if at least one party has Google Calendar connected, a real event is created — the connected user hosts and the other is added as an attendee by email (`RoundOrchestratorService` → `GoogleCalendarService#push_user_meeting`).

All AI calls reuse the existing OpenRouter setup (`ruby-openai` → `google/gemma-4-26b-a4b-it:free`). User emails are never sent to the model — only a display name.

### Running a matchmaking round

```bash
# All opted-in users (the daily batch):
bundle exec rake matchmaking:run

# A single user (the in-app "Run matchmaking now" button does this):
#   RunMatchmakingJob.perform_later(user_id)
```

### Scheduling the daily run

The app uses the `:async` ActiveJob adapter, which runs in-process and is tied to the web dyno — it cannot guarantee a daily run on its own. Drive `rake matchmaking:run` from an external scheduler instead:

- **Heroku Scheduler** (recommended): `heroku addons:create scheduler:standard`, then add a daily job running `bundle exec rake matchmaking:run`.
- **GitHub Actions**: a `schedule:` cron workflow running `heroku run rake matchmaking:run -a <app>`.

Set the API key in each environment:

```bash
heroku config:set OPENROUTER_API_KEY=...
```

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

## Terminology

- **Person** — A contact you want to stay in touch with. Stores `name`, `email`, `timezone` (IANA, e.g. `America/Chicago`), a preferred-hours window, and a target catch-up `frequency_weeks`. Not an authenticated user account — user accounts arrive in a later milestone.
- **Event** — A logged catch-up: call, coffee, video, text, in-person, or other. Each event has an `occurred_at`, a `medium`, an optional `title`, optional `notes`, and **one or more** participating People.
- **EventParticipant** — Join model between Person and Event. Deliberately a real model (not `has_and_belongs_to_many`) so future fields like `rsvp_status`, `role`, or `was_organizer` can be added without another migration.

More on the domain model and future direction in `wiki.md`.

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

- **Primary channel:** Slack group chat (set at project kickoff) for coordination; GitHub Issues for tracked work.
- **Decision rule:** Lazy consensus within 24 hours. If nobody objects to a proposal in chat or on the relevant PR within 24 h, it's approved. Anything contentious moves to a majority vote in chat.
- **Response-time expectation:** Messages acknowledged within 24 h on weekdays. Urgent items (blocking a teammate) tagged `@channel` and expected sooner.
- **Standups:** Short async status update in chat every Monday and Thursday: what I shipped, what I'm working on next, anything I'm blocked on.
- **Work assignment:** Tasks are claimed on a first-come, first-served basis via GitHub Issues. Once assigned, no issue should go more than 48 hours without a “working on it” update. Workload distribution will be reviewed in the next team meeting to ensure balanced contributions across all collaborators.
- **Code review:** At least one teammate reviews every PR before it merges to `main` and we also try to merge in person while checking the correct functionality. Squash-merge by default.
- **Meetings:** One 1hr weekly meeting on Tuesday from 2:30 to 3:40 pm; ad-hoc calls as needed.
