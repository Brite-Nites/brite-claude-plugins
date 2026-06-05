# BC-6969 — `/flow:audit` implementation plan

> Issue: <https://linear.app/brite-nites/issue/BC-6969/flow-architecture-implement-flowaudit>
> Worktree: `.claude/worktrees/bc-6969/` on `holden/bc-6969-flow-architecture-implement-flowaudit`
> Status: in-progress 2026-05-11
> Memory: `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/project_fda_plugin_interview.md` Q29 (line 240) + Q38 (line 700) + Q38 sub-decision 4 resolution (line 730).

## What

Single deliverable file: `plugins/flow-architecture/commands/audit.md`. This is a **utility** (not orchestrator) per `plugins/flow-architecture/CLAUDE.md` § Surface map — single-purpose, no user-confirmation gates between internal steps, does NOT write the `.flow-phase-state.json` breadcrumb (only READS `overrides[]` for stale detection).

## Why now

`/flow:audit` is the runner for Q29's 35-gate stack. Without it:
- Q29's gate manifest is unrunnable (sub-skills declare contracts but no consumer enumerates them).
- `/flow:ship` (BC-6977) cannot fire its ship-readiness pre-flight per Q38 sub-decision 5.
- `/flow:plan-{discipline}` (BC-6961 children) cannot fire their per-discipline pre-completion check.
- `/flow:audit` smoke-test fixture (BC-7059) and Brand Hub dogfood (BC-6998) both block on this.

BC-6955 (`skills/_shared/` utility kit) is **Done** (merged 2026-05-11) — `audit-concerns` marker is registered in `_shared/linear-writeback-pattern.md` v1 enum as reserved/unused, satisfying the v1.1 deferred-decision precondition.

## Out of scope

- Linear writeback for `audit-concerns` (Q38 sub-decision 4 deferred-decision resolution: stays strictly local in v1; reserved for v1.1 `--linear-surface[=parent|milestone]` flag promotion).
- `--strict` flag (Q38 sub-decision 6 explicit v1.1 parking lot).
- `--audit-preflight` flag for `/flow:review` bundling (plugin CLAUDE.md § Boundaries — v1.1 parking lot #48).
- Promoting Q38 sub-decision 3's batched `list_issues` pattern to `_shared/linear-batched-list-pattern.md` (parking lot #27 — v1.1 if a third caller emerges).
- Implementing `verify-docs.sh` itself (lives in the consuming project's `scripts/` directory; FDA invokes it but does not author it).

## Sections of the deliverable

The single `commands/audit.md` file contains:

1. **Frontmatter** — `description:` line per the cadence/sibling convention.
2. **Heading + one-line role** — utility, not orchestrator.
3. **Architecture overview** — three-phase ASCII diagram (Phase A → Phase B → Phase C with halt-aware short-circuit).
4. **Invocation** — `/flow:audit [--domain=<CODE>] [--flow=<DOMAIN-NN>] [--discipline={story|eng|design|qa|docs}] [--gate=<id>] [--json] [--no-verify-docs]` table mapping each flag to behavior.
5. **Filter composition** — defaults full-project markdown; `--domain=TEAM --discipline=eng` composes to TEAM's [Eng] gates only (Q38 sub-decision 1).
6. **Auto-invocation contract** — `/flow:ship` pre-flight + `/flow:plan-{discipline}` pre-completion. NOT auto-invoked by orchestrators (Q38 sub-decision 5).
7. **Phase A — `verify-docs.sh`** — invokes `bash scripts/verify-docs.sh` from project root. On failure, Phase B+C marked `skipped (verify-docs failed)`. `--no-verify-docs` skip path (debugging only).
8. **Phase B — deterministic filesystem gates** — Q29.2 22 per-flow checks (Story 5 + Eng 4 + Design 3 + QA 5 + Docs 5) + Q29.1 phase-transition file-existence gates that don't need Linear MCP.
9. **Phase C — Linear MCP gates** — Q29.3 cross-cutting (5 checks) + Q29.2 [Eng]/[Design]/[Docs] state checks. Adopts Q38 sub-decision 3 batched `list_issues({labels: ["domain:<slug>"]})` pattern inline (~14s on 28-domain project vs ~125s naive).
10. **Output formats** — markdown to stdout (default per Q29.6: Phase status table + per-flow discipline-grid + cross-cutting consistency report + Summary line + Overrides section); `--json` shape `{gates: [{id, type, status, scope, message}], summary: {hard_pass, hard_fail, soft_warn, overrides, exit_code}}`.
11. **Exit codes** — `exit 0` (all hard gates pass; overrides counted as pass per Q29.5), `exit 1` (any unoverridden hard-gate fail), `exit 2` (verify-docs.sh failed), `exit 64` (invalid args, `os.EX_USAGE`).
12. **Override semantics** — `Override` decisions counted as pass per Q29.5; recorded in breadcrumb's `overrides[]` slot `{gate, reason, timestamp, scope}` per Q31.1; surfaced in audit output (no auto-clear).
13. **Stale-override detection** — scan breadcrumb's `overrides[]` for: (a) entries with `timestamp` older than **30 days** from now; (b) entries where the underlying gate condition has changed (e.g., overridden gate was "file missing" but file now exists). Surface in Overrides section as **"Stale overrides — re-evaluate"** subsection.
14. **L-review coverage clarification** — L3 covered via Q29.3 `parent-l3-summary-populated`; L2 intentionally NOT gated (Q26 mod 2 locks the section as optional); L1 awaits Q41 lock.
15. **v1 boundary note** — `audit-concerns marker reserved` in Q46 enum but UNUSED in v1; v1.1 promotion via `--linear-surface[=parent|milestone]` flag (Q38 amendment territory).
16. **See also** — Q29 lock pointer, Q38 lock pointer, Q46 layer pointer, sibling commands, _shared/artifact-gate-pattern.md.

## Tasks

### T1 — author `plugins/flow-architecture/commands/audit.md`

Write the file end-to-end per the section list above. Faithful echo of Q38 + Q29 + Q38 sub-decision 4 resolution; do NOT re-derive (per BC-6962/BC-6963/BC-6965 task-1 precedent — orchestrator MD = canonical body-text spec).

Verify each greppable AC anchor at write time (don't paraphrase the load-bearing strings):
- `Phase A` literal (3 separate occurrences across the file are fine; AC just needs `grep -q`).
- `Phase B`, `Phase C` literal.
- `--domain`, `--flow`, `--discipline`, `--gate`, `--json`, `--no-verify-docs` literal.
- `exit 0`, `exit 1`, `exit 2`, `exit 64` literal.
- `verify-docs.sh` literal.
- `list_issues` followed eventually by `domain:` substring on the same line.
- `30-day` or `30 day` somewhere referencing the staleness threshold.
- `audit-concerns marker reserved` exact phrase.
- `v1.1 only` OR `v1.1 promotion` exact phrase.

### T2 — bump plugin version 0.2.8 → 0.2.9

Per CLAUDE.md gotcha (BC-6000 same-commit rule, **29th consecutive**). Bump BOTH files:
- `plugins/flow-architecture/.claude-plugin/plugin.json` `version: "0.2.9"`
- `.claude-plugin/marketplace.json` flow-architecture entry version field

### T3 — verify all 9 acceptance-criteria greps + scripts/validate.sh

Run each grep as a discrete bash check; capture exit codes. Then run `./scripts/validate.sh` for CI-equivalent validation.

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Drafter paraphrases load-bearing strings (`audit-concerns marker reserved`, `v1.1 only`/`v1.1 promotion`) | Med | T1 explicitly enumerates verbatim anchors; verify each one immediately after write before T3 |
| Wrong file count / version-bump skipped | Low | T2 is its own task with explicit BC-6000 same-commit rule citation |
| `verify-docs.sh` framed as plugin-owned (it's consuming-project-owned) | Med | Plan + drafter call out: file lives in consuming project's `scripts/`, not in `plugins/flow-architecture/scripts/` |
| Breadcrumb-write framing leaks into audit.md (utility, not orchestrator — does NOT write breadcrumb) | Med | Plan explicitly says "READS `overrides[]` only" — no breadcrumb writes anywhere in the file |
| `--no-verify-docs` flag forgotten (only 5/6 flags grepped) | Low | T1 anchors enumerate all 6 flags |

## Verification commands

```bash
# T1 file existence
test -f plugins/flow-architecture/commands/audit.md

# AC greps (run from worktree root)
F=plugins/flow-architecture/commands/audit.md
grep -q "Phase A" "$F" && grep -q "Phase B" "$F" && grep -q "Phase C" "$F"
for flag in -- domain -- flow -- discipline -- gate -- json -- no-verify-docs; do :; done  # pseudo
grep -q -- "--domain" "$F"
grep -q -- "--flow" "$F"
grep -q -- "--discipline" "$F"
grep -q -- "--gate" "$F"
grep -q -- "--json" "$F"
grep -q -- "--no-verify-docs" "$F"
grep -q "exit 0" "$F" && grep -q "exit 1" "$F" && grep -q "exit 2" "$F" && grep -q "exit 64" "$F"
grep -q "verify-docs.sh" "$F"
grep -qE "list_issues.*domain:" "$F"
grep -qE "30.day|30-day" "$F"
grep -q "audit-concerns marker reserved" "$F"
grep -qE "v1.1 only|v1.1 promotion" "$F"

# T2 version bump
grep -q '"version": "0.2.9"' plugins/flow-architecture/.claude-plugin/plugin.json
grep -q '"version": "0.2.9"' .claude-plugin/marketplace.json

# T3 CI-equivalent
./scripts/validate.sh
```

## Handoff to /workflows:review

Once all greps pass + validate.sh exits 0, hand off to `/workflows:review` (thorough loop per BC-6965 precedent — iterate until clean). Then `/workflows:ship` for PR + Linear close + compound learnings.
