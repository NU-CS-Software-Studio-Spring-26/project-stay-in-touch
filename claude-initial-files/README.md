# Serendipity

Automatically schedules catch-up calls between friends who both want to stay in touch. No app to install. Just a Google Form, Google Calendar, and a daily cron job.

## How it works

1. You and your friends fill out a Google Form with your preferences (who you want to talk to, how often).
2. A daily GitHub Actions job reads the form responses, finds mutual pairs (A listed B AND B listed A), checks both calendars for free time, and creates a Google Calendar event with a Meet link.
3. The call just shows up on your calendar. Serendipity.

Neither party sees the other's frequency preferences. If you say "every 2 weeks" and your friend says "every 6 weeks," the scheduler uses the geometric mean (~3.5 weeks) and neither of you knows.

## Setup

### 1. Create a Google Cloud service account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use an existing one)
3. Enable these APIs:
   - **Google Calendar API**
   - **Google Sheets API**
4. Go to **IAM & Admin > Service Accounts** and create a new service account (no IAM roles needed)
5. Create a JSON key for the service account and download it
6. Note the service account's email address (looks like `something@project-id.iam.gserviceaccount.com`)

### 2. Create the Google Form

Create a Google Form with these fields (in this exact order):

| # | Field | Type | Notes |
|---|-------|------|-------|
| 1 | Your name | Short text | |
| 2 | Your email | Short text | Must match their Google Calendar email |
| 3 | Your timezone | Short text | e.g. `America/Chicago` (not currently used for scheduling but useful metadata) |
| 4 | Preferred call hours (24h, e.g. "17-21") | Short text | The hour range you're available for social calls |
| 5 | Contact 1 email | Short text | |
| 6 | Contact 1 frequency (weeks) | Short text | How often you'd like to talk to this person |
| 7 | Contact 2 email | Short text | |
| 8 | Contact 2 frequency (weeks) | Short text | |
| ... | (repeat as needed) | | Add as many contact pairs as you want |

**Important:** The form's response spreadsheet column order must match this layout. The scheduler reads columns positionally: timestamp, name, email, timezone, hours, then repeating (contact email, frequency) pairs.

I'd suggest starting with 5-10 contact slots (10-20 columns of contact email + frequency pairs).

If someone submits the form multiple times, only their latest response is used.

#### Finding your form's entry IDs (needed for pre-fill links)

After creating the form, you need to grab the entry IDs so the pre-fill link generator can work:

1. Open your Google Form in edit mode
2. Click the three-dot menu (top right) and select **"Get pre-filled link"**
3. Fill in dummy values for every field (e.g. "test" for text fields)
4. Click **"Get link"** at the bottom, then **"Copy link"**
5. Paste the link somewhere. It will look like:
   ```
   https://docs.google.com/forms/d/e/FORM_ID/viewform?usp=pp_url&entry.1234567=test&entry.2345678=test&...
   ```
6. Extract the `entry.XXXXXXX` IDs in order and format them as a JSON array:
   ```json
   ["entry.1234567", "entry.2345678", "entry.3456789", "entry.4567890", "entry.5678901", "entry.6789012", "entry.7890123", "entry.8901234"]
   ```
   The order maps to: name, email, timezone, preferred hours, contact 1 email, contact 1 freq, contact 2 email, contact 2 freq, ...

Save this JSON string. You'll need it as the `ENTRY_IDS_JSON` environment variable / GitHub secret.

### 3. Share calendars with the service account

Each participant must share their Google Calendar with the service account email:

1. Open [Google Calendar](https://calendar.google.com)
2. Find your calendar in the left sidebar, click the three dots, select **Settings and sharing**
3. Under "Share with specific people or groups," add the service account email
4. Set permission to **"See all event details"**

> **Note:** The service account creates events on its own calendar and sends invites to both parties via email. The event appears on their calendars when they accept (or automatically if they have auto-accept enabled). "See all event details" permission is sufficient.

### 4. Share the response spreadsheet with the service account

1. Open the Google Form's linked spreadsheet (Responses tab > green Sheets icon)
2. Click **Share** and add the service account email with **Viewer** access
3. Copy the spreadsheet ID from the URL: `https://docs.google.com/spreadsheets/d/{THIS_PART}/edit`

### 5. Set up the GitHub repo

1. Create a private GitHub repo and push this code to it
2. Add these repository secrets (Settings > Secrets and variables > Actions):
   - `GOOGLE_SERVICE_ACCOUNT_JSON` -- the entire contents of the service account JSON key file
   - `SPREADSHEET_ID` -- the spreadsheet ID from step 4
   - `FORM_URL` -- your Google Form's URL (the `/viewform` URL, not the edit URL)
   - `ENTRY_IDS_JSON` -- the JSON array of entry IDs from step 2
3. The GitHub Actions workflow needs write permission to commit state changes. Go to **Settings > Actions > General > Workflow permissions** and select **"Read and write permissions"**

### 6. Test it

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GOOGLE_SERVICE_ACCOUNT_JSON=$(cat credentials.json)
export SPREADSHEET_ID="your-spreadsheet-id"

# List all mutual pairs (no events created)
python scripts/scheduler.py --list-pairs

# Dry run (shows what would be scheduled)
python scripts/scheduler.py --dry-run

# Actually schedule calls
python scripts/scheduler.py
```

## Inviting friends

Send your friends two things:

1. The Google Form link
2. The service account email address, with instructions to share their Google Calendar with it ("See all event details" permission)

That's it. No app to download, no account to create.

### Sample invite message

> Hey! I'm trying out a tool called Serendipity that automatically schedules catch-up calls between friends. It finds a time we're both free and drops a Google Meet on our calendars.
>
> To join:
> 1. Fill out this form: [FORM LINK]
> 2. Share your Google Calendar with `serendipity@your-project.iam.gserviceaccount.com` (Settings > "Share with specific people" > "See all event details")
>
> That's all. Calls will just start showing up when the timing is right.

## Updating preferences

To update your preferences (add/remove contacts, change frequencies), use your personalized pre-fill link. This opens the form with your current answers already filled in, so you just tweak what you want and resubmit.

To generate pre-fill links for all current users:

```bash
export FORM_URL="https://docs.google.com/forms/d/e/YOUR_FORM_ID/viewform"
export ENTRY_IDS_JSON='["entry.111", "entry.222", ...]'

python scripts/generate_prefill_links.py
```

This prints a personalized link for each user. Send them their link when they want to make changes.

## Post-call feedback (planned)

The original design includes a feedback loop: after each call, both participants indicate whether they'd like to talk **more often**, **less often**, or if the current frequency feels **just right**. This lets preferences evolve based on actual experience rather than upfront guesses.

This is not yet implemented. The planned approach is to include a link in the calendar event description pointing to a short feedback form. The scheduler would read those responses and adjust the effective frequency for that pair.

For now, if you want to change how often you talk to someone after a call, re-submit the main form with updated frequencies using your pre-fill link.

## How scheduling works

- The scheduler runs daily via GitHub Actions (7am UTC / 2am Eastern / 1am Central)
- For each mutual pair (both listed each other), it checks if a call is "due" based on the geometric mean of both parties' preferred frequencies
- Timing is randomized within the frequency window to preserve the feeling of serendipity
- It queries Google Calendar free/busy to find overlapping availability
- It picks a random free slot and creates a calendar event with a Google Meet link
- Both parties receive an email invitation

## Opting out of a specific person

Remove them from your form submission (re-submit without that contact via your pre-fill link). Since scheduling requires mutual opt-in, removing them from your list is sufficient.

## FAQ

**What if someone doesn't share their calendar?**
The free/busy query will return empty (no busy times), so the scheduler will assume they're always free. This is imperfect but functional. They may get events that conflict with existing commitments and will need to decline those manually.

**What if there's no overlapping free time?**
The pair is skipped for that scheduling cycle and retried the next day.

**Can I block someone?**
Yes. Just don't list them when you re-submit the form. Scheduling only happens for mutual pairs.

**What if I want to update my preferences?**
Use your personalized pre-fill link (ask the admin to generate one, or run `generate_prefill_links.py` yourself). It opens the form with your existing answers pre-populated.

**Does this cost anything?**
No. Google Calendar API, Google Sheets API, and GitHub Actions are all free at this scale.

**How do I stop using it entirely?**
Revoke the calendar sharing with the service account and stop submitting the form. You won't be paired with anyone.
