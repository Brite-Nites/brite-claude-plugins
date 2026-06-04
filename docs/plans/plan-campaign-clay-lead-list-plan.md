# Plan: plan-campaign — Clay lead-list spec + scaffold PR (branch tidy-up)

**Branch**: `drake/plan-campaign-two-issue-rework` (continuation — commit lands on this branch before merge)
**Decisions** (operator-confirmed 2026-06-04):
- Scaffold PR target: **brite-plugins** (this repo). brite-gtm migration deferred to a future ADR — moving `docs/campaigns/` would break the §9a suppression mine + 4 sibling readers (launch-campaign, campaign-analysis, campaign-debrief, portfolio-snapshot) per ADR-013/016.
- Branch naming: **`campaign/<slug>`** — the existing collision-checked V×P×O×M slug IS the wave naming convention's milestone form made git-ref-safe (the literal `FY26, M05 | Vertical | Offer` format contains spaces → invalid ref; Email_Type/ESP don't exist at scaffold time).
- Git in skill: **auto branch + commit + PR**, soft-fail, reviewer `corinne-brewer` (canonical spelling: Corinne).

## Tasks

### Task 1 — Frontmatter + overview updates
**File**: `plugins/marketing/commands/plan-campaign.md`
- `description:`: append "+ Clay lead-list spec (`lead-list.md`) + scaffold PR (branch `campaign/{slug}`, reviewer Corinne)" phrasing.
- `argument-hint:`: add `[--no-pr]`.
- Layer table ("Plugin filesystem" row): mention `manifest.json` **+ `lead-list.md`**.
- "Outputs" list: add the lead-list spec file + the scaffold PR (soft-fail, may be null).
- Flag table (Step 1): add `--no-pr` row — "Skip § 9f (branch + commit + PR). Files still written; operator commits via /workflows:ship."

### Task 2 — Soft-fail philosophy + idempotency sections
- Soft-fail philosophy: add § 9f (git/gh) to the soft-fail list. Linear milestone + 2 issues + manifest + lead-list.md remain the hard gates. Any git/gh error → WARN + a copy-pasteable manual command block at Step 10.
- Idempotency notes: branch already exists from a partial run → reuse it (WARN, no delete); `gh pr create` failing because a PR already exists for the branch → treat like `duplicate_slug` (INFO, reuse existing PR URL).

### Task 3 — New `### 9e — Write the Clay lead-list spec`
Inside `## Step 9` (after 9d; letter-suffix headings stay invisible to the validate.sh Step-sequence lint and inside the tests' Step 9 extraction window).
- Path: `docs/campaigns/<entity>/<slug>/lead-list.md`.
- **Redundant by design**: header note states the Linear issue (identifier captured at 9d) is the tracking surface; this file is the durable, machine-loadable artifact Corinne loads into **Clay MCP** context when building the table.
- Content contract — rendered from the SAME §9a drafted content as the 9c issue body (one drafting pass, two renderings; no second drafting step):
  - Header: slug, campaign milestone, Linear issue identifier + due date
  - ICP / account-level filters
  - Decision-maker title cascade (canonicals `titles[]`, YAML order)
  - Volume tier breakdown (per `--volume`)
  - Exclusion logic with prior-campaign EB campaign IDs (§9a mine) + 180-day rule callout
  - Output CSV column contract (same columns as 9c acceptance criteria)
  - Verification: MillionVerifier SMTP, bounce-risk <5%
  - "Using this spec with Clay" section: load file as Clay MCP context, map title cascade → Clay enrichment columns, sources (per handbook stack: Clay w/ Leadmagic, Prospeo, Icypeas, BounceBan)
- NEVER bare-TODO rule applies (same as 9a).

### Task 4 — Reconcile 9c issue body with Clay + spec pointer
- Source-stack bullets: add `**Clay** — list build + enrichment workspace (Leadmagic / Prospeo / Icypeas / BounceBan)` (keep existing ZoomInfo/LinkedIn Sales Nav + MillionVerifier lines — contract-tested markers).
- Add a `**Spec file:**` line: `docs/campaigns/<entity>/<slug>/lead-list.md` (+ PR link once § 9f runs) — load into Clay MCP context.

### Task 5 — New `### 9f — Scaffold branch + commit + PR (soft-fail)`
Skipped entirely when `--no-pr`. Sequence (all via Bash; every step soft-fail per Task 2):
1. `git checkout -b campaign/<slug>` (from current HEAD; if exists → `git checkout campaign/<slug>` + WARN).
2. `git add docs/campaigns/<entity>/<slug>/` — ONLY this directory. Never `git add -A`.
3. `git commit -m "feat(campaigns): scaffold <slug> — manifest + lead-list spec"`.
4. `git push -u origin campaign/<slug>` — plain push, NEVER `--force` (hook-blocked repo-wide).
5. `gh pr create --base <default-branch> --title "Campaign scaffold: <slug>" --reviewer corinne-brewer --body <...>` — body links milestone URL, both issue identifiers, lead-list spec path, and states Corinne's review of `lead-list.md` is the gate before list-build starts.
6. Capture PR URL for Step 10. Stay on `campaign/<slug>` (keeps the campaign dir visible to the §9a mine until merge); tell the operator.
- Note: campaign-state PRs touch only `docs/campaigns/**` → no `plugins/**` change → version-bump pre-commit guard does not fire. Intentional.

### Task 6 — Step 5 preview, Step 10 summary, 10.3 handoff
- Step 5 dry-run preview: add `Lead-list spec:` path line + `Scaffold PR:` block (branch name, target repo = origin, reviewer corinne-brewer, or "skipped (--no-pr)").
- Step 10 summary: add `Lead-list spec:` + `Branch:` + `PR:` lines (PR null + manual command block on soft-fail).
- 10.3 handoff: "Corinne reviews + merges the scaffold PR, builds the list per `lead-list.md` via Clay…" before the email-copywriting/launch-campaign pointer.

### Task 7 — Contract tests
**File**: `plugins/marketing/tests/test_plan_campaign_contracts.py` — new tests:
- `test_lead_list_spec_documented` — `lead-list.md` path format + "Clay" in Step 9 section.
- `test_lead_list_spec_single_drafting_pass` — 9e states it renders from the §9a content (no independent drafting).
- `test_scaffold_pr_step_documented` — `campaign/<slug>` branch format + `corinne-brewer` reviewer in Step 9 section.
- `test_scaffold_pr_is_soft_fail` — 9f referenced in the soft-fail philosophy section.
- `test_scaffold_pr_never_force_pushes` — `--force` absent from the 9f section; plain `git push -u` present.
- `test_no_pr_flag_documented` — `--no-pr` in flag table.
- Run: `python3 -m pytest plugins/marketing/tests/test_plan_campaign_contracts.py -q` — all pre-existing tests must stay green.

### Task 8 — Version bump + validate + commit
- `plugins/marketing/.claude-plugin/plugin.json`: `0.13.0` → `0.14.0`; matching `.claude-plugin/marketplace.json` entry — same commit (plugin-cache gotcha).
- `./scripts/validate.sh` (includes Step-sequence lint + hooks tests) — must pass.
- Commit on `drake/plan-campaign-two-issue-rework`: `feat(marketing): plan-campaign scaffolds Clay lead-list spec + campaign/<slug> PR with Corinne review gate (0.14.0)`.

## Verification
1. `python3 -m pytest plugins/marketing/tests/ -q` — green.
2. `./scripts/validate.sh` — green (no Step-sequence false positives from 9e/9f).
3. `grep -c "Step 9.5\|Step 9\.\d" plugins/marketing/commands/plan-campaign.md` → 0 (no dotted sub-steps).
4. Manual read-through of 9e/9f for drafting-contract coherence with 9a.

## Out of scope
- brite-gtm migration of `docs/campaigns/` (future ADR if desired).
- Clay MCP server registration in the plugin (`lead-list.md` is a context artifact; no new MCP server — keeps the per-plugin MCP soft cap untouched).
- `--reset-slug` / PR cleanup automation.
