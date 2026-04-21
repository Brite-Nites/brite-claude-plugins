# BC-5790 Plan — /revops:deploy-sandbox orchestration command

**Issue:** [BC-5790](https://linear.app/brite-nites/issue/BC-5790)
**Priority:** High
**Milestone:** RevOps Plugin (Phase 2, first-of-N)
**Worktree:** `.claude/worktrees/bc-5790`
**Branch:** `holden/bc-5790-build-revopsdeploy-sandbox-orchestration-command`

## Goal

Ship `plugins/revops/commands/deploy-sandbox.md` — a 6-phase slash command that orchestrates sandbox deploy with Brite's discipline: pre-flight → dry-run → deploy → Apex tests → manual browser verification → completion. Fills the gap between `/workflows:review` and `/workflows:ship` that SF-work needs. First-of-N Phase 2 command; BC-5791 and BC-5792 will inherit this template.

## Context anchor

- **Spec:** Issue body is the design doc (6 phases, exact `sf` commands, verify matrix T1–T7, out-of-scope). No design space left open.
- **Reference pattern:** `plugins/marketing/commands/setup-email-bison.md` — phase-gated `AskUserQuestion`, `allowed-tools: Bash, Read, AskUserQuestion`, `## Phase N — Name` sections. This plugin's `plugins/revops/commands/` is empty; we set the template here.
- **Source-of-truth facts** (from `brite-salesforce/CLAUDE.md` via `gh api`, verified 2026-04-20):
  - Sandbox alias: `brite-sandbox`
  - Deploy dry-run: `sf project deploy start --source-dir force-app --dry-run --target-org brite-sandbox`
  - Deploy actual: drop `--dry-run`
  - Apex tests: `sf apex run test --target-org brite-sandbox --wait 10`
  - Always use `sf` (not `sfdx`); always pass `--target-org` explicitly
  - Manual browser verification covers: flexipage rendering, Kanban Group By cache (BC-4734 precedent), IndexedDB cache (hard refresh insufficient), Dynamic Forms FLS
- **Out of scope:** prod deploy (BC-5791), post-deploy runbook (BC-5792), browser-automation of verification.

## Task list

| # | Task | File | Est | Verifies |
|---|------|------|-----|----------|
| 1 | Write command frontmatter (`description`, `allowed-tools: Bash, AskUserQuestion`) | `plugins/revops/commands/deploy-sandbox.md` | 1 min | T7 |
| 2 | Write Phase 1 — Pre-flight (sfdx-project.json check, `sf config get target-org`, confirm gate) | same | 3 min | T5 |
| 3 | Write Phase 2 — Dry-run deploy (exact command with `--json`, parse failure path, confirm gate) | same | 4 min | T1, T2, T3 |
| 4 | Write Phase 3 — Actual sandbox deploy (drop `--dry-run`, parse output) | same | 3 min | T1 |
| 5 | Write Phase 4 — Apex tests (`sf apex run test --wait 10 --json`) | same | 2 min | T1 |
| 6 | Write Phase 5 — Manual browser verification (`AskUserQuestion`: Verified / Not yet / Failed) | same | 3 min | T1, T4 |
| 7 | Write Phase 6 — Completion summary + next-step hint | same | 2 min | T1 |
| 8 | Run `./scripts/validate.sh`; expect `0 errors, 17 warnings` | — | 1 min | T6 |
| 9 | Static verify: grep frontmatter for `allowed-tools`; walk-through T3/T4/T5 dry-paths by reading the command file | — | 3 min | T3, T4, T5, T7 |
| 10 | Commit: `add /revops:deploy-sandbox orchestration command (BC-5790)` | — | 1 min | — |

**Total:** 10 tasks, ~23 minutes of authoring.

## Phase structure in the command file

```
---
description: ...
allowed-tools: Bash, AskUserQuestion
---

# /revops:deploy-sandbox

<brief preamble>

## Phase 1 — Pre-flight
  [cwd check, default-org check, AskUserQuestion confirm]

## Phase 2 — Dry-run deploy
  [sf project deploy start --dry-run --json, parse, AskUserQuestion proceed gate]

## Phase 3 — Actual sandbox deploy
  [same without --dry-run, parse, report]

## Phase 4 — Apex tests
  [sf apex run test --wait 10 --json, summarize]

## Phase 5 — Manual browser verification
  [AskUserQuestion: Verified / Not yet / Failed verification]

## Phase 6 — Completion
  [summary + next-step hint to /workflows:review or /revops:deploy-prod]
```

## Verify matrix (from issue spec)

| Test | Setup | Command / Action | Pass criteria | How we check in this session |
|------|-------|------------------|---------------|------------------------------|
| T1 | brite-salesforce + no-op change + valid sandbox | Run `/revops:deploy-sandbox` | 6 phases complete; dry-run passes; user confirms; deploy succeeds; tests pass; prompt appears | **Dry-path only** in this session — verify the command file describes the happy path correctly. Real T1 is an end-to-end live test, deferred to a follow-up session or documented as out-of-session validation. |
| T2 | brite-salesforce + broken metadata | Run `/revops:deploy-sandbox` | Dry-run fails at Phase 2; user told why; no actual deploy | Static review of Phase 2 error-path branch |
| T3 | User answers "no" at Phase 2 gate | — | Exit cleanly, no deploy | Static review of Phase 2 `AskUserQuestion` options |
| T4 | User answers "Not yet" at Phase 5 gate | — | Exit with advisory (deploy landed, verification pending) | Static review of Phase 5 advisory branch |
| T5 | Run from non-SFDX cwd | — | Halt at Phase 1 with "Not in an SFDX project" | Static review of Phase 1 `sfdx-project.json` check |
| T6 | — | `./scripts/validate.sh` | Exit 0 | In-session, after commit |
| T7 | — | `grep` frontmatter for `allowed-tools: Bash, AskUserQuestion` | Match | In-session |

**Note on T1/T2:** Live execution against a real brite-sandbox org would require SFDX auth and a live org session, which is out of this session's scope. The command file is the deliverable; Holden's first real-world run is itself T1. We paste the static/dry-path verification + live-run expectations into the PR body per the issue spec.

## Non-goals (per issue)

- Prod deploy path (BC-5791)
- Post-deploy runbook (BC-5792)
- Automating browser verification
- Adding a skill alongside the command (command is standalone)

## Risks

- **Risk:** `sf project deploy start --json` output shape changes between CLI versions. **Mitigation:** Document the `--json` flag and exact command; if parse fails, print raw output + halt — don't silently proceed. (User also has `sf` CLI 2.x per brite-salesforce CLAUDE.md Scratch-Orgs note.)
- **Risk:** Drift between this command and `brite-salesforce/CLAUDE.md` §Development Flow. **Mitigation:** Command references the canonical invocation verbatim; any divergence is a handbook-drift issue for `/workflows:ship` to flag.
- **Risk:** Template this command sets will be inherited by BC-5791/5792 verbatim. **Mitigation:** Keep phase shape minimal + consistent (AskUserQuestion gate between each mutating phase; one question at a time).

## Definition of done

- `plugins/revops/commands/deploy-sandbox.md` exists with 6 phases + frontmatter + `allowed-tools: Bash, AskUserQuestion`
- `./scripts/validate.sh` exits 0 with no new warnings beyond baseline 17
- T3/T4/T5 dry-paths each visible as a discrete branch in the command file
- Committed on `holden/bc-5790-build-revopsdeploy-sandbox-orchestration-command`
- Ready for `/workflows:review` → `/workflows:ship`

## References

- `docs/plans/revops-plugin-master-plan.md` §8 Issue 2.1
- `plugins/marketing/commands/setup-email-bison.md` (phase-gated AskUserQuestion pattern)
- `plugins/workflows/commands/ship.md` (narration + step counter pattern)
- `brite-salesforce/CLAUDE.md` §Commands, §Development Flow §2
- BC-5793 precedent (sf-deploy customization — matches same SF domain)
- BC-5798 precedent (write plan to worktree, not primary checkout)
