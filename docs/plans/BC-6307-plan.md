# Plan: BC-6307 — Phase 2 email-type detection in `/marketing:launch-campaign`

**Issue**: BC-6307 — BC-5906 follow-up: launch-campaign Phase 2 — extend segmentation by email-type axis (role/personal/professional)
**Branch**: `corinne/bc-6307-bc-5906-follow-up-launch-campaign-phase-2-extend`
**Tasks**: 7 (estimated ~60–75 min before review)
**Design doc**: `docs/designs/BC-6307-phase-2-email-type-segmentation.md`

## Prerequisites

- Working tree clean (untracked `docs/campaigns/` is fine; no other untracked).
- Worktree created via `git-worktrees` skill (next phase).
- **Precedent alignment**:
  - BC-5829 + BC-5830 task-1 — factual-anchor recipe check #7 (cross-skill schema contracts at Plan gate). Applied: predicate output names match BounceBan response shape so future swap is internals-only.
  - BC-2717 task-3 — cross-skill keep-in-sync reciprocal annotation. 2nd surface, near 3rd-promotion threshold. Applied: Task 5 annotates BOTH sides of the launch-campaign ↔ tam-mapping mirror.
  - BC-5832 task-2 — cross-skill contract review-validation hit rate ~100%. Calibration: budget for review pipeline to find issues; allocate fix time accordingly.
- **CDR alignment**: CDR INDEX check skipped (Context7 unavailable this session).

## Tasks

### Task 1: Add the email-type detection step as the new first step of Phase 2

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: This is the core behavior — classify each lead as `professional` / `role` / `personal` before the existing dig pipeline runs.

**Implementation**:

1. Locate Phase 2 in `plugins/marketing/commands/launch-campaign.md` (currently lines 224–278). Find the `**Steps:**` block (line 230).
2. Renumber the existing steps 1–5 to **steps 2–6**.
3. Insert a new **step 1** titled `**Email-type detection (per-lead pre-filter).**` with this body:
   - Open paragraph: "Before resolving ESP per domain, tag each lead by email-type. Two static lists are baked into the spec — no DNS lookup, no API call. Predicate output names (`is_role`, `is_free`) match the BounceBan response shape so the future brite-enrichment-MCP swap (BC-5538) is an internals-only change."
   - Sub-bullet: **Role-prefix list (19 entries)** — list verbatim: `info`, `sales`, `contact`, `support`, `hello`, `team`, `office`, `admin`, `help`, `service`, `general`, `feedback`, `enquiries`, `inquiry`, `inquiries`, `pr`, `press`, `partnerships`, `partners`. Match: case-insensitive exact on local-part. No normalization (no hyphen-stripping, no underscore-collapsing) — variant forms like `customer-service@` and `info-team@` are intentionally NOT caught at this level; that's the BC-5538 BounceBan-swap's job. Scope rationale (decided at plan time): list focuses on generic shared inboxes that genuinely show up in B2B CSVs and aren't a fit as cold-outreach targets. **Intentionally excluded**: back-office department names (`accounting`, `accountspayable`, `ap`, `billing`, `accounts`, `legal`), HR/talent (`hr`, `recruiting`, `recruiter`, `jobs`, `careers`), IT (`it`), customer-service-team queues (`cs`, `customerservice`), media/marketing/events (`media`, `marketing`, `events`), operations (`operations`, `ops`), and system addresses (`noreply`, `postmaster`, `webmaster`, `mail`, `email`). The exclusions reflect Brite's TAM (back-office departments aren't decision-makers for lighting; system addresses shouldn't appear in clean CSVs from list-building) plus the operator-override safety valve at gate 2 for the rare slip-through. False-positive cost is bounded — operator review at gate 2, not silent deletion.
   - Sub-bullet: **Free-mail-domain list (12 entries)** — list verbatim: `gmail.com`, `yahoo.com`, `hotmail.com`, `outlook.com`, `icloud.com`, `aol.com`, `protonmail.com`, `googlemail.com`, `live.com`, `me.com`, `mac.com`, `mail.com`. Match: case-insensitive exact on domain. First 7 cover the canonical free providers (the original 5 from tam-mapping's Operational rule 1 plus `aol.com` + `protonmail.com`). Last 5 are US-relevant aliases that legitimately appear in US-based prospect lists: `googlemail.com` (Google's older alias), `live.com` (Microsoft consumer), `me.com` + `mac.com` (Apple legacy), `mail.com` (generic free provider). **Intentionally excluded**: country-localized variants (`yahoo.co.uk`, `outlook.de`, etc.), Russian/Chinese providers (`mail.ru`, `yandex.*`, `163.com`, `qq.com`), and US ISP-attached email (`comcast.net`, `verizon.net`, `att.net`, etc.). The first two categories are out of Brite's TAM. The ISP category is a deliberate skip — false-positive risk on home-based micro-businesses (sole-proprietor installers giving out `tom@comcast.net` as the business contact) is high in Brite Nites' contractor-targeted campaigns.
   - Sub-bullet: **Per-lead predicate**:
     ```
     is_role(email):  local-part ∈ role-prefix list (case-insensitive exact match)
     is_free(email):  domain ∈ free-mail-domain list (case-insensitive exact match)
     bucket(email):
       if is_free(email):       → "personal"   (tiebreak: personal beats role)
       elif is_role(email):     → "role"
       else:                    → "professional"
     ```
   - Sub-bullet: **Tiebreak rule.** Spell out plainly: "If a lead matches both `is_role` AND `is_free` (e.g., `sales@gmail.com`), report as `personal`, not `role`. Reasoning: dominant signal is the free-mail domain; aligns with operator-override semantics — if the operator opts to 'include role but skip personal,' this lead correctly follows the personal rule."
   - Sub-bullet: **Output**: per-lead tag plus aggregated counts: `email_type_segments: {professional: N, role: N, personal: N}`. Empty buckets absent from object (matches existing `esp_segments` shape).
   - Closing: "Steps 2–6 below operate on the surviving lead set after gate 2 applies the filter (default: professional only). If gate 2's chosen action drops all leads, halt with a clear message."
4. Add a forward-reference at the top of Phase 2's `**Purpose.**` paragraph: "Phase 2 has two detection passes. **Email-type detection** (step 1) classifies each lead as `professional` / `role` / `personal` and lets the operator drop role + personal addresses by default. **ESP detection** (steps 2–6) resolves who hosts each surviving lead's domain so professional leads can be split into Google / Microsoft / Other campaigns."

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0; no markdown / frontmatter / structural errors.

**Verify**:
- Phase 2 of launch-campaign.md now has 6 numbered steps with email-type detection as step 1.
- Role-prefix and free-mail-domain lists appear verbatim as specified above.
- Tiebreak rule is documented inline (not deferred to a footnote).

---

### Task 2: Update Phase 2's user gate 2 prompt to surface email-type counts and override options

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Operator needs to see the email-type counts and decide whether to apply the default skip rule, include everything, or abort — before the dig pipeline finishes and the existing ESP gate-2 prompt fires.

**Implementation**:

1. Locate the existing `**User gate 2.**` block in `launch-campaign.md` (currently lines 270–276).
2. Replace the existing 3-option `Approve / Disable / Abort` block with a unified gate that surfaces both detections and lets the operator make a single combined decision. New shape:

   ```
   **User gate 2.** Ask via `AskUserQuestion`:

   > Phase 2 detection summary for campaign `{base}`:
   >
   > **Email-type breakdown** (lead-level):
   > - Professional — N leads
   > - Personal     — N leads (free-mail domains)
   > - Role         — N leads (info@, sales@, etc.)
   >
   > **ESP breakdown** (after applying default email-type filter — professional only):
   > - {base} | Google     — N leads ({% of professional}%)
   > - {base} | Microsoft  — N leads ({% of professional}%)
   > - {base} | Other      — N leads ({% of professional}%)
   >
   > {IF any ESP bucket skipped:}
   > Skipped (0 leads after filter): {skipped-bucket-list}.
   > {END IF}
   >
   > Detailed ESP breakdown (8-bucket, professional only): Google N, Microsoft N, Proofpoint N, Mimecast N, Barracuda N, Cisco N, Custom N, Unknown N.
   >
   > **Default action: skip role + skip personal.** Only the {N-professional} professional leads will be segmented into ESP campaigns.
   >
   > - Apply default — skip role + personal, segment professionals by ESP (Recommended)
   > - Include role addresses too — segment role + professional by ESP, skip personal only
   > - Include personal addresses too — segment personal + professional by ESP, skip role only
   > - Include all — segment every lead by ESP, no email-type filter
   > - Disable ESP segmentation — single combined campaign on the chosen email-type subset
   > - Abort
   ```
3. After the gate, add a follow-up note: "If the operator's chosen action leaves zero leads in any ESP bucket after filtering, the existing F12 skip-empty-buckets logic (step 3) handles it. If ALL surviving leads end up in a single bucket, gate-2-disable behavior applies."
4. Update the existing `**If Phase 2 fails:**` paragraph (line 278) to also cover the email-type-detection failure mode: "If email-type detection encounters a malformed lead (missing `@`, multiple `@`, etc.), record the row number in `invalid_email_rows` (sibling of `invalid_domain_rows`) and skip the lead from BOTH email-type and ESP buckets. Operator sees the count at gate 2."

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0.

**Verify**:
- Gate-2 prompt shows email-type breakdown above ESP breakdown.
- Six options listed (apply default, +role, +personal, all, disable-segmentation, abort).
- Default action is explicitly stated.
- `invalid_email_rows` is mentioned as the sibling of `invalid_domain_rows` for malformed-email failures.

---

### Task 3: Add sidecar CSV write step + document path convention and schema

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Skipped leads must not vanish silently. Operator audits post-run via the sidecar log.

**Implementation**:

1. After Task 2's gate-2 block, insert a new sub-step (between gate 2 and the existing metadata-write step) titled `**Sidecar CSV write for skipped leads.**` with this body:
   - "If gate 2's chosen action skips any leads, write them to a sidecar CSV before proceeding. Path convention mirrors the metadata JSON's dual-path rule from § Launch metadata schema 'Dogfood write path' note:"
   - **Production path**: `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}-skipped.csv`
   - **Dogfood path**: `.claude/worktrees/<detected-worktree>/dogfood/{campaign-name}-{YYYY-MM-DD}-skipped.csv`
   - "CSV columns: original CSV columns verbatim (preserve order) + one new trailing column `skip_reason` with values `role_address` or `personal_domain`. If a lead matches both lists (tiebreak case), `skip_reason` is `personal_domain` per the personal-beats-role rule."
   - "If gate 2's chosen action skips zero leads, the sidecar file is NOT created. The metadata JSON's `skipped_leads_csv_path` field is `null` in that case."
2. Add a `skipped_leads_csv_path: <path> | null` entry to the **Optional fields** section (lines 144–157) of § Launch metadata schema, with a brief description: "Phase 2 step 1+gate 2: path to sidecar CSV of skipped leads (role/personal). `null` if no leads skipped."

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0.

**Verify**:
- Sidecar CSV step is present after gate 2 in Phase 2.
- Both paths (production + dogfood) are documented.
- `skip_reason` column values are exactly `role_address` and `personal_domain`.
- `skipped_leads_csv_path` is in the optional-fields list of the metadata schema.

---

### Task 4: Add `email_type_segments` to the metadata JSON schema + update Phase 2's metadata-write step

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Resume + audit need the per-bucket email-type counts persisted alongside `esp_segments`.

**Implementation**:

1. Locate the canonical metadata schema example block (currently lines 115–140). Add `email_type_segments` immediately after `esp_segments` (line 125):
   ```json
   "email_type_segments": {"professional": 84, "role": 3, "personal": 9},
   ```
2. Add a one-line description in the prose paragraph following the schema (line 142): "`email_type_segments` records the per-email-type bucket counts BEFORE the gate-2 filter is applied — captures the operator's full input, not just the surviving subset. Empty buckets are absent from the object (matches `esp_segments` convention)."
3. Update Phase 2's metadata-write step (currently step 5, will become step 6 after Task 1's renumbering) to also populate `email_type_segments`:
   - Existing line 268: `5. **Append to metadata JSON.** Set `segmented: true`, `esp_segments: {<only non-empty buckets>}`, `last_completed_phase: 2`.`
   - Updated text: `**Append to metadata JSON.** Set `segmented: true`, `esp_segments: {<only non-empty buckets>}`, `email_type_segments: {<only non-empty buckets>}`, `email_type_filter_applied: "<gate-2-choice-label>"`, `skipped_leads_csv_path: <path>|null`, `last_completed_phase: 2`. Empty buckets absent from both objects.`
4. Add `email_type_filter_applied` to the optional-fields section (lines 144–157) with values: `"default"` / `"include_role"` / `"include_personal"` / `"include_all"` / `"disabled_segmentation"`. Description: "Phase 2 gate 2: which override the operator picked. `default` means skip role + personal."

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0.

**Verify**:
- Canonical schema example includes `email_type_segments` between `esp_segments` and `custom_variables_created`.
- Phase 2's metadata-write step populates `email_type_segments`, `email_type_filter_applied`, `skipped_leads_csv_path`.
- Optional-fields list documents `email_type_filter_applied` with all 5 valid values.

---

### Task 5: Add reciprocal "Keep in sync" annotation to tam-mapping/SKILL.md and launch-campaign.md

**Files**: `plugins/marketing/skills/tam-mapping/SKILL.md`, `plugins/marketing/commands/launch-campaign.md`
**Why**: BC-2717 task-3 precedent (2nd surface, near 3rd-promotion). When two skills mirror a rule, BOTH sides must annotate. tam-mapping's Operational rule 1 (free-email exclusion) and launch-campaign's email-type detection (step 1, free-mail filter) implement the same conservative-default policy at different stages.

**Implementation**:

1. **tam-mapping/SKILL.md** — Locate Operational rule 1's primary site (line 353). Append a `**Keep in sync.**` annotation:
   - "**Keep in sync.** This rule is mirrored at runtime by `/marketing:launch-campaign` Phase 2 step 1 (email-type detection, free-mail-domain list). When the upstream pipeline correctly applies this rule, launch-campaign's filter is a no-op safety net. When CSVs reach launch-campaign that bypassed this filter (e.g., manually-sourced lists, exports of `personal-contacts.csv`), launch-campaign's filter catches them. **If you change this rule (add/drop a free-mail domain), update both sides.** Annotation pair: `plugins/marketing/skills/tam-mapping/SKILL.md` § Operational rule 1 ↔ `plugins/marketing/commands/launch-campaign.md` § Phase 2 step 1 free-mail-domain list."
2. **launch-campaign.md** — Inside Task 1's step-1 body (after the free-mail-domain list sub-bullet), append a `**Keep in sync.**` annotation:
   - "**Keep in sync.** This list mirrors `plugins/marketing/skills/tam-mapping/SKILL.md` § Operational rule 1 (free-email-provider pre-tier filter). The upstream rule routes free-mail rows to `personal-contacts.csv` BEFORE tier-A/B/C delegation; the runtime rule here is a safety net for CSVs that bypassed tam-mapping. **If you change this list (add/drop a free-mail domain), update both sides.** Annotation pair: `plugins/marketing/commands/launch-campaign.md` § Phase 2 step 1 free-mail-domain list ↔ `plugins/marketing/skills/tam-mapping/SKILL.md` § Operational rule 1."
3. Mechanical asymmetry test: post-edit, run `grep -l "Annotation pair:" plugins/marketing/skills/tam-mapping/SKILL.md plugins/marketing/commands/launch-campaign.md`. Both files must appear in the output. If only one appears, the mirror has half-broken — fix immediately.

**Test**:
- Run: `./scripts/validate.sh`
- Run: `grep -l "Annotation pair:" plugins/marketing/skills/tam-mapping/SKILL.md plugins/marketing/commands/launch-campaign.md | wc -l`
- Expected: both grep commands report `2`.

**Verify**:
- Both files contain the `Annotation pair:` token.
- Both annotations cite the OTHER file's path + section name verbatim.
- Asymmetry-test grep passes.

---

### Task 6: Bump plugin version (per CLAUDE.md gotcha — same commit as `plugins/<plugin>/{commands,skills}/**` edits)

**Files**: `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Why**: Per CLAUDE.md gotcha: "Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`." Costly precedent BC-6000 — a hook fix sat uncollected in cache for 4+ ship sessions before diagnosis. This is a spec change touching `commands/launch-campaign.md` and `skills/tam-mapping/SKILL.md`, both under the bump-required path.

**Implementation**:

1. Read `plugins/marketing/.claude-plugin/plugin.json` to find the current `version` value.
2. Bump the `version` field by patch level (e.g., `1.4.2` → `1.4.3`). This is a behavioral spec change, no breaking API change.
3. Read `.claude-plugin/marketplace.json`. Find the entry for the marketing plugin. Bump its `version` field to match.
4. Confirm both versions are identical post-bump.

**Test**:
- Run: `./scripts/validate.sh`
- Run: `jq -r '.version' plugins/marketing/.claude-plugin/plugin.json`
- Run: `jq -r '.plugins[] | select(.name == "marketing") | .version' .claude-plugin/marketplace.json`
- Expected: both jq commands return the same version string; validate.sh exits 0.

**Verify**:
- `plugins/marketing/.claude-plugin/plugin.json` version bumped.
- `.claude-plugin/marketplace.json` marketing entry version matches.

---

### Task 7: Final verification — full validate.sh run + spot-check the design-doc → spec mapping

**Files**: (read-only verification pass)
**Why**: BC-5829 factual-anchor recipe + BC-5832 task-2 calibration — review pipeline has ~100% hit rate on cross-skill contract work. Pre-empt easy P1s by self-checking before invoking review.

**Implementation**:

1. Run `./scripts/validate.sh`. Confirm exit 0 and no warnings on the touched files.
2. Confirm the design doc's "In scope" list (`docs/designs/BC-6307-phase-2-email-type-segmentation.md`) maps 1:1 to changes shipped:
   - Email-type detection in Phase 2 → Task 1
   - Role-prefix list, free-mail-domain list (predicates) → Task 1
   - Gate-2 prompt extension → Task 2
   - Default-skip rule → Task 2 (shipped as one of six options, with "Apply default" labeled Recommended)
   - Sidecar CSV → Task 3
   - `email_type_segments` field added to metadata JSON schema → Task 4
   - Reciprocal tam-mapping annotation → Task 5
3. Run a `grep` sweep for the anchor strings:
   - `grep -c "is_role(email)" plugins/marketing/commands/launch-campaign.md` ≥ 1
   - `grep -c "is_free(email)" plugins/marketing/commands/launch-campaign.md` ≥ 1
   - `grep -c "personal beats role" plugins/marketing/commands/launch-campaign.md` ≥ 1
   - `grep -c "skip_reason" plugins/marketing/commands/launch-campaign.md` ≥ 1
   - `grep -c "email_type_segments" plugins/marketing/commands/launch-campaign.md` ≥ 2 (canonical schema + Phase 2 step)
   - `grep -c "Annotation pair:" plugins/marketing/skills/tam-mapping/SKILL.md` = 1
   - `grep -c "Annotation pair:" plugins/marketing/commands/launch-campaign.md` = 1
4. If any grep returns less than expected, the corresponding Task is incomplete — fix before invoking review.

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exit 0.

**Verify**:
- All grep counts meet or exceed expected values.
- validate.sh clean.
- 1:1 design → spec mapping holds.

---

## Task Dependencies

- Task 1 → Task 2 (gate references the detection results from step 1).
- Task 1 + Task 2 → Task 3 (sidecar writes the leads gate-2 chose to skip).
- Task 1 → Task 4 (metadata field name `email_type_segments` is fixed by Task 1's bucket labels).
- Task 5 (reciprocal annotation) is **parallelizable** with Tasks 1–4 — the annotation text is independent of the spec's other internals.
- Task 6 (version bump) must come AFTER all spec edits.
- Task 7 (verification) is final.

Sequential order with parallelization opportunity: 1 → 2 → 3 → 4, with 5 running parallel anywhere in 1–4, then 6 → 7.

## Verification Checklist

- [ ] All 7 tasks complete (each task's verify-step satisfied).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `grep "Annotation pair:" plugins/marketing/skills/tam-mapping/SKILL.md plugins/marketing/commands/launch-campaign.md | wc -l` returns 2.
- [ ] Plugin versions match between `plugins/marketing/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- [ ] Phase 2 of launch-campaign.md has 6 steps (was 5).
- [ ] Canonical metadata schema example includes `email_type_segments`.
- [ ] Optional-fields section includes `email_type_filter_applied` and `skipped_leads_csv_path`.
- [ ] Design doc's "In scope" list maps 1:1 to shipped changes (no scope creep, no scope drop).
- [ ] No `BounceBan` API call introduced (Task 1 documents heuristic-only; no MCP tool added; predicate naming is the only forward-reference).
