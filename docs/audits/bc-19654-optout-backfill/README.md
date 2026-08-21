# BC-19654 — Karol Hotel opt-out back-fill (first case)

Actioned 2026-08-21. This is the trigger case from the issue, worked end to end as a
template for the remaining back-fill.

## The opt-out

**Reply 48487**, ws55, `2025-11-04T22:30:24Z`, subject `Re: dec programs`.

> "Jessica is no longer with the company. **Please remove The Karol Hotel from email
> distribution list.** Thank you — the Director of Sales, Director of Sales | The Karol Hotel"

Sent **from** `<person>@thekarolhotel.com`, **written by** the Director of Sales (`from_name`
on the reply is "the Director of Sales" — she has delegate access to the departed employee's
mailbox).

### Human, not an auto-reply

- `automated_reply = false` (heuristic — not relied on alone)
- **~27h latency**: original sent Mon 2025-11-03 14:54, reply stamped 2025-11-04 17:30 ET.
  Autoresponders fire in seconds. This is the decisive signal.
- `from_name` (the Director of Sales) differs from the mailbox owner (a departed employee) — an OOO
  or system notice carries the owner's name.
- Personal signature block with her own direct office + cell.
- Two separate speech acts: a departure notice *and* an independent company-wide removal
  request. A departure autoresponder routes you to a successor; it does not opt a company out.
- Correctly threaded, quoting the original with intact headers.

## Corrections to the issue body

1. **Date and attribution.** The issue says mpavlik replied to campaign #60 in April 2026.
   The actual opt-out is 2025-11-04 from jsaldivar@'s mailbox. The "April 2026" almost
   certainly comes from the SF Contact created date (OutboundSync mirroring our own cold
   sends) and/or the 2026-04-03 blocklist entry for jsaldivar@ — not from a reply.
2. **It was partially actioned in April 2026, not ignored.** `jsaldivar@` was blocklisted
   2026-04-03. Someone read the request and blocklisted **the address that sent it**. The
   request named the company; the action covered one mailbox — and that mailbox belonged to
   a departed employee nobody reads. Michele and Conary stayed mailable another 4.5 months.

## Root cause

`read = false` on reply 48487. It sat unopened in the EB inbox from November 2025.
The failure was not misclassification — nothing was watching the inbox.

## Actions taken (2026-08-21)

| Action | ws55 (send.outbase.so) | ws13 (personal.outbase.so) |
| --- | --- | --- |
| Domain blocklist `thekarolhotel.com` | added (id 18) | added (id 1) |
| Email blocklist — 6 addresses | 4 added, 2 pre-existing | 5 added, 1 pre-existing |
| Lead unsubscribe | 5 PATCHed, 1 already unsubscribed | n/a (no leads at domain) |

Per-address decisions: `triage-decisions.csv`.

**Verified end state (ws55):** all 6 leads `status = unsubscribed`; campaign 177 moved
`in_sequence → unsubscribed` for `cbullard@`; nothing `in_sequence` anywhere.

ws13 had zero leads at this domain — the domain + email blocks there are pre-emptive, so a
future list build can't reintroduce them.

## Method notes for the remaining back-fill

**`/api/blacklisted-emails?search=` returns false zeros.** Searching `thekarolhotel.com`
returned `total: 0` while `mpavlik@` (id 571) and `jsaldivar@` (id 193) were both on the
list. `GET /api/blacklisted-emails/{email}` resolves them correctly. **This endpoint is
distinct from `/api/leads?search=`, which fails the other way — a no-match dumps the whole
workspace.** Two opposite failure modes, both HTTP 200.

Consequence for the issue's headline metric: if the "407 not on the blocklist" figure was
derived by comparing against a search-based blocklist lookup, it is **overstated**. Recompute
against a full blocklist dump via cursor pagination before treating 407 as the work queue.

**Key back-fill rule this case establishes:** when the reply text names the organisation
("remove The Karol Hotel"), suppress at the **domain**, not the sending address. The sender
is frequently not the person opting out — here it was a departed employee's mailbox — and
sender-keyed suppression is exactly what failed in April.

**Idempotency:** `POST /api/blacklisted-emails` returns 422 on an address already present.
Safe to re-run; treat 422 as "already covered" after confirming via
`GET /api/blacklisted-emails/{email}`.

**Bulk endpoints** (`/bulk`) exist for both emails and domains but carry `requestBody: null`
in the API spec — payload shape undocumented. Singular endpoint used here.

## Salesforce check

Account `The Karol Hotel` (`001a500002Jj6LRAAZ`), 2 Contacts (both created April 2026 by
OutboundSync), **0 Opportunities**. No relationship to protect — Contact-exists is not a
suppression signal, Opportunity is.

Open loose end: `mpavlik@` sent two replies on 2026-07-13 reading "Good morning, Please see
attached for your review", with attachments and no campaign attached. With no Opportunity
behind them, read as misdirected or forwarded mail rather than re-engagement. Recorded, not
resolved.
