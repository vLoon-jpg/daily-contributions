#!/usr/bin/env bash
#
# contribute.sh — the commit-generation logic for the daily contribution
# automation, extracted so it can be exercised non-destructively.
#
# This mirrors the commit steps that .github/workflows/daily.yml performs
# inline (append a dated README log line, stage, commit with a noreply identity,
# push). Keeping the logic here lets scripts/verify.sh prove the exact behavior
# produces one valid commit without pushing. When daily.yml is next touched it
# should delegate to this script (`scripts/contribute.sh`) so the verified logic
# and the scheduled logic can never drift apart.
#
# Usage:
#   scripts/contribute.sh               # commit + push (production path)
#   scripts/contribute.sh --dry-run     # commit locally, never push
#   scripts/contribute.sh --date YYYY-MM-DD   # pin the date (tests only)
#
# Flags:
#   --dry-run           Create the commit but skip `git push`.
#   --date YYYY-MM-DD   Override today's date (deterministic tests only).
#                       Without it, the current UTC date is used.
#
# Exit codes:
#   0  success (or nothing to commit — see below)
#   1  a real error
#
# When README.md has no pending change (e.g. already updated today), the
# script exits 0 WITHOUT creating a commit and WITHOUT failing the workflow,
# which mirrors the no-op guard in the previous inline implementation.

set -euo pipefail

DRY_RUN=0
DATE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --date)
      if [[ $# -lt 2 ]]; then
        echo "error: --date requires a YYYY-MM-DD argument" >&2
        exit 1
      fi
      DATE_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "usage: scripts/contribute.sh [--dry-run] [--date YYYY-MM-DD]" >&2
      exit 1
      ;;
  esac
done

# Identity: use the account's noreply address so commits attribute to
# vLoon-jpg regardless of the account's email-privacy setting.
git config user.name "vLoon-jpg"
git config user.email "251421586+vLoon-jpg@users.noreply.github.com"

if [[ -n "$DATE_OVERRIDE" ]]; then
  DATE_UTC="$DATE_OVERRIDE"
  TIMESTAMP_UTC="${DATE_OVERRIDE} 00:00:00 UTC"
else
  DATE_UTC="$(date -u '+%Y-%m-%d')"
  TIMESTAMP_UTC="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
fi

echo "- Auto-commit on ${TIMESTAMP_UTC}" >> README.md

git add README.md

# No-op guard: if there is genuinely nothing new to commit, succeed quietly
# instead of failing the run or fabricating an empty commit.
if git diff --cached --quiet; then
  echo "No changes to commit (README.md unchanged)."
  exit 0
fi

git commit -m "chore(daily): update activity log [${DATE_UTC}]"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry-run: commit created but not pushed."
  exit 0
fi

git push
