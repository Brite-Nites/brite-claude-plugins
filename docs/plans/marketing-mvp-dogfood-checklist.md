---
title: Marketing Plugin GTM Workflows — MVP dogfood checklist
created: 2026-04-26
context: BC-5906 / BC-5950 / BC-2717 / BC-5832 / BC-5831 — the 5-issue MVP set
milestone: Marketing Plugin: GTM Workflows
exit-criterion: BC-6002 (full lifecycle dogfood — comes after MVP)
mvp-vertical: Hotels & Resorts
---

# Marketing Plugin GTM Workflows — MVP dogfood checklist

Reference companion for completing the 5 MVP issues (BC-5906, BC-5950, BC-2717, BC-5832, BC-5831). Walks the user-facing flow once those ship + defines success criteria for the dogfood pass.

**MVP scope** (locked 2026-04-26 via the per-function audit captured in [BC-6002 comment](https://linear.app/brite-nites/issue/BC-6002)):
- TAM construction, list-building, ICP scoring **IN MVP**
- Brite enrichment MCP, conductor, reply-processing, marketing ops, alt channels, additional-vertical preset fan-outs **OUT** (deferred to backlog)
- Vertical: Hotels & Resorts (BC-5921 R-7 playbook + BC-5935 R-13 presets, both shipped)

---

## What the MVP chain looks like in practice

Picture a Tuesday afternoon. You sit down to launch a Hotels & Resorts campaign. Here's the actual user flow once the 5 MVP issues land:

```
─── Step 1 ─────────────────────────────────────────────────────────
You:    /marketing:tam-map hotels-resorts

Claude: [confirms with you, then runs the 7-phase pipeline]
        → Spider.cloud crawls hotel domains
        → AI Ark discovers companies matching firmographics
        → Discolike expands lookalikes from peer venues
        → IcyPeas keyword-search fills gaps
        → 3-tier dedup
        → MANDATORY EB-workspace exclusion (catches "we already emailed these")
        → BlitzAPI → Prospeo enrichment waterfall
        → MillionVerifier SMTP validation
        → Haiku tier-scoring (delegates to icp-scoring rubric=abc)
        → outputs:
            docs/campaigns/labs/tam/hotels-resorts-2026-04-XX/
            ├── tier-a.csv   (your A-list — top 30-100)
            ├── tier-b.csv   (B-list — next 100-300)
            ├── tier-c.csv   (C-list)
            └── catch-all.csv (isolated, not for B2B)

─── Step 2 ─────────────────────────────────────────────────────────
You:    [auto-invoke] /marketing:list-building tier-a.csv hotels-resorts

Claude: → reads tier-a.csv
        → suppresses against EB-b2b + EB-personal workspaces (re-check)
        → suppresses against SF Contacts/Leads (already-known)
        → contact-discovery 3-step pipeline (domain → LinkedIn → verified email)
        → outputs:
            docs/campaigns/labs/tam/hotels-resorts-2026-04-XX/
            ├── campaign-ready.csv   (final, enriched, deduped, suppressed)
            └── suppression-report.md

─── Step 3 ─────────────────────────────────────────────────────────
You:    [eyeball campaign-ready.csv — looks reasonable, ~50 hotels]

You:    [optionally invoke situation-mining for top-10 prospects to add
         personalization, OR skip and use the Hotels preset directly]

─── Step 4 ─────────────────────────────────────────────────────────
You:    /marketing:email-copywriting --vertical hotels-resorts
         --offer landscape-lighting --leads campaign-ready.csv

Claude: → loads Hotels preset (BC-5935 R-13 preset library, shipped)
        → drafts subject + body for Step 1 + Step 2 of sequence
        → outputs:
            docs/campaigns/labs/tam/hotels-resorts-2026-04-XX/
            └── copy-artifact.json  (EB-formatted, ready for launch-campaign)

─── Step 5 ─────────────────────────────────────────────────────────
You:    /marketing:launch-campaign copy-artifact.json campaign-ready.csv

Claude: → 11-phase orchestration validated by BC-5906 round-2 dogfood
        Phase 1: pre-flight (workspace, sender pool, schedule, blocklist)
        Phase 2: dry-run preview (eyeball one rendered email)
        Phases 3-9: compose campaign + attach leads + attach senders +
                    schedule + sequence steps + resume
        Phase 10: stage activation
        ║ Phase 11: ACTIVATE — STOP HERE in MVP, dry-run only

        → output: campaign live in EB workspace, ready to flip to active
```

---

## Success criteria for the dogfood

Grade on three axes — execution, artifacts, decision quality. Each axis can land at one of three confidence levels.

### ✅ Strong success (ship MVP, iterate)

- **Execution**: Chain ran end-to-end without dropping into bash to manually edit a CSV. Each `/command` invocation completed cleanly. Total wall-time ≤ 90 minutes from `/marketing:tam-map` to staged-launch artifact.
- **Artifacts**: `tier-a.csv` looks like real Hotels you'd actually want to email. `campaign-ready.csv` has ≥ 80% verified emails. `copy-artifact.json` produces emails you'd be willing to send to a real customer (passes your gut check + Brite's anti-slop rules).
- **Decision quality**: Tiering matches your intuition (no obvious B-list venues in tier-a, no A-list venues in tier-c). Suppression caught at least 1-2 already-known contacts.

### 🟡 OK success (MVP works, but file follow-ups)

- **Execution**: Chain completed but you had to manually patch a CSV column rename or fix one `~/.zshrc` env-var. 1-2 retries needed mid-chain.
- **Artifacts**: Mostly usable; you'd want to hand-edit ~10-30% of the email copy before sending. Tier scoring is in the right ballpark but a few placements feel off.
- **Decision quality**: Suppression worked. Tiering is "directionally right." Acceptable for v1; file 3-5 follow-up issues for sharpening.

### 🔴 Not yet (MVP doesn't compose)

- **Execution**: Chain breaks at a handoff (e.g., list-building can't read tam-map's CSV format, or launch-campaign rejects the copy artifact). Fundamental design issues, not just bugs.
- **Artifacts**: Email copy is generic enough that you wouldn't send it. Tier scoring buckets feel arbitrary.
- **Decision quality**: Suppression missed obvious things, or tiered known A-list venues into tier-c.

**Decision rule**:
- 🔴 → BC-6002 is premature. File design issues against specific steps and re-MVP.
- 🟡 → Ship MVP and ramp BC-6002 with the follow-ups in flight.
- ✅ → You've earned the right to start unlocking the deferred chains (Brite enrichment MCP, conductor, marketing ops, etc.).

---

## Pre-dogfood checklist (run before invoking `/marketing:tam-map`)

- [ ] All 5 MVP issues shipped + merged
- [ ] `/marketing:setup-tam-map` ran successfully (8 env vars exported in `~/.zshrc`, all 3 MCPs `✓ Connected`, all 5 CLI scripts pass `--help`)
- [ ] Hotels & Resorts preset files present at `plugins/marketing/skills/email-copywriting/presets/list-building-hotels-resorts.md` + `risk-reversal-hotels-resorts.md` (shipped via BC-5935)
- [ ] Hotels & Resorts vertical playbook present at `plugins/marketing/references/vertical-playbooks/hotels-resorts.md` (shipped via BC-5921)
- [ ] Email Bison MCP connected to b2b workspace (the one you'll launch from)
- [ ] Test sender pool active in EB (sender warmup ≥ 14 days, healthy bounce rate)
- [ ] You have a clear ICP statement for the Hotels run (geography filter, employee band, type filter — boutique vs chain vs resort)

---

## Per-step verification gates

Run these checks at each step. If any gate fails, stop and triage before proceeding.

### After Step 1 (TAM construction)

- [ ] `tier-a.csv` exists with ≥ 20 rows and ≤ 200 rows (sane volume)
- [ ] Random spot-check 5 rows of tier-a.csv: each is a real Hotels & Resorts company (not a vendor, not a contractor, not adjacent industry)
- [ ] `catch-all.csv` is SEPARATE from tier-a/b/c.csv (per BC-5832 anti-slop rule)
- [ ] No `gmail.com` / `yahoo.com` / `hotmail.com` / `outlook.com` / `icloud.com` rows in tier-a/b/c.csv (free-email exclusion rule)
- [ ] Cost report shows total enrichment spend ≤ $X (set your own threshold; rough budget: ~$0.10-0.30/lead for the BlitzAPI → Prospeo waterfall + MillionVerifier verification)

### After Step 2 (list-building)

- [ ] `campaign-ready.csv` has ≥ 80% verified emails (the rest are catch-all-flagged, not invalid)
- [ ] `suppression-report.md` shows at least 1-2 contacts caught by EB-workspace suppression (proves the suppression actually ran)
- [ ] Spot-check 3 contacts: do they have plausible titles for the offer? (e.g., GM, Operations Director, F&B Director for a landscape-lighting offer at hotels)

### After Step 4 (email-copywriting)

- [ ] `copy-artifact.json` parses as valid JSON with the EB-shaped fields (subject, body, sequence_step, etc. — see `plugins/marketing/skills/email-copywriting/SKILL.md` §3)
- [ ] Subject line passes Brite anti-slop (no em-dashes, no "I hope this finds you well", no merge-var collisions)
- [ ] Body uses Hotels preset's vertical-specific Hook section (cite case study or peer venue, not generic)
- [ ] Render one email with realistic merge-var values: does it sound like a human Brite would write?

### After Step 5 (launch-campaign Phase 10)

- [ ] EB campaign exists in the b2b workspace, status = staged (not active — this is dry-run)
- [ ] Lead count in EB matches `campaign-ready.csv` row count
- [ ] Sender pool attached and healthy
- [ ] Schedule attached (sending window matches your intent)
- [ ] Phase 2 dry-run preview email looked correct when previewed earlier
- [ ] You're confident you could flip Phase 11 to ACTIVATE without surprises

---

## Time-to-MVP estimates

Of the 5 MVP issues:

- **Yours (3)**: BC-5906 + BC-5950 + BC-2717 — call it 1-2 sessions each = **3-6 sessions for your part**
- **Corinne's (2)**: BC-5831 + BC-5832 — depends on her bandwidth + the tam-mapping skill is dense (BC-5832 has ~25 sub-tasks in its description)

Recommended sequence for your 3:

1. **BC-5906 first** (independent, builds your launch confidence — validates `/marketing:launch-campaign` Phases 3-9 in isolation)
2. **BC-2717 next** (your part of the chain — can develop against fixture CSV before Corinne's BC-5832 lands)
3. **BC-5950 last** (orchestrator over Corinne's tam-mapping skill — best done after BC-5832 ships so you can wire to the real interface)

**Realistic MVP-shippable date**: 2-4 weeks if Corinne is in flight on her two issues in parallel. 4-6 weeks if her work is sequential after yours.

After MVP ships and you've run the dogfood once, **BC-6002 is roughly 1 session** — it's a structured walk + findings doc, not a build issue.

---

## What comes after MVP dogfood

```
MVP (5 issues) ships
   │
   ▼ Holden runs Hotels campaign through chain → grade outcome (✅ / 🟡 / 🔴)
   │
   ▼ if 🟡 / ✅
   │
BC-6002 (full 12-step lifecycle dogfood — exit criterion)
   │  Adds: situation-mining + creative-angles + MSPA framing + analysis
   │  + debrief on top of the 7-step MVP chain. Validates the full BC-6002
   │  lifecycle on the same Hotels vertical (or your second pick).
   │
   ▼ if 🟡 / ✅
   │
Milestone: GTM Workflows CLOSE
   │
   ▼ then unlock backlog selectively based on what dogfooding surfaced:
   │
   ├── Outbound conductor (BC-2722) — for one-command runs
   ├── Reply processing (BC-2720) — once replies start coming in
   ├── Brite enrichment MCP (BC-5536/5537/5538) — broader enrichment
   ├── Marketing ops chain (BC-2716 + BC-2725-2728) — production-scaling
   ├── Alt channels (BC-2723 LinkedIn, BC-2724 events) — multi-channel
   └── Preset fan-outs (BC-5880 Exploring, BC-5881 Future) — broaden vertical coverage
```

---

## Where this came from

This checklist was generated 2026-04-26 during a strategic re-grounding session after the BC-5947 PR shipped. The full reasoning for the MVP-vs-backlog split is captured in the BC-6002 comment thread (linked above). 11-question per-function audit walked through TAM construction, list-building, Brite enrichment MCP, ICP scoring, launch dogfood, conductor, marketing ops, alt channels, vertical pick, polish — each with explicit IN/OUT decision and rationale. 20 of 25 Todo issues were demoted to Backlog as a result.
