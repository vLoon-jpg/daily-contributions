#!/usr/bin/env bash
#
# verify.sh — non-destructive verification of the daily-contribution logic.
#
# Creates a throwaway clone, runs scripts/contribute.sh --dry-run against a
# pinned date, and asserts that the run produces EXACTLY ONE valid commit on
# the expected date with the expected author and message, and that nothing is
# pushed to any remote. On success it exits 0; on any mismatch it prints a
# precise failure and exits non-zero.
#
# This script is safe to run anywhere (locally or in CI): it only touches a
# fresh temp directory, never the calling repository, never a remote, and it
# requires no secrets or credentials.
#
# Usage:
#   scripts/verify.sh                 # use today's UTC date as the expected date
#   scripts/verify.sh YYYY-MM-DD      # pin the expected date

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# On Windows git-bash/MSYS, `pwd` yields /c/Users/... which native git cannot
# resolve. Convert to a C:/Users/... path so `git clone` works; on Linux/macOS
# cygpath is absent and the POSIX path is used unchanged.
if command -v cygpath >/dev/null 2>&1; then
  REPO_ROOT="$(cygpath -m "$REPO_ROOT")"
fi

EXPECTED_DATE="${1:-$(date -u '+%Y-%m-%d')}"
# sanity-check the date format
if [[ ! "$EXPECTED_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "FAIL: expected date must be YYYY-MM-DD, got: $EXPECTED_DATE" >&2
  exit 1
fi

EXPECTED_MESSAGE="chore(daily): update activity log [${EXPECTED_DATE}]"
EXPECTED_AUTHOR="vLoon-jpg <251421586+vLoon-jpg@users.noreply.github.com>"

WORKDIR="$(mktemp -d)"
WORKDIR_NATIVE="$WORKDIR"
# Same native-path conversion as REPO_ROOT, so `git clone` and `cd` (a shell
# builtin that understands MSYS paths) both resolve the directory correctly.
if command -v cygpath >/dev/null 2>&1; then
  WORKDIR_NATIVE="$(cygpath -m "$WORKDIR")"
fi
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Ephemeral checkout at $WORKDIR"
git clone -q "$REPO_ROOT" "$WORKDIR_NATIVE/repo"
cd "$WORKDIR/repo"

BEFORE="$(git rev-parse HEAD)"

echo "==> Running scripts/contribute.sh --dry-run --date $EXPECTED_DATE"
./scripts/contribute.sh --dry-run --date "$EXPECTED_DATE"

AFTER="$(git rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Assertion 1: exactly one commit was created.
# ---------------------------------------------------------------------------
COMMIT_COUNT="$(git rev-list --count "${BEFORE}..${AFTER}")"
if [[ "$COMMIT_COUNT" -ne 1 ]]; then
  echo "FAIL: expected exactly 1 new commit, got $COMMIT_COUNT" >&2
  exit 1
fi
echo "PASS: exactly one commit created."

# ---------------------------------------------------------------------------
# Assertion 2: commit message and author are correct.
# ---------------------------------------------------------------------------
MESSAGE="$(git log -1 --format='%s' "$AFTER")"
if [[ "$MESSAGE" != "$EXPECTED_MESSAGE" ]]; then
  echo "FAIL: commit message mismatch" >&2
  echo "  expected: $EXPECTED_MESSAGE" >&2
  echo "  actual:   $MESSAGE" >&2
  exit 1
fi
echo "PASS: commit message correct."

AUTHOR="$(git log -1 --format='%an <%ae>' "$AFTER")"
if [[ "$AUTHOR" != "$EXPECTED_AUTHOR" ]]; then
  echo "FAIL: author mismatch" >&2
  echo "  expected: $EXPECTED_AUTHOR" >&2
  echo "  actual:   $AUTHOR" >&2
  exit 1
fi
echo "PASS: commit author correct."

# ---------------------------------------------------------------------------
# Assertion 3: the README log entry records the expected (UTC) date. This is
# the semantic "contribution date" — the git author timestamp is incidental
# (local timezone) and deliberately not asserted here.
# ---------------------------------------------------------------------------
LOG_LINE="$(git diff "${BEFORE}" "${AFTER}" -- README.md | grep '^+' | grep -v '^+++')"
if [[ "$LOG_LINE" != *"$EXPECTED_DATE"* ]]; then
  echo "FAIL: README log line does not contain expected date $EXPECTED_DATE" >&2
  echo "  actual line: $LOG_LINE" >&2
  exit 1
fi
echo "PASS: README records contribution on $EXPECTED_DATE."

# ---------------------------------------------------------------------------
# Assertion 4: nothing was pushed. The new commit must not appear on any
# remote-tracking ref — --dry-run never advances a remote, so `git branch -r
# --contains AFTER` must be empty. (Robust against detached-HEAD checkouts.)
# ---------------------------------------------------------------------------
if git branch -r --contains "$AFTER" 2>/dev/null | grep -q .; then
  echo "FAIL: commit reached a remote — something was pushed." >&2
  git branch -r --contains "$AFTER" >&2
  exit 1
fi
echo "PASS: commit is local-only; nothing was pushed."

# ---------------------------------------------------------------------------
# Assertion 5: exactly one line was added to README.md (the contribution log
# entry), and no other file changed.
# ---------------------------------------------------------------------------
CHANGED_FILES="$(git diff --name-only "${BEFORE}" "${AFTER}")"
if [[ "$CHANGED_FILES" != "README.md" ]]; then
  echo "FAIL: unexpected files changed:" >&2
  echo "$CHANGED_FILES" >&2
  exit 1
fi

ADDED_LINES="$(git diff "${BEFORE}" "${AFTER}" -- README.md | grep -c '^+[^+]')"
if [[ "$ADDED_LINES" -ne 1 ]]; then
  echo "FAIL: expected 1 line added to README.md, got $ADDED_LINES" >&2
  exit 1
fi
echo "PASS: README.md is the only changed file, with exactly one line added."

echo ""
echo "SUCCESS: contribution logic verified — one valid commit on $EXPECTED_DATE, nothing pushed."
