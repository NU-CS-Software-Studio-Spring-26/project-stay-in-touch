# Serendipity - Project Wiki

## Problem

Friendships take effort to maintain, and that effort is asymmetric: initiating a catch-up feels weirder the longer it's been, so both sides wait, and the relationship quietly cools. Calendar reminders ("call Alice every 4 weeks") feel cold, and a scheduled block on the calendar without a warm reason to reach out tends to get skipped.

Serendipity (formerly "Stay In Touch") is the Software Studio team's attempt at a small tool that removes the social cost of initiating a catch-up while keeping the interaction itself feeling natural - not robotically scheduled.

## Milestone 0 scope

M0 is a minimal web app that delivers the data plumbing and UI needed for later milestones:

- Track the **people** you want to stay in touch with (name, email, timezone, preferred hours, target catch-up frequency).
- Log **events** - calls, coffee, group dinners, texts - against one or more of those people.
- See a "days until due" indicator for each person based on `frequency_weeks` and the most recent event.
- Full CRUD over both resources, seeded with realistic data, deployed to Heroku, covered with RSpec tests running in GitHub Actions.

M0 does **not** include any external integrations (Google Calendar, email, mutual-pair discovery, scheduling). Those are roadmap items described below.

## Object-oriented design

The domain has two primary classes plus one join model:

```
Person 1 --- * EventParticipant * --- 1 Event
  name                                    occurred_at
  email                                   medium
  timezone                                title
  preferred_start_hour                    notes
  preferred_end_hour
  frequency_weeks
  notes
```

- A `Person` has many `Event`s **through** the `EventParticipant` join model. This supports group events - one `Event` ("birthday dinner") naturally involves multiple `Person` records.
- `EventParticipant` is an explicit model rather than a `has_and_belongs_to_many` so future fields (`rsvp_status`, `role`, `was_organizer`) can be added without restructuring the schema.
- `Person` exposes two derived methods, `#latest_event` and `#days_until_due`, that read from the join rather than caching state. This keeps the schema simple and lets us change the "due" policy later without migration.

### Future classes sketched in the Python prototype

See `claude-initial-files/scheduler.py` for the original Serendipity design, which anticipates these additional classes post-M0:

- `User` - an authenticated account holder (distinct from a generic `Person`). Authorization likely via Rails 8's built-in generators or Devise.
- `Pairing` - a bidirectional edge between two `User`s (A wants to catch up with B **and** B wants to catch up with A). The geometric-mean `effective_frequency_days = sqrt(a.frequency * b.frequency)` lives here.
- `ScheduledCall` - a concrete auto-scheduled catch-up with a Google Calendar event id and Meet link. Analogous to today's `Event` but forward-dated.
- `AvailabilityWindow` - a per-user free/busy view built from Google Calendar, used to pick a slot.

### Miro board

_TODO: add link to team Miro board with class diagram and user flow._

## Future features (post-M0 roadmap)

Rough order; details in the Python prototype.

1. **User authentication.** Bring auth in before multi-user features so every Person is owned by a User.
2. **Mutual opt-in pairing.** Only schedule catch-ups when both parties have listed each other. Compute effective frequency as the geometric mean of each party's preference (per the Python prototype).
3. **"Who to reach out to" page.** Personalized feed sorted by days-overdue.
4. **Google Calendar integration.** Read free/busy windows for both parties over the next 7 days, intersected with both users' preferred hours.
5. **Automatic scheduler.** Daily job (Heroku Scheduler) that picks mutual pairs due for catch-up, drops a random slot in both calendars with a Meet link, and emails both parties. The slot randomness preserves the "manufactured serendipity" feel.
6. **Notifications.** Gentle email nudges when someone is significantly overdue.
7. **Admin dashboard.** Moderation / debugging / seeding scheduled calls manually.
8. **Mobile-first UX polish.** The Bootstrap base is responsive; add PWA install, offline-friendly viewing, timezone-aware form UX.

## Similar products

- **Monaru** - CRM for personal relationships; heavy on journaling, less on scheduling.
- **Dex** - "personal CRM" with reminders; manual, no automated scheduling.
- **Clay** - relationship graph pulled from email/social; focus is discovery, not maintenance.
- **UpHabit** - reminder-based check-in cadence app; no calendar integration.
- **Nat.app** - Notion-style relationship notebook.

Our differentiator: **manufactured serendipity**. The app proposes and confirms a real slot without either party having to initiate, and presents it as "hey, both of you are free Thursday at 7 - talk then?" instead of "you have not contacted Alice in 28 days."

## References

- Python prototype and product report: `claude-initial-files/` (not deployed; kept for design continuity).
- Core scheduling algorithm: `claude-initial-files/scheduler.py` lines 403-518 (geometric-mean frequency, jittered due-check, random slot selection).
- Class deliverable: `initial-deliverable.txt`.
