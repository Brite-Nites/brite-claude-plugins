# livech.com property/geo corrections — 2026-08-19

## Why

Inbound meeting request from `Olivia.smith@livech.com` (EA to Candice Davis-Griffin,
VP Marketing) traced back to a campaign-185 send to **Ryan Eller**. Eller was labeled
`Live! Casino & Hotel Philadelphia` in every artifact. He is in fact **EVP & General
Manager of Live! Casino & Hotel Maryland** (Cordish newsroom, appointed 2023-01-17;
still in role per the Oct 2024 Maryland leadership announcement).

## Root cause

The scrape harvested people from press releases hosted under
`philadelphia.livecasinohotel.com/globalnews/` and tagged each person with the **host
property page**, not their actual property. Confirmed by John Chaszar, whose
"EVP & GM of Live! Casino & Hotel **Louisiana**" release is served from that same
Philadelphia globalnews path — and who was likewise labeled Philadelphia.

Nothing downstream could catch it: Clay derived `@livech.com` addresses that validated
clean (BounceBan 98/deliverable). **`livech.com` is the chain-wide Cordish domain** —
Maryland, Philadelphia, Pittsburgh, Louisiana, and Virginia staff all share it, so a
valid email carries zero property signal.

## Corrections applied (EB lead records + 22 CSVs, 92 row-fixes)

| lead_id | person | was | now | confidence |
|---|---|---|---|---|
| 320838 | Ryan Eller | Philadelphia / PA | **Maryland** / Hanover MD | confirmed |
| 320822 | Rich Puffinburger | Philadelphia / PA | **Maryland** / Hanover MD | confirmed |
| 320746 | John Chaszar | Philadelphia / PA | **Louisiana** / Bossier City LA | confirmed |
| 284564 | Cheryl Brown | Maryland / Chesapeake VA | **Virginia** / Petersburg VA | confirmed (moved roles) |
| 248795 | Kevin O'Sullivan | Philadelphia / MD | Philadelphia / **PA** | confirmed (VP Slots) |
| 248916 | Brent Colston | Pittsburgh / MD | Pittsburgh / **PA** | confirmed |
| 320851 | Stephane Hainaut | Philadelphia / PA | **Maryland** / Hanover MD | likely |
| 284256 | Dawn Dodimead | Maryland / Philadelphia PA | Maryland / **Hanover MD** | likely |
| 284378 | Anthony Gustafson | (already correct) | Maryland / Hanover MD | confirmed |

**UNRESOLVED — `tracey.witchko@livech.com` (248813).** SVP Property Operations, property
not named by any source. Maryland's SVP Property Ops was announced as Penny Penilla Parayo
(Oct 2024), which argues she is elsewhere. Left as Philadelphia. Verify before her next touch.

## Sends stopped (campaign 185)

`POST /api/campaigns/185/leads/stop-future-emails` for the five Maryland contacts —
same office as the live Candice Davis-Griffin thread, per the audit's
WARM_FOLLOWUP → drop-same-office rule:

- 320838 Ryan Eller (follow-up was due Aug 21 15:38 UTC)
- 284378 Anthony Gustafson (**cold step 1** was due Aug 24 21:06 UTC)
- 320822 Rich Puffinburger (follow-up Aug 22 00:07 UTC)
- 320851 Stephane Hainaut (follow-up Aug 21 15:49 UTC)
- 284256 Dawn Dodimead (unscheduled, now blocked)

Left running as sibling properties: John Chaszar (LA), Ken Lanigan (Philadelphia),
Kevin O'Sullivan (Philadelphia), Brent Colston (Pittsburgh), Cheryl Brown (Virginia).

## Still unverified

`FOUND-people.csv` holds six more Live! contacts all tagged Philadelphia from the same
scrape path — Daniel Clark, Jake Joyce, Jon Campbell, Jay Day, Gretchen Holzhauser,
Renee Mutchnik. None are in an active campaign. Treat their property labels as unverified.
