# BC-17347 — Seed matched-both-null cold-outbound Contacts (ADR-037 D1 build gap)

**Issue:** [BC-17347](https://linear.app/brite-nites/issue/BC-17347) · **Project:** Salesforce Implementation · **Assignee:** Kells
**Branch:** `kells/bc-17347-salesforce-preload-seed-matched-both-null-cold-outbound` · **Base:** `9f46573`
**Handoff:** `/tmp/bc-17347-handoff.md` · **Governing decision:** brite-salesforce ADR-037 D1/D2

## Problem

The shipped `salesforce-preload` skill seeds the lifecycle floor (`Lifecycle_Stage__c=Cold_Prospect`
/ `Lead_Status__c=New`) on **net-new Contacts only**. ADR-037 Decision 1 also requires seeding a
**matched Contact that is `null` on BOTH governed fields** (keeps otherwise-invisible contacts in BDR
queues). Root cause: `classify_rows` receives `contacts_by_email: Mapping[str, int]` — a *count*, not
field values — so it is structurally incapable of the both-null decision.

## Design (approved)

- Widen the lookup to mirror the SOQL result shape: `contacts_by_email: Mapping[str, Sequence[MatchedContact]]`,
  where `MatchedContact(contact_id, lifecycle_stage, lead_status)`. `count == len(records)`.
- Add a distinct `MATCHED_SEED` disposition (legible in the operator write-gate; it is a *write* to
  existing records).
  - `len == 1` and **both** governed fields blank (`None`/`""`) → `MATCHED_SEED` (carry `contact_id`, uploads to EB).
  - `len == 1` and **either** non-blank → `MATCHED` (touch nothing — ADR-037 D2 opt-out).
  - `len > 1` → `MULTIPLE_CONTACTS` (unchanged).
- Expose the floor as module constants `FLOOR_LIFECYCLE_STAGE="Cold_Prospect"`, `FLOOR_LEAD_STATUS="New"`.

**Non-goals (preserved):** no VR-bypass perm (`null → New` doesn't trip `Lead_Status_Forward_Only`);
never part-seed one axis; never touch `OSLastCampaignId__c`/CampaignMember/`Segment__c`/`Referral_Source__c`;
owner stays Marketing Admin; never fuzzy-match; idempotent.

## Tasks (TDD — red first)

1. **Red** — `test_salesforce_preload.sh`: add matched-both-null → `MATCHED_SEED` (carries id, in `eb_rows`,
   not sidecar); suppression (`Do_Not_Prospect` + null status → `MATCHED`, nothing written); each single-axis-null
   → `MATCHED`; `counts["matched_seed"]`; migrate existing `contacts_by_email` fixtures to `MatchedContact`.
   Run → confirm red (import of `MATCHED_SEED`/`MatchedContact` fails).
2. **Green** — `salesforce_preload.py`: add `MatchedContact`, `MATCHED_SEED`, `FLOOR_*` constants,
   `_is_blank`, `contact_id` on `RowPlan`, both-null branch, `matched_seed` count, updated docstrings.
   Run → confirm green.
3. **Docs** — `SKILL.md`: Phase-2 disposition note, Phase-4 field table + matched-seed UPDATE-by-Id step,
   deterministic-core signature/shape, anti-slop line qualifier, Tier-1 test list, ADR-037 bullet.
4. **Version bump (same commit)** — marketing plugin `0.15.0 → 0.15.1` (plugin.json + marketplace.json);
   skill `metadata.version 0.1.0 → 0.2.0`.
5. **Verify** — `./scripts/validate.sh` green (esp. §15a-bc-17213b).

## Review

Independent of the builder (fresh-session receipt per `docs/guides/independent-review-receipt.md`) — the
spec was authored in the prior review session; the builder must not rubber-stamp it.
