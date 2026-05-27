# BC-5823 Plan — Port marketing references from Revgrowth1/ai-gtm-workflows

**Linear:** BC-5823 · **Milestone:** Marketing Plugin v0.1 — GTM Workflows (Revgrowth) · **Branch:** `holden/bc-5823-port-marketing-references`
**Upstream:** [Revgrowth1/ai-gtm-workflows](https://github.com/Revgrowth1/ai-gtm-workflows) (MIT) @ `03b30e166d3f8ed0eb9864cd2a78dda719558826`
**Design doc:** `docs/plans/marketing-gtm-expansion.md` §1.1

## Deliverables

1. `plugins/marketing/references/research-processes/` — 16 per-dimension query files (Company: 8, People: 8)
2. `plugins/marketing/references/creative-thinking-models.md` — 5 forcing functions, ≥2 Brite-adapted worked examples
3. `plugins/marketing/references/hidden-signals-library.md` — all upstream industry tables verbatim (≥7) + 3 Brite-entity tables **(Municipalities, HOAs, Universities — swapped from issue body per handbook canon; see Resolved departure #6)**, ≥5 rows each
4. `plugins/marketing/references/shelf-life-patterns.md` — 5 decay categories verbatim
5. `plugins/marketing/references/UPSTREAM.md` — MIT attribution, per-file manifest, upstream SHA, LICENSE link

## Resolved departures from issue body

1. **Serper → WebSearch translation rule.** Issue says "replace any literal `Serper` references." Interpretation: preserve the exact Google-dork query STRINGS verbatim (they are the validated IP); only change the surrounding prose that names the execution tool. Add a one-line note at the top of `research-processes/` explaining the translation.
2. **Frontmatter shape.** Issue says `source: Revgrowth1/ai-gtm-workflows@<sha>`. Use YAML frontmatter block with three fields per file: `source:`, `upstream_path:`, `license: MIT`. Matches ADR-007 §3.6 attribution shape. All 16 research-processes files + the 3 top-level reference docs get this block.
3. **Attribution note placement.** Per UPSTREAM.md convention (`plugins/revops/UPSTREAM.md`), also include an HTML-comment `<!-- Adapted from Revgrowth1/ai-gtm-workflows@03b30e1 (MIT). -->` on line 1 of every Brite-entity-extended file (i.e., `hidden-signals-library.md`, and `creative-thinking-models.md` if we adapt worked examples). Files ported verbatim get only the frontmatter.
4. **Execution approach.** Per issue §Execution Protocol step 2, I would `TaskCreate` one task per Tasks entry. Replaced with: single Agent (Explore or general-purpose) dispatched for the 19-file bulk port (tasks 3-7) to keep main context clean. Main context retains tasks 1, 2, 5 (Brite rows — needs user approval gate), 8, 9. Session-level task list tracks these in TaskCreate.
5. **Check-in gate location.** Brite-entity hidden-signals rows are proposed to user **before** the bulk port subagent runs — so subagent can write the complete file in one pass. Alternative (propose after subagent completes) would require a second write. Approve-then-write chosen.
6. **Brite-entity vertical swap (USER-APPROVED 2026-04-20).** Issue body lists 3 new tables as "Entertainment Venues (Brite Labs), Landscape/Hardscape Contractors (Brite Supply), HOAs/Property Management." Handbook `marketing/go-to-market/verticals/README.md` (23-vertical taxonomy) shows: (a) no canonical "Entertainment Venues" — closest are Event Venues / Sports Stadiums / Theme Parks as separate verticals, all Exploring or Future; (b) Brite Supply verticals (installers, property management) are **explicitly deferred** from taxonomy; (c) HOAs matches. Swapped to the **3 handbook-Active verticals with ship-ready ICP + persona docs**: Municipalities (Both), HOAs (Nites), Universities (Nites). Each row anchors to a handbook trigger (offer page, persona change, procurement/budget cycle) so downstream skills reuse the same signals the handbook already validates. Departure documented in PR body + UPSTREAM.md.

## Execution approach

**Two phases:**

- **Phase A (main context, interactive):** Propose Brite-entity signal rows to user, get approval. Then kick off Phase B.
- **Phase B (single subagent, one-shot):** Dispatch a `general-purpose` Agent with complete instructions — fetch all 19 upstream files via `gh api`, transform, write to `plugins/marketing/references/`, write UPSTREAM.md. Return a verification summary.
- **Phase C (main context):** Run `scripts/validate.sh` + `scripts/check-guardrails.sh`, spot-check ≥3 files, commit, push, PR.

## Tasks

1. **[Main] Create `plugins/marketing/references/` directory + README stub.**
   - `mkdir -p plugins/marketing/references/research-processes`
   - Minimal `references/README.md` noting the directory's purpose + link to UPSTREAM.md.
   - Verify: `ls plugins/marketing/references/` shows `research-processes/` + `README.md`.

2. **[Main] Pin upstream SHA.** Already fetched: `03b30e166d3f8ed0eb9864cd2a78dda719558826`. Record in plan + pass to subagent.

3. **[Main, user gate] Propose Brite-entity signal rows.**
   - Present to user (AskUserQuestion or plain prompt): draft signal rows for each of the 3 new tables.
     - **Entertainment Venues** (Brite Labs): event calendar updates, AV/lighting RFPs, new GM hires, sponsorship signals, permit filings, seasonal capacity changes.
     - **Landscape/Hardscape Contractors** (Brite Supply): licensing renewals, fleet additions, commercial project wins, hiring for installers, equipment financing signals, HOA contract awards.
     - **HOAs / Property Management** (Brite Supply + Nites cross-motion): board election news, capital-reserve approvals, amenity-upgrade RFPs, new property-management company onboardings, storm-damage remediation bids, seasonal lighting RFPs.
   - Each row follows the upstream 5-column schema: `SIGNAL / SOURCE / WHAT-IT-REVEALS / EXAMPLE ANGLE / SHELF LIFE`.
   - Minimum 5 rows per table; draft 6-7 to give user pruning room.
   - Block on user approval before Phase B.

4. **[Subagent, Phase B] Bulk port.** Dispatch `general-purpose` Agent with this brief:
   - Fetch upstream SHA `03b30e1` content via `gh api repos/Revgrowth1/ai-gtm-workflows/contents/<path>?ref=03b30e1`.
   - For each of 16 `references/research-processes/*.md` files:
     - Decode base64 content.
     - Prepend YAML frontmatter (`source`, `upstream_path`, `license`).
     - Replace every occurrence of literal `Serper` in prose with `WebSearch` (preserve query strings verbatim).
     - Write to `plugins/marketing/references/research-processes/<filename>`.
   - For `creative-thinking-models.md`: fetch verbatim, add frontmatter + HTML-comment attribution, append or inline ≥2 Brite-adapted worked examples (entities: Brite Nites residential, Brite Supply landscape, Brite Labs venue partnership). Brite-adapted examples can go in a new `## Brite-Adapted Worked Examples` section.
   - For `hidden-signals-library.md`: fetch verbatim (7 industry tables), add frontmatter + HTML-comment attribution, then append ≥3 Brite-entity tables (Entertainment Venues, Landscape Contractors, HOAs) using the rows approved in task 3.
   - For `shelf-life-patterns.md`: fetch verbatim, add frontmatter only.
   - Write `UPSTREAM.md` with: MIT attribution header, upstream SHA, per-file manifest (path + upstream_path pairs), link to upstream LICENSE, note Brite adaptations (which files carry added content vs verbatim).
   - Return: list of files written + line counts + any Serper occurrences detected in upstream that weren't in prose (surface for review).

5. **[Main] Verify subagent output.**
   - `ls plugins/marketing/references/research-processes/ | wc -l` → 16
   - `grep -rE 'Serper' plugins/marketing/references/` → 0 matches
   - Spot-check 3 files: 1 research-process, `creative-thinking-models.md`, `hidden-signals-library.md`. Confirm frontmatter + attribution + Brite additions where expected.
   - `grep -cE '^##' plugins/marketing/references/hidden-signals-library.md` → ≥10 (7 upstream industries + ≥3 Brite).
   - `grep -cE '^\|' plugins/marketing/references/hidden-signals-library.md` per-table row count → ≥5 for each Brite table.
   - `grep -E 'Inversion|Adjacent Transfer|Timing Arbitrage|Specificity Escalator|Ecosystem Gap Analysis' plugins/marketing/references/creative-thinking-models.md` → all 5 named.
   - `grep -E 'Regulatory/Deadline|Competitive Move|Data Insight|Industry Pattern|Structural' plugins/marketing/references/shelf-life-patterns.md` → all 5 named.

6. **[Main] Run validation.**
   - `./scripts/validate.sh` → exits 0
   - `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → exits 0

7. **[Main] Commit + push + PR.**
   - Commit title: `BC-5823: port marketing references from Revgrowth1/ai-gtm-workflows`
   - Mention: 16 research-processes files + 3 top-level refs + UPSTREAM.md + Brite entity additions. Cite upstream SHA `03b30e1`.
   - Push via `gh` (security hook may block — retry per memory pattern).
   - Open PR using `/workflows:ship` or manual `gh pr create`.
   - Attach PR to BC-5823 Linear issue; move status Todo → In Review.

8. **[Main, post-PR] File BC-5823 precedent if pattern novel.** First marketing-plugin upstream port; may warrant precedent doc. Evaluate after `/workflows:review`.

## Verification checklist (from issue body)

- [ ] `plugins/marketing/references/` directory exists
- [ ] `research-processes/` contains ≥16 `.md` files with exact filenames listed in issue Scope §1
- [ ] Every research-processes file has `source: Revgrowth1/ai-gtm-workflows@<sha>` frontmatter
- [ ] `grep -rE "Serper" plugins/marketing/references/` returns no matches
- [ ] `creative-thinking-models.md` names all 5 forcing functions
- [ ] `creative-thinking-models.md` has ≥2 Brite-entity-adapted worked examples
- [ ] `hidden-signals-library.md` has ≥10 industry headings total (7 upstream + ≥3 Brite)
- [ ] Each Brite-added industry table has ≥5 signal rows
- [ ] `shelf-life-patterns.md` names all 5 decay categories
- [ ] `UPSTREAM.md` exists, lists every ported file, cites upstream SHA, links upstream LICENSE
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0

## Downstream unblocks

Closing BC-5823 unblocks: BC-5824 situation-mining, BC-5825 email-copywriting, BC-5826 launch-campaign command, BC-5828 account-research, BC-5830 creative-angles, BC-5832 tam-mapping, BC-5833 campaign-debrief.

## Risks + mitigations

- **Upstream file drift during execution.** SHA pinned → use `?ref=03b30e1` in every `gh api` call.
- **Serper translation false positives.** Query strings may contain `site:serper.dev`-style tokens; preserve. Only translate prose mentions. Subagent brief explicitly says so.
- **Brite row quality.** Check-in gate at task 3 de-risks; user approves rows before they land.
- **Validate.sh drift.** If new directory triggers a frontmatter-lint rule, expect to add `references/` to the allowlist in `scripts/_lib/lint_*.py`. Flag if it happens.
