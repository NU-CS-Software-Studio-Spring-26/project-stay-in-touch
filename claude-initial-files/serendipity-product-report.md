# Serendipity: A Product Report

*Automatic social reconnection for people who want to stay in touch but never reach out*

---

## 1. The Problem

Maintaining friendships across distance and time is one of the most universally acknowledged-yet-unsolved problems in social life. The friction is not that people don't care. It's that reaching out after a long silence carries psychological costs:

- **Initiation asymmetry**: Someone has to be "the one" who reaches out, which feels increasingly awkward as time passes.
- **Exponential awkwardness decay**: The longer you wait, the harder it gets, creating a vicious cycle where the optimal strategy (call now) is perpetually deferred.
- **Scheduling coordination**: Even when motivation exists, finding a mutually available time across time zones and busy calendars is its own barrier.
- **No natural forcing function**: In school or at work, relationships are maintained by proximity and shared structure. After those structures dissolve, there is nothing to replace them.

The result is predictable and well-documented: people lose touch with friends they genuinely care about, not because the relationship died, but because nobody overcame the activation energy to maintain it.

## 2. The Insight

The core insight behind this product is not "people need reminders to call their friends." That's what existing apps do, and it's insufficient, because the reminder still leaves you staring at your phone thinking "...but what do I even say after 8 months?"

The real insight is: **if a third party schedules the interaction, neither person bears the social cost of initiating.** Both parties show up with the implicit understanding: "The system paired us. I didn't have to be the one to reach out, and neither did you." This is psychologically distinct from every existing product in the space.

This is the same dynamic that makes bumping into someone at a coffee shop feel easy and natural while calling that same person feels like a big deal. The encounter is *not your fault*, so there's no awkwardness about it. Serendipity manufactures that feeling.

## 3. Competitive Landscape

### 3.1 Existing Categories

**Reminder/Tracker Apps** (Fabriq, SoonCall, Smart Contact Reminder, Call Your Friends)
These apps let you set frequencies for how often you want to contact someone and then nudge you when it's time. They are single-player tools: only you use them, the other person has no idea, and you still bear 100% of the initiation cost. They solve the "I forgot" problem but not the "it's awkward" problem.

**Availability Broadcasting** (CallMe)
CallMe lets you signal when you're free to talk, and friends can see that and call you. This is closer to the right idea, but it's still passive. Someone still has to decide to open the app and make the call. It also requires both parties to have the app.

**Friend-Making Apps** (Bumble BFF, 222, Timeleft, We3)
These match strangers for new connections. Completely different use case: they're for expanding your network, not maintaining your existing one.

**Coordination/Calendar Apps** (Howbout, Doodle, Calendly)
These solve the logistics of scheduling when both parties already want to meet. They don't solve motivation or initiation.

### 3.2 The Gap

No existing product combines:
1. **Bilateral opt-in** among existing contacts (not strangers)
2. **Automatic scheduling** that removes initiation burden from both parties
3. **Calendar integration** to find mutually available times
4. **Serendipity** as a deliberate design choice rather than predictable reminders
5. **Privacy** of individual frequency preferences

## 4. Product Design

### 4.1 Working Name

"Serendipity." The name evokes the feeling of a happy accident rather than a scheduled obligation.

### 4.2 Target Audience

Young professionals (22-30) who recently graduated or moved cities, losing touch with school and previous-job friends. The initial deployment targets technically able friends who are comfortable sharing a Google Calendar and filling out a form. This audience lets us validate the core loop with minimal infrastructure.

### 4.3 Core Loop

1. **User fills out a Google Form** with their name, email, preferred call hours, and a list of contacts with desired frequencies.
2. **A daily cron job** reads form responses from a Google Sheet, finds mutual pairs (A listed B AND B listed A), and checks both calendars for free time.
3. **The scheduler picks a random free slot** and creates a Google Calendar event with a Google Meet link. Both parties receive an email invitation.
4. **The call happens.** The event just shows up on your calendar, like bumping into someone.
5. **Post-call feedback (planned).** After the call, each participant can adjust frequency preferences via a lightweight mechanism (link in the calendar event description to a short feedback form, or re-submitting the main form with updated frequencies).
6. **The cycle repeats**, with frequency influenced by mutual preferences and randomized timing.

### 4.4 The Serendipity Engine

The scheduling algorithm is central to the experience. Key design principles:

**Randomized timing within frequency bounds.** If two people both say "every 2-3 months," the scheduler does not place a call on exactly the same day every quarter. Instead, it checks daily whether a pair is "due" with a jitter factor of ±30%, so the timing feels unpredictable.

**Geometric mean for frequency merging.** If user A says "every 3 weeks" and user B says "every 6 weeks," the scheduler uses:

$$\mu_{AB} = \sqrt{\mu_A \cdot \mu_B} = \sqrt{3 \cdot 6} \approx 4.2 \text{ weeks}$$

The geometric mean handles asymmetric preferences gracefully: it's pulled toward the lower frequency (respecting the person who wants less contact) without ignoring the person who wants more. An alternative is $\mu_{AB} = \max(\mu_A, \mu_B)$ (never contact anyone more than they asked for), which is more conservative. The right choice is worth A/B testing.

**Time-of-day awareness.** Each user specifies preferred call hours (e.g., "17-21"). The scheduler only picks slots within the overlap of both parties' preferred windows. If there's no overlap, it falls back to the union.

**Random slot selection.** When multiple free slots are available, the scheduler picks one at random rather than always choosing the earliest. This further preserves the serendipity feeling.

### 4.5 Privacy

A critical design constraint: **no user should see another user's frequency preferences.** You shouldn't know that your friend set you to "every 12 weeks" while you set them to "every 2 weeks."

This informed the architecture choice. Preferences live in a Google Sheet (populated by a Google Form) that only the admin and service account can read. Individual frequency preferences are never exposed. The scheduler uses the geometric mean internally; neither party knows the other's input.

We explicitly rejected a shared-config-repo model (where each user commits a YAML file) because it would expose preferences to anyone with repo access.

### 4.6 Blocking and Safety

- **Block**: Don't list someone in your form response. Since scheduling requires mutual opt-in, this is sufficient.
- **Mute**: Temporarily remove someone and re-add them later via the pre-fill link.
- **Opt out entirely**: Revoke calendar sharing with the service account and stop submitting the form.

## 5. Technical Architecture (Current MVP)

### 5.1 Design Philosophy

The MVP is deliberately lightweight. The target users are technically able friends, so we optimized for speed of buildability and minimal ongoing maintenance rather than polished UX. No mobile app, no backend server, no database. Just a Python script, a Google Form, and a cron job.

### 5.2 Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Preference input | Google Form → Google Sheet | Users enter/update who they want to talk to and how often |
| Preference updates | Pre-fill link generator script | Generates personalized URLs so users can re-submit with existing data pre-populated |
| Scheduling logic | Python script (`scheduler.py`) | Finds mutual pairs, queries calendars, creates events |
| Calendar integration | Google Calendar API (free/busy + event creation) via service account | Checks availability, creates events with Meet links |
| Orchestration | GitHub Actions (daily cron) | Runs the scheduler automatically |
| State persistence | `state.json` committed to the repo | Tracks when each pair last talked |

### 5.3 Data Flow

```
Google Form
    ↓ (responses)
Google Sheet (private, shared only with service account)
    ↓ (read by)
scheduler.py (runs daily via GitHub Actions)
    ↓ (queries)
Google Calendar free/busy API
    ↓ (creates)
Calendar events with Meet links → email invitations to both parties
    ↓ (persists)
state.json (committed back to repo)
```

### 5.4 Service Account Setup

The Google Cloud service account needs:
- **No IAM roles** (it doesn't access Google Cloud resources)
- **Google Calendar API** enabled on the project
- **Google Sheets API** enabled on the project
- Each participant shares their calendar with the service account email ("See all event details" permission)
- The response spreadsheet is shared with the service account email (Viewer access)

### 5.5 GitHub Actions Secrets

| Secret | Value |
|--------|-------|
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Full contents of the service account JSON key file |
| `SPREADSHEET_ID` | The Google Sheet ID from the form's response spreadsheet URL |
| `FORM_URL` | The Google Form `/viewform` URL (for pre-fill link generation) |
| `ENTRY_IDS_JSON` | JSON array of `entry.XXXXXXX` IDs from the form (for pre-fill link generation) |

### 5.6 Scheduling Algorithm (V1)

1. Nightly batch job runs via GitHub Actions.
2. For each active mutual pair, compute `days_since_last_call` and compare to `effective_frequency`.
3. If `days_since_last_call > effective_frequency × (1 ± 0.3 jitter)`, mark the pair as "due."
4. For "due" pairs, query both calendars for free slots in the next 7 days within both parties' preferred hours.
5. Pick a random slot from available options.
6. Create a calendar event with a Google Meet link, sending email invitations to both parties.
7. Update `state.json` with the scheduled time.

## 6. Files in This Repo

| File | Purpose |
|------|---------|
| `scripts/scheduler.py` | Main scheduling script. Reads sheet, finds pairs, queries calendars, creates events. |
| `scripts/generate_prefill_links.py` | Generates personalized pre-fill URLs for each user to update their form responses. |
| `.github/workflows/schedule.yml` | GitHub Actions workflow. Daily cron trigger at 7am UTC. |
| `requirements.txt` | Python dependencies (google-api-python-client, google-auth, pyyaml). |
| `state.json` | Persistent state tracking last call dates and scheduled events. |
| `README.md` | Setup instructions, usage guide, FAQ. |
| `serendipity-product-report.md` | This document. |

## 7. Remaining Work and Future Improvements

### 7.1 Immediate (before first real use)

- **Setup**: Create Google Cloud service account, Google Form, push to private repo, add secrets.
- **Test run**: Invite 2-3 friends, do a dry run, verify events appear correctly.
- **Post-call feedback loop**: Add a lightweight way for users to adjust frequency after a call (see §7.2).

### 7.2 Post-call feedback loop (not yet implemented)

The original product vision includes a feedback step after each call where both parties can indicate "talk more often / just right / talk less often." This closes the loop so preferences evolve based on actual experience rather than upfront guesses.

Options for implementing this in the lightweight MVP:

1. **Link in the calendar event description** to a short one-question Google Form ("How was your call with [name]? Talk more / Just right / Talk less"). The scheduler reads responses and adjusts the effective frequency. This is the most frictionless option.
2. **Reminder to re-submit the main form** with updated frequencies, sent via the pre-fill link. Lower engineering effort but higher user effort.
3. **A separate "feedback" Google Form** per pair, auto-generated by the scheduler. More infrastructure but cleaner data.

Option 1 is probably the right starting point.

### 7.3 Near-term enhancements

- **Automatic decay**: If someone repeatedly declines events with a specific contact, automatically increase the interval (e.g., double after each miss).
- **"Not today" rescheduling**: A low-friction way to decline a specific event and have the scheduler automatically propose a new time.
- **Surprise mode**: Instead of placing events days in advance, notify users the morning of or 1-2 hours before, to better simulate the "bumping into someone" feeling. Tension: some people want advance notice. Should be a per-user setting.
- **Automated pre-fill link emails**: The cron job could periodically email each participant their pre-fill link with a summary of current preferences, making updates even more frictionless.

### 7.4 Longer-term (if the concept validates)

- **Web app or mobile app**: Self-service onboarding, in-app preference management, eliminating the Google Form.
- **SMS bridge for non-users**: Reach people who haven't signed up by sending SMS invitations. The original product design explored this in detail: Contact B would receive an SMS like "Your friend [A's name] uses Serendipity and wants to catch up. Are you free [proposed time]? Reply YES/LATER/STOP." This was deferred for the MVP due to complexity, spam risk, and TCPA compliance requirements.
- **Revenue model**: Freemium ($4.99/month premium with unlimited contacts, advanced scheduling, analytics). The current version runs entirely on free-tier infrastructure, but SMS costs would require monetization at scale. Unit economics are favorable: ~95% margin at $4.99/month after SMS and hosting costs.
- **More sophisticated scheduling**: Constraint satisfaction, learning from acceptance/decline patterns, reinforcement learning on call quality signals.
- **Group calls**: Scheduling 3-person catch-ups, not just pairs.

## 8. Open Questions and Risks

1. **Will the "manufactured serendipity" framing resonate?** The only way to know is to test with real users.

2. **Calendar sharing friction.** The main onboarding hurdle is asking friends to share their Google Calendar with a service account email. This is a mildly unusual ask even for technical people. If someone doesn't share their calendar, the scheduler assumes they're always free, which leads to conflicting events. Consider whether to skip free/busy entirely for V1 and just schedule during stated preferred hours.

3. **Mismatched expectations.** User A sets Contact B to "every 2 weeks" but B thinks of A as a twice-a-year friend. The geometric mean smooths this, but the emotional mismatch could still be uncomfortable. The privacy of preferences helps (neither knows the other's setting), but the mismatch in enthusiasm may become apparent over time.

4. **Time zone complexity.** If two friends are in very different time zones, overlapping preferred hours may be very narrow or nonexistent. The current fallback (use the union of preferred hours) isn't ideal.

5. **State management.** `state.json` is committed to the repo by GitHub Actions. This works but is fragile (merge conflicts if the workflow runs while someone is pushing, though unlikely). A database would be more robust but adds infrastructure.

6. **Post-call feedback loop is missing from V1.** Without it, preferences are static unless someone proactively re-submits the form. Adding even a simple feedback mechanism would close the loop from the original product vision.

## 9. Original Product Vision (for reference)

The initial concept was a full consumer mobile app with:
- Contact import from phone and social media
- In-app calendar integration (Google + Apple)
- SMS bridge to reach non-users (Twilio-based, with warm contextual messages)
- Post-call in-app feedback prompts
- React Native (Expo) frontend, Node.js backend, Supabase (PostgreSQL) database
- Freemium subscription model
- Network-effects-driven growth via the SMS bridge viral loop

This was scoped down to the current Google Form + Python + GitHub Actions approach after deciding to target technically able friends first. The full app vision remains relevant if the core loop validates and the user base grows beyond the initial friend group. The estimated timeline for the full app was 6-8 weeks with Claude Code as the primary implementer; the lightweight MVP was built in a single session.
