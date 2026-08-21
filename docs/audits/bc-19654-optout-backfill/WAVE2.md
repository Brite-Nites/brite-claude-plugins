# BC-19654 wave 2 — two reviewed domains

Executed 2026-08-21, after operator review of the 7 held-back domains. Two approved; the
remaining five are still open.

| Domain | Addrs | Basis |
| --- | --- | --- |
| `thebridgesrsf.com` | 8 | the COO / Club GM, **COO / Club GM** — *"Please remove us from all further solicitations."* Authoritative signer, total scope. |
| `bede.org` | 13 | *"please remove us from your email and mailing lists."* Single organisation, plural lists. |

## Result

- Both domains blocked on **both** instances (4 × HTTP 201).
- **21 / 21** leads unsubscribed, all HTTP 200. Zero remain `in_sequence` or `not_started`.
- b2b domain blocklist 60 → **62**; personal 44 → **46**.

## Wave 1 residual — closed

`<person>@hotelwalloon.com` (lead 321041) was the one lead left `in_sequence` in active campaign 177,
un-unsubscribable because the endpoint 422s on leads with no prior send. The operator stopped her
sequence manually; the lead now reads `camp 177 -> stopped`. No open exposure remains from wave 1.

The underlying API limitation still stands and is worth designing around: a queued-but-never-sent
lead cannot be unsubscribed via the API and has no detach endpoint, so clearing it requires either
a UI action or a domain blocklist entry to backstop the send.

## Still open — 5 domains / 167 addresses

| Domain | Addrs | Why it was held |
| --- | --- | --- |
| `imperialcars.com` | 98 | *"Remove us from your email list."* One dealership campus, but the largest domain in the set. |
| `theindigoroad.com` | 36 | GM signs for **three named restaurants**, not the whole Indigo Road group. |
| `commonhouse.com` | 16 | Sender is the **Charlottesville** concierge; the club has several city locations. |
| `bhglex.com` | 14 | Director of **Drake's** marketing — one brand inside Bluegrass Hospitality Group. |
| `penrosebar.com` | 3 | Opted out 2025-10-10, then **re-engaged 2026-05-23** with a genuine question. A block would cut off a live conversation. |

The common thread on the middle three: **"us" is scoped to whatever the speaker represents.** A
location manager or single-brand marketer may mean their site, not the registered domain.
