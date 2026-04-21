# Conversation Logs

Archived Claude Code conversation transcripts for this project, kept alongside
the code for auditability and transparency about how the project was built.

Both the raw `.jsonl` files (the format Claude Code stores natively) and a
human-readable Markdown rendering of each session are included. The Markdown
files are produced by `scripts/jsonl_to_markdown.py`; regenerate them with:

```bash
uv run scripts/jsonl_to_markdown.py logs/conversation/
```

Secrets scans (`detect-secrets scan logs/conversation/`) are expected to pass
cleanly before these files are committed.

## Sessions

| # | File | Summary |
|---|------|---------|
| 01 | `01_initial_deliverable_implementation` | Implementing the initial deliverable (M0 Rails foundation) — explored the repo, planned the work, then built out the Rails app with seeded data, tests, CI, and Heroku deploy config. Includes a follow-up request to push the feature branch to GitHub (not main) and ensure the repo is well-documented. |
| 02 | `02_archive_logs_attempt` | Invocation of the `/archive-logs` skill to archive conversation logs into the repository. |
