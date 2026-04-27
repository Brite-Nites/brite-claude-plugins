# BC-5806 — Build RevOps SessionStart hook (cwd-aware SF banner)

**Issue:** [BC-5806](https://linear.app/brite-nites/issue/BC-5806/build-revops-sessionstart-hook-cwd-aware-sf-banner)
**Milestone:** RevOps Plugin (Phase 4 — Hooks)
**Branch:** `holden/bc-5806-build-revops-sessionstart-hook-cwd-aware-sf-banner`
**Worktree:** `.claude/worktrees/bc-5806/`

## Goal

Add a `SessionStart` hook to `plugins/revops/` that detects an SFDX-adjacent cwd (presence of `sfdx-project.json` within reach of the user's pwd) and emits a short "RevOps Active" banner listing the three `/revops:*` orchestration commands. Silent in non-SF repos.

This closes Phase 4.1 of the RevOps Plugin master plan and brings the milestone to **22/23 done** (the four Low-priority tail issues — BC-5786, BC-5787, BC-5820 — remain as opportunistic cleanup).

## Issue-vs-ground-truth reconciliation

The issue body was authored 2026-04-19. One spec detail has drifted since:

| # | Spec text | Ground truth (2026-04-26) | Resolution |
|---|---|---|---|
| 1 | Banner names `brite-deploy, brite-permissions, brite-apex, brite-metadata, brite-soql` | Skills are still `sf-*` — renaming deferred per master-plan §13 + Phase 3 customization issues kept the upstream `sf-*` filenames. `ls plugins/revops/skills/` confirms 14 directories all prefixed `sf-`. | Banner uses `sf-*` names verbatim. Substituting `brite-*` would advertise non-existent skills. |

Per BC-5831 task-2 precedent: scope amendments vs issue text recorded as a grep-verifiable table in the plan doc.

## Decisions

### D1 — Probe: unbounded stat-walk up, not find

Issue offered two probe candidates:
- `test -f sfdx-project.json` (sub-ms but only checks pwd)
- `find . -maxdepth 3 -name sfdx-project.json -not -path './node_modules/*'` (always walks down 3 levels)

Chose **unbounded stat-walk up parents**: start at `$PWD`, check for `sfdx-project.json`, walk up until `dirname` returns the same path (filesystem root). Why:
- A user inside `force-app/main/default/lwc/<cmp>/__tests__/` is already 5 levels deep — a 3-cap silently misses them. `find` from pwd would walk down (wrong direction).
- Cost difference between 3-cap and unbounded is ~200µs (4 stat calls vs 5–8). Both well under the 50ms budget. Reliability win is significant; perf cost is noise.
- `dirname /` returns `/`, so the loop self-terminates at filesystem root with no explicit cap.

```sh
dir="$PWD"
while :; do
  [ -f "$dir/sfdx-project.json" ] && { print_banner; exit 0; }
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
exit 0
```

### D2 — Extract probe to `plugins/revops/hooks/sfdx-banner.sh`

Issue threshold: ">10 lines → separate file". Probe + banner together is ~25 lines. Inlining into JSON requires escaping every `\n` and quote, which makes it unreadable. The workflows-plugin precedent inlines a 70-line printf, but that's because it always runs and is single-purpose; ours has conditional logic that benefits from real shell syntax.

Hook entry calls `bash "${CLAUDE_PLUGIN_ROOT}/hooks/sfdx-banner.sh"`.

### D3 — Banner text (final, with sf-* reconciliation applied)

```
RevOps Active

You're in an SFDX project. SF intelligence loaded.

Commands:
  /revops:deploy-sandbox — dry-run + sandbox deploy + tests
  /revops:deploy-prod — prod deploy with double-confirm + Tooling API verify
  /revops:post-deploy-runbook — walk manual post-merge steps

Skills auto-activate by intent: sf-deploy, sf-permissions, sf-apex, sf-metadata, sf-soql, etc.
```

Use `printf` not `echo -e` (memory: `gotcha_prompt_hook_model_id.md` companion convention — `echo` interprets `-e`/`-n` inconsistently across shells).

### D4 — Version bump (BC-6000 same-commit rule)

- `plugins/revops/.claude-plugin/plugin.json`: `0.2.2 → 0.2.3` (patch — adds Phase 4 hook, no breaking change)
- `.claude-plugin/marketplace.json` revops entry: `0.2.2 → 0.2.3`

Bumping in the SAME commit as the hook addition. This is the 12th consecutive session applying the rule per current memory cadence.

## File-by-file changes

| Path | Op | Change |
|---|---|---|
| `plugins/revops/hooks/hooks.json` | NEW | SessionStart entry calling `sfdx-banner.sh` via `${CLAUDE_PLUGIN_ROOT}` |
| `plugins/revops/hooks/sfdx-banner.sh` | NEW | Stat-walk probe + printf banner; `chmod +x` |
| `plugins/revops/.claude-plugin/plugin.json` | EDIT | `version` 0.2.2 → 0.2.3 |
| `.claude-plugin/marketplace.json` | EDIT | revops entry `version` 0.2.2 → 0.2.3 |

`plugin.json` does NOT list `hooks` — auto-discovered by convention (CLAUDE.md gotcha: never add `agents`, `hooks`, or `mcpServers` as string path).

## Verify table — T1-T9 from issue

| # | Test | Pre-state | Action | Pass criteria |
|---|---|---|---|---|
| T1 | Banner present in SF repo | Fresh Claude Code session in `brite-salesforce` | Start session | Banner appears with exact `/revops:*` command list |
| T2 | Silent in non-SF repo (gtm) | Fresh session in `brite-gtm` | Start session | No RevOps banner; session unaffected |
| T3 | Silent in non-SF repo (data) | Fresh session in `brite-data-platform` | Start session | No RevOps banner |
| T4 | Silent in plugin repo itself | Fresh session in `britenites-claude-plugins` | Start session | No RevOps banner |
| T5 | Perf budget — SF cwd | brite-salesforce | `time bash sfdx-banner.sh` | <50ms |
| T6 | Perf budget — non-SF cwd | non-SF repo | `time bash sfdx-banner.sh` | <10ms |
| T7 | Repo validation | working tree | `./scripts/validate.sh` | Exit 0 |
| T8 | Hook lint | working tree | `python3 scripts/_lib/lint_hooks.py plugins/revops/hooks/hooks.json` | All `OK:` lines, no `ERROR:` (no tier-alias model IDs — N/A since `type: command`) |
| T9 | Banner-content grep | working tree | `grep -c '/revops:deploy-sandbox\|/revops:deploy-prod\|/revops:post-deploy-runbook' plugins/revops/hooks/sfdx-banner.sh` | exactly 3 |

T1-T6 require fresh Claude Code sessions in three external repos. T1, T5 = positive controls. T2-T4, T6 = negative controls. T7-T9 run locally.

Cross-repo verification checkboxes (paste into PR body):
- [ ] brite-salesforce (SFDX — banner appears, T1 + T5)
- [ ] brite-gtm (non-SFDX — silent, T2 + T6)
- [ ] brite-data-platform (non-SFDX — silent, T3)
- [ ] britenites-claude-plugins (plugin repo — silent, T4)

## Out of scope (per issue + master plan §10)

- PreToolUse `sfdx` deprecation warner (deferred 4.2 — Jaganpro hooks check first)
- PostToolUse XML validator (cut 4.3 — `sf project deploy start --dry-run` covers it)
- Banner customization UI / user preferences
- Skill renaming `sf-*` → `brite-*` (deferred per master-plan §13)

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` not set in fresh sessions | Low | Already used by workflows hooks.json line 73 — proven pattern. |
| Banner clashes with workflows banner ordering | Low | SessionStart hooks from different plugins concatenate; both are short and visually distinct. |
| `sfdx-project.json` exists outside true SFDX project (e.g. tutorial copy in another repo) | Very low | Acceptable false positive; banner is read-only and harmless. |

## Acceptance

- [ ] All 9 verify tests pass with results pasted in PR body
- [ ] `./scripts/validate.sh` exit 0
- [ ] `python3 scripts/_lib/lint_hooks.py plugins/revops/hooks/hooks.json` clean
- [ ] revops 0.2.3 in both `plugin.json` and `marketplace.json`
- [ ] PR body lists cross-repo checkbox results

## Post-review amendments

| # | Source | Change | Reason |
|---|---|---|---|
| A1 | simplify-pass (efficiency) | Replace `dirname` subshell with `${dir%/*}` parameter expansion | Eliminates fork-per-iteration; non-SF cwd perf 7ms → 3ms. |
| A2 | simplify-pass (efficiency) | Consolidate 7 `printf` calls into single `printf '%s\n'` with multi-arg | Cleaner, fewer printf-builtin invocations. |
| A3 | simplify-pass (quality) | Drop `set -eu` | No failure paths benefit (no pipelines, no optional vars). Per simplify-agent rationale. |
| A4 | review (user feedback at gate) | Remove `🔧` emoji from banner heading | User preference: no emojis in generated content. Also resolves the workflows-banner `🔧` collision flagged by code-reviewer. |
