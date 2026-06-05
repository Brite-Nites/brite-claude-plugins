---
name: prospect-temporal-gate
description: Enforces the Brite Labs 2-cycle/year + 180-day non-repeat hard rule by querying EB workspaces 55+13 plus SF Activity history and emitting a suppression-aware filtered prospect list. Runs as a mandatory pre-enrichment gate inside list-building Workflow 2. Triggers "temporal gate", "180-day check", "non-repeat enforcement", "cycle dedup", "outreach recency suppression".
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Bash, Glob, Grep
metadata:
  version: 0.1.0
  category: Outbound Lead Gen
  status: DRAFT — proposed by 2026-05-15 planning session, awaiting Holden review (BC-10190)
---

# Prospect Temporal Gate

> **DRAFT — pending Holden review.** This skill encodes the 2-cycle/year + 180-day non-repeat hard rule that's currently enforced only in operator memory. See [BC-10190](https://linear.app/brite-nites/issue/BC-10190) for the parent issue. Do not register in plugin marketplace until reviewed.

A list-builder running net-new outreach has FOUR failure modes around outreach recency, tiering, and seasonality:

1. **Silent re-touch within 180 days** — prospect was on M4 Botanical Gardens list, ends up on M8 Botanical Gardens list under a different campaign name. Hurts reply rate AND sender reputation.
2. **Same-org-same-persona re-touch dressed as "different offer"** — Universities M2 academic-affairs send + M7 academic-affairs send under a renamed offer = same human, same year, same buyer-worldview. The 2-cycle rule was designed for this case and it must be machine-enforced.
3. **Enterprise-commercial post-Q2 send** — locked corporate fiscal budgets mean post-Q2 outreach to large commercial enterprises (per [campaign-rules.md § enterprise-commercial-post-Q2](../../../../handbook/marketing/go-to-market/campaign-rules.md)) is a guaranteed waste of sender heat. Cutoff is **June 30** (end of Q2). Affected: Corporate Campuses (F1000), Shopping Centers (REITs), chain-corporate Hotels/Casinos/Bars/Restaurants/Theme Parks. **NOT affected:** Sports Stadiums (multi-year procurement cycles make post-Q2 the correct FY27-capex window) and Auto Dealerships (SMB tier, not enterprise FP&A) — both stay year-round eligible.
4. **Tier-1 campaign launched post-Q2** — Brite Labs revenue is install-driven, and Tier-1 campaigns require Q1-Q2 launch to capture either summer (Jun-Sep) or Q4 holiday (Nov-Dec) install seasons. Any Tier-1 offer scheduled for M7-M12 is a planning error; the skill refuses to pass them.

This skill is the third option — it runs after ICP-scoring and BEFORE enrichment (to save credits), queries EB workspaces 55 + 13 + SF Activity history for any past-touch of every candidate prospect within the lookback window, enforces the enterprise-commercial-post-Q2 and Tier-1-Q1-Q2 hard rules, and emits a filtered CSV plus a suppression report. Failure of this gate halts the launch — it is NOT advisory.

---

## Before Starting

**Check for marketing context first.** If `docs/marketing-context.md` does not exist, halt with: "Marketing context doc not found. Run `/marketing:product-marketing-context` first — the temporal gate requires entity (Nites/Supply/Labs) to resolve which EB workspaces and SF org to query."

### Input

Single canonical input: a candidate prospect CSV with at minimum `email` + `domain` + `company_name` columns. Typically this is the output of `icp-scoring` (pre-enrichment).

### Invocation flags

| Flag | Default | Notes |
|---|---|---|
| `--input-csv <path>` | (required) | Candidate prospect CSV. Required columns: `email`, `domain`, `company_name`. |
| `--lookback-days N` | 180 | Window for the non-repeat check. Maps directly to the 2-cycle/year hard rule. |
| `--early-warning-days N` | 90 | Borderline window — flagged as warning, not suppressed. Useful when planning campaigns close to the 180-day floor. |
| `--same-org-different-persona` | (off) | Permits new individuals at a `domain` where prior individuals were contacted. Use when M(N+k) targets a deliberately different buying committee at same orgs (see Universities M7, Botanical Gardens M8, Zoos M8 patterns from 2026-05 plan). |
| `--vertical <slug>` | (required) | Vertical slug — resolves to a vertical-specific exception policy if one exists at `handbook/marketing/go-to-market/verticals/<slug>/exceptions.md`. |
| `--entity <Nites\|Supply\|Labs>` | (read from marketing-context.md) | Determines which EB workspaces to query (Labs = 55+13; Nites = 13 only; Supply = TBD per S4 program scope). |
| `--enterprise-commercial-filter` | (auto) | Enables the [no-enterprise-commercial-post-Q2](../../../../handbook/marketing/go-to-market/campaign-rules.md#no-enterprise-commercial-post-q2) rule. **AUTO-ENABLED when `current_month > June` AND vertical resolves to enterprise-commercial category in handbook.** Override with `--enterprise-commercial-filter=off` only with `--override-reason=<text>` written to the suppression report. |
| `--tier-1-window-check` | (auto, hard-coded) | Enforces the Tier-1-Q1-Q2 rule. **CANNOT BE DISABLED.** Halts the launch if the campaign's offer has `tier: 1` frontmatter in the handbook offer page AND the send month is M7-M12. |
| `--output-dir <path>` | `docs/research/lists/<entity>-<YYYY-MM-DD>/temporal-gate/` | Where filtered.csv and suppression-report.md land. |
| `--dry-run` | (off) | Don't write output files; emit summary to stdout for review. |

---

## Methodology

### Phase 1 — Resolve entity + lookback config

1. Read `docs/marketing-context.md` to determine entity. Halt if missing.
2. Resolve EB workspaces:
   - **Brite Labs:** workspaces 55 (`Brite Nites`/B2B) + 13 (`BriteNites Team`/personal)
   - **Brite Nites:** workspace 13 only (residential personal)
   - **Brite Supply:** TBD — pending S4-program EB workspace decision (flag for Holden if S4 entity passed)
3. Resolve SF org via `mcp__plugin_marketing_salesforce__*` (production org per CDR-XXX).
4. Compute the cutoff date: `today() - lookback_days`.

### Phase 2 — Build the candidate-domain map

Read input CSV via `Read`. Build:
- `candidate_emails`: set of `email` values
- `candidate_domains`: set of `domain` values
- `candidate_companies`: map of `domain → company_name`

### Phase 3 — Query EB workspaces (parallel)

For each resolved workspace, fetch all leads contacted within `lookback_days`:

- `mcp__emailbison-b2b__call_api` endpoint `/api/leads` with filter for `total_leads_contacted_count > 0` AND `updated_at >= cutoff_date`
- `mcp__emailbison-personal__call_api` same shape, workspace 13
- Paginate to completion; cache per-workspace results

For each EB lead record, extract `email`, `company_domain`, `last_contacted_at`, `campaign_id`, `campaign_name`. Build `eb_history_index` keyed by email AND domain.

### Phase 4 — Query SF Activity history

Run SOQL:

```sql
SELECT Id, WhoId, Who.Email, Who.Account.Website, ActivityDate, Subject, Type
FROM Task
WHERE ActivityDate >= :cutoff_date
  AND (Type = 'Email' OR Type = 'Outbound' OR Type = 'Sequence')
ORDER BY ActivityDate DESC
LIMIT 50000
```

(Adjust LIMIT + paginate if 50k cap reached.) Build `sf_history_index` keyed by email AND account-website-domain.

### Phase 5 — Apply suppression logic

For each candidate row:

1. **Email-level match** → suppress (any prior touch in lookback window blocks this exact email).
2. **Domain-level match WITHOUT `--same-org-different-persona`** → suppress (the whole org is in cooldown).
3. **Domain-level match WITH `--same-org-different-persona`** → keep but flag with `same_org_new_persona = true` for audit.
4. **Bounce history** — if email is in any prior campaign's `bounced` set, suppress permanently (never re-attempt).
5. **Enterprise-commercial filter (auto-enabled when `current_month > 6` AND vertical ∈ enterprise-commercial set)** — suppress entire list (next-FY conversation only). Hard rule; override requires `--override-reason` written to suppression report for audit.
6. **Tier-1 window check (cannot be disabled)** — if the campaign's offer has `tier: 1` frontmatter AND `send_month > 6`, HALT with planning-error message. Reschedule to Q1-Q2 next FY or downgrade offer to Tier-2 (which requires offer-page edit and rationale).
7. **Borderline early-window (days_since_last_touch ∈ [early_warning_days, lookback_days])** → keep but flag with `borderline_2_cycle = true` for operator review.

### Phase 6 — Emit outputs

Write:

1. `<output-dir>/filtered.csv` — survivors only, with `same_org_new_persona` and `borderline_2_cycle` flag columns appended.
2. `<output-dir>/suppression-report.md` — markdown report containing:
   - Counts: input rows, EB-suppressed (per workspace), SF-suppressed, bounce-suppressed, enterprise-commercial-suppressed, borderline-flagged, survivors.
   - Top 10 most-recent past-touch dates per suppressed prospect (for audit).
   - Recommended next-touchable date for high-value suppressed prospects (today + 180 — most_recent_touch).
3. `<output-dir>/temporal-gate-confidence.json` — machine-readable summary for downstream `list-building`:
   ```json
   {
     "input_count": 0,
     "survivor_count": 0,
     "suppression_rate": 0.0,
     "borderline_count": 0,
     "borderline_rate": 0.0,
     "halt_recommended": false
   }
   ```

### Phase 7 — Halt gates

This skill HALTS the launch (returns non-zero exit) when:

- `survivor_count == 0` (the campaign has no eligible prospects)
- `suppression_rate > 0.80` (>80% suppressed → upstream list quality is broken, not a temporal issue; operator must rebuild list)
- `borderline_rate > 0.50` AND `--same-org-different-persona` is off (you're trying to send to a vertical you just hit; operator must justify with the flag OR reschedule the campaign)
- **Enterprise-commercial filter triggered** AND no `--override-reason` provided (post-Q2 enterprise-commercial sends require explicit operator override + written rationale per Rule 1)
- **Tier-1 window violation** — offer is `tier: 1` AND `send_month > June` (cannot be overridden — Rule 2 is unconditional; reschedule or downgrade offer tier with explicit edit to offer page)

Halt messages quote the exact `BC-10190` rule + a `next-touchable-date` recommendation. Tier-1 violations additionally quote the offer-page path and require the operator to either reschedule to Q1-Q2 of next FY OR edit the offer's `tier:` frontmatter (which is a separate handbook PR with rationale).

---

## Per-vertical exception policy

A vertical's handbook page may declare a custom exception at `handbook/marketing/go-to-market/verticals/<slug>/exceptions.md` with frontmatter:

```yaml
---
exception_id: <kebab-slug>
applies_to: <vertical-slug>
lookback_override_days: <int>  # optional
same_org_different_persona_auto: <bool>  # optional
reason: |
  Why this vertical needs a custom rule. Cite the data.
expires: <YYYY-MM-DD>  # optional but recommended
---
```

The skill reads these per-vertical exception files and applies overrides only when explicitly declared. Default behavior is conservative — the global 180-day rule wins unless a vertical has a published exception.

**Example use case:** Municipalities 250th send had a calendar-forced 90-day exception in [BC-10175](https://linear.app/brite-nites/issue/BC-10175) (M3 → M6 send because 250th cannot ship in July). This would live as `verticals/municipalities/exceptions.md` with `lookback_override_days: 90` and `expires: 2026-07-01`.

---

## Integration: where this skill lives in the pipeline

```
tam-mapping output  →  icp-scoring  →  PROSPECT-TEMPORAL-GATE  →  enrichment  →  SMTP verify  →  EB campaign launch
```

It is the second-to-last gate before enrichment spend, which is the right place — credits aren't wasted on prospects we're not allowed to contact.

**Caller integration:**

- `list-building` Workflow 2 must invoke this skill after the existing cross-workspace EB exclusion (which is a coarser lifetime-suppression check) and before enrichment provider dispatch.
- `launch-campaign` Phase 1 (pre-flight) must verify `temporal-gate-confidence.json` exists for the prospect list and `halt_recommended: false`. Refuses activation otherwise.

---

## Acceptance criteria (for shipping v0.1)

- [ ] EB MCP queries against workspaces 55 + 13 return full lookback-window history in parallel
- [ ] SF MCP SOQL Activity query paginated and joined correctly
- [ ] Suppression report includes per-source counts + actionable next-touchable dates
- [ ] `--same-org-different-persona` flag works against `company_domain` (case-insensitive, www-stripped)
- [ ] Per-vertical exception files parsed and applied correctly
- [ ] Halt gates fire correctly on the 3 conditions
- [ ] `dry-run` produces stdout summary identical to file outputs
- [ ] Test fixtures: 4 vertical scenarios — net-new (Wineries M6), 180-day-blocked (Botanical Gardens M8 with `--same-org-different-persona` off should suppress; with flag on should keep new personas), borderline 150-day, exception-active (Municipalities 250th)

---

## Known gotchas (DRAFT — fill in during implementation)

- **EB `total_leads_contacted_count`** is per-sender, not per-campaign. Need to verify the `updated_at` field is the last-contact date, not last-status-change date. Test against a known recent send.
- **SF Activity Subject lines** are inconsistent (some campaigns set `Subject = campaign_name`, some don't). Type filter is more reliable than Subject-string match.
- **Bounced emails** sometimes resurface in EB if the sender pool was rotated and the new sender hasn't seen the bounce. Bounce suppression must aggregate across ALL workspace senders, not just per-campaign.
- **Personal workspace (13)** lead schema may differ from B2B workspace (55) — needs verification during scaffold.

---

## Related

- [BC-10190](https://linear.app/brite-nites/issue/BC-10190) — parent issue, full spec context
- [BC-2717](https://linear.app/brite-nites/issue/BC-2717) — `list-building` skill, this skill plugs into its Workflow 2
- [BC-10191](https://linear.app/brite-nites/issue/BC-10191) — `offer-catalog` skill, reuses this skill's EB-history reader
- Memory: project_two_cycle_outreach_rule, feedback_two_send_max_rule, feedback_no_enterprise_commercial_post_q1
- Handbook: `handbook/marketing/go-to-market/campaign-rules.md` (TO BE CREATED — see [BC-10192](https://linear.app/brite-nites/issue/BC-10192) `campaign-calendar` issue for the consolidated rules doc spec)
