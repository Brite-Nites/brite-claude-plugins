# BC-5932 — Compose zoos preset files (Offer E primary + Offer A tactical)

**Issue:** [BC-5932](https://linear.app/brite-nites/issue/BC-5932) — Compose 4 zoos preset files.
**Branch:** `holden/bc-5932-compose-zoos-preset-files-offer-e-primary-offer-a-tactical`
**Worktree:** `.claude/worktrees/bc-5932/` (per operator request).
**Blocked by:** BC-5920 (zoos playbook) — DONE, landed in PR #184.
**Blocks:** BC-5938 (preset library ship readiness), BC-5879 (roadmap).

---

## Goal

Compose 4 preset files in `plugins/marketing/skills/email-copywriting/presets/`:

1. `list-building-zoos.md` — Offer E T2 (default filename; primary motion).
2. `risk-reversal-zoos.md` — Offer E T4 (default filename; primary motion).
3. `list-building-zoos-pilot-zone.md` — Offer A T2 (variant filename; tactical complement).
4. `risk-reversal-zoos-pilot-zone.md` — Offer A T4 (variant filename; tactical complement).

All 4 follow the EB-format shape from `plugins/marketing/skills/email-copywriting/SKILL.md` § 3 Methodology and mirror the Municipalities seed structure from `list-building-municipalities.md` + `risk-reversal-municipalities.md` (BC-5825 precedent).

## Complexity call

Skip brainstorming. Single-module markdown composition; approach fully prescribed by SKILL.md § 3 + Municipalities seeds + zoos playbook. Sixth consecutive TRIVIAL-class ship in this rhythm (BC-5917 → 5918 → 5919 → 5924 → 5920 → 5921 → 5932).

---

## Source ledger (already read; treat as frozen)

- `plugins/marketing/references/vertical-playbooks/zoos.md` (BC-5920 output, 240 lines) — Offer E + Offer A definitions, voice rules, anti-slop, Hogle + S4 anchors, vendor-landscape framing.
- `plugins/marketing/skills/email-copywriting/SKILL.md` § 3 Methodology — EB format rules, Hormozi value equation, base skeletons A + B, lazy-load preset contract.
- `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md` + `risk-reversal-municipalities.md` — format precedent (5-key frontmatter + Hook / Step 1 / Step 2 / Vertical anti-slop sections).
- `docs/plans/BC-5879-zoos-ledger.md` § A1 (Offer E Hormozi mapping) + § A3 (Hogle + S4 anchors) + § Voice rules § Offer A fixes.

---

## Tasks

### Task 1 — Compose `list-building-zoos.md` (Offer E T2 primary)

**Shape:** 5-key frontmatter → H1 → Hook → Step 1 skeleton → Step 2 bump → Vertical anti-slop. Target **55–65 lines**.

**Frontmatter:**
- `preset: list-building`
- `vertical: zoos`
- `entity: brite-labs`
- `when:` program-season window (Nov–Jan or summer variant) + title-sponsor-pipeline signal OR economic-impact-study publication OR Director-of-Corporate-Partnerships role change.
- `situation_mining_row:` cite the Active-tier zoos row in SKILL.md § 3 (or roadmap R-10 anchor).

**Hook:** Vertical-specific recency waterfall — anchor on title-sponsor precedent (Invesco QQQ / ComEd / CPS Energy / Meijer) OR Denver-style economic-impact figure OR program-announcement date. Greeting-merged first sentence per SKILL.md § 3.

**Step 1 body:** Base skeleton A adaptation. `{FREE_ASSET_NOUN}` default = `"economic-impact deck"` OR `"sponsor-target shortlist"` (operator picks; both are Offer-E-native assets tied to the funding-orchestration pitch). Hogle Zoo proof anchor + S4 partnership name-drop. Value-equation inputs:
- Dream Outcome → "a seasonal program that makes the zoo money instead of costing it."
- Perceived Likelihood → Hogle Zoo named anchor + S4 partner venue breadth.
- Time Delay → "6–9 months to program-live; year-2 renewal default upside."
- Effort + Sacrifice → "we underwrite the sponsor pipeline and ad-monetized stack; you contribute site access."

**Step 2 bump:** Re-frame funding orchestration in one paragraph; reinforce the free-asset offer.

**Vertical anti-slop** (5 bullets, cumulative from playbook § Voice rules + § Anti-slop rules):
- Don't over-specify incumbent vendor type ("existing lighting vendor" / "incumbent" only; not "lantern vendor" / "projection vendor").
- Don't name-drop Disney / Universal / theme-park analogs — stay within zoo precedents.
- Don't use "event" or "activation" — use "program" (multi-season, YoY refresh).
- Don't name species ("tigers", "elephants") — use "your collection" / "your flagship exhibits" / the public program name.
- No "magical" / "enchanting" / "wondrous" / "mesmerizing" adjectives.

### Task 2 — Compose `risk-reversal-zoos.md` (Offer E T4 primary)

**Shape:** same sections, target **55–65 lines**.

**Frontmatter:** `preset: risk-reversal`, `vertical: zoos`, `entity: brite-labs`, `when:` large-capital-commitment signal (multi-year pipeline + committee-heavy procurement + sponsor-stack large enough that zoo wants performance underwrite). `situation_mining_row:` T4 variant of Active-tier zoos row.

**Hook:** Same as T2 but tone-shifted: less playful, more respectful of the multi-season capital commitment. Reference the specific sponsor pipeline or bond cycle.

**Step 1 body:** Base skeleton B adaptation. **Guarantee framing:** first-season-breakeven-or-no-pay. Language pattern: "If the program doesn't break even in year one against {AGREED_BASELINE} (attendance + sponsor + ad revenue), the production-finance fee isn't billed." Hogle Zoo as the proof anchor that Brite has delivered AT a zoo (not just underwritten paperwork). S4 partnership as the supply-chain credibility layer.

**Step 2 bump:** Specify what "breakeven" means (which line items count), reinforce the committee-safe outcome-based framing.

**Vertical anti-slop** (5 bullets, same cumulative list as Task 1, adjusted for T4 tone):
- No "ROI uplift" without a named metric — specify hotel-room-nights / membership-conversion / per-cap / sponsor-inventory sell-through.
- Don't over-promise beyond documented case studies.
- Avoid guarantee language that triggers legal review at a nonprofit ("refund in full"); use outcome-gated framing ("fee not billed until breakeven").
- Don't reference installers or property management — Supply-excluded per handbook canon.
- Don't mention competitors (Tianyu / Illuminight / Moment Factory) by name — T4 is Brite's own commitment, not head-to-head.

### Task 3 — Compose `list-building-zoos-pilot-zone.md` (Offer A T2 tactical complement)

**Shape:** same sections, target **55–65 lines**.

**Frontmatter:** `preset: list-building`, `vertical: zoos`, `entity: brite-labs`, `when:` venue has a long-tenured incumbent lighting vendor AND a decision-maker (Marketing Director or Director of Corporate Partnerships) open to a low-commitment test. `situation_mining_row:` Offer-A-tactical row.

**Hook:** Position for venues with entrenched incumbent — open with the recency anchor + a hypothesis that the incumbent scope has a blind spot in one zone. Greeting-merged.

**Step 1 body:** Apply the three Offer A fixes from BC-5879 zoos-ledger § Offer A review:
1. **Frontend deliverable:** `{FREE_ASSET_NOUN}` = `"rendered concept board for [specific area at venue]"`. Tangible artifact, not visualization-required promise. Phrase as "a rendered concept board (24″×36″) for {PILOT_ZONE_AREA}".
2. **Commercial structure:** "We'll underwrite the install cost. In exchange, we use the results — footage, metrics, venue name — in our sales material." Confident, not supplicant.
3. **Frame for incumbent:** body copy references "your existing lighting vendor" or "current seasonal-program vendor" (never "lantern vendor" / "projection vendor" per voice rule #1).

Hogle Zoo + S4 partnership anchors same as Offer E presets. Persona default: Director of Corporate Partnerships or Marketing Director (per playbook § Buyer personas — they're the Offer A coalition-builders).

**Step 2 bump:** Reinforce the narrow scope ("one zone, one season") and the low-commitment shape.

**Vertical anti-slop** (5 bullets):
- Same cumulative list as Task 1, **plus** one Offer-A-specific rule: don't frame the pilot as a "replacement" of the incumbent — frame as a "specialist add-on" or "complementary zone." Positioning matters for the decision-maker's internal politics.

### Task 4 — Compose `risk-reversal-zoos-pilot-zone.md` (Offer A T4 tactical complement)

**Shape:** same sections, target **55–65 lines**.

**Frontmatter:** `preset: risk-reversal`, `vertical: zoos`, `entity: brite-labs`, `when:` pilot-zone scope where decision-maker wants performance underwrite before committing to budget or scope expansion. `situation_mining_row:` Offer-A-tactical T4 variant.

**Hook:** Same as Task 3 hook but T4-toned.

**Step 1 body:** Base skeleton B adaptation. **Guarantee metric (pick ONE, name it explicitly):**
- `dwell_time` → "15-minute average dwell time in the pilot zone, measured by {MEASUREMENT_METHOD} (sensor / head-count)."
- `attendance_uplift` → "{PCT}% attendance uplift in programmed hours vs baseline, measured by gate-scan data."
- `sponsor_visibility` → "{N} sponsor-visibility impressions on pilot-zone branding, measured by photo/dwell-count or AI-computer-vision pass."

**NOT photo-share** — per BC-5879 ledger § Offer A fix #2, photo-share is gimmicky and disconnected from venue success. The anti-slop list enforces this.

Commercial structure: "We'll underwrite the install cost and carry the guarantee. If {MEASURED_METRIC} doesn't hit {THRESHOLD}, the case-study rights clause voids — you walk with the install and no obligation."

**Step 2 bump:** Specify measurement method + threshold + walk-away terms.

**Vertical anti-slop** (5 bullets):
- **Do not use photo-share metrics.** First rule, named explicitly so future regenerations don't drift back to the gimmicky framing.
- Same cumulative rules from Task 1/2/3, adjusted for T4 tone.

### Task 5 — Anti-slop greps (12 AC checkboxes)

Run after all 4 files written. Hard-pass required on every check:

```bash
FILES="plugins/marketing/skills/email-copywriting/presets/{list-building-zoos,risk-reversal-zoos,list-building-zoos-pilot-zone,risk-reversal-zoos-pilot-zone}.md"

# AC: exists
ls -1 plugins/marketing/skills/email-copywriting/presets/list-building-zoos.md \
      plugins/marketing/skills/email-copywriting/presets/risk-reversal-zoos.md \
      plugins/marketing/skills/email-copywriting/presets/list-building-zoos-pilot-zone.md \
      plugins/marketing/skills/email-copywriting/presets/risk-reversal-zoos-pilot-zone.md

# AC: frontmatter keys
for f in $FILES; do head -8 $f | grep -E '^(preset|vertical|entity|when|situation_mining_row):' | wc -l; done
# expect 5 per file

# AC: no double-brace
grep -l '{{' $FILES  # expect: no files

# AC: no <p> tags
grep -l '<p>' $FILES  # expect: no files

# AC: no em-dash in body
grep -l '—' $FILES  # expect: no files

# AC: no merge variable in Subject
grep '^\*\*Subject:\*\*' $FILES | grep -E '\{[A-Z_]+\}' | grep -v '^\*\*Subject:\*\* `\{[^|]+\|'
# expect: no results (the only braces in subject should be spintax {a|b|c}, not merge vars)

# AC: Hogle anchor present
for f in $FILES; do grep -l 'Hogle\|{LABS_PEER_VENUE}' $f; done  # expect all 4

# AC: S4 reference present
for f in $FILES; do grep -lE 'S4 Lights|S4 partnership|\{S4_PARTNER_VENUE\}' $f; done  # expect all 4

# AC: no "lantern vendor" / "projection vendor" in body (voice rule — allowed in anti-slop as "don't use")
for f in $FILES; do
  awk '/^## Vertical anti-slop/,0' $f > /tmp/antislop.$f
  awk '/^## Vertical anti-slop/{exit} {print}' $f > /tmp/body.$f
  grep -ciE 'lantern vendor|projection vendor' /tmp/body.$f
done  # expect 0 for each body

# AC: line count 55-65 (±5 tolerance)
for f in $FILES; do wc -l $f; done

# AC: validate.sh
./scripts/validate.sh  # expect exit 0

# AC: check-guardrails.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md  # expect exit 0
```

### Task 6 — `./scripts/validate.sh`

Baseline: 0 errors / 16 warnings. New preset files should add 0 errors (warnings may stay at 16 or drop — neither is a regression).

### Task 7 — `./scripts/check-guardrails.sh --claude-md CLAUDE.md`

Must exit 0. No changes to CLAUDE.md in this PR.

---

## Departures / deliberate deviations from the prescribed protocol

_(Fill in during execution as they arise. Anticipate at least one — every prior session in this rhythm has logged 1–3.)_

**Anticipated pre-execution candidates:**
- Offer A preset filenames use a `-pilot-zone` suffix (variant filename) while Offer E presets use default filenames. This is a structural departure from Municipalities (which has only one offer per preset file). Intentional per issue spec.

---

## Precedent candidates (draft, finalize at ship)

- **task-2 or task-4** — First instance of `first-season-breakeven-or-no-pay` as a risk-reversal guarantee shape in a Brite preset. If composition surfaces a reusable linguistic pattern (e.g., "fee not billed until {measured_outcome}"), that's a pattern-application precedent candidate.
- **task-3/4 (Offer A pair)** — First instance of a two-offer preset split in one vertical (default filename + variant filename). If the filename convention holds up under review, that's a pattern-choice precedent candidate worth filing for future roadmap offers.

---

## Non-goals (verbatim from issue)

- Do NOT compose Offer B variants (deferred pending R-19 / BC-5941 Facilities-VP motion confirmation).
- Do NOT modify SKILL.md or Municipalities seeds.
- Do NOT file Linear issue for v2 refresh (that's R-17 BC-5939 + R-18 BC-5940 jobs).

---

## Verification gates (12 AC checkboxes — issue body verbatim)

- [ ] All 4 files exist at correct paths.
- [ ] Each has 5-key frontmatter.
- [ ] Each has H1 + Hook + Step 1 + Step 2 + Vertical anti-slop sections.
- [ ] `grep -l '{{'` returns no files.
- [ ] `grep -l '<p>'` returns no files.
- [ ] `grep -l '—'` returns no files.
- [ ] No merge variable in any Subject line.
- [ ] Each file cites Hogle or `{LABS_PEER_VENUE}`.
- [ ] Each file cites S4 partnership or `{S4_PARTNER_VENUE}`.
- [ ] `grep -ci 'lantern vendor\|projection vendor'` returns 0 in body (antislop section may name them).
- [ ] Line count 55–65 per file (±5 tolerance).
- [ ] `./scripts/validate.sh` + `./scripts/check-guardrails.sh` exit 0.
