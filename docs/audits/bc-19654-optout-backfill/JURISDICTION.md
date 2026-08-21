# BC-19654 — jurisdiction check

Run 2026-08-21 because the domain-vs-address rule rests on CAN-SPAM, which is opt-out-based and
**address-scoped**. CASL (Canada) and GDPR/PECR (EU/UK) are consent-based and materially stricter,
so a single non-US recipient in the queue would change the standard.

## Result: no non-US recipients in the actionable set

Six senders tripped a non-US signal. All six resolve to US entities:

| Sender | Signal | Actually |
| --- | --- | --- |
| `<person>@edwardjones.com` | CA place name | Out-of-office. US (301 = MD). |
| `<person>@edwardjones.com` | CA place name | Out-of-office. US. |
| `<person>@edwardjones.com` | CA place name | Out-of-office. US (941 = FL, CST). |
| `<person>@calvary.ch` | `.ch` ccTLD | **`.ch` used as a vanity TLD for "church"**, not Switzerland. Calvary Bellevue, 402 = Nebraska. |
| `<person>@realgreece.com` | intl phone | Chicago IL, +1-312. US travel agency selling Greek holidays; Greek mobile is secondary. |
| `<person>@eetgrp.com` | intl phone | Edinburgh, Scotland — but already excluded as *not an opt-out*. |

CAN-SPAM is therefore the governing standard: the opt-out obligation attaches to the address that
made the request, and domain-level suppression is a business choice above the legal floor, not a
requirement. The practical driver is spam-complaint and deliverability risk, not regulatory risk.

## Method warning — a false zero I nearly shipped

The first pass reported **zero** Canadian and zero international-phone matches. That was wrong.
Snowflake `REGEXP_LIKE` anchors to the whole string, and without the **`s`** flag `.` does not match
newlines — so `.*pattern.*` silently fails on every multi-line email signature.

The tell was that "Ontario" appeared **zero** times in 166,028 replies. Re-run with `'is'`/`'cs'`:

| Signal | without `s` | with `s` |
| --- | --- | --- |
| CA postal code | 1 | 1,399 |
| CA province / city | 0 | 15 |
| intl phone code | 0 | 28 |

**Every regex in this audit that scans a reply body must carry the `s` flag.** Validate any
silently-failable detector against a known positive before trusting a negative.

## Side finding: auto-reply false positives in the queue

**23 of 277** actionable senders need re-reading before they are actioned:

| Class | Senders |
| --- | --- |
| Every reply from them is automated | 22 |
| Out-of-office / "currently closed" language | 10 |
| Carries a **corporate unsubscribe footer** — e.g. *"If you do not wish to receive any email messages from Edward Jones…"* | 3 |
| Union (needs re-read) | **23** |

The corporate-footer class is new and distinct from the marketing-footer class already catalogued:
it is a company's own compliance boilerplate on an out-of-office reply, matching our opt-out regex.

**Automated does not mean drop.** `<person>@taubman.com` is an auto-reply that reads *"This user email
is no longer being monitored. Please remove this email address from all communications."* — a
genuine, actionable removal request. These 23 need eyes, not a blanket rule.
