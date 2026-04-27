# Overcommit (local git hooks)

Overcommit is a git-hook framework. In this repo it runs a **secret scanner (gitleaks)**, a YAML syntax check, and a merge-conflict-marker check **before each `git commit`**, so a leaked API key never reaches your local history in the first place.

This is the **local fast-feedback layer**. The GitHub Actions `secret-scan` workflow runs the same gitleaks scan on every PR and is the authoritative backstop — you can't bypass it.

## One-time setup (after cloning)

```bash
# 1. Install Ruby gems (installs overcommit itself)
bundle install

# 2. Install the gitleaks binary
# macOS
brew install gitleaks
# Linux (Debian/Ubuntu)
#   see https://github.com/gitleaks/gitleaks#installing
#   or: go install github.com/gitleaks/gitleaks/v8@latest

# 3. Install the git hooks into .git/hooks/
bundle exec overcommit --install

# 4. Sign the config so Overcommit will actually run.
#    This writes your local trust signature into .git/config
#    (per-clone — signatures are NOT committed to the repo).
bundle exec overcommit --sign
bundle exec overcommit --sign pre-commit
```

You only do this once per clone. After that, every `git commit` automatically runs the hooks.

## Running manually

```bash
# Run pre-commit hooks against currently staged files:
bundle exec overcommit --run
```

Useful when you want to lint-check before actually staging, or when debugging a failing hook.

## Bypassing in an emergency

```bash
OVERCOMMIT_DISABLE=1 git commit -m "…"
```

**Warning:** the GitHub Actions `secret-scan` workflow runs the same gitleaks scan on every PR. Bypassing locally does not help — your PR will fail CI and the secret will be visible in the diff. If you genuinely need to commit something gitleaks false-positives on, add a targeted `# gitleaks:allow` comment on that line or an entry in `.gitleaks.toml` allowlist instead.

## Troubleshooting

**"Overcommit::Exceptions::InvalidHookSignature"** — the config or a hook plugin changed since you last signed. Run:

```bash
bundle exec overcommit --sign           # re-sign .overcommit.yml
bundle exec overcommit --sign pre-commit  # re-sign plugins in .git-hooks/
```

Read the diff first (`git diff .overcommit.yml .git-hooks/`) before signing — the signature check exists precisely so a malicious branch can't silently add a hook that runs on your machine.

**"gitleaks: command not found"** — install it (`brew install gitleaks` on macOS). Overcommit will tell you this when the hook runs.

**Hook is slow / I want to skip just one hook** — set `SKIP=Gitleaks git commit …` to skip a single named hook for one commit. Prefer this over `OVERCOMMIT_DISABLE=1` because the other fast checks (YAML, merge markers) still run.

## What's configured

See `.overcommit.yml` at the repo root. Current pre-commit hooks:

- `Gitleaks` — scans staged diff for secrets via `gitleaks git --staged`
- `YamlSyntax` — parses every staged `*.yml` / `*.yaml`
- `MergeConflicts` — greps for `<<<<<<<` markers

We intentionally do **not** run rubocop / brakeman / rspec in the pre-commit hook — those run in CI and would make commits feel slow. If you want to run them locally, use `rails test`, `bundle exec rubocop`, or `bundle exec brakeman` directly.
