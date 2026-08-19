# Casinos — session handoff (2026-08-14)

## ✅ LIVE — activated 2026-08-14, sending

| Campaign | Lane | Leads | Sent | Status | plain_text | Steps | Senders | Cap |
|---|---|---:|---:|---|---|---:|---:|---:|
| **#185** | SMTP | 763 | 0 | **active** | true | 2 | 15 | 50/day |
| **#186** | Google | 27 | 0 | **active** | true | 2 | 15 | 25/day |
| **#187** | Outlook | 813 | 0 | **active** | true | 2 | 15 | 50/day |

Named `FY26, M08 | Casinos | Holiday Decor | Professional Emails | …`
Leads ordered **WAVE-1 net-new first** (261 never-contacted, 1,342 re-engagement).

**Copy shipped is the right shape** — camp 54's pattern, which is the only one that ever
worked in this vertical (1.1% human reply vs 0.1% for the dense-pitch version):
- bare subject — *"Holiday decor"*, *"December idea"*, *"Q4 plans"*
- step 1: one question — *"Who's the best person to talk to about holiday decor at your property?"*
- step 2 (3d): the permission-ask — *"happy to be pointed to whoever runs the holiday decor
  if it's not you"* — the exact move that produced every referral in camp 54

### One free upgrade not taken

Step 2 says *"our work with other casinos"* generically. **Seminole Tribe of Florida is a real
~$286k won customer** (Big Cypress, Brighton, Immokalee, Chupco) and has **never** appeared in
cold copy — only in 8 hand-written replies. Naming it, especially to tribal properties, is
stronger than any generic claim. Worth a step-2 variant.
⚠️ **Do not cite Casino Pauma** — its only opportunity is Closed Lost ($17,279, Dec 2025).


## What the copy needs to do (evidence, not opinion)

The audit produced one finding that outweighs the list work. Across 3,902 contacts and
7,533 sends, the message — not the list — drove everything:

| | Camp 54 (Mar–Apr 26) | Camp 94/95 (May 26) |
|---|---|---|
| Subject | bare 2–3 words: *"guest experience"*, *"event season"* | *"NYE programming for {COMPANY}"* |
| Body | one line: *"has your property ever looked into event lighting?"* | dense pitch, *"…not catalog garland from a strip-mall vendor"* |
| Step 2 | *"is this something you'd handle? if not, happy to go that route"* | *"programming calendars anchor around end of summer…"* |
| **Human reply** | **1.1%** | **0.1–0.2%** |

Camp 54 produced 17 of the 23 human replies and 4 of the 5 warm leads in the vertical's
entire history. Copy 94/95 also addressed *"casino marketing teams"* — the wrong buyer,
and prospects said so: *"I am a casino host and work in casino marketing. You have the
wrong person."*

**Also: we have real casino references that have NEVER appeared in cold copy.**
Seminole Tribe of Florida (~$286k won across Big Cypress, Brighton, Immokalee, Chupco)
and Casino Pauma appear in 8 hand-written replies and **zero** sequences.
⚠️ Casino Pauma's only opportunity is **Closed Lost** ($17,279, Dec 2025) — cite Seminole,
drop Pauma.

Suggested shape: bare subject, one question, and camp 54's permission-asking step 2
(*"if someone else handles this, point me their way"*) — that step generated every
referral we got. Lead tribal properties with the Seminole reference.

## Chase these three before any campaign sends

| Who | What happened | Age |
|---|---|---|
| **Justin Sullivan** — Corp Dir Marketing, Gila River (`justin.sullivan@wingilariver.com`) | *"I've got a couple of projects… maybe set up a call late next week?"* Santi replied same day. **Nothing since.** | since 2026-06-01 |
| **John Moss** — VP Eng & Facilities, Virgin Hotels LV | Asked for a palm-tree lighting proposal, **call booked Apr 8 9am**, then mis-filed do-not-contact | Apr 2026 |
| **Elise Grabowski** — Fortune Bay | **Call booked Wed 4/15 11am** with Rainer, then mis-filed do-not-contact | Apr 2026 |

Virgin Hotels LV is suppressed from the campaign (open SF opportunity) — that's correct,
it belongs to sales, not outbound.

## Files

Audit + list build: `docs/campaigns/audits/casinos/`
- `SEND-LIST-FINAL-VERIFIED.csv` — 1,734 verified (pre-load-suppression)
- `WAVE-1-net-new.csv` (262) / `WAVE-2-previously-mailed.csv` (1,472)
- `README.md` — the full audit; `SUPPRESSION-ACTIONS-LOG.md` — every suppression + why
- `scripts/` — re-runnable pipeline
- `UNIVERSE-final.csv` (896 properties) · `GAP-final-by-company.csv` · `ENRICH-target-companies.csv`

Load artifacts: `docs/campaigns/audits/casinos-load/`
- `SEND-LIST-FINAL-VERIFIED-1734-2026-08-14.csv`, `SUPPRESSED-2026-08-14.csv`, chunks, lead IDs

Also mirrored to `~/Desktop/Casinos/`.

## Still open (not blockers)

- **~210 enriched people still have no email** after an 11-provider Clay waterfall.
- **100 of 521 companies have no LinkedIn page at all** — smallest tribal properties;
  they need website scraping (`spider_crawl.py`), not LinkedIn.
- **571 universe properties still have zero contacts** — NV 105, OK 74, MN 34, CA 30.
  80 of them sit inside operators we already reach (Caesars 38, Boyd 13, Penn 8) and are
  referral asks, not cold prospecting.
- **Size qualification was never solved.** LinkedIn headcount is useless here — it claims
  WinStar has 32 employees and Westgate Las Vegas has 1. Hotel room counts via Wikipedia
  would be the real test.
- **`bc-5930-casinos-research.md` is stale on scope** — it excludes Las Vegas Strip
  flagships; the operator put Vegas **in** on 2026-08-13. `casinos.yaml` carries a note.

## Config change made this session

`plugins/marketing/data/canonicals/casinos.yaml` went from `personas: []` to four
operator-approved personas — Director of F&B, GM/COO, Director of Facilities, Director of
Special Events — with title strings observed from 2,359 real casino contacts, not invented.
That empty file is why three campaigns drifted to 655 marketing contacts against 40 in F&B.
**Modified but uncommitted, and you're on `main` — branch before committing.**
