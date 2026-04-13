#!/usr/bin/env python3
"""
Serendipity Scheduler

Reads user preferences from a Google Sheet (populated by a Google Form),
finds mutual pairs that are due for a call, checks Google Calendar
free/busy, and creates calendar events with Google Meet links.

Usage:
    python scheduler.py                  # normal run
    python scheduler.py --dry-run        # show what would be scheduled without creating events
    python scheduler.py --list-pairs     # show all mutual pairs and their status
"""

import os
import sys
import json
import math
import random
import hashlib
import logging
import argparse
from pathlib import Path
from datetime import datetime, timedelta, timezone
from typing import Optional

from google.oauth2 import service_account
from googleapiclient.discovery import build

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

STATE_FILE = Path(__file__).parent.parent / "state.json"

SCOPES = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/spreadsheets.readonly",
]

# Scheduling parameters
CALL_DURATION_MINUTES = 30
SCHEDULING_WINDOW_DAYS = 7
DEFAULT_PREFERRED_HOURS = (9, 21)  # fallback if user doesn't specify
JITTER_FRACTION = 0.3

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("serendipity")


# ---------------------------------------------------------------------------
# Google API setup
# ---------------------------------------------------------------------------

def get_credentials():
    """Load service account credentials."""
    creds_json = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON")
    if not creds_json:
        creds_path = Path(__file__).parent.parent / "credentials.json"
        if not creds_path.exists():
            log.error(
                "No credentials found. Set GOOGLE_SERVICE_ACCOUNT_JSON env var "
                "or place credentials.json in the repo root."
            )
            sys.exit(1)
        creds_json = creds_path.read_text()

    info = json.loads(creds_json)
    return service_account.Credentials.from_service_account_info(info, scopes=SCOPES)


def get_services(credentials):
    """Build Google API service objects."""
    calendar = build("calendar", "v3", credentials=credentials)
    sheets = build("sheets", "v4", credentials=credentials)
    return calendar, sheets


# ---------------------------------------------------------------------------
# Google Sheets: read form responses
# ---------------------------------------------------------------------------

# Expected columns in the sheet (0-indexed):
#   0: Timestamp
#   1: Your name
#   2: Your email (must match Google Calendar)
#   3: Your timezone (e.g. "America/Chicago")
#   4: Preferred call hours (e.g. "9-21" or "17-21")
#   5: Contact 1 email
#   6: Contact 1 frequency (weeks)
#   7: Contact 2 email
#   8: Contact 2 frequency (weeks)
#   ... (repeating pairs)
#
# If a person submits the form multiple times, only their LATEST response is used.

def load_preferences_from_sheet(sheets_service, spreadsheet_id: str) -> dict:
    """
    Read the Google Sheet and return preferences keyed by email.
    Later submissions override earlier ones (so people can update prefs).

    Returns: {
        "alice@gmail.com": {
            "name": "Alice",
            "email": "alice@gmail.com",
            "timezone": "America/Chicago",
            "preferred_hours": (17, 21),
            "contacts": {
                "bob@gmail.com": {"frequency_weeks": 4},
                "carol@gmail.com": {"frequency_weeks": 8},
            }
        },
        ...
    }
    """
    result = (
        sheets_service.spreadsheets()
        .values()
        .get(spreadsheetId=spreadsheet_id, range="Form Responses 1")
        .execute()
    )
    rows = result.get("values", [])
    if len(rows) < 2:
        log.warning("Sheet has no data rows.")
        return {}

    header = rows[0]
    preferences = {}

    for row in rows[1:]:
        # Pad row to header length
        row = row + [""] * (len(header) - len(row))

        email = row[2].strip().lower()
        if not email:
            continue

        name = row[1].strip()
        tz = row[3].strip() if len(row) > 3 and row[3].strip() else "America/Chicago"

        # Parse preferred hours
        preferred_hours = DEFAULT_PREFERRED_HOURS
        if len(row) > 4 and row[4].strip():
            try:
                parts = row[4].strip().split("-")
                preferred_hours = (int(parts[0]), int(parts[1]))
            except (ValueError, IndexError):
                pass

        # Parse contact pairs (columns 5,6 then 7,8 then 9,10 ...)
        contacts = {}
        col = 5
        while col + 1 < len(row):
            contact_email = row[col].strip().lower()
            freq_str = row[col + 1].strip()
            if contact_email and freq_str:
                try:
                    freq = float(freq_str)
                    if freq > 0:
                        contacts[contact_email] = {"frequency_weeks": freq}
                except ValueError:
                    pass
            col += 2

        preferences[email] = {
            "name": name,
            "email": email,
            "timezone": tz,
            "preferred_hours": preferred_hours,
            "contacts": contacts,
        }

    log.info(f"Loaded preferences for {len(preferences)} users.")
    return preferences


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def load_state() -> dict:
    """Load persistent state (last call dates, scheduled events)."""
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_calls": {}, "scheduled": {}}


def save_state(state: dict):
    """Save state to disk."""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2, default=str)


def pair_key(email_a: str, email_b: str) -> str:
    """Canonical key for a pair of emails (order-independent)."""
    return "|".join(sorted([email_a, email_b]))


# ---------------------------------------------------------------------------
# Calendar helpers
# ---------------------------------------------------------------------------

def get_freebusy(service, calendar_ids: list[str], time_min: datetime, time_max: datetime):
    """Query free/busy for multiple calendars. Returns {calendar_id: [(start, end), ...]}."""
    body = {
        "timeMin": time_min.isoformat(),
        "timeMax": time_max.isoformat(),
        "items": [{"id": cid} for cid in calendar_ids],
    }
    result = service.freebusy().query(body=body).execute()
    busy = {}
    for cid in calendar_ids:
        cal_info = result.get("calendars", {}).get(cid, {})
        errors = cal_info.get("errors", [])
        if errors:
            log.warning(f"Free/busy errors for {cid}: {errors}")
        cal_busy = cal_info.get("busy", [])
        busy[cid] = [
            (
                datetime.fromisoformat(b["start"].replace("Z", "+00:00")),
                datetime.fromisoformat(b["end"].replace("Z", "+00:00")),
            )
            for b in cal_busy
        ]
    return busy


def find_mutual_free_slots(
    busy_a: list[tuple[datetime, datetime]],
    busy_b: list[tuple[datetime, datetime]],
    window_start: datetime,
    window_end: datetime,
    slot_duration: timedelta,
    preferred_hours_a: tuple[int, int],
    preferred_hours_b: tuple[int, int],
) -> list[datetime]:
    """
    Find 30-min-aligned time slots where both parties are free
    and within BOTH parties' preferred hours.
    """
    # Overlap of preferred hours
    start_h = max(preferred_hours_a[0], preferred_hours_b[0])
    end_h = min(preferred_hours_a[1], preferred_hours_b[1])
    if start_h >= end_h:
        # No overlap in preferred hours; fall back to union
        start_h = min(preferred_hours_a[0], preferred_hours_b[0])
        end_h = max(preferred_hours_a[1], preferred_hours_b[1])
        log.info(f"  No preferred-hours overlap; using union {start_h}-{end_h}")

    # Merge all busy intervals
    all_busy = sorted(busy_a + busy_b, key=lambda x: x[0])
    merged = []
    for start, end in all_busy:
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))

    # Generate candidate slots
    free_slots = []
    cursor = window_start
    # Align to next 30-min boundary
    if cursor.minute not in (0, 30):
        if cursor.minute < 30:
            cursor = cursor.replace(minute=30, second=0, microsecond=0)
        else:
            cursor = (cursor + timedelta(hours=1)).replace(minute=0, second=0, microsecond=0)

    while cursor + slot_duration <= window_end:
        hour = cursor.hour
        if start_h <= hour < end_h:
            # Check not overlapping any busy block
            slot_end = cursor + slot_duration
            is_free = True
            for bstart, bend in merged:
                if cursor < bend and slot_end > bstart:
                    is_free = False
                    break
            if is_free:
                free_slots.append(cursor)
        cursor += timedelta(minutes=30)

    return free_slots


def create_call_event(
    service,
    email_a: str,
    email_b: str,
    name_a: str,
    name_b: str,
    start_time: datetime,
    duration_minutes: int = CALL_DURATION_MINUTES,
):
    """Create a calendar event with a Google Meet link, inviting both parties."""
    end_time = start_time + timedelta(minutes=duration_minutes)

    event = {
        "summary": f"\u2728 Serendipity: {name_a} \u2194 {name_b}",
        "description": (
            "This call was auto-scheduled by Serendipity because you both "
            "want to stay in touch.\n\n"
            "If you'd like to adjust how often you're paired, just re-submit "
            "the sign-up form with updated preferences.\n\n"
            "Have a great conversation!"
        ),
        "start": {"dateTime": start_time.isoformat(), "timeZone": "UTC"},
        "end": {"dateTime": end_time.isoformat(), "timeZone": "UTC"},
        "attendees": [
            {"email": email_a},
            {"email": email_b},
        ],
        "conferenceData": {
            "createRequest": {
                "requestId": hashlib.md5(
                    f"{email_a}-{email_b}-{start_time.isoformat()}".encode()
                ).hexdigest(),
                "conferenceSolutionKey": {"type": "hangoutsMeet"},
            }
        },
        "reminders": {
            "useDefault": False,
            "overrides": [
                {"method": "popup", "minutes": 60},
                {"method": "popup", "minutes": 10},
            ],
        },
        "guestsCanModify": True,
    }

    created = (
        service.events()
        .insert(
            # Create on the service account's primary calendar.
            # Both parties receive invites via the attendees list.
            calendarId="primary",
            body=event,
            conferenceDataVersion=1,
            sendUpdates="all",
        )
        .execute()
    )

    meet_link = created.get("hangoutLink", "")
    log.info(
        f"  Created event: {name_a} <-> {name_b} at "
        f"{start_time.strftime('%a %b %d %H:%M UTC')} "
        f"(Meet: {meet_link})"
    )
    return created


# ---------------------------------------------------------------------------
# Core scheduling logic
# ---------------------------------------------------------------------------

def find_mutual_pairs(preferences: dict) -> list[dict]:
    """
    Find all mutual pairs where A lists B AND B lists A.
    Returns list of pair dicts with merged frequency.
    """
    pairs = []
    seen = set()

    for email_a, prefs_a in preferences.items():
        for email_b, contact_info in prefs_a["contacts"].items():
            pk = pair_key(email_a, email_b)
            if pk in seen:
                continue
            seen.add(pk)

            if email_b not in preferences:
                continue

            prefs_b = preferences[email_b]
            if email_a not in prefs_b["contacts"]:
                continue

            freq_a = contact_info["frequency_weeks"] * 7  # days
            freq_b = prefs_b["contacts"][email_a]["frequency_weeks"] * 7

            # Geometric mean
            effective_freq_days = math.sqrt(freq_a * freq_b)

            pairs.append({
                "a_email": email_a,
                "b_email": email_b,
                "a_name": prefs_a["name"],
                "b_name": prefs_b["name"],
                "a_preferred_hours": prefs_a["preferred_hours"],
                "b_preferred_hours": prefs_b["preferred_hours"],
                "effective_freq_days": effective_freq_days,
            })

    return pairs


def is_pair_due(pair: dict, state: dict, now: datetime) -> bool:
    """Check if a pair is due for a call, with jitter."""
    pk = pair_key(pair["a_email"], pair["b_email"])

    # Check if there's already a future scheduled call
    scheduled_time_str = state.get("scheduled", {}).get(pk)
    if scheduled_time_str:
        scheduled_time = datetime.fromisoformat(scheduled_time_str)
        if scheduled_time > now:
            log.info(
                f"  {pair['a_name']} <-> {pair['b_name']}: "
                f"already scheduled for {scheduled_time.strftime('%b %d')}"
            )
            return False

    last_call_str = state.get("last_calls", {}).get(pk)
    if not last_call_str:
        # Never called; they're due
        return True

    last_call = datetime.fromisoformat(last_call_str)
    days_since = (now - last_call).total_seconds() / 86400

    # Add jitter: due if days_since > freq * (1 - jitter) to freq * (1 + jitter)
    freq = pair["effective_freq_days"]
    threshold = freq * (1 - JITTER_FRACTION + random.random() * 2 * JITTER_FRACTION)

    return days_since >= threshold


def run_scheduler(
    preferences: dict,
    calendar_service,
    state: dict,
    dry_run: bool = False,
) -> dict:
    """Main scheduling loop. Returns updated state."""
    now = datetime.now(timezone.utc)
    window_start = now + timedelta(days=1)  # don't schedule today
    window_end = now + timedelta(days=SCHEDULING_WINDOW_DAYS)

    pairs = find_mutual_pairs(preferences)
    log.info(f"Found {len(pairs)} mutual pairs.")

    # Shuffle so we don't always prioritize alphabetically first pairs
    random.shuffle(pairs)

    scheduled_count = 0

    for pair in pairs:
        pk = pair_key(pair["a_email"], pair["b_email"])
        log.info(
            f"Checking: {pair['a_name']} <-> {pair['b_name']} "
            f"(every ~{pair['effective_freq_days']:.0f} days)"
        )

        if not is_pair_due(pair, state, now):
            continue

        log.info(f"  Pair is due. Searching for free slots...")

        if dry_run:
            log.info(f"  [DRY RUN] Would search calendars and schedule.")
            continue

        # Query free/busy
        try:
            busy = get_freebusy(
                calendar_service,
                [pair["a_email"], pair["b_email"]],
                window_start,
                window_end,
            )
        except Exception as e:
            log.error(f"  Failed to query free/busy: {e}")
            continue

        busy_a = busy.get(pair["a_email"], [])
        busy_b = busy.get(pair["b_email"], [])

        slots = find_mutual_free_slots(
            busy_a,
            busy_b,
            window_start,
            window_end,
            timedelta(minutes=CALL_DURATION_MINUTES),
            pair["a_preferred_hours"],
            pair["b_preferred_hours"],
        )

        if not slots:
            log.info(f"  No mutual free slots found in the next {SCHEDULING_WINDOW_DAYS} days.")
            continue

        # Pick a random slot from the available ones (serendipity!)
        chosen_slot = random.choice(slots)

        try:
            create_call_event(
                calendar_service,
                pair["a_email"],
                pair["b_email"],
                pair["a_name"],
                pair["b_name"],
                chosen_slot,
            )
            state.setdefault("scheduled", {})[pk] = chosen_slot.isoformat()
            # Also mark as last_call so we don't re-schedule immediately
            state.setdefault("last_calls", {})[pk] = chosen_slot.isoformat()
            scheduled_count += 1
        except Exception as e:
            log.error(f"  Failed to create event: {e}")
            continue

    log.info(f"Scheduled {scheduled_count} new calls.")
    return state


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Serendipity Scheduler")
    parser.add_argument("--dry-run", action="store_true", help="Don't create events")
    parser.add_argument("--list-pairs", action="store_true", help="List mutual pairs and exit")
    parser.add_argument(
        "--spreadsheet-id",
        default=os.environ.get("SPREADSHEET_ID", ""),
        help="Google Sheets spreadsheet ID (or set SPREADSHEET_ID env var)",
    )
    args = parser.parse_args()

    if not args.spreadsheet_id:
        log.error("No spreadsheet ID provided. Use --spreadsheet-id or set SPREADSHEET_ID.")
        sys.exit(1)

    credentials = get_credentials()
    calendar_service, sheets_service = get_services(credentials)

    preferences = load_preferences_from_sheet(sheets_service, args.spreadsheet_id)
    if not preferences:
        log.info("No preferences found. Nothing to do.")
        return

    if args.list_pairs:
        state = load_state()
        now = datetime.now(timezone.utc)
        pairs = find_mutual_pairs(preferences)
        print(f"\n{'Pair':<45} {'Freq (days)':<15} {'Last call':<15} {'Status'}")
        print("-" * 90)
        for p in sorted(pairs, key=lambda x: x["effective_freq_days"]):
            pk = pair_key(p["a_email"], p["b_email"])
            last = state.get("last_calls", {}).get(pk, "never")
            scheduled = state.get("scheduled", {}).get(pk)
            if scheduled and datetime.fromisoformat(scheduled) > now:
                status = f"scheduled {scheduled[:10]}"
            elif last == "never":
                status = "due (never called)"
            else:
                days_since = (now - datetime.fromisoformat(last)).days
                if days_since >= p["effective_freq_days"] * (1 - JITTER_FRACTION):
                    status = f"due ({days_since}d ago)"
                else:
                    status = f"not due ({days_since}d ago)"
            print(
                f"{p['a_name']} <-> {p['b_name']:<20} "
                f"{p['effective_freq_days']:<15.0f} "
                f"{last[:10] if last != 'never' else 'never':<15} "
                f"{status}"
            )
        return

    state = load_state()
    state = run_scheduler(preferences, calendar_service, state, dry_run=args.dry_run)

    if not args.dry_run:
        save_state(state)
        log.info("State saved.")


if __name__ == "__main__":
    main()
