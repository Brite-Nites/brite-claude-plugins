# BC-5040 Plan — Phase 1: Validate Outbound Pipeline Research

**Issue:** [BC-5040](https://linear.app/brite-nites/issue/BC-5040/design-outbound-agent-architecture-phase-1-validate-prior-research)
**Branch:** `holden/bc-5040-validate-outbound-research`
**Worktree:** `~/Projects/work/brite-nites/bc-5040-validate-outbound-research`
**Parent (canceled):** BC-2736
**Source of truth:** BC-5040 issue description (this plan is a session-specific execution companion, not a replacement)

---

## Metadata

- **Inputs:**
  - Research WIP on branch `holden/bc-2714-research-wip`, file `docs/research/outbound-pipeline-research-wip.md` (183 lines, 15 claims to validate)
  - 3 external repos at `~/Projects/work/brite-nites/{outbound-sales-ops, brite-salesforce, brite-data-platform}` — already fetched this session (origin/main: 82169c1, e8995a0, 7653736 respectively)
  - Handbook at `/brite-nites/handbook` via Context7 (or local clone at `~/Projects/work/brite-nites/handbook` if available)
- **Outputs:**
  - `docs/research/outbound-pipeline-research-wip.md` (copied + annotated) in the BC-5040 worktree
  - Draft PR against `main`
  - Linear comment on BC-5040
- **Non-goals:** ADRs (BC-5041), design doc (BC-5042), any writes to external repos, any user Q&A mid-execution
- **No build/test/lint commands to run** — this is a doc-only PR. The repo has no build/test/lint per CLAUDE.md.

## Pre-execution bookkeeping

- Main worktree (this session): `/Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins` on `main`
- After approval, Step 7 creates a new worktree + branch for BC-5040

---

## Task breakdown (T1–T9)

### T1. Create worktree and copy plan forward (Step 7/8 action)

- **What:** Create worktree + branch, copy this plan into it so it ships with the PR.
- **Commands:**
  ```bash
  git -C ~/Projects/work/brite-nites/britenites-claude-plugins worktree add \
    ~/Projects/work/brite-nites/bc-5040-validate-outbound-research \
    -b holden/bc-5040-validate-outbound-research
  cp docs/plans/BC-5040-plan.md \
    ~/Projects/work/brite-nites/bc-5040-validate-outbound-research/docs/plans/BC-5040-plan.md
  ```
- **Verify:** Worktree exists at expected path; branch is new (no commits ahead of main); plan file present in worktree.

### T2. Copy research WIP forward into BC-5040 worktree

- **What:** Extract the 183-line research WIP from `holden/bc-2714-research-wip` and write it into the BC-5040 worktree at the same path.
- **Commands:**
  ```bash
  cd ~/Projects/work/brite-nites/bc-5040-validate-outbound-research
  mkdir -p docs/research
  git show holden/bc-2714-research-wip:docs/research/outbound-pipeline-research-wip.md \
    > docs/research/outbound-pipeline-research-wip.md
  ```
- **Verify:**
  ```bash
  diff <(git show holden/bc-2714-research-wip:docs/research/outbound-pipeline-research-wip.md) \
       docs/research/outbound-pipeline-research-wip.md
  # must print nothing
  ```

### T3. Validate MCP servers (1a — 8 parallel Explore subagents)

- **What:** Launch 8 Explore subagents in parallel — one per target. READMEs only, no install/API calls.
- **Subagent prompt template** (use the same template for all 8, swap `<target>`):
  > I'm validating a claim about the `<target>` MCP server for an architecture decision.
  > Please find it on GitHub or npm (or confirm it does NOT exist).
  >
  > If it exists: fetch the README and return a markdown block with: full repo URL, tool count, tool list (names only), auth method (API key / OAuth / JWT / none), latest commit date, star count, open issue count, and a 2–3 sentence production-readiness assessment.
  >
  > If it does NOT exist after thorough search: return `NOT FOUND` plus a list of what you searched (GitHub query, npm query, any relevant keywords).
  >
  > Do NOT install anything, do NOT make API calls, do NOT clone the repo. READMEs only. Return under 400 words.
- **Targets (1 subagent each):**
  1. `@salesforce/mcp` (official)
  2. `apolloio/apollo-mcp-plugin` (official)
  3. `LeadMagic/smartlead-mcp-server` (community, 116+ tools claim)
  4. `emailbison-mcp-server` (community, read-only claim)
  5. `resend/resend-mcp` (official)
  6. OutboundSync — expected: NOT FOUND
  7. Master Inbox — expected: NOT FOUND
  8. **Discovery agent:** "Search GitHub and npm for any NEW `mcp-server-*` packages published since 2026-04-01 that target outbound sales tools (cold email, sequencing, enrichment, CRM, reply processing). Return a list with repo/package URL + 1-line description each. Return under 400 words."
- **Verify:** 8 structured responses received. Each has either a complete data block or an explicit `NOT FOUND`.

### T4. Validate brite-data-platform claims (1b — serial)

- **What:** Read-only validation against `origin/main` of brite-data-platform. Read local HEAD only if a claim is explicitly marked as local-only by the user.
- **Claims to verify (from research WIP §1 Layer 1):**
  1. Enrichment CLI: `python -m enrichment.cli` with subcommands `run-recipe, ingest-people, discover-people, check-spend`
  2. Golden record schema: `dim_people` + `dim_companies` with field-level survivorship + 10-point quality scoring
  3. Audience views: "planned but not yet built"
  4. Single-writer gold pattern: Python → RAW, dbt → ANALYTICS
  5. Email waterfall: IcyPeas → Prospeo → LeadMagic (in that order, with prices ~$0.01, $0.02, $0.03)
  6. Verification stack: BounceBan (deliverability) + EmailGuard (ESP detection)
  7. Cost claim: ~$0.045/contact for full enrichment
  8. Acquisition layer: Serper Places API + Apollo People Search API
- **Commands (examples):**
  ```bash
  RP=~/Projects/work/brite-nites/brite-data-platform
  # 1. Enrichment CLI
  git -C $RP show origin/main:enrichment/cli.py 2>/dev/null | head -80
  git -C $RP ls-tree -r origin/main | grep -i "enrichment/cli"
  # 2. dbt models
  git -C $RP ls-tree -r origin/main | grep -iE "dim_(people|companies)"
  # 3. Audience views
  git -C $RP grep -l "audience_view" origin/main -- 'models/**' 2>/dev/null || echo "not found"
  # 4-8. CLAUDE.md for architectural claims and cost
  git -C $RP show origin/main:CLAUDE.md | head -200
  ```
- **Verify:** Every claim in the list above has a ✓ / ✗ / ? marker plus a file reference (path + line number if applicable).

### T5. Validate outbound-sales-ops claims (1b — serial)

- **What:** Same pattern as T4, targeting outbound-sales-ops.
- **Claims to verify (from research WIP §1 Layer 3):**
  1. Repo stack: TypeScript on Vercel Serverless + Supabase Postgres
  2. 3 Cloud Functions by exact name: `label-sync`, `reply-notification`, `message-router`
  3. `label-sync` behavior: classification → SF sync → Email Bison block list → Slack → MI list routing
  4. `reply-notification` behavior: Speed to Lead → Slack #positive-replies, <30s SLA
  5. `message-router` behavior: BDR reply tracking (Connected, Follow-Up)
  6. Priority resolution order: Suppress > Escalate > Speed to Lead > Redirect > Archive > Deferred > Triage > No Action
  7. 3 architectural rules: no tool-to-tool writes, single-label enforcement in Master Inbox, upgrade-only lifecycle transitions
  8. 5 cron jobs by exact name: `replay-pending, error-rate-monitor, canary, send-count-reconciliation, lifecycle-check`
  9. 6 Master Inbox BDR lists: Hot, Pending Action, Needs Triage, Connected, Follow-Up, Archived
- **Commands (examples):**
  ```bash
  RP=~/Projects/work/brite-nites/outbound-sales-ops
  git -C $RP ls-tree -r origin/main | grep -iE "(label-sync|reply-notification|message-router)"
  git -C $RP show origin/main:vercel.json 2>/dev/null || git -C $RP show origin/main:package.json
  git -C $RP show origin/main:CLAUDE.md | head -200
  # Priority resolution
  git -C $RP grep -n "PRIORITY\|priority" origin/main -- '**/label-sync*' 2>/dev/null | head -40
  # Crons
  git -C $RP show origin/main:vercel.json 2>/dev/null | grep -A 30 "crons"
  ```
- **Verify:** 9 markers with file references.

### T6. Validate brite-salesforce claims (1b — serial)

- **What:** Same pattern, targeting brite-salesforce.
- **Claims to verify (from research WIP §1 Layer 4):**
  1. Stack: Salesforce Enterprise Edition, SFDX source-driven, Apex-first
  2. 3 business lines: Brite Nites (residential), Brite Labs (commercial), Brite Supply (SaaS)
  3. 8-stage lifecycle: Cold_Prospect → Lead → MQL → SQL → Active Opp → Active Customer → Pending Renewal → Inactive Customer
  4. Custom objects: `Territory__c`, `Lifecycle_Stage_History__c` (audit trail)
  5. 7 Opportunity Record Types with business-specific stage sequences
  6. HubSpot → Salesforce migration in progress; 26/50 accounts validated at time of research
  7. Integration points: Brite Base (ops app), Aircall, web forms, NetSuite, Snowflake/Fivetran
- **Commands (examples):**
  ```bash
  RP=~/Projects/work/brite-nites/brite-salesforce
  git -C $RP ls-tree -r origin/main | grep -iE "Territory__c|Lifecycle_Stage_History"
  git -C $RP ls-tree -r origin/main | grep -i "Opportunity.*recordType"
  git -C $RP show origin/main:CLAUDE.md | head -200
  git -C $RP show origin/main:README.md 2>/dev/null | head -100
  git -C $RP grep -l "Cold_Prospect\|MQL\|SQL" origin/main 2>/dev/null | head
  ```
- **Verify:** 7 markers with file references.

### T7. Validate tool stack via automated discovery (1c — no user Q&A)

- **What:** Every §2 handbook-drift claim gets verified via handbook query + repo grep, not a user question.
- **Claim 1 — Email Bison as sole sequencer:**
  ```bash
  # Context7 handbook query (use resolve-library-id if needed)
  # Then grep repos for Smartlead
  git -C ~/Projects/work/brite-nites/outbound-sales-ops grep -l -i "smartlead" origin/main 2>/dev/null | head
  ```
  - No matches → `[VERIFIED 2026-04-09]`
  - Matches → document the files, mark `[UNCERTAIN]`
- **Claim 2 — Aircall → Dialpad:**
  ```bash
  git -C ~/Projects/work/brite-nites/outbound-sales-ops grep -l -i "dialpad\|aircall" origin/main 2>/dev/null
  git -C ~/Projects/work/brite-nites/brite-salesforce grep -l -i "dialpad\|aircall" origin/main 2>/dev/null
  ```
- **Claim 3 — HubSpot → Salesforce migration status:**
  ```bash
  git -C ~/Projects/work/brite-nites/brite-salesforce show origin/main:CLAUDE.md | grep -iA 3 "hubspot\|migration"
  git -C ~/Projects/work/brite-nites/brite-salesforce ls-tree -r origin/main | grep -i migration
  ```
- **Claim 4 — New tools since 2026-04-01:**
  ```bash
  git -C ~/Projects/work/brite-nites/outbound-sales-ops log --since=2026-04-01 --until=2026-04-09 origin/main --oneline
  git -C ~/Projects/work/brite-nites/brite-salesforce log --since=2026-04-01 --until=2026-04-09 origin/main --oneline
  git -C ~/Projects/work/brite-nites/brite-data-platform log --since=2026-04-01 --until=2026-04-09 origin/main --oneline
  ```
- **Verify:** 4 findings logged with sources. Any that can't be resolved get `[DEFERRED: reason]`.

### T8. Write the Phase 1 Validation Log and inline markers

- **What:** Append §8 to the WIP and add inline `[VERIFIED 2026-04-09]` / `[CORRECTED 2026-04-09: ...]` / `[DEFERRED: ...]` markers next to each validated claim in §1, §2, §3.
- **Format:** Additive only — do not rewrite or delete original content. Use Edit tool with exact old_string matches.
- **Verify:** `grep -c "^## 8\. Phase 1 Validation Log"` returns 1; `grep -c "\[\(VERIFIED\|CORRECTED\|DEFERRED\)" docs/research/outbound-pipeline-research-wip.md` ≥ 15.

### T9. Commit, push, open draft PR, comment on BC-5040

- **What:** Commit both files, push, open draft PR, comment on Linear.
- **Commands:**
  ```bash
  cd ~/Projects/work/brite-nites/bc-5040-validate-outbound-research
  git add docs/plans/BC-5040-plan.md docs/research/outbound-pipeline-research-wip.md
  git commit -m "BC-5040: Validate outbound pipeline research claims

  Phase 1 of the outbound agent architecture work (superseded BC-2736).
  Copies research WIP forward from holden/bc-2714-research-wip, validates
  all 15 claims against current repo/handbook state, and writes a
  Phase 1 Validation Log with per-claim status.

  Supersedes: BC-2736 (split into BC-5040/5041/5042)
  Blocks: BC-5041"
  git push -u origin holden/bc-5040-validate-outbound-research
  gh pr create --draft \
    --title "BC-5040: Validate outbound pipeline research" \
    --body "..."
  ```
- **Linear comment (via save_comment on BC-5040):** Summary of findings, X verified / Y corrected / Z deferred, link to PR, list of open questions for BC-5041.
- **Verify:** `gh pr list --head holden/bc-5040-validate-outbound-research --json number` returns a PR; Linear comment API returns a comment ID.

---

## Risk log

| Risk | Mitigation |
|------|-----------|
| Subagent returns inconsistent output shapes | Fixed prompt template with explicit "return under 400 words" and required fields |
| Brite repo paths or file names have changed since 2026-04-01 | Every claim verification includes a `ls-tree` or `grep` fallback — if the expected file doesn't exist, search broadly before marking `?` |
| Handbook claims can only be verified via Context7 (no local clone) | Both paths supported — handbook at `~/Projects/work/brite-nites/handbook` OR Context7 query. Either satisfies the claim. |
| User's feature-branch WIP on external repos might contain newer architecture | Access pattern is `origin/main` by default. If validation shows a `[DEFERRED: requires local HEAD of <branch>]`, the main session pauses and asks the user. |
| Some WIP claims are behavioral (e.g., "priority resolution order") and span multiple files | Accept `? partial — logic verified in label-sync:N, routing verified in router.ts:M` as valid status |
| New MCP servers discovery query returns nothing OR too many false positives | Acceptable outcome — discovery is explicitly "find or NOT FOUND". A clean "no new MCP servers published since 2026-04-01" is a valid answer. |

## Objective verify checklist (from BC-5040 issue)

At the end of execution, every one of these must pass:

1. [ ] `docs/research/outbound-pipeline-research-wip.md` exists in BC-5040 worktree
2. [ ] `grep -c "## 8\. Phase 1 Validation Log" <file>` returns 1
3. [ ] MCP server table in §3 has 8 rows with explicit status
4. [ ] 1b section has 3 repos with per-bullet status + file references
5. [ ] 1c section has 4 findings
6. [ ] `grep -c "\[\(VERIFIED\|CORRECTED\|DEFERRED\)" <file>` ≥ 15
7. [ ] `git log --oneline | grep "Validate outbound pipeline research"` returns a match
8. [ ] `gh pr list --head holden/bc-5040-validate-outbound-research --json number` returns a PR
9. [ ] Linear comment posted on BC-5040 containing the PR URL

If any of the 9 checks fails, fix the underlying issue before marking the session complete. Do not mark tasks completed until their verify step passes.

## Exit criteria for this session

1. Draft PR open from `holden/bc-5040-validate-outbound-research` against `main`
2. All 9 objective verify checks pass
3. TaskCreate list shows T1–T9 complete
4. BC-5040 has a Linear comment linking the PR
5. No modifications made to any external Brite repo working tree (read-only throughout)
