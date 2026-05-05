# Plan: BC-6654 — launch-campaign multiplicative segmentation rewrite

**Issue**: [BC-6654](https://linear.app/brite-nites/issue/BC-6654) — BC-6514 follow-up: launch-campaign multiplicative segmentation rewrite (Phase 2 + Phase 5 + naming + metadata schema + drop `--no-segment`)
**Branch**: `corinne/bc-6654-bc-6514-follow-up-launch-campaign-multiplicative`
**Tasks**: 11 (estimated ~50 min focused agent time)

## Plain-language gist

Today's `/marketing:launch-campaign` splits a CSV into up-to-3 campaigns (one per ESP — Google / Microsoft / Other) and uses email-type (professional / role / personal) only as a pre-filter. Holden's BC-6514 call (memo at `docs/designs/BC-6514-segmentation-axis-decision.md`) flips that: split into up-to-9 campaigns, one per (email-type × ESP) cell. Empty cells get pruned automatically. The single escape hatch — `--no-host-lookup` (one combined campaign for tiny test launches) — stays. The old `--no-segment` flag goes away entirely (it would silently let operators bypass the multiplicative call into a rejected model).

This plan rewrites the spec at every site that named the ESP-only model: Phase 2 (gate-2 prompt + post-gate apply), Phase 5 (campaign-create loop + naming convention), Phase 6 (lead bucketing), Phase 7 (sender invariant cardinality), Phases 9/10/11 (metadata example keys + preview-lead pick), the metadata JSON schema (worked example + new `segments` shape), the flag table, and the verification checklist. Plan files and the BC-6307 design doc that cite the old shape get a one-line annotation pointing to BC-6514 (per BC-6301 task-1 — production-template files fix in lockstep, round-evidence files keep verbatim with forward-pointer). Closes with a marketing plugin version bump (CLAUDE.md gotcha).

No code change in any other skill — `email-copywriting` / `tam-mapping` impacts are deferred to the BC-6655 sibling audit. `campaign-debrief` will read the new metadata shape via the BC-6655 audit; no work here. Resume-breadcrumb compat is one-way break (acceptable cost per issue body).

## Prerequisites

- BC-6514 architectural decision memo at `docs/designs/BC-6514-segmentation-axis-decision.md` is ground truth — read first.
- BC-6654 issue body enumerates 7 in-scope sections with exact line-number anchors.
- `evals/launch-campaign/` directory does **not** exist (verified — only per-skill evals exist under `plugins/marketing/skills/<skill>/evals/`). Issue scope item 7 ("Eval scenarios") is therefore vacuous; skip without action and note in Verification.
- **CDR alignment**: handbook CDR INDEX not retrievable via Context7 (`brite-nites/handbook` not indexed in Context7); CDR check skipped per skill rule (advisory). Decision memo + project precedents are the binding architectural reference instead.
- **Precedent alignment**:
  - BC-6514 task-1 (decision-memo supersession) — drives the "Precedent + upstream sources" cross-link in Task 11
  - BC-6514 task-2 (escape-hatch vs opt-into-rejected-model flag) — drives `--no-segment` removal in Tasks 1, 3
  - BC-6306 task-1 (scope-narrowing — edit every section that references) — drives Tasks 6–9 multi-site sweep
  - BC-6307 task-2 (factual-anchor recipe — read end-to-end before declaring checkpoint complete) — verification step on every task
  - BC-6301 task-1 (production-template files fix in lockstep, round-evidence historical) — drives Task 10 annotation-not-rewrite for plan files + BC-6307 design doc
  - BC-6300 task-2 (plan file co-locates with worktree) — write to main repo for approval, git-worktrees moves to worktree

## Tasks

### Task 1: Drop `--no-segment` from flag-related sites
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: BC-6514 removes the flag entirely (escape-hatch vs opt-into-rejected-model distinction per task-2 precedent). Five sites name the flag — all must go in lockstep, otherwise operators see contradictory signals (frontmatter says flag exists, table doesn't list it, etc.).

**Implementation**:
1. **Frontmatter `argument-hint` (line 3)**: remove the `[--no-segment]` token from the bracketed flag list. After the edit the list reads: `... [--no-host-lookup] [--no-sequence] [--preview] [--activate] [--reference <campaign-id>] [--test-send <email>] [--test-send-sender <id>]`.
2. **Flag table — `--campaign-name` description (line 114)**: rewrite the suffix example. Today: `Segmentation adds suffixes (`\| Google`, `\| Microsoft`, `\| Other`).` After: `Segmentation adds compound suffixes (`\| Professional \| Google`, `\| Role \| Microsoft`, etc. — one per non-empty (email-type × ESP) cell).`
3. **Flag table — drop `--no-segment` row (line 116)**: delete the entire row. The row directly above (`--entity`) and the row immediately below (`--no-host-lookup`) are unaffected.
4. **`--no-host-lookup` description (line 117)**: today reads `Skip Phase 2 entirely. Implies --no-segment.` After: `Skip Phase 2 entirely. Single combined campaign with the base name. Sole opt-out from multiplicative segmentation — for tiny test launches where 9-cell setup overhead isn't justified.`
5. **Verification checklist (line 996)**: today reads `All 4 required args + 9 flags documented (...--no-segment, --no-host-lookup, ...)`. After: `All 4 required args + 8 flags documented (--no-host-lookup, --no-sequence, --activate, --preview, --reference, --entity, --test-send, --test-send-sender)`.

**Test**:
- `grep -n "no-segment" plugins/marketing/commands/launch-campaign.md` — expect zero matches
- `grep -c "no-host-lookup" plugins/marketing/commands/launch-campaign.md` — expect ≥4 (frontmatter + flag table + Phase 2 skip-flag block, kept)
- Frontmatter `argument-hint` line passes: `head -10 plugins/marketing/commands/launch-campaign.md | grep argument-hint | grep -v "no-segment"`

**Verify**: open the flag table section in an editor — only 8 flag rows present, all referenced consistently in the verification checklist.

---

### Task 2: Rewrite metadata schema § — replace `esp_segments` + `email_type_segments` with unified `segments` shape
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: BC-6654 issue body § 4 specifies a new shape: keyed by `{email_type}|{esp}`, each value an object `{email_type, esp, count}`. Empty cells absent. The same key shape propagates through `lead_ids_by_bucket`, `campaign_ids`, `sender_attach_counts`, `campaign_schedule_ids`, `sequence_ids`, `activated_per_campaign`. The worked example block + descriptive paragraph + optional-fields enum + error-recovery-table row all reference the old shape.

**Implementation**:
1. **Worked example JSON block (lines 141–170)**: rewrite the 7 keyed objects to use compound keys. Verbatim target:
   - Replace `"esp_segments": {"Google": 84, "Microsoft": 31, "Other": 12},` and the line below `"email_type_segments": {"professional": 84, "role": 3, "personal": 9},` with:
     ```json
       "segments": {
         "professional|Google": {"email_type": "professional", "esp": "Google", "count": 84},
         "professional|Microsoft": {"email_type": "professional", "esp": "Microsoft", "count": 31},
         "professional|Other": {"email_type": "professional", "esp": "Other", "count": 12}
       },
     ```
   - `lead_ids_by_bucket` (line 155): change keys to compound form. Example:
     ```json
       "lead_ids_by_bucket": {"professional|Google": [14706, 14707, 14708], "professional|Microsoft": [14709], "professional|Other": [14710, 14711]},
     ```
   - `campaign_ids` (line 156): same key shape. `{"professional|Google": 5551, "professional|Microsoft": 5552, "professional|Other": 5553}`
   - `sender_attach_counts` (line 159): same. `{"professional|Google": 3, "professional|Microsoft": 3, "professional|Other": 3}`
   - `campaign_schedule_ids` (line 161): same. `{"professional|Google": 4, "professional|Microsoft": 5, "professional|Other": 6}`
   - `sequence_ids` (line 162): same. `{"professional|Google": 8801, "professional|Microsoft": 8802, "professional|Other": 8803}`
   - `activated_per_campaign` (line 166): same. `{"professional|Google": null, "professional|Microsoft": null, "professional|Other": null}`
   - **Note: the worked example uses a single email-type (`professional`) only because the operator's gate-2 default skips role + personal — the cell shape is what's authoritative, not the example's column collapse.** Add this as a one-line comment after the JSON block.
2. **Descriptive paragraph (line 174)**: today reads `email_type_segments records the per-email-type bucket counts BEFORE the gate-2 filter is applied — captures the operator's full input, not just the surviving subset. Empty buckets are absent from the object (matches esp_segments convention). The operator's chosen filter is recorded separately in email_type_filter_applied (see optional fields below).` Rewrite to:
   > `segments` records one entry per non-empty (email-type × ESP) cell post-gate-2 filter. Each entry carries the cell's `email_type`, `esp`, and `count`. Empty cells are absent from the object — F12 prune (Phase 2 step 4b) drops zero-lead cells before the metadata write. The operator's chosen email-type filter is recorded separately in `email_type_filter_applied` (see optional fields below). All downstream per-bucket fields (`lead_ids_by_bucket`, `campaign_ids`, `sender_attach_counts`, `campaign_schedule_ids`, `sequence_ids`, `activated_per_campaign`, `lead_attach_counts`) use the same `{email_type}|{esp}` key shape.
   > 
   > **Resume-breadcrumb compat (one-way break).** Pre-BC-6654 metadata files written with the old `esp_segments` / `email_type_segments` shape will not auto-resume — the per-phase resume code reads `segments` and won't find it. Manual recovery: open the legacy metadata, manually map each ESP bucket count into the corresponding (professional × ESP) cell of the new shape (assumes default email-type filter, which dropped role/personal pre-gate), then save and re-run from the next phase. Acceptable cost — schema migration is structural and resume from breadcrumb is a rare path.
3. **Optional fields enum (line 184)**: today the `email_type_filter_applied` enum reads `"default" | "include_role" | "include_personal" | "include_all" | "disabled_segmentation"`. Drop the `"disabled_segmentation"` value (the gate-2 option that mapped to it is being removed in Task 6). After: `"default" | "include_role" | "include_personal" | "include_all"`. Description text unchanged otherwise; the `Set to null when --no-host-lookup skipped Phase 2 entirely.` clause stays.
4. **Optional fields — `lead_attach_counts` description (line 190)**: today the field is mentioned without a "key shape mirrors" clarifier. Add: `lead_attach_counts: {<bucket>: <count>, ...}` keyed by `{email_type}|{esp}` (same shape as `segments`).
5. **Error recovery table — Phase 2 row (line 962)**: today reads `Unchanged (read-only) | segmented, esp_segments populated | Fix failing domain lookup, re-run from scratch`. Update middle column to `segmented, segments populated`.

**Test**:
- `grep -c "esp_segments" plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c "email_type_segments" plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c "disabled_segmentation" plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c '"segments"' plugins/marketing/commands/launch-campaign.md` — expect ≥2 (worked example + descriptive paragraph)
- Quick JSON-shape sanity: open the worked example block, confirm every per-bucket field uses compound keys (no bare `"Google":` keys remain in any per-bucket field).

**Verify**: open § Launch metadata schema in editor — worked example, descriptive paragraph, optional-fields enum, and error-recovery row all reference `segments` consistently; no surviving `esp_segments` or `email_type_segments` strings.

---

### Task 3: Phase 2 § purpose + skip-flag block
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Phase 2's purpose paragraph today describes the ESP-axis-only model ("ESP detection so professional leads can be split into Google / Microsoft / Other campaigns"). The two-flag skip-block enumerates `--no-segment` separately, with the line "The flag table at line 90/91 is the contract: `--no-host-lookup` is the broader skip; `--no-segment` is the narrower ESP-only skip." Under multiplicative there's only one skip flag.

**Implementation**:
1. **Phase 2 purpose paragraph (line 270)**: today reads `Phase 2 has two detection passes. Email-type detection (step 1) classifies each lead as professional / role / personal and lets the operator drop role + personal addresses by default. ESP detection (steps 2–3) resolves who hosts each lead's domain so professional leads can be split into Google / Microsoft / Other campaigns. The operator's gate-2 choice is applied in step 4 (post-gate). ESP segmentation reduces cross-provider deliverability interference — a sender warmed on Google may perform differently into Microsoft inboxes, and mixing providers in one campaign can pollute the stats. This phase is read-only; no leads are mutated.` Rewrite to:
   > Phase 2 has two detection passes whose outputs combine into a 9-cell (email-type × ESP) segmentation grid. **Email-type detection** (step 1) classifies each lead as `professional` / `role` / `personal` and lets the operator drop role + personal addresses at gate 2 (default skip). **ESP detection** (steps 2–3) resolves who hosts each lead's domain so leads can be split into Google / Microsoft / Other. Step 3 joins the two: each surviving lead lands in exactly one (email-type, ESP) cell. The operator's gate-2 filter choice + F12 empty-cell prune are applied in step 4 (post-gate); the resulting non-empty cells become campaigns in Phase 5. Multiplicative segmentation reduces cross-provider AND cross-email-type deliverability interference — a sender warmed on Google professional may perform differently into Google role addresses or Microsoft professional, and isolating cells gives clean per-segment metrics. This phase is read-only; no leads are mutated.
2. **Skip flags block (lines 272–277)**: today the block lists two flags (`--no-host-lookup` and `--no-segment`) plus a contract-clarification line. Rewrite to a single-flag block:
   > **One skip flag:**
   > 
   > - **`--no-host-lookup`** — skip Phase 2 entirely. Step 1 (email-type detection) does NOT run; step 2 (ESP detection) does NOT run. Set `segmented: false`, `segments: null`, `email_type_filter_applied: null`, `skipped_leads_csv_path: null`, `invalid_email_rows: []` in metadata. No gate 2. Proceed to Phase 3 with one combined campaign on the full lead set.
   > 
   > Without `--no-host-lookup` Phase 2 always runs and produces the multiplicative segmentation grid. There is no escape hatch from email-type-axis or ESP-axis individually — that path was removed per BC-6514 (opting into either rejected single-axis model would silently bypass the multiplicative call).
3. **Step 1 output reference (line 302)**: today the bullet ends `Per-lead tag plus aggregated counts: email_type_segments: {professional: N, role: N, personal: N}. Empty buckets absent from the object (matches existing esp_segments shape).` Rewrite to: `Per-lead tag plus aggregated counts (scratch state for step 3's join, not metadata-bound). Step 3 is where these counts are projected into the (email-type × ESP) cell grid that becomes metadata's segments map.`

**Test**:
- `grep -n "two skip flags\|narrower ESP-only\|--no-segment" plugins/marketing/commands/launch-campaign.md` — expect 0 (the contract-clarification line should be gone)
- `grep -c "9-cell\|9-cell grid\|(email-type × ESP)" plugins/marketing/commands/launch-campaign.md` — expect ≥3
- Phase 2 purpose paragraph reads cleanly end-to-end with the new framing (no orphan "ESP segmentation reduces cross-provider..." sentence detached from context)

**Verify**: skim Phase 2 § from "**Purpose.**" through end of skip-flag block — narrative flows; no contradictory references to two-flag scope.

---

### Task 4: Phase 2 step 3 (cell-grid build) + step 4a–4b (apply filter + F12 prune)
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Step 3 today builds an 8-bucket ESP detail + 3-bucket plan and notes that gate-2's preview is computed for any of the 5 filter choices. Under multiplicative, step 3 builds the full 9-cell grid up-front; gate 2's preview shows the grid post-filter. Step 4a's filter-application enum drops `disabled_segmentation`. Step 4b's F12 prune now operates on the 9-cell grid.

**Implementation**:
1. **Step 3 (line 330)**: today reads `Count leads per (ESP × email-type) cell. Join scratch state from steps 1 and 2: for each lead, look up its (email-type tag, domain → ESP bucket) tuple and increment the appropriate cell of a 3×3 grid {Google, Microsoft, Other} × {professional, role, personal}. Single pass over the per-lead tag table from step 1; no additional CSV walks. Gate 2's preview ESP table for any of the 5 filter choices is computed by summing the email-type columns that choice would keep. Surface the full 8-bucket ESP detail in the user gate (post-filter under the default choice) but use the 3-bucket plan for actual campaign segmentation — deliverability infra considers Google and Microsoft separately; the long tail stays one bucket.` Rewrite to:
   > **Build the 9-cell (email-type × ESP) grid.** Join scratch state from steps 1 and 2: for each lead, look up its (email-type tag, domain → ESP bucket) tuple and increment the appropriate cell of `{professional, role, personal} × {Google, Microsoft, Other}`. Single pass over the per-lead tag table from step 1; no additional CSV walks. The 9-cell grid is the segmentation plan — each non-empty cell post-gate-2 becomes one campaign in Phase 5. ESP detail beyond the 3-bucket plan (Proofpoint, Mimecast, Barracuda, Cisco, Custom, Unknown) is rolled up into `Other` for segmentation but surfaced in gate 2's preview for operator visibility — deliverability infra considers Google and Microsoft separately; the long tail stays one bucket.
2. **Step 4a — apply gate-2 decision (line 334)**: today the bulleted list of branches has 5 entries (default, include_role, include_personal, include_all, disabled_segmentation). Drop the 5th bullet entirely. Updated bullets:
   - `Apply default → skip leads tagged role OR personal (enum: default)` *(unchanged)*
   - `Include role addresses too → skip leads tagged personal only (enum: include_role)` *(unchanged)*
   - `Include personal addresses too → skip leads tagged role only (enum: include_personal)` *(unchanged)*
   - `Include all → skip nothing (enum: include_all)` *(unchanged)*
   - **DELETE** the `Disable ESP segmentation → apply the default email-type filter ... enum: disabled_segmentation` bullet entirely.
3. **Step 4b — F12 prune (line 341)**: today reads `Skip empty buckets (F12). With the surviving (post-filter) lead set, if any bucket in the 3-bucket ESP plan has 0 leads, drop it from the segmentation plan — do NOT create an empty campaign. Example: post-filter resolves to Google: 84, Microsoft: 0, Other: 12 → create 2 campaigns (| Google, | Other), skip Microsoft entirely. Record the skipped buckets in scratch state so the metadata JSON reflects the actual (pruned) plan. If ALL buckets are empty (either no leads survived the email-type filter, or every surviving lead's domain failed DNS), halt — the campaign has zero deliverable leads and Phase 3 cannot proceed.` Rewrite to:
   > **(4b) Skip empty cells (F12).** With the surviving (post-filter) lead set, drop any cell in the 9-cell grid that has **0 leads** — do NOT create an empty campaign. Example: post-filter under `include_role` resolves to `(professional, Google): 84, (professional, Microsoft): 31, (professional, Other): 12, (role, Google): 3, (role, Microsoft): 0, (role, Other): 0` → create 4 campaigns (the 4 non-empty cells), skip the 2 empty role cells entirely. Record the skipped cells in scratch state so the metadata `segments` map reflects the actual (pruned) plan. If ALL cells are empty (either no leads survived the email-type filter, or every surviving lead's domain failed DNS), halt — the campaign has zero deliverable leads and Phase 3 cannot proceed.
4. **Step 4d — metadata write (line 347)**: today reads `Append to metadata JSON. Set segmented: true (or false if disabled_segmentation), esp_segments: {<only non-empty post-filter buckets>} (or null if disabled_segmentation), email_type_segments: {<only non-empty pre-filter buckets>} ..., email_type_filter_applied: "<enum>" ..., skipped_leads_csv_path: <path>|null, last_completed_phase: 2.` Rewrite to:
   > **(4d) Append to metadata JSON.** Set `segmented: true`, `segments: {<only non-empty post-filter cells, keyed by "{email_type}|{esp}", value {email_type, esp, count}>}`, `email_type_filter_applied: "<enum>"` (use the enum value from 4a, NOT the prose label), `skipped_leads_csv_path: <path>|null`, `last_completed_phase: 2`.
5. **F12 cross-reference at end of gate prompt (line 382)**: today reads `If the operator's chosen action leaves zero leads in any ESP bucket after filtering, the F12 skip-empty-buckets logic (step 4b) handles it.` Update to: `If the operator's chosen action leaves zero leads in any (email-type × ESP) cell after filtering, the F12 skip-empty-cells logic (step 4b) handles it.`

**Test**:
- `grep -c "9-cell\|(email-type × ESP)\|9-cell grid" plugins/marketing/commands/launch-campaign.md` — expect ≥5 after this task
- `grep -c "3-bucket plan\|3-bucket\|3×3 grid\|8-bucket" plugins/marketing/commands/launch-campaign.md` — should drop substantially (at most 1–2 remain in unrelated context; flag any survivors for inspection)
- `grep -n "disabled_segmentation\|Disable ESP segmentation" plugins/marketing/commands/launch-campaign.md` — expect 0 (further verified by Task 6)
- F12 example reads coherently (Microsoft+Other → multi-cell example)

**Verify**: read Phase 2 step 3 + step 4 end-to-end. Step 3 builds the grid; step 4a chooses 4 filter options; step 4b prunes the grid; step 4c is unchanged (sidecar CSV — no key shape involved); step 4d writes `segments`. No orphan references to ESP-only or 3-bucket plan.

---

### Task 5: Phase 2 User gate 2 prompt rewrite
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: The gate-2 prompt today renders an ESP-breakdown table preceded by an email-type breakdown, with 5 filter options + abort. Under multiplicative the operator should see the 9-cell grid (post-current-radio-selection preview) with 4 filter options + abort.

**Implementation**:
1. **Replace the entire User gate 2 prompt block (lines 349–381)** with this version:
   > **User gate 2.** Ask via `AskUserQuestion`:
   > 
   > > Phase 2 detection summary for campaign `{base}`:
   > >
   > > **Email-type breakdown** (lead-level, before filter):
   > > - Professional — N leads
   > > - Personal     — N leads (free-mail domains)
   > > - Role         — N leads ({role-list-summary} addresses)
   > >
   > > {IF invalid_email_rows non-empty:}
   > > Skipped due to malformed email format: N rows.
   > > {END IF}
   > >
   > > **9-cell segmentation grid** (after applying the chosen email-type filter — preview reflects current radio selection):
   > >
   > > | Email-type    | Google     | Microsoft  | Other      |
   > > |---|---|---|---|
   > > | Professional  | N leads    | N leads    | N leads    |
   > > | Role          | N leads    | N leads    | N leads    |
   > > | Personal      | N leads    | N leads    | N leads    |
   > >
   > > {IF any cell skipped by F12:}
   > > Skipped cells (0 leads after filter): {skipped-cell-list}. No campaigns will be created for these.
   > > {END IF}
   > >
   > > Detailed 8-bucket ESP breakdown (post-filter, rolled into the `Other` column above): Google N, Microsoft N, Proofpoint N, Mimecast N, Barracuda N, Cisco N, Custom N, Unknown N.
   > >
   > > **Default action: skip role + skip personal.** Only the {N-professional} professional leads will be segmented into up to 3 (Professional × ESP) campaigns.
   > >
   > > - Apply default — skip role + personal, segment professionals across (Professional × ESP) cells (Recommended)
   > > - Include role addresses too — also create (Role × ESP) cells, skip personal only
   > > - Include personal addresses too — also create (Personal × ESP) cells, skip role only
   > > - Include all — segment every lead across all (email-type × ESP) cells, no email-type filter
   > > - Abort
2. The prompt no longer includes the "Disable ESP segmentation — single combined campaign on the chosen email-type subset" option. F12 prune handles sparse cells; tiny-launch case is served by `--no-host-lookup`.

**Test**:
- `grep -c "Disable ESP segmentation\|disabled_segmentation" plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c "9-cell segmentation grid" plugins/marketing/commands/launch-campaign.md` — expect 1 (the gate-2 prompt)
- The gate-2 markdown table renders as a 4-column markdown table with 4 rows when previewed (the spec is markdown; the embedded blockquote table is preserved verbatim by the operator's `AskUserQuestion` rendering).
- Filter options list has exactly 5 entries (4 filter choices + Abort), down from 6.

**Verify**: read the entire User gate 2 block. Markdown table is well-formed; `IF` clauses are intact; `Recommended` annotation flows naturally; cell labels match the metadata `segments` key shape from Task 2.

---

### Task 6: Phase 5 — purpose + step 2 (naming + multiplicative loop) + step 9 (metadata example)
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Phase 5 today says "Create one empty campaign shell per ESP segment (or one total if `--no-segment`)" and step 2 branches on `--no-segment`. Under multiplicative, the loop iterates the (now non-empty) cells from `segments`; the `--no-segment` branch goes away. Naming convention is `{base} | {Email-type} | {ESP}` per BC-6514 memo (workspace 13 production order). Step 9's metadata write example needs cell-keyed `campaign_ids`.

**Implementation**:
1. **Phase 5 purpose (line 507)**: today reads `Create one empty campaign shell per ESP segment (or one total if --no-segment). Campaigns at this point have no leads, senders, schedule, or sequence — those come in phases 6–9.` Rewrite: `Create one empty campaign shell per non-empty (email-type × ESP) cell from Phase 2's segments map (or one combined campaign if --no-host-lookup skipped Phase 2). Campaigns at this point have no leads, senders, schedule, or sequence — those come in phases 6–9.`
2. **Step 2 (line 514)**: today reads `Determine campaign names. If --no-segment: one campaign named {campaign-name}. Otherwise: one campaign per ESP bucket from Phase 2 (esp_segments). Default naming convention from the copy artifact's preset (if preset supplies one) or the Brite default: {Niche} | {Target} | {Source} | {Region} | {Size} | {Offer} — full convention per issue spec; Short form (default): {campaign-name-base} | {ESP} — e.g., Denver Downtown Lighting | Google. Operator can override the suffix format in the user gate.` Rewrite to:
   > **Determine campaign names.** Two paths:
   > 
   > - **`--no-host-lookup`**: one campaign named `{campaign-name}`.
   > - **Default (multiplicative)**: one campaign per non-empty cell in metadata's `segments` map. Default naming convention from the copy artifact's preset (if preset supplies one) or the Brite default short form: `{campaign-name-base} | {Email-type-titlecased} | {ESP}` — e.g., `Denver Downtown Lighting | Professional | Google`, `Denver Downtown Lighting | Role | Microsoft`. Email-type comes before ESP per BC-6514 (matches workspace 13 production naming, which groups per-vertical campaign rosters by email-type first). Capitalize the email-type label for display: `professional` → `Professional`, `role` → `Role`, `personal` → `Personal`. Full long-form convention per issue spec: `{Niche} | {Target} | {Source} | {Region} | {Size} | {Offer}` — applies when copy artifact preset declares it. Operator can override the suffix format in the user gate.
3. **Render the create plan (line 519, the bullet list under step 4)**: today shows three buckets keyed by ESP only. Update example to show 4 cells from a multi-email-type filter:
   > > Campaigns to create in workspace `{workspace}`:
   > > 1. `Denver Downtown Lighting | Professional | Google` — 84 leads
   > > 2. `Denver Downtown Lighting | Professional | Microsoft` — 31 leads
   > > 3. `Denver Downtown Lighting | Professional | Other` — 12 leads
   > > 4. `Denver Downtown Lighting | Role | Google` — 3 leads
4. **Step 9 metadata write (line 558)**: today reads `Set campaign_ids: {"Google": 5551, "Microsoft": 5552, "Other": 5553} (adjust keys per actual segmentation), existing_campaign_matches: ..., reused_existing_ids: ..., plain_text_applied: ... (only if step 8 PATCH succeeded for ALL campaigns; else false), last_completed_phase: 5. Also seed activated_per_campaign: {<bucket>: null, ...} ...`. Rewrite the example portion: `Set campaign_ids: {"professional|Google": 5551, "professional|Microsoft": 5552, "professional|Other": 5553, "role|Google": 5554}` (adjust keys per actual segmentation — one entry per non-empty cell from segments, keyed by `{email_type}|{esp}`). Rest of bullet (`existing_campaign_matches`, `reused_existing_ids`, `plain_text_applied`, `last_completed_phase`, `activated_per_campaign` seeding) unchanged in semantic content; only the example key shape changes.

**Test**:
- `grep -n '"Google":\|"Microsoft":\|"Other":' plugins/marketing/commands/launch-campaign.md | grep -v "professional|\|role|\|personal|"` — expect 0 (every per-bucket map key is now compound)
- `grep -c "Email-type-titlecased\|Professional | Google\|Role | Microsoft" plugins/marketing/commands/launch-campaign.md` — expect ≥2
- Phase 5 step 2 references neither `--no-segment` nor `esp_segments`; both paths through `--no-host-lookup` and multiplicative are present.

**Verify**: read Phase 5 § from purpose through step 9 — naming convention is `Email-type | ESP`, step 6's "Reuse existing IDs" path still works against compound keys (the matching is `name`-based, agnostic to key shape), step 9's example uses 4 cells with at least one role-cell to make the multiplicative shape visible.

---

### Task 7: Phase 6 — purpose + step 2 (cell bucketing) + step 7 (metadata write)
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Phase 6 today bucketing is "by ESP segment". Under multiplicative, leads are bucketed by (email-type, ESP) cell — same key shape as Phase 5's `campaign_ids`. The bucket map drives both `lead_attach_counts` and `lead_ids_by_bucket`.

**Implementation**:
1. **Phase 6 purpose (line 566)**: today `Attach the lead IDs created in Phase 4 to the campaign IDs created in Phase 5, bucketed by ESP segment. This is the join step between the lead pool and per-segment campaigns.` Rewrite: `Attach the lead IDs created in Phase 4 to the campaign IDs created in Phase 5, bucketed by (email-type × ESP) cell. This is the join step between the lead pool and per-cell campaigns.`
2. **Step 2 (line 577)**: today `Bucket the lead IDs by ESP segment. From the CSV + Phase 2 bucket assignments, build a map {ESP bucket → [lead_id, lead_id, ...]}. Each lead belongs to exactly one bucket.` Rewrite: `Bucket the lead IDs by (email-type × ESP) cell. From the CSV + Phase 2 cell assignments, build a map {"{email_type}|{esp}" → [lead_id, lead_id, ...]} keyed identically to metadata's segments and campaign_ids. Each lead belongs to exactly one cell.`
3. **Show attach plan (line 580, the bullet list under step 3)**: update example to compound keys:
   > > Attach plan:
   > > - `{campaign_ids["professional|Google"]}` ← 84 leads
   > > - `{campaign_ids["professional|Microsoft"]}` ← 31 leads
   > > - `{campaign_ids["professional|Other"]}` ← 12 leads
   > > - `{campaign_ids["role|Google"]}` ← 3 leads
   > > Total: 130 leads attached across 4 campaigns.
4. **Step 7 metadata write (line 603)**: today reads `Append to metadata JSON. The campaign_ids already list the per-campaign mapping. Add lead_attach_counts: {<bucket>: <count>, ...} mirroring esp_segments. Add lead_ids_by_bucket: {<bucket>: [<lead_id>, ...], ...} from the bucket map built in step 2 — this is the resume primitive that lets a Phase 6 re-run reconstruct the bucket→IDs mapping without re-running Phase 2 MX lookups + CSV-row joins. Set last_completed_phase: 6.` Rewrite: replace `mirroring esp_segments` with `mirroring segments (compound key shape)`. Other content unchanged.

**Test**:
- `grep -c "by ESP segment\|ESP bucket" plugins/marketing/commands/launch-campaign.md` — expect minimal (1–2 hits in legacy contexts that were never load-bearing); flag any in Phase 6 for follow-up
- `grep -c "(email-type × ESP) cell" plugins/marketing/commands/launch-campaign.md` — expect ≥3 after this task
- Phase 6 step 3 example shows 4-cell attach with role-cell — validates the multiplicative shape is rendered, not just renamed.

**Verify**: read Phase 6 end-to-end. Two-call gate semantics unchanged (vendor mechanics don't depend on key shape); `allow_parallel_sending` branch unchanged; per-campaign verification unchanged; step 7 metadata write uses `segments` reference.

---

### Task 8: Phase 7 — sender invariant cardinality
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Phase 7's invariant — "all senders to all campaigns" — is unchanged. But step 8's metadata example shows three buckets (`{"Google": N, "Microsoft": N, "Other": N}`) which now becomes up to 9. The "all values MUST be equal" invariant still holds across however many cells the run produced. The forbidden-pattern example references "Google" / "Microsoft" — minor refresh.

**Implementation**:
1. **Step 4 attach plan render (line 645–650)**: example bullets show 3 ESP buckets. Update to 4 cells (matching the role-cell example used in earlier tasks):
   > > Attach plan (per-campaign count must match):
   > > - `{campaign_ids["professional|Google"]}` ← {N-senders} senders
   > > - `{campaign_ids["professional|Microsoft"]}` ← {N-senders} senders
   > > - `{campaign_ids["professional|Other"]}` ← {N-senders} senders
   > > - `{campaign_ids["role|Google"]}` ← {N-senders} senders
2. **Step 8 metadata write (line 667)**: today `Set sender_ids_attached: [<full list>], sender_attach_counts: {"Google": N, "Microsoft": N, "Other": N} — all three values MUST be equal (that's the invariant). last_completed_phase: 7.` Rewrite: `Set sender_ids_attached: [<full list>], sender_attach_counts: {"professional|Google": N, "professional|Microsoft": N, "professional|Other": N, "role|Google": N} (one entry per cell in campaign_ids; example shows 4-cell from the gate-2 include_role path). All values MUST be equal (that's the invariant — sender pool is the same for every campaign). last_completed_phase: 7.`
3. **Forbidden patterns (line 671)**: today `Splitting senders across campaigns (e.g., senders 1–10 to Google, 11–20 to Microsoft).` Update example: `Splitting senders across campaigns (e.g., senders 1–10 to Professional|Google, 11–20 to Role|Microsoft).` Keep the explicit-anti-pattern wording.

**Test**:
- `grep -c '"Google": N, "Microsoft": N, "Other": N' plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c "all three values\|three values MUST" plugins/marketing/commands/launch-campaign.md` — expect 0 (replaced with "all values MUST be equal")
- Sender invariant prose still asserts "ALL senders to ALL campaigns" verbatim (unchanged).

**Verify**: read Phase 7 end-to-end. Pagination logic, while-true loop, count-scalar verification, ground-truth fallback all unchanged. Only the per-cell example keys + forbidden-pattern example moved to compound shape.

---

### Task 9: Phases 9–11 — metadata example keys + Phase 10 preview-lead pick + Phase 11 final-report examples
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Three downstream phases reference the per-bucket map by ESP-only keys in their examples. Phase 10 step 1 picks "first lead in largest ESP bucket" — semantics work the same on cells (the largest cell wins); only the wording needs update.

**Implementation**:
1. **Phase 9 step 8 metadata write (line 775)**: today `Set sequence_ids: {"Google": 8801, "Microsoft": 8802, "Other": 8803}, last_completed_phase: 9.` Rewrite: `Set sequence_ids: {"professional|Google": 8801, "professional|Microsoft": 8802, "professional|Other": 8803, "role|Google": 8804} (one entry per cell in campaign_ids; example shows 4-cell from gate-2 include_role), last_completed_phase: 9.`
2. **Phase 10 Mode 1 step 1 (line 796)**: today `Pick a preview lead. Prefer the first lead in the largest ESP bucket. Fall back to row 2 of the CSV. Read the lead's CSV row.` Rewrite: `Pick a preview lead. Prefer the first lead in the largest cell of the segments map (most leads → most representative). Ties broken by the cell's display order in the gate-2 grid (professional|Google → professional|Microsoft → professional|Other → role|Google → ...). Fall back to row 2 of the CSV if segments is empty (--no-host-lookup path). Read the lead's CSV row.`
3. **Phase 10 step 7 example (line 812)**: today `Preview — campaign {campaign-name} | Google, lead alex@gmail.com:`. Update example: `Preview — campaign {campaign-name} | Professional | Google, lead alex@gmail.com:`. (Single-line text edit.)
4. **Phase 10 final summary (lines 870–872)**: today shows `{campaign_ids.Google}` — 84 leads etc. Update bullets to compound-key form (just the example):
   > > Launch flow complete at Phase 10. Campaigns created in `Draft` state:
   > > - `{campaign_ids["professional|Google"]}` — 84 leads, 2-step sequence, ready to activate
   > > - `{campaign_ids["professional|Microsoft"]}` — 31 leads, 2-step sequence, ready to activate
5. **Phase 11 step 2 final summary (lines 906–908)**: same shape — 3 example bullets keyed by `Google` / `Microsoft` / `Other`. Update to compound keys:
   > > - `{campaign_ids["professional|Google"]}` — 84 leads, step 1 sends on the campaign's next scheduled window
   > > - `{campaign_ids["professional|Microsoft"]}` — 31 leads, same
   > > - `{campaign_ids["professional|Other"]}` — 12 leads, same
6. **Phase 11 step 4b vendor gate prompt (line 924)**: today `Vendor prompt for campaign {campaign-name} | Google: ...`. Update: `Vendor prompt for campaign {campaign-name} | Professional | Google: ...`.
7. **Phase 11 step 7 final report (lines 936–938)**: update bullets to compound-key form:
   > > - `{campaign-name} | Professional | Google` (id {id}) — Queued, 84 leads, first sends next scheduled window
   > > - `{campaign-name} | Professional | Microsoft` (id {id}) — Queued, 31 leads, same
   > > - `{campaign-name} | Professional | Other` (id {id}) — Queued, 12 leads, same

**Test**:
- `grep -c '"Google": 8801\|"Google": 5551\|"Google": null' plugins/marketing/commands/launch-campaign.md` — expect 0 (all bare-ESP keys gone from example shapes)
- `grep -c "largest ESP bucket" plugins/marketing/commands/launch-campaign.md` — expect 0
- `grep -c "largest cell" plugins/marketing/commands/launch-campaign.md` — expect ≥1
- `grep -c "campaign-name} | Google\|campaign-name} | Microsoft\|campaign-name} | Other" plugins/marketing/commands/launch-campaign.md` — expect 0 (all updated to `Professional | Google` form in examples)

**Verify**: read Phases 9–11 examples in editor. Naming convention is consistent (`base | Email-type | ESP`); preview-lead picker semantics work for both `segments`-present and `--no-host-lookup`-empty paths.

---

### Task 10: Annotate plan files + BC-6307 design doc with BC-6654 supersession pointer
**Files**: `docs/plans/BC-5826-plan.md`, `docs/plans/BC-5906-plan.md`, `docs/plans/BC-6303-plan.md`, `docs/plans/BC-6307-plan.md`, `docs/plans/BC-6308-plan.md`, `docs/designs/BC-6307-phase-2-email-type-segmentation.md`
**Why**: Per BC-6301 task-1 precedent — production-template files fix in lockstep, round-evidence files keep verbatim with forward-pointer. Plan files are execution artifacts at their issue's time-point; rewriting the body destroys their historical-record value. A one-line annotation at the top points future readers to BC-6654 for the current-truth metadata shape and naming convention. The BC-6307 design doc's alternatives-considered #2 was already explicitly superseded by the BC-6514 memo (verified — see lines 50–58 of BC-6514 memo); this annotation is at the file-top for discoverability, not a body rewrite.

**Implementation**:
1. **For each plan file** (`BC-5826-plan.md`, `BC-5906-plan.md`, `BC-6303-plan.md`, `BC-6307-plan.md`, `BC-6308-plan.md`), add a single annotation line immediately after the H1 heading:
   ```markdown
   > **Note (2026-05-05, BC-6654):** segmentation references in this plan reflect the pre-multiplicative ESP-axis spec. The current spec uses (email-type × ESP) cell segmentation per BC-6514 (`docs/designs/BC-6514-segmentation-axis-decision.md`); the metadata schema, naming convention, and `--no-segment` flag all changed. This plan is preserved as historical execution record.
   ```
2. **For `docs/designs/BC-6307-phase-2-email-type-segmentation.md`**, add the same annotation at the top (immediately after H1):
   ```markdown
   > **Note (2026-05-05, BC-6654):** Alternatives Considered #2 in this memo was explicitly superseded by BC-6514 (`docs/designs/BC-6514-segmentation-axis-decision.md`). The "augment ESP × email-type → up to 9 buckets" path is now the default per BC-6514's reasoning. This memo is preserved as historical decision record.
   ```
3. **Skip `docs/designs/BC-6514-segmentation-axis-decision.md`** — it's the supersession-source itself; annotating would be circular.

**Test**:
- `grep -l "Note (2026-05-05, BC-6654)" docs/plans/BC-{5826,5906,6303,6307,6308}-plan.md docs/designs/BC-6307-phase-2-email-type-segmentation.md | wc -l` — expect 6
- Each annotation appears before any body content (after H1, before any `##` section)
- `grep -L "Note (2026-05-05, BC-6654)" docs/plans/BC-{5826,5906,6303,6307,6308}-plan.md` — expect empty (every plan annotated)

**Verify**: open each annotated file. Annotation reads as a standalone blockquote forward-pointer; body content unmodified.

---

### Task 11: Add BC-6514 + BC-6654 cross-link to launch-campaign.md "Precedent + upstream sources" block + version bump
**Files**: `plugins/marketing/commands/launch-campaign.md`, `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Why**: Issue acceptance criterion 8: "Cross-link: BC-6514 memo + this issue's title cited in launch-campaign.md 'Precedent + upstream sources' block." That block is at line 22 of the spec. Plus the CLAUDE.md plugin-version-bump gotcha — any edit under `plugins/marketing/{commands,...}/**` requires bumping the marketing plugin's version in BOTH `plugins/marketing/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` in the same commit (BC-6000 precedent — without the bump, clients' plugin cache serves stale content for the next N `/workflows:ship` sessions).

**Implementation**:
1. **launch-campaign.md "Precedent + upstream sources" block (line 22)**: read the existing block content (it's a list of upstream references). Append a new bullet (or insert in chronological order if the list is dated):
   ```markdown
   - **BC-6514** — segmentation-axis architectural decision (multiplicative ESP × email-type as default; single `--no-host-lookup` opt-out; `--no-segment` removed). See `docs/designs/BC-6514-segmentation-axis-decision.md`.
   - **BC-6654** — spec rewrite + metadata schema migration applying BC-6514's call to Phase 2 (9-cell grid + gate-2 prompt), Phase 5 (naming + multiplicative loop), and downstream phase 6/7/9/10/11 examples.
   ```
2. **`plugins/marketing/.claude-plugin/plugin.json`**: bump `"version": "0.3.23"` → `"version": "0.3.24"`.
3. **`.claude-plugin/marketplace.json`**: find the `marketing` plugin entry; bump its `version` from `0.3.23` to `0.3.24` in lockstep. (Use `grep -n` to locate the entry; the version field sits inside the `plugins[]` array entry whose `name` is `"marketing"`.)

**Test**:
- `grep -c "BC-6514\|BC-6654" plugins/marketing/commands/launch-campaign.md` — expect ≥4 (existing references + the 2 added in the precedent block)
- `grep -E '"version"' plugins/marketing/.claude-plugin/plugin.json` — expect `"version": "0.3.24"`
- `python3 -c 'import json; d = json.load(open(".claude-plugin/marketplace.json")); v = next(p["version"] for p in d["plugins"] if p["name"] == "marketing"); assert v == "0.3.24", v; print("ok", v)'` — expect `ok 0.3.24`
- Both version fields match (`0.3.24`); no orphan `0.3.23` reference left under `plugins/marketing/` or `.claude-plugin/marketplace.json`

**Verify**: open the precedent block in the spec — BC-6514 + BC-6654 entries are present, formatted consistently with existing entries; both version fields are `0.3.24` and lockstep.

---

## Task Dependencies

- **Task 1 → Task 3**: Task 3 references the flag-table line numbers; Task 1 deletes the `--no-segment` row. Run Task 1 first to avoid stale line-number references during Task 3 verification (though both edit different sections, the verification grep counts in Task 3 are cleanest after Task 1).
- **Task 2 → Tasks 4, 6, 7, 8, 9**: Task 2 establishes the `segments` shape + compound-key contract; downstream tasks reference that shape in metadata writes + per-cell examples. Run Task 2 second.
- **Tasks 3, 4, 5 are sequential within Phase 2**: Task 3 (purpose/skip-flag), Task 4 (step 3 + step 4), Task 5 (gate-2 prompt). Same § so do them in order.
- **Tasks 6, 7, 8, 9 are independent of each other** (different phases, no shared content) — could parallelize after Task 2 lands.
- **Task 10 is independent** of all spec edits — different files. Parallelizable with any spec task.
- **Task 11 is the last task** — it requires all spec edits to be done so the version bump captures the full set, and CLAUDE.md gotcha says the bump must be in the same commit as the edits.

## Verification Checklist

- [ ] **Task 1**: `grep -c "no-segment" plugins/marketing/commands/launch-campaign.md` = 0; flag table has 8 rows (one less than today); frontmatter `argument-hint` excludes `--no-segment`.
- [ ] **Task 2**: `grep -c "esp_segments\|email_type_segments\|disabled_segmentation" plugins/marketing/commands/launch-campaign.md` = 0; `grep -c '"segments"' plugins/marketing/commands/launch-campaign.md` ≥ 2; metadata worked-example block uses compound keys consistently.
- [ ] **Task 3**: Phase 2 § purpose paragraph mentions 9-cell (email-type × ESP) grid; only one skip flag (`--no-host-lookup`) in the skip-flags block; the "narrower ESP-only skip" contract line is gone.
- [ ] **Task 4**: Step 3 builds 9-cell grid; step 4a has 4 filter bullets (no `Disable ESP segmentation`); step 4b prunes empty cells with multi-cell example; step 4d writes `segments` only.
- [ ] **Task 5**: User gate 2 markdown table renders 3 email-types × 3 ESPs; filter options list has 5 entries (4 + Abort); no "Disable ESP segmentation" option.
- [ ] **Task 6**: Phase 5 purpose mentions cell-shell creation; step 2 has both `--no-host-lookup` and multiplicative branches; step 9's `campaign_ids` example uses compound keys.
- [ ] **Task 7**: Phase 6 § references `(email-type × ESP) cell` consistently; step 7 metadata mirrors `segments`.
- [ ] **Task 8**: Phase 7 § sender-invariant prose unchanged ("ALL senders to ALL campaigns"); examples + forbidden patterns updated to compound-key form.
- [ ] **Task 9**: Phase 9–11 examples use compound keys; Phase 10 preview-lead picker semantics work for both `segments`-present and `--no-host-lookup`-empty paths.
- [ ] **Task 10**: 5 plan files + 1 design doc carry the BC-6654 annotation; bodies otherwise unmodified.
- [ ] **Task 11**: Precedent + upstream sources block in launch-campaign.md cites BC-6514 + BC-6654; both `plugin.json` files report `0.3.24`; no orphan `0.3.23`.
- [ ] **End-to-end self-read (BC-6307 task-2 factual-anchor recipe)**: read launch-campaign.md once front-to-back after all spec tasks land. Confirm: every `--no-segment` reference is gone; every `esp_segments` reference is gone; the 9-cell shape is consistently described in Phase 2 § purpose, step 3, step 4b, gate-2 prompt, Phase 5 purpose; the metadata schema worked example agrees with the descriptive paragraph.
- [ ] **No vacuous claims**: BC-6654 issue scope item 7 ("Eval scenarios") cited a non-existent `evals/launch-campaign/` directory — verified absent. Skip without action; PR description should note this absence so reviewer doesn't expect eval changes.
- [ ] **Out-of-scope respected**: no edits in `plugins/marketing/skills/email-copywriting/`, `plugins/marketing/skills/tam-mapping/`, or `plugins/marketing/skills/campaign-debrief/` (BC-6655 sibling audit handles these).
