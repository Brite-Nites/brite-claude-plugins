# livech.com property/geo corrections — 2026-08-19

> Contacts are referenced by EB lead ID + role + property. No names or email
> addresses: this repo is public and person-level detail is out of scope per the
> PR #511 policy. Resolve a lead ID in EB or Salesforce.

## Why

An inbound meeting request arrived from an executive assistant at Live! Casino &
Hotel Maryland. It traced back to a campaign-185 send to **lead 320838**, who was
labeled `Live! Casino & Hotel Philadelphia` in every artifact. That lead is in fact
the **EVP & General Manager of Live! Casino & Hotel Maryland** (Cordish newsroom,
appointed 2023-01-17; still in role per the Oct 2024 Maryland leadership release).

The reply itself was an **untracked reply** — composed fresh, new subject, no thread
headers — so it carried `campaign_id: null` and could not be attributed automatically.

## Root cause

The scrape harvested people from press releases hosted under
`philadelphia.livecasinohotel.com/globalnews/` and tagged each person with the **host
property page**, not their actual property. Confirmed by lead 320746, whose
"EVP & GM of Live! Casino & Hotel **Louisiana**" release is served from that same
Philadelphia globalnews path — and who was likewise labeled Philadelphia.

Nothing downstream could catch it: Clay derived `@livech.com` addresses that validated
clean (BounceBan 98/deliverable). **`livech.com` is the chain-wide Cordish domain** —
Maryland, Philadelphia, Pittsburgh, Louisiana, and Virginia staff all share it, so a
valid address carries zero property signal.

## Corrections applied (EB lead records + 22 CSVs, 92 row-fixes)

| lead_id | role | was | now | confidence |
|---|---|---|---|---|
| 320838 | EVP & General Manager | Philadelphia / PA | **Maryland** / Hanover MD | confirmed |
| 320822 | VP Facility Operations | Philadelphia / PA | **Maryland** / Hanover MD | confirmed |
| 320746 | EVP & General Manager | Philadelphia / PA | **Louisiana** / Bossier City LA | confirmed |
| 284564 | VP Marketing | Maryland / Chesapeake VA | **Virginia** / Petersburg VA | confirmed (changed roles) |
| 248795 | VP Slots | Philadelphia / MD | Philadelphia / **PA** | confirmed |
| 248916 | VP Gaming Operations | Pittsburgh / MD | Pittsburgh / **PA** | confirmed |
| 320851 | VP Food & Beverage | Philadelphia / PA | **Maryland** / Hanover MD | likely |
| 284256 | Senior Marketing Manager | Maryland / Philadelphia PA | Maryland / **Hanover MD** | likely |
| 284378 | SVP Marketing Analytics | (already correct) | Maryland / Hanover MD | confirmed |

**UNRESOLVED — lead 248813 (SVP Property Operations).** Property not named by any
source. Maryland's SVP Property Ops was announced separately in Oct 2024, which argues
this lead sits elsewhere. Left as Philadelphia. Verify before the next touch.

## Sends stopped (campaign 185)

`POST /api/campaigns/185/leads/stop-future-emails` for the five Maryland contacts —
same office as a live conversation, per the audit's WARM_FOLLOWUP → drop-same-office
rule:

- 320838 (follow-up was due Aug 21 15:38 UTC)
- 284378 (**cold step 1** was due Aug 24 21:06 UTC)
- 320822 (follow-up Aug 22 00:07 UTC)
- 320851 (follow-up Aug 21 15:49 UTC)
- 284256 (unscheduled, now blocked)

Left running as sibling properties: 320746 (LA), 320768 (Philadelphia), 248795
(Philadelphia), 248916 (Pittsburgh), 284564 (Virginia).

## Still unverified

`FOUND-people.csv` holds six more Live! contacts all tagged Philadelphia from the same
scrape path. None are in an active campaign. Treat their property labels as unverified.
