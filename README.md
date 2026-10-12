# Daily Contributions

An automated GitHub Actions workflow that makes periodic contributions to maintain an active commit history.

## How It Works

- **Workflow File**: [`.github/workflows/daily.yml`](.github/workflows/daily.yml) — scheduled at 00:00 UTC (also manually triggerable from the Actions tab).
- **Commit logic**: [`scripts/contribute.sh`](scripts/contribute.sh) — the single source of truth for how each contribution commit is produced.
- **Verification**: [`scripts/verify.sh`](scripts/verify.sh) — a non-destructive check that the commit logic works correctly.

## Verifying the automation (non-destructive)

Before trusting a change to the commit logic, run the verification. It clones
the repo into a throwaway directory, runs the commit-generation logic in
`--dry-run` mode, and asserts that exactly one valid commit is produced on the
expected date **without pushing anything**. It needs no secrets and never
touches a remote.

### Locally

```bash
# Uses today's UTC date as the expected date
scripts/verify.sh

# Pin a specific date to reproduce a past/future run deterministically
scripts/verify.sh 2026-10-12
```

You can also preview what the commit logic does by hand:

```bash
scripts/contribute.sh --dry-run           # create a local commit, no push
scripts/contribute.sh --dry-run --date 2026-10-12
```

### From CI

[`.github/workflows/verify.yml`](.github/workflows/verify.yml) runs
`scripts/verify.sh` on every push and pull request. It declares
`permissions: contents: read` and uses no secrets — a green check means the
commit logic produces exactly one valid commit and would not alter the public
contribution graph.

## Contribution History
- Auto-commit on 2026-09-21 12:19:29 UTC
