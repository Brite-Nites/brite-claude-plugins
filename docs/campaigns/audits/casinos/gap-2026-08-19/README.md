# Casino coverage gap — 2026-08-19

Rebuilt against the **live** campaign (ws55 #185/#186/#187, 1,603 leads, sending since 2026-08-14).

## Territory model (operator decision, 2026-08-19)

**National for resort-scale, in-territory for everything else.**

- **In territory** = the 16 Brite service states (NY DC CA FL IL TX MA PA CO NC VA MD NJ AZ UT CT).
  No size bar — take every casino.
- **Out of territory** = everywhere else. Only properties clearing the resort-scale bar.

## Resort-scale bar: ≥3,000 Google reviews

The TAM carries **no** size column — no rooms, gaming positions, revenue or headcount. A
name-token heuristic (`resort|hotel|lodge|inn`) was tried and **rejected**: it missed WinStar
World Casino (no "resort" in its name, 67,834 reviews) while admitting 18 Deadwood storefronts
that merely have "Hotel" in the name. Review count is the objective proxy actually available.

Calibration (Serper `/maps`, 893 queries, ~$0.90, `scale-serper.json`):

| Property | Reviews | Verdict |
|---|---|---|
| WinStar World Casino | 67,834 | giant |
| Riverwind Casino | 13,450 | resort-scale |
| Grand Casino Hotel & Resort | 12,004 | resort-scale |
| Remington Park | 9,992 | resort-scale (live lead) |
| Bear River Casino Resort | 3,412 | mid — *replied with a referral*, so the bar sits below it |
| Historic Bullock Hotel (Deadwood) | 740 | storefront, excluded |

Bar set at 3,000 so properties like Bear River — which produced a real referral — stay in.

## Method

1. 896 UNIVERSE-final rows → Serper `/maps` for reviews, rating, address, phone, website.
2. Drop non-venues (smoke shops, trading posts, tobacco, clubhouses, unbuilt "Project -" rows)
   and anything under 200 reviews (not findable / not a real venue) → 633.
3. Dedupe on (resolved domain | normalised title) + state → collapses the 500nations/wikipedia
   double-listings that survived the original merge.
4. Mark in-campaign by domain root (gap-file domain **and** Serper-resolved domain, since they
   often differ — Beau Rivage is `beaurivage.com` in EB but `mgmresorts.com` on Google) plus a
   **two-distinctive-token** name match. One shared token was tried and rejected — it collapsed
   Grand Casino Shawnee into Grand Sierra Resort on the word "grand".
5. Split the remaining 287 zero-contact properties by territory + bar.

Verified against six known cases: Beau Rivage IN, WinStar IN, Hard Rock Tulsa IN, Riverwind GAP,
Grand Casino Shawnee GAP, Pechanga GAP.

## Output

| File | Rows | What |
|---|---|---|
| `LIST-B-in-territory-all.csv` | 75 | **Enrich first.** CA 19, FL 15, CO 13, NY 11, AZ 7, PA 3, IL 2, MD 2, TX 2, VA 1 |
| `LIST-A-out-of-territory-resort-scale.csv` | 72 | NV 20, OK 10, WA 6, NM 5, MI 4, MS 4, IA/LA/MN 3 each |
| `scale-serper.json` | 893 | raw Serper payload, keyed by UNIVERSE property name |

Each row carries a Google-verified address, phone and website — so people-finding starts from a
real domain rather than the pattern-guessed junk in `GAP-final-by-company.csv`
(`grandresortapartments.com` for Grand Casino, `roland.com`, `stables.com`, typos like
`yandottenation.com`). Grand Casino Shawnee's real domain is `grandresortok.com`.

## Known TAM defects this did NOT fix

- Choctaw Landing (Hochatown, opened 2024) and FireLake Grand Casino are absent from the universe.
- Chickasaw properties carry the Ada HQ address as their city, so Riverwind reads as being in Ada.
- Chain rows still hide members: one row named "Cherokee Casino - South Coffeyville" stands in for
  all 14 Cherokee properties; "Choctaw Casino - Pocola Travel Plaza" stands in for 23 including
  the Durant flagship.
