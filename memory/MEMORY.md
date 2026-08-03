# MEMORY.md — session-spanning knowledge

Check this at session start before asking about prior work. Keep entries one
line with a pointer; details live in the linked files, `docs/`, or Linear.
Append new facts, prune entries once their subject is recorded in `docs/` or
the handbook. This file was first built 2026-08-03; older history lives in
git log and `docs/history/`.

## Project status (2026-08-03)

- All 6 plugins validate green (0 errors). Authoritative versions:
  `.claude-plugin/marketplace.json`.
- Broker suite: 63 asserts, `plugins/core/tests/test_gbrain_team_broker.sh`.
- 3 stale PRs deliberately kept open with revival notes on each: #432 (ICP
  canonicals layer), #436 (marketing-context.md — still referenced by
  tam-mapping and launch-campaign, still missing), #466 (email-copywriting
  copy-craft fold-in). 7 others closed 2026-08-03 with superseded/obsolete
  pointers.

## Recent decisions

- ADR-044 (Bitwarden Secrets Manager broker, `bw-run.sh` deleted) and ADR-045
  (gbrain broker reads OAuth client from env vars) merged 2026-08-03 —
  `docs/decisions/`.
- Independent review receipt pattern is live practice for bash/shell changes —
  `docs/guides/independent-review-receipt.md`; receipts on PRs #494 and #573.
- Recorded, accepted residuals (do not re-raise): `bws run --project-id`
  injects every secret in the project (ADR-044); the machine account keeps
  read+write scope.

## Gotchas cited by scripts

- [gotcha_bash_case_glob_crosses_slash.md](gotcha_bash_case_glob_crosses_slash.md)
  — bash `case` globs match across `/`; P2 on PR #317. Cited by
  `scripts/validate.sh` § 2c and `scripts/test_pre_commit_bump.sh`.
- The broader trap catalog stays in `docs/gotchas.md` (canonical); this dir
  holds only notes that scripts cite by path.

## Known drift to be aware of

- Linear ran an administrative batch-close on 2026-06-05 (16:37–16:47) marking
  several issues Done whose PRs never merged (e.g. BC-12966 / PR #466,
  BC-12570 / PR #436). A "Done" status from that window is not completion
  evidence — check the attached PR.

## Session history

- 2026-08-03 (2): Dependabot cleared via tam-map lockfile refresh (PR #574);
  stale-PR sweep — 7 closed with pointers, 3 assessed and kept; BC-17506
  host check on workstation-box FAILED (BW_SESSION still exported, gbrain env
  pair absent — remediation steps on the ticket); `precedent-promotion` label
  created and applied to BC-12276; this memory/ convention built.
- 2026-08-03 (1): BC-17944 shipped (enrichment `mcp<2` pin,
  brite-data-platform#538 → SHA re-pin #572, cold-handshake verified);
  BC-17946 shipped (broker `client_secret` off curl argv via stdin, PR #573,
  review receipt LGTM-with-notes, suite 48 → 63).
- Earlier sessions: `docs/history/` and git log.
