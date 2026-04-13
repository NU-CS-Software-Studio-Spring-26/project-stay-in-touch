#!/usr/bin/env python3
"""
Generate pre-filled Google Form links for each user based on their
current responses in the spreadsheet.

Each user gets a personalized URL that opens the form with their
existing answers already populated. They can tweak and resubmit.

Usage:
    python generate_prefill_links.py

Required env vars:
    GOOGLE_SERVICE_ACCOUNT_JSON  -- service account credentials (or credentials.json file)
    SPREADSHEET_ID               -- the form responses spreadsheet
    FORM_URL                     -- the Google Form /viewform URL
    ENTRY_IDS_JSON               -- JSON array of entry.XXXXXXX IDs matching form field order

Example:
    export FORM_URL="https://docs.google.com/forms/d/e/1FAIpQL.../viewform"
    export ENTRY_IDS_JSON='["entry.111", "entry.222", "entry.333", "entry.444", "entry.555", "entry.666"]'
    python scripts/generate_prefill_links.py
"""

import os
import sys
import json
import logging
from pathlib import Path
from urllib.parse import quote

from google.oauth2 import service_account
from googleapiclient.discovery import build

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("prefill")

SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]


def get_credentials():
    creds_json = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON")
    if not creds_json:
        creds_path = Path(__file__).parent.parent / "credentials.json"
        if not creds_path.exists():
            log.error("No credentials found.")
            sys.exit(1)
        creds_json = creds_path.read_text()
    info = json.loads(creds_json)
    return service_account.Credentials.from_service_account_info(info, scopes=SCOPES)


def get_latest_responses(sheets_service, spreadsheet_id: str) -> dict:
    """
    Read form responses. For users who submitted multiple times,
    keep only the latest response. Returns {email: row_values}.
    """
    result = (
        sheets_service.spreadsheets()
        .values()
        .get(spreadsheetId=spreadsheet_id, range="Form Responses 1")
        .execute()
    )
    rows = result.get("values", [])
    if len(rows) < 2:
        return {}

    header = rows[0]
    latest = {}

    for row in rows[1:]:
        row = row + [""] * (len(header) - len(row))
        email = row[2].strip().lower()
        if email:
            # Later rows overwrite earlier ones (latest wins)
            latest[email] = row

    return latest


def generate_prefill_url(form_url: str, entry_ids: list[str], row: list[str]) -> str:
    """
    Build a pre-filled form URL.

    row[0] is the timestamp (skip it).
    row[1:] maps to entry_ids[0:].
    """
    params = []
    for i, entry_id in enumerate(entry_ids):
        value_index = i + 1  # skip timestamp column
        if value_index < len(row) and row[value_index].strip():
            params.append(f"{entry_id}={quote(row[value_index].strip())}")

    separator = "&" if "?" in form_url else "?"
    return f"{form_url}{separator}{'&'.join(params)}"


def main():
    spreadsheet_id = os.environ.get("SPREADSHEET_ID", "")
    form_url = os.environ.get("FORM_URL", "")
    entry_ids_json = os.environ.get("ENTRY_IDS_JSON", "")

    if not spreadsheet_id:
        log.error("Set SPREADSHEET_ID env var.")
        sys.exit(1)
    if not form_url:
        log.error("Set FORM_URL env var.")
        sys.exit(1)
    if not entry_ids_json:
        log.error("Set ENTRY_IDS_JSON env var.")
        sys.exit(1)

    entry_ids = json.loads(entry_ids_json)

    credentials = get_credentials()
    sheets_service = build("sheets", "v4", credentials=credentials)

    latest = get_latest_responses(sheets_service, spreadsheet_id)

    if not latest:
        print("No responses found in the spreadsheet.")
        return

    print(f"\nPre-fill links for {len(latest)} users:\n")
    print("=" * 80)

    for email, row in sorted(latest.items()):
        name = row[1].strip() if len(row) > 1 else email
        url = generate_prefill_url(form_url, entry_ids, row)
        print(f"\n{name} ({email}):")
        print(f"  {url}")

    print("\n" + "=" * 80)
    print(f"\nSend each person their link so they can update their preferences.")


if __name__ == "__main__":
    main()
