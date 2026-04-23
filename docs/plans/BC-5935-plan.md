# BC-5935 — Compose hotels & resorts preset files

**Issue:** [BC-5935](https://linear.app/brite-nites/issue/BC-5935)
**Roadmap row:** R-13 (email-copywriting preset library)
**Blocks:** BC-5938 (preset library ship readiness), BC-5879 (superseded parent)
**Blocked by:** BC-5921 — `hotels-resorts.md` playbook (shipped, PR #186)

## Scope

Compose **4 preset files** for the hotels & resorts vertical v1 offer set. Offer E is primary; Offer A is tactical complement; Offer B is pending R-19 (do not compose).

V1 offer set derives from `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` § V1 offer picks:

- **Primary: Offer E — Branded Seasonal Program** (2 files)
- **Tactical complement: Offer A — Rate-Premium Pilot** (2 files)
- Pending R-19: Offer B — skip

## Files to produce

All under `plugins/marketing/skills/email-copywriting/presets/`:

1. `list-building-hotels-resorts.md` — Offer E, T2 free-asset. Default filename (Offer E is primary). `{FREE_ASSET_NOUN}` = "program design deck" or "revenue pro-forma".
2. `risk-reversal-hotels-resorts.md` — Offer E, T4. Year-1 guarantee = peak-weekend ADR lift vs comp-set baseline OR revenue-share-floor structure.
3. `list-building-hotels-resorts-rate-premium.md` — Offer A, T2. `{FREE_ASSET_NOUN}` = "rendered concept board for [named pilot zone at property]". Frames for properties with long-tenured incumbent holiday-lighting vendor.
4. `risk-reversal-hotels-resorts-rate-premium.md` — Offer A, T4. Revenue-native guarantee metric (ADR lift / direct-channel mix / attach rate; NOT photo-shares or vanity metrics). Commercial framing: "we underwrite install; in exchange we use results + property name in sales material."

Offer-slug `rate-premium` matches playbook "Rate-Premium Pilot" and mirrors zoos' `-pilot-zone` suffix convention.

## Format contract (from SKILL.md § 3 + Municipalities seeds)

**5-key frontmatter:** `preset`, `vertical: hotels-resorts`, `entity: brite-labs`, `when`, `situation_mining_row`.

**Sections:** H1 → Hook (vertical-specific recency waterfall anchor) → Step 1 skeleton (`**Subject:**` + `**Body:**` + `**wait_in_days:**`) → Step 2 bump → Vertical anti-slop bullets.

**Length target:** 55–65 lines (zoos convention; hotels inherits).

## EB format rules (hard failures at verify time)

- Single-brace uppercase merge vars: `{FIRST_NAME}`, `{COMPANY}`. No `{{ }}`.
- `<br><br>` for paragraph breaks. No `<p>` / `</p>`.
- Zero em-dashes (`—`) in body.
- No `{FIRST_NAME}` or any merge var in subject line.
- Exactly 2 steps (step 1 + step 2 bump).
- Sign-off spintax: `{Best|Cheers|Thanks},<br>{SENDER_FIRST_NAME}`.
- Word-level spintax every 3–5 words where grammar permits.

## Vertical-specific content rules

- **Framing:** "rate-premium" and "destination-experience" are load-bearing — at least one per hook/body.
- **Personas in body:** GM / Director of Revenue / DOSM / Owner-Operator (NOT VP Revenue Management / VP Experience — enterprise-only, per playbook § Buyer personas).
- **Vocabulary:** ADR, RevPAR, compression events, booking pace, on-the-books, attach rate, length-of-stay minimums, direct channel, comp-set index. Not "beautiful lighting" / "transform your property."
- **Proof anchors:** Fairmont Scottsdale Princess (15-year compounding), Hotel del Coronado (1904 heritage + annual theme rotation), Callaway Fantasy In Lights (Lodge package economics). Hard Rock Hollywood acceptable as *scale ceiling* reference, not as peer target.
- **Explicitly forbidden in body copy (may appear in anti-slop "don't" bullets only):** Marriott / Hilton / Hyatt / Ritz-Carlton / Four Seasons / Waldorf Astoria as default ICP; "romantic" / "ambiance" / "magical" / "enchanting" / "dazzling" / "mesmerizing"; wedding-market framing as lead; urgency language ("limited availability", "book now"); "lighting upgrade" framing.

## Tasks (TDD-style verification per task)

1. Draft `list-building-hotels-resorts.md` → per-file anti-slop grep passes.
2. Draft `risk-reversal-hotels-resorts.md` → per-file anti-slop grep passes.
3. Draft `list-building-hotels-resorts-rate-premium.md` → per-file anti-slop grep passes.
4. Draft `risk-reversal-hotels-resorts-rate-premium.md` → per-file anti-slop grep passes.
5. Cross-file anti-slop greps (4 files together): `{{`, `<p>`, `—`, `{FIRST_NAME}` in subject, step count = 2, sign-off spintax present.
6. Vocabulary greps: `grep -ci 'marriott\|hilton\|hyatt\|ritz-carlton\|four seasons\|waldorf' <files>` returns 0 in body copy; `grep -ci 'romantic\|ambiance\|magical\|enchanting' <files>` returns 0 in body copy.
7. `./scripts/validate.sh` exits 0.
8. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.

## Non-goals

- Do NOT compose Offer B variants (pending R-19, blocked on BC-5941-equivalent hospitality-side).
- Do NOT update `presets/README.md` manifest — deferred to BC-5938.
- Do NOT modify SKILL.md or Municipalities seeds.
- Do NOT target Marriott / Hilton / Hyatt enterprise flagships.
- Do NOT pitch GM-only (missing Director of Revenue as co-primary).

## Departures from zoos (R-10 / BC-5932) structural pattern

Track here; update at ship time with any runtime drift:

- **3 offers in playbook, 2 composed here** (vs zoos' 4 offers, 2 composed). Offer B pending, Offer D folded into E in playbook — no D-composition task.
- **Offer-slug `rate-premium` vs zoos' `pilot-zone`** — Offer A at hotels is rate-premium-metric-pilot (revenue-manager scorecard), not physical-zone-pilot (attendance-metric). Different slug surfaces the different mental model.
- **Proof-anchor shape differs** — hotels uses YoY-compounding continuity anchors (Fairmont 15yr, Hotel del 1904, Callaway multi-decade); zoos used case-study peers (Hogle Zoo + S4 Lights partnership). Structural role equivalent.
- **Enterprise-brand anti-slop more explicit** — Marriott/Hilton/Hyatt/Ritz-Carlton/Four Seasons/Waldorf all named as forbidden defaults (vs zoos' single Smithsonian-tier forbiddance).

## Worktree

Branch: `holden/bc-5935-hotels-presets` (shortened from Linear's suggestion for readability).
Worktree path: `.claude/worktrees/bc-5935/`.
Baseline: `./scripts/validate.sh` must pass on main before worktree setup.

## Verification checklist (copy from issue)

- [ ] All 4 preset files exist at correct paths.
- [ ] Each has 5-key frontmatter with `vertical: hotels-resorts` and `entity: brite-labs`.
- [ ] Each has H1 + Hook + Step 1 + Step 2 + Vertical anti-slop sections.
- [ ] `grep -l '{{'` across 4 files returns no files.
- [ ] `grep -l '<p>'` across 4 files returns no files.
- [ ] `grep -l '—'` across 4 files returns no files (body em-dash absent).
- [ ] No `{FIRST_NAME}` in any `**Subject:**` line.
- [ ] `grep -ci 'marriott\|hilton\|hyatt'` returns 0 in body copy (anti-slop bullets OK).
- [ ] `grep -ci 'romantic\|ambiance'` returns 0 in body copy (anti-slop bullets OK).
- [ ] Line count 55–65 per file (±5 tolerance).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
