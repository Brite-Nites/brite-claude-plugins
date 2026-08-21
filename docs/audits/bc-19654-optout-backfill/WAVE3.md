# BC-19654 wave 3 — the five reviewed domains

Worked one at a time with the operator, 2026-08-21. Four blocked, one deliberately left alone.

## Decisions

| Domain | Addrs | Decision | Reasoning |
| --- | --- | --- | --- |
| `imperialcars.com` | 98 | **domain block** | *"Remove us from your email list."* Since that request we sent **97 more emails to 50 different people**, through 2026-06-09. One dealership campus, not an enterprise. 0 SF opportunities. |
| `theindigoroad.com` | 36 | **domain block** | GM of three named venues wrote *"Remove us from your list"*. 3 of the 4 replies were machine noise (an NDR + two OOOs). 26 further emails to 16 people since. 0 engagement, 0 opportunities. |
| `commonhouse.com` | 16 | **domain block** | Weakest-authority opt-out in the set — an unnamed concierge desk at 1 of 5 cities. But 20 further emails to 14 people, 11 replies, **0 marked interested**, 0 opportunities. |
| `bhglex.com` | 14 | **domain block** | Director of *Drake's* marketing (one brand inside Bluegrass Hospitality). Only 2 replies ever — hers and a retirement auto-reply. 26 emails, 0 engagement, no SF account at all. |
| `penrosebar.com` | 3 | **left alone** | See below. |

## Why `penrosebar.com` was not blocked

Their October message was explicitly **temporary**: *"We will definitely keep your information for the
future, if we ever decide to jump on board. Kindly take us off your list **in the meantime**."*

Seven months later, unprompted, they came back:

> *"Not sure I understand the question here — are you interested in booking an event with us, or are
> you with a company that does decorating?"* — 2026-05-23

**Both replies have `is_read = false`.** That sales question has sat unopened for three months.
Blocking the domain would bury a live lead. This needs a reply, not a suppression — routed to
whoever works inbound.

Root cause is identical to the Karol Hotel case that opened BC-19654: the reply landed in the EB
inbox and nobody read it. Karol's opt-out went unread for nine months; Penrose's *sales question*
for three. **The failure is not classification, it is that nothing reads the inbox.**

## Operating principle the operator set

> "If it's borderline, the upside of keeping it in is not worth the downside."

Applied to `commonhouse.com` and `bhglex.com`, where the speaker's authority was genuinely
ambiguous but the account showed zero engagement. It does **not** apply where the upside is
concrete rather than hypothetical — `penrosebar.com` had a named prospect with an open question, so
the principle pointed the other way.

## Result

- 4 domains blocked on both instances (8 × HTTP 201), all verified live by direct fetch.
- `penrosebar.com` confirmed **absent** from both blocklists (404 on both) — intentional.
- Leads unsubscribed: imperialcars 50/98, theindigoroad 27/36, commonhouse 16/16, bhglex 14/14.
- Every 422 was the known "never been sent an email" case; **none** of them sit in a live campaign.
- b2b domain blocklist → **66**; personal → **50**.

## Running total for BC-19654

| | |
| --- | --- |
| Domains blocked | **49** |
| Addresses covered | ~330 |
| Waves | 1 (43 domains) · 2 (2) · 3 (4) |
| Deliberately not blocked | `penrosebar.com` |
