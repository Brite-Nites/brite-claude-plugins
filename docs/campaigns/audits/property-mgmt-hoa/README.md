# Property-Management / HOA campaign audit

**Run:** 2026-07-26 · **Recency cutoff:** 60 days → anyone emailed on/after **2026-05-24** is held out.
**Scope:** Community Management (HOA / community-association mgmt) + Apartments (multifamily). Shopping Centers excluded per operator.

## Campaigns audited (13)

| Vertical | Camp | Name | Last sent |
|---|---|---|---|
| Community Mgmt | b2b/7 | FY25 M09 · Managers+ | 2025-10-14 |
| Community Mgmt | b2b/42 | FY25 M11 · Professional | 2025-12-02 |
| Community Mgmt | b2b/51 | FY26 M02 · Professional | 2026-05-13 |
| Community Mgmt | personal/17 | FY25 M11 · Personal | never sent (0 leads) |
| Apartments | b2b/37 | FY25 M11 · Managers+ | 2025-11-27 |
| Apartments | b2b/38 | FY25 M11 · Role | 2025-11-19 |
| Apartments | b2b/70 | FY26 M04 · Professional | **still sending** |
| Apartments | b2b/114 | FY26 M07 · SMTP | 2026-06-25 |
| Apartments | b2b/122 | FY26 M07 · Google | 2026-06-24 |
| Apartments | b2b/123 | FY26 M07 · Microsoft | 2026-06-25 |
| Apartments | b2b/148 | FY26 M07 · Re-verified Microsoft | 2026-07-14 |
| Apartments | b2b/149 | FY26 M07 · Re-verified SMTP | 2026-07-10 |
| Apartments | personal/15 | FY25 M11 · Personal | 2025-11 |

## Result — 20,574 unique contacts

| File | Rows | Meaning |
|---|---|---|
| `ELIGIBLE-for-new-campaign.csv` | **14,552** | All clean-to-re-mail contacts (6,095 orgs). Master eligible list. |
| `ELIGIBLE-by-company.csv` | 6,095 | One row per organization, account-tier + contact count. Planning view. |
| `HOLD-route-to-sales.csv` | 112 | Positive / interested repliers — warm, hand to sales, don't cold-mail. |
| `SUPPRESSED.csv` | 5,910 | Excluded, with a reason per row. |
| `AUDIT-all-contacts.csv` | 20,574 | Everyone + verdict + all flags + evidence. |

### Launch segments (ELIGIBLE split by account size)

The eligible 14,552 splits into two populations you pitch differently. Cutoff: an org with **≤5 eligible contacts** = safe to cold-blast; **6+** = treat as an account.

| File | Contacts | Orgs | Use |
|---|---|---|---|
| `SEGMENT-A-safe-to-blast.csv` | **7,678** | 5,715 | Single-site + small firms. Launch a normal cold campaign now. |
| ↳ `SEGMENT-A-Apartments.csv` | 4,593 | — | Apartments offer |
| ↳ `SEGMENT-A-HOA-CommunityMgmt.csv` | 3,081 | — | HOA offer |
| `SEGMENT-B-big-accounts-portfolio.csv` | 6,874 | 380 | Top firms (Asset Living, Greystar, Associa…). **Don't blast** — pitch a multi-property portfolio program to a chosen few per firm, or throttle sends per domain. `account_domain` / `account_size` columns group them. |

### Why the 5,910 were suppressed (highest-precedence reason)

| Reason | Count | Rule |
|---|---|---|
| RECENT | 4,320 | Emailed on/after 2026-05-24 (all M07 apartment sends + camp 70 in-flight). |
| BOUNCED | 851 | Hard/soft bounce, incl. DSN failures that landed in the inbox. |
| LEFT_COMPANY | 306 | Person gone, or mailbox dead / redirected / org changed hands. |
| BLOCKLIST | 206 | On an EB blocklist (email or domain), either workspace. |
| REPLIED_UNCLEAR | 81 | Human reply that isn't clearly yes/no — held out to be safe. |
| SAID_NO_SOFT | 53 | Situational no ("vendor in place this year", "try next year"). |
| OPT_OUT | 35 | Explicit unsubscribe / do-not-contact / "remove me". |
| SAID_NO_HARD | 26 | Structural no (in-house, no budget, don't decorate). |
| JUNK | 22 | Phishing / doc-share spam / newsletter blasts — compromised senders. |
| WRONG_PERSON | 10 | Valid company, wrong contact (routed us elsewhere). |

## Method

1. Pulled every lead-slot from all 13 campaigns via `/api/campaigns/{id}/leads` (per_page hard-capped at 15 → paged concurrently). 38,113 slots → 20,574 unique emails.
2. Pulled per-campaign replies (`/api/campaigns/{id}/replies`, 3,432 records) and both workspaces' blocklists.
3. Recency: campaign-level send windows, plus per-lead send dates for the two campaigns straddling the cutoff (51, 70).
4. Classified every reply into buckets (opt-out / bounced / left / no / positive / wrong-person / junk / auto-only). Rule-based first, then hand-read the 327 replies the rules couldn't resolve; hand-overrides live in `FORCE` in `build_list.py`.
5. Applied suppression by precedence. **Verified: 0 disqualified contacts leaked into ELIGIBLE**, and every reply attached to an eligible contact is either our own outbound or a benign out-of-office.

## Caveats

- **De-dup at import.** ELIGIBLE is unique by email, but if you're loading into a workspace that already holds these leads, run the usual EB overlap/blocklist check — blocklists are instance-relative.
- **Not opens.** Open-tracking is off on these campaigns, so "engagement" = replies only.
- **Reply-body classification is best-effort.** 81 genuinely ambiguous human replies were parked in SUPPRESSED (REPLIED_UNCLEAR) rather than risk mailing someone who objected. Review that slice if you want to reclaim any.
- Regenerate anytime: `python3 build_list.py` (reads the raw JSON pulls in the scratchpad).
