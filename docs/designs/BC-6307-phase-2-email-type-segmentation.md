# Design: BC-6307 — Phase 2 email-type detection

**Issue:** BC-6307 (parent: BC-5906)
**Date:** 2026-04-30

## Problem

`/marketing:launch-campaign` Phase 2 segments leads by ESP only. Role addresses (`info@`, `sales@`, etc.) and personal-domain addresses (`@gmail.com`, etc.) get sent to alongside professional B2B targets, hurting deliverability and engagement. Brite's data-platform enrichment pipeline already classifies these via BounceBan, but launch-campaign doesn't yet read or replicate that classification.

## Approach

Add an email-type detection step that runs **before** the existing ESP detection in Phase 2. Two static lists (role prefixes, free-mail domains) baked into the spec — no DNS lookup, no API call. Per-lead tag of `professional` / `role` / `personal`. Operator sees counts at user gate 2; default action skips role + personal. Surviving leads continue into the existing ESP detection unchanged.

The detection block is structured as two predicates — `is_role(email)` and `is_free(email)` — returning the same boolean shape that BounceBan returns, so the future brite-enrichment-MCP swap (BC-5538) is an internals-only change. **This naming choice is the only forward-reference to BounceBan; no BounceBan API call is made in this PR.**

### Structural mirror of existing ESP detection

| Step | ESP detection (existing) | Email-type detection (new) |
|---|---|---|
| 1. Get input | Read CSV, extract domains | Read CSV, extract emails |
| 2. Filter | Drop malformed domains via regex | Reuses Phase 1 valid-domain check |
| 3. Classify | `dig MX` → pattern-match against ESP patterns | Match local-part against role list, match domain against free-mail list |
| 4. Bucket label | `Google` / `Microsoft` / `Other` | `professional` / `role` / `personal` |
| 5. Aggregate counts | `esp_segments: {Google: 84, Other: 12}` | `email_type_segments: {professional: 88, role: 3, personal: 9}` |
| 6. Operator gate | "Approve / Disable / Abort" | "Apply default skip / Include all / Abort" |
| 7. Metadata write | `esp_segments` + `last_completed_phase` | `email_type_segments` + sidecar log path |

## Key Decisions

1. **Heuristics now, BounceBan-shaped swap point.** Static lists ship in this PR; predicate signature returns `is_role` / `is_free` booleans matching what BounceBan would return. *Why:* BC-5536/5537/5538 (production enrichment MCP) hasn't started; can't block BC-6307 on it. Future swap touches only the predicate bodies — every consumer of the booleans keeps working.
2. **Email-type runs BEFORE ESP detection.** Filter first; ESP-detect on the smaller surviving set. *Why:* avoids DNS lookups on dropped leads; combined gate-2 summary; existing skip-empty-buckets logic naturally handles the no-survivors case.
3. **Default action: skip role + skip personal.** Operator override at gate 2. *Why:* matches tam-mapping's Operational rule 1 policy.
4. **Personal beats role on tiebreak** (`sales@gmail.com` → `personal`). *Why:* dominant signal is the free-mail domain; aligns with operator-override semantics — if the operator ever opts to "include role but skip personal," this lead correctly follows the personal rule.
5. **Skipped leads → sidecar CSV** named `{campaign-name}-{date}-skipped.csv` with original CSV columns plus a `skip_reason` column (`role_address` / `personal_domain`). *Why:* no silent data loss; auditable post-run.
6. **Reciprocal "Keep in sync" annotation** between launch-campaign Phase 2 and tam-mapping Operational rule 1. *Why:* BC-2717 task-3 precedent (2nd surface, near 3rd-promotion threshold). Both sides annotate.

### Role-prefix list (19 entries)

`info`, `sales`, `contact`, `support`, `hello`, `team`, `office`, `admin`, `help`, `service`, `general`, `feedback`, `enquiries`, `inquiry`, `inquiries`, `pr`, `press`, `partnerships`, `partners`

Match is exact + case-insensitive on the local-part. List focuses on generic shared inboxes that genuinely appear in B2B CSVs and aren't a fit as cold-outreach targets.

**Intentionally excluded (decided at plan refinement):**
- Back-office department names (`accounting`, `accountspayable`, `ap`, `billing`, `accounts`, `legal`) — never Brite buyers; clean list-building shouldn't produce these
- HR / talent (`hr`, `recruiting`, `recruiter`, `jobs`, `careers`) — never Brite buyers
- IT (`it`) — not a buyer for lighting at any Brite TAM
- Customer-service queues (`cs`, `customerservice`) — back-office, not buyers
- Media / marketing / events (`media`, `marketing`, `events`) — could be Brite Labs buyers in some campaign types, so default-let-through (operator can flag at gate 2 if needed)
- Operations (`operations`, `ops`) — could be facilities-ops buyers, default-let-through
- System addresses (`noreply`, `postmaster`, `webmaster`, `mail`, `email`) — shouldn't appear in clean CSVs; if they do (rare slip-through from website-scraped lists), an auto-bounce is acceptable cost

False-positive cost is bounded — a real person named "Sales" gets flagged for operator review, not deleted. Operator override available at gate 2.

### Free-mail-domain list (12 entries)

`gmail.com`, `yahoo.com`, `hotmail.com`, `outlook.com`, `icloud.com`, `aol.com`, `protonmail.com`, `googlemail.com`, `live.com`, `me.com`, `mac.com`, `mail.com`

Match is exact + case-insensitive on the domain. First 7 cover the canonical free providers (the 5 from tam-mapping's Operational rule 1 plus `aol.com` + `protonmail.com`). Last 5 are US-relevant aliases used by US individuals as personal email: `googlemail.com` (Google's older alias), `live.com` (Microsoft consumer), `me.com` + `mac.com` (Apple legacy), `mail.com` (generic free provider).

**Intentionally excluded:** country-localized variants (`yahoo.co.uk`, `outlook.de`), Russian/Chinese providers (`mail.ru`, `yandex.*`, `163.com`, `qq.com`) — out of Brite's TAM. US ISP-attached email (`comcast.net`, `verizon.net`, `att.net`) — high false-positive risk on home-based micro-businesses in Brite Nites' contractor-targeted campaigns.

## Alternatives Considered

- **Replace ESP with email-type only.** Rejected — destroys Phase 2's deliverability-interference rationale (Google vs Microsoft sender warm-up).
- **Augment ESP × email-type → up to 9 buckets.** Rejected — combinatorial explosion on small lists; most segments empty in practice.
- **Toggle (operator picks axis at gate).** Rejected — adds operator decision burden for marginal flexibility over the pre-filter shape.
- **Defer until brite-enrichment-MCP ships.** Rejected by operator — gap window matters; behavior is needed now.
- **Full BounceBan-via-MCP integration in this PR.** Rejected — infrastructure-shaped issue (MCP wiring + credentials + rate-limits); would balloon BC-6307 scope. File as the follow-up to swap heuristics for the production engine.

## Risks & Mitigations

- **Heuristic edge-case miss** (catch-all domains, disposable services like Mailinator, exotic free providers like `@mail.ru`). → Mitigated by future MCP swap; near-term cost is a small false-negative rate.
- **Cross-skill drift between launch-campaign Phase 2 and tam-mapping Operational rule 1** if either rule changes without the other. → Reciprocal "Keep in sync" annotation per BC-2717 task-3. Mechanical asymmetry test post-PR: grep both files for the annotation; if only one side has it, the mirror has half-broken.
- **Schema contract drift with BC-6303** (metadata bundle, shipping next). BC-6303 adds `lead_ids_by_bucket` keyed by ESP bucket; BC-6307 changes which leads land in those buckets. → Resolved by ordering: BC-6307 lands first; BC-6303's `lead_ids_by_bucket` reflects post-filter lead IDs.

## Scope Boundaries

**In scope:**
- Email-type detection in Phase 2.
- Role-prefix list, free-mail-domain list (both as predicates).
- Gate-2 prompt extension showing email-type counts + override options.
- Default-skip rule (skip role + skip personal).
- Sidecar CSV for skipped leads.
- `email_type_segments` field added to metadata JSON schema.
- Reciprocal tam-mapping Operational rule 1 annotation.

**Out of scope:**
- Per-email-type sequence routing (different copy for personal vs role) — would require Phase 9 changes; file as follow-up if needed.
- Catch-all domain detection.
- Disposable-email detection.
- Score-threshold deliverability checks.

All four out-of-scope items wait for the brite-enrichment-MCP swap (post-BC-5538).

## Precedents Referenced

- **BC-5829 + BC-5830 task-1** — factual-anchor recipe check #7 (cross-skill schema contracts at Plan gate). Applies because launch-campaign Phase 2 consumes tam-mapping's CSV output.
- **BC-2717 task-3** — cross-skill keep-in-sync reciprocal annotation. 2nd surface; near 3rd-promotion threshold. Drives Decision 6.
- **BC-2717 task-5** — architecture-reviewer independent re-read of downstream contract is the backstop for cross-skill schema breaks.
- **BC-5832 task-2** — cross-skill contract review-validation hit rate ~100%; calibrate review-fix budget accordingly.

## Open Questions

None.
