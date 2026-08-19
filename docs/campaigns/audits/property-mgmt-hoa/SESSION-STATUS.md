# HOA Campaign — Session Status (2026-07-27)

**State: audience fully loaded + scrubbed into 3 EB draft campaigns. NOT sending.**
Source of truth = Email Bison (b2b ws55). The CSVs here are the working audit trail.

## Loaded now

| Lane | Campaign ID | Leads |
|---|---|--:|
| SMTP | 162 | 1,880 |
| Google | 163 | 216 |
| Microsoft | 164 | 1,716 |
| **Total** | | **3,812** |

~99% residential (62% HOA/community-association + 37% apartment/multifamily). ESP lanes routed by recipient mail provider; catch-all → SMTP.

## To go live (all still pending — nothing sends without these)
1. **Copy** — no sequence set on any campaign yet. Angle decided: write to the **community/property manager**, sell them on how easy you make the **board** conversation (free board-ready proposal/mockup). Board-timing subject lines proved best last cycle.
2. **Sender accounts** assigned per ESP lane.
3. **Activation** — flip drafts → active.

## Held out / removed (not in the 3,812)
- **373 execs** (VP/owner/etc.) → `HOA_EXEC_portfolio_segment.csv`, for a separate portfolio pitch.
- **55 shopping-center/commercial** removed (Vestar, Cushman, Baceline, Kleban, Bell Properties, Hall Equities, Majestic, Barclay, GDC + explicit commercial/retail titles). Newland + The Lewis Group (master-planned residential) also pulled — reversible if wanted.

## Fully passed suppression (9 gates)
BounceBan deliverable · dedup (4 sources) · ICP fit · domain+geo cap (max 3/city) · EB blocklist (0 hits) · negative-reply scan across ALL campaigns (0 opt-outs) · Salesforce brite-prod (8 customers/active-deals pulled) · 60-day recency across all campaigns (14 pulled) · exec removal.

## Key files (this folder + `~/Desktop/HOA communities/`)
- `HOA-FINAL-load-ready.csv` — the 4,262 pre-removal master (geo-capped)
- `HOA-COMBINED-ready-v2.csv` — 4,818 uncapped backup
- `HOA_EXEC_portfolio_segment.csv` — 373 execs
- Per-lane upload files: `HOA_upload_camp{162,163,164}_*_FINAL.csv`

## GREENLIT: Self-managed HOA vertical (Phoenix build) — operator committed 2026-07-27
New segment to pursue — independent/self-managed HOAs (volunteer boards, no mgmt company). Not in the current campaign. Method validated:
- **Source:** Arizona Corporation Commission nonprofit filings (agent = board → self-managed) + azhoawatch.org (flags self-managed vs mgmt-co + board names).
- **Findability proven; contactability is the bottleneck** (~30-50% email-reachable, rest direct-mail-only).
- **Build:** ACC/azhoawatch pull (Maricopa) → filter self-managed → board names+address → split has-website vs names-only → BounceBan verify. Est. ~50-100 emailable Phoenix self-managed HOAs.
- **Copy angle:** direct-to-board, smaller communities, higher-touch, less competition.

## Next-session options
1. **Build the Phoenix self-managed HOA list** (committed vertical), OR
2. **Copy** for camps 162/163/164 (loaded audience waiting on copy+senders+activation).

Full detail in memory: `project_hoa_campaign_build`.
