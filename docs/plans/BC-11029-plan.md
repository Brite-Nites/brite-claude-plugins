# BC-11029 — flow-architecture: ship project-side verify-docs.sh ecosystem via /flow:retrofit-project

**Status:** plan v1 — pending exec.
**Issue:** [BC-11029](https://linear.app/brite-nites/issue/BC-11029) (currently in v1.1 milestone; move to v1.2 — see § Version + milestone).
**Branch (planned):** `holden/bc-11029-verify-docs-ecosystem`
**Worktree (planned):** `.claude/worktrees/bc-11029/`
**Source-of-truth reference impl:** `~/Projects/work/brite-nites/brite-roster` post-PR-#8 (commit 8c5ab9e, merged 2026-05-20). Read-only side-trip.

## Goal

Plugin ships `plugins/flow-architecture/templates/{scripts,.flow}/` carrying the canonical reference impl of the verify-docs.sh ecosystem. `/flow:retrofit-project` Phase 1 grows a templates-scaffold step that copies the templates into the consumer project + sed-substitutes placeholders + `chmod +x` after `.flow/config.json` is written, before the Phase 1 breadcrumb advances. Q58 captures the A/B/C decision + Option C migration trigger.

## Out of scope (matching handoff)

- `/flow:start-project` parity — file sibling BC as follow-up.
- brite-roster swap to plugin-provided scripts — manual diff for functional equivalence noted in PR body; commit deferred to sibling BC.
- brite-base swap — let template stabilize over 1-2 more retrofits.
- Option C (plugin-owned logic + thin project wrapper) — planned end-state, deferred to v1.x / v2.
- Q12 `.flow/config.json` schema amendment (skip: use placeholder substitution at copy-time instead).
- `verify-docs.sh` new checks — separate v1.x feature issues.
- Pre-commit hook integration — per-project concern.
- Retire manual-orchestration fallback — separate ~30-min follow-up (BC-10352 + BC-10728 unlocked it; not bundled here).
- R2 cdr-compliance-reviewer's legacy-UPPERCASE-inventory handbook-drift item — separate cross-repo session.

## Design calls (key ones)

1. **Phase positioning** — insert a `templates-scaffold` step inside `/flow:retrofit-project` **Phase 1**, AFTER `flow-preflight` returns + `.flow/config.json` is written, BEFORE the Phase 1 terminal breadcrumb write. Atomic phase boundary; if any sub-step fails, Phase 1 fails closed per Q36.5.
2. **Q29.7 reconciliation** — Q29.7 still locks "verify-docs.sh is consumer-project-owned." Q58 doesn't override this; it specifies the canonical TEMPLATE SOURCE without changing ownership semantics. The consumer still owns the on-disk script.
3. **Placeholder substitution > schema amendment** — ship template scripts with `<LINEAR_PROJECT_ID>`, `<LINEAR_ORG_SLUG>`, `<EXPECTED_FDA_ISSUE_COUNT>`, `<PROJECT_NAME>` placeholders; orchestrator sed-substitutes at copy-time. Avoids a Q12 schema amendment.
4. **Genericize divergences** — brite-roster's `EXPECTED_PHASE_4_COUNT = 240`, 12-domain `FDA_DOMAINS` set, `LINEAR_ORG = "brite-nites"`, and project-specific header text all become placeholders or stripped defaults. Count gate defaults to off (`<EXPECTED_FDA_ISSUE_COUNT>` materializes as `0`, signaling "no gate"); FDA_DOMAINS starts empty with a "populate to enable label-hygiene gate" comment.
5. **normalize-fda-frontmatter.mjs is brite-roster-specific** (parent-issue tables + display names + status overrides + flow-id-to-folder map) — ship as TODO skeleton ~80 lines, not the 219-line bootstrap impl.
6. **Idempotency = Option (b)** — default: per-file check; error if any of the 9 target paths exists. `--overwrite-scripts` flag (orchestrator-side) bypasses per-file. No diff prompts in v1.
7. **Version + milestone = 1.2.0** + move BC-11029 to v1.2 milestone. Q57 locked v1.1 = maintenance-only; shipping a new feature in v1.1 violates that scope discipline. v1.2 milestone exists (`aac7eb53-4636-4e13-898d-b72375ddc5a9`); BC-11029 joins BC-10219.
8. **Q58 audit trail** captures (1) A/B/C decision + Option C migration trigger; (2) reference-impl divergences (brite-roster vs brite-base) + how the canonical template resolves them; (3) idempotency design; (4) genericization decisions; (5) Q29.7 cross-cite; (6) cross-link BC-11029 + brite-roster PR #8 + BC-6956.

## Tasks (12 — sequential)

### T1 — Worktree + branch + initial template directory tree
- `git worktree add .claude/worktrees/bc-11029 -b holden/bc-11029-verify-docs-ecosystem main`
- `mkdir -p plugins/flow-architecture/templates/{scripts/lib,.flow/scaffold-log}`
- Baseline test: `./scripts/validate.sh` exits 0.

### T2 — Author 9 template files (genericized batch)
Files (in `plugins/flow-architecture/templates/`):
- `scripts/verify-docs.sh` — copy verbatim from brite-roster (191 lines); the script is already generic enough (uses `git rev-parse --show-toplevel`, reads `LINEAR_API_KEY` from env, no hardcoded org/project). Only change: strip the brite-roster cross-repo path-exclusion regex (`brite-base|brite-recruiting|...`) since it's project-specific; replace with a generic exclusion of standard cross-repo paths (`.git`, `node_modules`, `vendor`).
- `scripts/regenerate-flow-index.sh` — 6-line wrapper, copy verbatim.
- `scripts/regenerate-flow-index.mts` — replace `LINEAR_ORG = "brite-nites"` with `LINEAR_ORG = "<LINEAR_ORG_SLUG>"`; replace `Brite Roster` references in `HEADER_BODY` with `<PROJECT_NAME>` placeholder + a more neutral 3-line section-order paragraph.
- `scripts/verify-linear-references.mts` — replace `BRITE_ROSTER_PROJECT_ID` import with `<LINEAR_PROJECT_ID>`; replace `EXPECTED_PHASE_4_COUNT = 240` with `EXPECTED_FDA_ISSUE_COUNT = <EXPECTED_FDA_ISSUE_COUNT>` (default `0` materialization); count gate becomes a no-op when the constant is `0`.
- `scripts/lib/fda-title.mts` — replace brite-roster's 12-domain `FDA_DOMAINS` set with empty set + comment block: "Populate FDA_DOMAINS with your project's domain codes (e.g., `'TEAM'`, `'AUTH'`) to enable the label-hygiene gate in verify-linear-references.mts. Empty set = gate disabled (no-op)."
- `scripts/lib/linear-graphql.mts` — replace `BRITE_ROSTER_PROJECT_ID = "9c305022-..."` with `EXPECTED_PROJECT_ID = "<LINEAR_PROJECT_ID>"`; rename the export.
- `scripts/normalize-fda-frontmatter.mjs` — ship as ~80-line TODO skeleton with the contract-merge logic intact but the data tables (`PARENT_ISSUES`, `DISPLAY_NAMES`, `STATUS_OVERRIDES`, `DOMAIN_FOLDER`) reduced to empty stubs with `// TODO: populate per-project` comments.
- `.flow/config.json` — canonical schema reference with Q12's 5-field v1 schema (`linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`) populated with `<...>` placeholders. The actual `.flow/config.json` is written by `flow-preflight` Section 4.4 atomic-rename per Q12.4 lock; this template file is **schema reference only**, NOT copied into the project at retrofit time (flow-preflight owns the runtime write).
- `.flow/scaffold-log/SCHEMA.md` — frontmatter schema doc (7 fields: `domain`, `domain_code`, `linear_milestone_id`, `linear_milestone_name`, `created_at`, `created_via`, `total_writes`) + canonical body shape (3 markdown tables: milestone × 1, parents × N, discipline children × 5N). Based on the brite-roster `.flow/scaffold-log/secure-file-ingestion.md` shape.
- `README.md` — install-via-retrofit pattern + Option C migration plan + which placeholders the orchestrator substitutes + how to opt into the label-hygiene gate.

### T3 — Update retrofit-project.md Phase 1 with templates-scaffold step + --overwrite-scripts flag
Edit `plugins/flow-architecture/commands/retrofit-project.md`:
- Add `--overwrite-scripts` flag to the orchestrator's CLI surface (document in the existing flag-table near the top OR add new "Flags" section if absent).
- After the existing `.flow/config.json` write logic + before the "Initial breadcrumb write" subsection: insert a new "**Templates scaffold (BC-11029, Q58):**" subsection that:
  1. Reads `linear_project_id` + `linear_project_url` from MCP `get_project` response captured during preflight.
  2. Derives `LINEAR_ORG_SLUG` from `linear_project_url` (parse `https://linear.app/<org>/...`).
  3. For each of the 9 template-file source paths, computes the target path in the project root.
  4. Idempotency check: if any target path exists AND `--overwrite-scripts` is NOT set, FAIL with `"Templates already present in project (paths listed) — re-run with --overwrite-scripts to replace."`
  5. Otherwise: `cp` template files into target paths, run `sed -i` (BSD-portable: `sed -i ''`) for the 4 placeholders, `chmod +x` on `.sh` files.
  6. Log: `"Templates scaffolded: 9 files written. Run \`bash scripts/verify-docs.sh --no-linear\` to verify."`

### T4 — Append Q58 lock to design-rationale
File: `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` (append after Q57).
~120-180 lines following Q56/Q57 structure (verbatim user-decision lock + sub-decisions + audit trail). Captures: A vs B vs C decision (Option A wins for v1; Option C is planned end-state; Option B rejected); reference-impl divergences observed in brite-roster vs brite-base; placeholder substitution mechanism; idempotency design (default = no overwrite, `--overwrite-scripts` opt-in); Q29.7 cross-cite (consumer-project-owned framing PRESERVED, source clarified); migration trigger for Option C. Lock format follows the Q57 verbatim-with-audit-trail precedent.

### T5 — Update CLAUDE.md surface map + BC-6956 description + version bump
- `plugins/flow-architecture/CLAUDE.md` § Pre-existing-vs-FDA-output mapping — new row noting `templates/` ships and is copied at retrofit Phase 1.
- BC-6956 description update via Linear MCP `save_issue` — append a one-line scope-boundary note: `"BC-6956 = plugin-internal helpers; BC-11029 = project-side toolchain templates."`
- Bump `plugins/flow-architecture/.claude-plugin/plugin.json` `version` 1.1.1 → 1.2.0.
- Bump `.claude-plugin/marketplace.json` matching entry's `version` 1.1.1 → 1.2.0.

### T6 — Move BC-11029 to v1.2 milestone + update body
Linear MCP `save_issue`:
- `id: "BC-11029"`, `milestone: "Flow-Driven Architecture Plugin v1.2"` (milestone id `aac7eb53-4636-4e13-898d-b72375ddc5a9`).
- Body amendment: prepend a one-line `> **Milestone change 2026-05-22 (Q57 scope discipline):** moved from v1.1 → v1.2 per Q57 lock + BC-11029 implementation Q58.` note. Do not rewrite the rest of the body.

### T7 — Add test fixture + harness
- `tests/fixtures/synthetic-fresh-retrofit-target/` — minimal fixture: `docs/product/master-flow-inventory.md` with 1 domain + 1 sub-flow row; empty `docs/product/flows/` + `docs/product/journeys/`; minimal `package.json` with `tsx` listed; empty `node_modules` is fine (template `verify-docs.sh --no-linear` doesn't need `tsx` for the no-linear path — `npm run build/lint/test` is wrapped in `>/dev/null 2>&1 && ... || fail` so missing scripts fail loudly but predictably).
- `tests/run-verify-docs-ecosystem-vslice.sh` — harness asserting:
  - All 9 template files have canonical homes under `plugins/flow-architecture/templates/`.
  - No template file contains a literal `brite-roster` or `brite-nites` string (forces genericization).
  - Each `<PLACEHOLDER>` listed in the README appears in at least one template file (forces placeholder map honesty).
- Wire into `scripts/validate.sh` (new section near existing FDA-helper-scripts section §2b').

### T8 — Run validate.sh + check-guardrails until clean
`./scripts/validate.sh && ./scripts/check-guardrails.sh --claude-md plugins/flow-architecture/CLAUDE.md`. Iterate on findings. Both must exit 0 before T9.

### T9 — /workflows:review iter 1 + fixes
Per BC-6934/9027/10657 discipline: stage explicit paths only (no `git add -A`). Expect 5-6 agents; expect 2-4 P2s on a change this size.

### T10 — /workflows:review iter 2 + final + iter-marker
Loop per [[feedback_review_loops_can_introduce_regressions]] — iter 1 fixes can introduce regressions. Post one-line clean-pass marker comment to PR after final clean iter.

### T11 — Commit + push + PR
- Single squash commit. Branch BC-free per [[gotcha_linear_pr_title_magic_id_auto_close]] 3-axis mitigation. PR title: `flow-architecture 1.2.0: ship verify-docs.sh ecosystem templates + /flow:retrofit-project scaffold phase`. PR body: every BC ref is a markdown link except the intentional `Closes BC-11029` at end. Use `gh pr merge --squash --body-file <clean-body.txt>` if magic-ID-safe squash control needed.
- Do NOT pre-post Linear comment on BC-11029 with PR URL (auto-attach via PR description's `Closes BC-11029`).

### T12 — Manual brite-roster regression check (NO commit)
- Side-trip read-only into `~/Projects/work/brite-nites/brite-roster`.
- Diff each of brite-roster's `scripts/verify-docs.sh` / `regenerate-flow-index.mts` / `verify-linear-references.mts` etc. against the plugin-provided + brite-roster-substituted version (apply the placeholder substitution manually using brite-roster's `LINEAR_ORG_SLUG = "brite-nites"`, `LINEAR_PROJECT_ID = "9c305022-..."`, `EXPECTED_FDA_ISSUE_COUNT = 240`).
- Expect functional equivalence (no diff in execution behavior on brite-roster's docs tree). Note in PR body.
- Do NOT commit brite-roster swap — file sibling BC for that.

## Acceptance criteria mapping

| BC-11029 AC | Plan task | Verification |
|---|---|---|
| AC1 — `/flow:retrofit-project` against fresh project produces working ecosystem | T3 + T7 | T7 vslice asserts files land; manual dry-run check in T8 |
| AC2 — `verify-docs.sh --no-linear` exits 0 on retrofitted project | T7 | vslice + assertion |
| AC3 — All 7 reference files have canonical home under `templates/` | T2 | T7 vslice asserts file count + paths |
| AC4 — New Q-lock captures A/B/C decision + Option C migration | T4 | grep Q-lock contents during T8 |
| AC5 — BC-6956 description updated with layer-boundary note | T5 | post-T5 `get_issue` verifies |
| AC6 — Acceptance test exercises dry-run retrofit | T7 | wired into validate.sh §2b' |
| AC7 — Backward-compat: re-running retrofit doesn't silently overwrite | T3 | `--overwrite-scripts` flag prose + idempotency check |

## Risks + mitigations

- **R1 — sed BSD/GNU divergence (`sed -i` syntax).** Mitigation: use the BSD-portable `sed -i ''` form per CLAUDE.md's macOS-bash-3.2-compat discipline; test on macOS during T8.
- **R2 — placeholder leakage.** A `<LINEAR_PROJECT_ID>` in shipped code rather than just templates would break downstream consumers. Mitigation: T7 vslice grep asserts no `<...>` placeholder strings appear in any non-`templates/` file under `plugins/flow-architecture/`.
- **R3 — brite-roster scripts have undeclared dependencies (`gray-matter`, `tsx`).** Mitigation: T2 + README documents the runtime dependency list; flag `package.json` peer-dependency considerations for the retrofit orchestrator to surface during scaffold output.
- **R4 — Q58 lock contradicts Q29.7.** Mitigation: explicit cross-cite in Q58 body — "Q29.7 consumer-project-ownership semantics PRESERVED; Q58 specifies template SOURCE, not OWNERSHIP."
- **R5 — review-loop regression** per [[feedback_review_loops_can_introduce_regressions]]. Mitigation: T10 explicitly does iter 2; substring-assertion harness in T7 catches regressions.
- **R6 — Linear save_issue valid-ID silent no-op** ([[gotcha_linear_save_issue_state_param]]-adjacent). Mitigation: T6 reads back issue post-`save_issue` to verify the milestone change landed.

## Report-back format

After PR merges:
- PR URL.
- Version landed + milestone state (BC-11029 verified at v1.2).
- Q58 line count + lock-number confirmed.
- 9 template files landed under `plugins/flow-architecture/templates/`.
- Idempotency mechanism = (b) — error if exists, `--overwrite-scripts` flag overrides.
- brite-roster regression check result.
- BC-6956 description update verified.
- validate.sh exit 0.
- Confirmation BC-11029 closed (via `Closes BC-11029` auto-flip per [[gotcha_github_auto_close_linear_state]]).
- Admin-merge note if invoked.
- Any new gotchas worth memorializing.
