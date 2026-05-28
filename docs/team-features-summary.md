# Team Features Summary — Stay In Touch

## Joshua Yao

- **People index UI** — full table layout with color-hashed initials avatars, soft pill status badges (Overdue / Due Soon / On Track), sortable columns with Turbo Frame swaps, real-time search with debounce, tag filter chips, and favorites filter.
- **Overdue alerts** — highlighted panel at the top of the People index surfacing contacts past their catch-up deadline with direct "Log Event" links.
- **Person show page** — restructured into a card layout with contact info, streak/days-until-due stats, event history, timezone conversion (contact's local time + preferred hours converted to the user's timezone), and AI reconnect message in one view.
- **Events index UI** — per-medium color badges, medium filter bar, and a full monthly calendar grid view where events are placed on their actual days; hovering any event shows a popover with full title, people, medium, time, and notes snippet.
- **Log Event form UX** — participant search bar, person pre-fill when navigating from a contact, notes character counter, and 12-hour time select dropdowns for preferred hours.
- **Relationship health dashboard** — collapsible summary panel categorizing all contacts into Overdue / Slipping / On Track with stat cards (this month's catch-ups, streak, avg frequency, top contacts); catch-ups-per-month bar chart and by-medium pie chart (Chartkick + Groupdate); upcoming birthdays alert showing contacts with birthdays in the next 30 days; set as the app's default landing page.
- **AI reconnect messages** — integrated OpenRouter (Gemma 4) to generate a personalized reach-out suggestion on the Person show page, with one-click clipboard copy.
- **Contact import** — CSV and vCard (.vcf) upload flow with smart header normalization (Google Contacts and Apple Contacts formats), duplicate detection, and a results summary.
- **Birthday tracking** — birthday field on contacts with inline save on the show page; 🎂 indicator next to names on the People list for anyone with a birthday in the next 30 days; birthday badge on the show page counting down days.
- **Login & signup UI** — redesigned as a split-panel layout with brand panel on the left and form on the right.
- **PWA & mobile** — web manifest, service worker with offline cache, and offline fallback page; app is installable via "Add to Home Screen" on iOS and Android; custom app logo and icon.
- **Tags** — tags management page (rename, delete, person count), inline toggle-tag on People.
- **Pagination & seed data** — Pagy pagination (25/page) on People and Events; large seed dataset (10 users, 550 people, 1650 events) for load testing and demos.
- **Polish & quality** — About + Privacy Policy pages, footer links, server-side field length limits, name/title whitespace normalization, RuboCop CI job, custom 404/500 pages, `rescue_from RecordNotFound`.
- **Frontend modernization** — fixed sidebar nav (desktop) + offcanvas drawer (mobile) replacing top navbar; indigo-tinted page background bridging sidebar to content; dashboard greeting hero; icon-forward stat cards; card-row people table where each row floats as its own surface; frameless pill search bar and filter chips; on-theme pagination.

---

## Rohit Katakam

- **User authentication & per-user data scoping** — Devise-based sign-up/login with full per-user isolation of contacts and events; safe NOT NULL migration on `user_id` columns via a backfill-then-constrain approach; changelog entry documenting the deployment steps.
- **Password reset flow** — email-based password reset with `reset_token` and `reset_token_expires_at` columns, a request form, and a reset form with token validation and expiry enforcement.
- **Accessibility fixes** — fixed two WCAG violations: associated the Participants label to its multi-select checkboxes (1.3.1) and added `aria-label` to icon-only dropdown trigger buttons (4.1.2).
- **Real-time person search** — debounced live search on the People index using a Stimulus controller + Turbo Frames; filters the contact table without a page reload.
- **Favorite/star contacts** — boolean `favorite` column with a star toggle button on each person row; favorited contacts are pinned to the top of the People list.
- **AI reconnect message suggestions** — AI-generated short, personalized reach-out message on the Person show page, pre-populated in an editable textarea with one-click clipboard copy.
- **Calendar-based meeting time recommendations** — queries Google Calendar free/busy for both the user and the contact, then surfaces open slots on the Person show page as clickable suggested times.
- **Quick Log Modal** — Turbo Frame modal that lets users log a catch-up directly from the People list or overdue banner without navigating away; refined in a follow-up iteration with improved UX.
- **Suggested time slot → Quick Log pre-fill** — clicking a suggested calendar slot on the Person show page opens the Quick Log modal pre-filled with that exact datetime, removing double-entry.
- **Activity timeline** — chronological feed view accessible from the dashboard; all events grouped by week so users can browse their relationship history at a glance.
- **Snooze contacts** — "Snooze" button on the Person show page writes a `snoozed_until` date that suppresses the contact from the overdue list until that date.
- **Inline notes editing** — edit a person's notes directly on the show page via an inline Turbo Frame; no navigation to the full edit form required.
- **ERB-Lint CI job** — added `erb_lint` to the CI pipeline alongside RuboCop so ERB templates are linted on every push.
- **Analytics/activity dashboard** — dashboard page with engagement metrics: catch-ups logged this month, most-frequently-contacted people, and streak stats.

---

## Tais Martinez

- **Google Calendar integration** — full OAuth flow with a `GoogleCredential` model storing tokens, `GoogleCalendarService` to push events to the user's calendar on creation, OAuth callback controller and routes, "Connect Google Calendar" button on the People index, and RSpec tests for the service.
- **Sign in with Google** — added Google OAuth to the login and signup pages as an alternative to email/password authentication; guarded against missing env vars in production.
- **Session security** — sessions expire after 30 days; guarded seeds against running in production; added SRI integrity hash to the Bootstrap Icons CDN link.
- **Password strength UI** — live checklist that validates complexity requirements as the user types, with show/hide toggle extended to the confirm password field.
- **Accessibility improvements** — added `aria-labels` to icon-only buttons and status badge icons to meet WCAG guidelines.
- **Log Event form redesign** — calendar-aware scheduling with 15-minute slot suggestions pulled from Google Calendar free/busy data, iCal invite generation, duration field, and timezone bug fix.
- **Email delivery via Gmail SMTP** — configured Action Mailer to send emails through Gmail in production, enabling iCal invites and future notifications to reach users.
- **Events index polish** — converted to a single scrollable page, fixed event display title and dropdown overflow, updated datetime format to 12-hour MM/DD display, and renamed table headers.
- **Gravatar avatars on People index** — auto-loads each contact's Gravatar from their email with a colored-initials fallback.
- **CSV export for contacts** — "Export CSV" button downloads all contacts with name, email, tags, and last contact date.
- **Weekly catch-ups chart on dashboard** — line chart showing catch-ups per week over the last 12 weeks using `chartkick` and `groupdate`.
- **AI conversation topic suggestions on Log Event form** — `TopicSuggestionService` queries the OpenRouter API from the contact's previous notes and surfaces 2–3 clickable chips via a custom Stimulus controller.
- **RuboCop linting CI workflow** — standalone `lint.yml` GitHub Actions workflow running RuboCop on every push and pull request to main.

---

## Matthew Khoriaty

- **AI-negotiated meeting matchmaking (#141, #143)** — opt-in feature where each user's "AI secretary" picks a target from other opted-in users, writes a pitch, and the target's secretary accepts or declines with a reason; recorded as a `MeetingProposal` on a new **Matches** page and, on acceptance, pushed to Google Calendar (host's calendar; other party invited by email). Includes `display_name` / `meeting_interests` / `matchmaking_enabled` fields, three services under `app/services/matchmaking/`, a daily rake task (`matchmaking:run`) and `RunMatchmakingJob`, an in-app "Run matchmaking now" button for demos, OpenRouter integration that degrades gracefully without an API key, retry-on-rate-limit, and seeded demo profiles.
- **Initial project scaffold** — Rails 8.1 app with RSpec harness; Person, Event, EventParticipant models with specs; initial People/Events CRUD UI with Bootstrap; first seed dataset of 12 people and 15 events with realistic relationships.
- **CI/CD & secret scanning (PR #16)** — Heroku deployment config, RSpec test job in CI, gitleaks CI scan with the binary pinned directly (no paid action license), and Overcommit local hook for fast-feedback pre-commit checks.
- **Accessibility — skip link, focus indicator, AAA contrast, plain copy (PRs #75, #76, #77, #78)** — skip-to-main-content link for keyboard users; consistent `:focus-visible` indicator across focusable elements; recolored buttons, links, and muted text to clear WCAG AAA (7:1) on white; rewrote About + Privacy copy to remove passive voice and Hemingway "hard-to-read" sentences.
- **Match contacts to users (PR #139, #89, #90)** — when a Person record matches a signed-up User by email, scheduling honors *both* calendars (host + invitee free/busy intersection) and the calendar invite is accompanied by a sign-up-encouraging email when the invitee isn't on the platform yet.
- **Rebrand to "Serendipity" with custom logo (PR #135, #95, #115)** — designed a cup-and-clover logo (SVG full lockup + icon-only mark), regenerated favicons/PWA icons, renamed the product across navbar, layout, login/signup, mailers, About/Privacy, README, wiki, and PWA manifest, and wrote `docs/MAKING_LOGOS.md` for future logo work.
- **M2 hardening (PR #142)** — scaled seed dataset, CSV upload size/row limits, event-duration validation, and edit-form UX fixes (live tag toggle, unsaved-changes banner pinned while scrolling).
- **Seed production guard + schema docs (PR #140, #23, #24)** — `db/seeds.rb` refuses to run in production unless an explicit override is set; added `docs/schema.md` describing tables and relationships; replaced lorem ipsum with realistic catch-up text so demos read naturally.
- **Security patches (PR #137)** — bumped `jwt` to 3.2.0 and `faraday` to 2.14.2 for CVEs, fixed the Google OAuth callback path in `.env.example`, and guarded external calendar-link `href`s against `javascript:` URLs.
- **Documentation & teammate handoff** — wrote the README and project wiki (problem statement, OO design, post-M0 roadmap, similar-products comparison), later elevating user auth and Google Calendar to M1 priorities with concrete scope; authored most GitHub issues used by other team members for milestone planning.
