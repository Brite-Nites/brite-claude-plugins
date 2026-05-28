# GTM v1.1 Executor Prompt Template

**Purpose**: Reusable Mad-Libs the tracker fills in per BC when the user is about to spawn an executor session. The user pastes the filled prompt into a fresh Claude Code session in a dedicated worktree.

**Filename convention**: `_executor-prompt-template.md` — leading underscore so it sorts above the dated sweep entries in `docs/reconciliation/`.

---

## How the tracker fills this in

1. Read the BC body via `mcp__plugin_workflows_linear-server__get_issue` — pull title, description, validation criteria, dependencies.
2. Identify the BC's class (plugin build / schema / canonicals / discovery / operational / documentation) — drives the validation block.
3. Pick the worktree path (`bc-XXXXX-<short-slug>` under `.claude/worktrees/`).
4. Check the cross-repo target (plugins only, plugins + handbook, plugins + brite-salesforce).
5. Cross-check `git log origin/main` for any sibling BC that already touched the same surface (warn about merge-conflict risk in the "Coordination" block).
6. Paste the filled template back to the user as a code block they can copy-paste into the new session.

---

## Template

````markdown
# Executor session — <BC-NNNNN> <short title>

**Linear**: <BC URL>
**Linear ID**: <BC-NNNNN>
**Tracker-canonical ID**: <issue UUID>
**Milestone**: GTM Campaign Orchestration v1.1
**Priority**: <High | Medium | Low>
**Tier**: <T1 Discovery | T2 Canonicals | T3 Plugin | T4 Operational | T5 Docs>

## You are the executor

You own this BC end-to-end — worktree, code, tests, /workflows:review, PR, merge. Report PR URL + status back through Holden to the tracker session when you land. Do not pick up other BCs; do not file new BCs without surfacing to Holden first.

The tracker session is watching. If you discover the briefed path is infeasible, surface via `AskUserQuestion` BEFORE silently picking an alternative (per `feedback_executor_surfaces_infeasibility.md`).

## Already-filed BCs — DO NOT re-file

<list other v1.1 BCs the executor might re-derive during brainstorm, comma-separated:
BC-11845, BC-11847, BC-11849, BC-11850, BC-11851, BC-11852, BC-11853, BC-11854, BC-11855, BC-11856, BC-11857, BC-11858, BC-11859, BC-11860, BC-11861>

If your brainstorm phase identifies the same gap, treat the existing BC as canonical and skip re-filing.

## Required reading (zero-context primer — read in parallel)

- `memory/project_gtm_v1_closeout_2026-05-27.md` — v1.0 end-state
- `memory/project_gtm_campaign_architecture.md` — 3-layer canon (Handbook=HOW / Linear=orchestration / Plugin=WHAT)
- `memory/project_marketing_vocabulary.md` — vocabulary locks (Vertical, Persona, Offer Posture, etc.)
- `docs/gtm-campaign-orchestration-README.md` — system mental model (v1.3 CLOSED)
- <BC-specific extra reading — e.g., `docs/decisions/016-canonicals.md` for schema work; ADR-015 for σ3 work>

## Working directory

```bash
# From repo root (bare repo — must use worktree)
git worktree add .claude/worktrees/<bc-XXXXX-short-slug> -b holden/<BC-NNNNN>-<short-slug> origin/main
cd .claude/worktrees/<bc-XXXXX-short-slug>
```

## Scope (verbatim from BC body)

<paste the BC's "Scope" or "Implementation Steps" section verbatim — no paraphrase>

## Validation Criteria (verbatim from BC body — must all pass before /workflows:ship)

<paste the BC's "Validation Criteria" section verbatim>

## Out of scope — do not expand

<list any sibling BC scope that this executor might be tempted to absorb, e.g.:
- A2 schema v2 is BC-11852; do NOT modify schema in this session
- σ3 auto-file is BC-11855; do NOT wire it here>

## Coordination with other in-flight executors

<list any in-flight BCs that touch overlapping files; from tracker sweep:
- BC-XXXXX is in flight touching plugins/marketing/data/canonicals/schema.json — coordinate
- None known — clean lane>

## Plugin version bump reminder

This BC touches `plugins/<plugin>/{commands,skills,hooks,agents}/**` → bump BOTH
`plugins/<plugin>/.claude-plugin/plugin.json` AND the matching `.claude-plugin/marketplace.json` entry
in the SAME commit. See CLAUDE.md gotcha (BC-6000 precedent).

<OR — for docs-only BCs:>
This BC is docs-only — no plugin version bump needed.

<OR — for cross-repo BCs:>
This BC ships PRs to BOTH `britenites-claude-plugins` AND `brite-nites/handbook`. Use the two-PR pattern
from BC-8733 (PR #371 + handbook PR #568). Auto-close on the plugin PR; reference the handbook PR in the
plugin-PR body.

## Ship discipline

1. `/workflows:review` — iterate until 0/0/0 (P1/P2/P3 all clean)
2. `/workflows:ship` — PR title format: `<one-line summary>` (NO magic ID in title — gotcha_linear_pr_title_magic_id_auto_close)
3. PR body: include `Closes <BC-NNNNN>` line for auto-close
4. After squash-merge, verify Linear `status: Done` + `completedAt` populated via `get_issue`
5. Paste PR URL + final status back to Holden for tracker validation

## Tracker will verify

- Linear `status: Done` AND `completedAt` populated
- PR merged on `origin/main` with the squash SHA you reported
- Plugin version bumped in plugin.json + marketplace.json (if applicable)
- Validation Criteria above all grep-verifiable in the final tree
- For cross-repo BCs: handbook PR also merged

Failures get reopened — fix and reship rather than papering over.
````

---

## Cross-references

- `feedback_tracker_vs_executor_sessions.md` — role split
- `feedback_executor_surfaces_infeasibility.md` — surface deviations before shipping
- `gotcha_linear_pr_title_magic_id_auto_close.md` — keep BC-NNNNN out of PR titles
- `gotcha_plugins_repo_bare_true_use_worktrees.md` — bare-repo discipline
- `gotcha_parallel_pr_version_collision.md` — plugin-version race when two PRs bump same plugin
