# 020. GTM campaign manifest schema v2 — multi-EB-campaigns + structured audience-tier

**Status:** Accepted
**Date:** 2026-05-27
**Linear:** [BC-11852](https://linear.app/brite-nites/issue/BC-11852)
**Related ADRs:** [ADR-012](012-gtm-campaign-unit.md) (campaign unit), [ADR-013](013-gtm-three-layer-split.md) (3-layer canon), [ADR-016](016-gtm-plugin-side-canonicals.md) (plugin-side canonicals)
**Predecessor data:** [`docs/reconciliation/master-index.md` / `master-index.json`](../reconciliation/master-index.md) (BC-11851, PR #391) — enumerated audience-tier strings across 77 logical campaigns × 11 distinct composite EB strings

## Context

The v1 GTM campaign manifest (`docs/campaigns/<entity>/<slug>/manifest.json`,
introduced under ADR-012 / BC-8724) assumed a 1:1 relationship between a
logical Brite campaign and an Email Bison record:

```json
"email_bison": {
  "workspace": "emailbison-b2b",
  "campaign_id": null,
  "campaign_name": "...",
  "launched_at": null
}
```

BC-11851 reconciliation data shows this assumption never held in practice. A
single logical Brite campaign produces **multiple EB records** — split across:

- **Workspace**: most campaigns produce one record in `emailbison-b2b` (for
  professional / role / general emails) AND one record in `emailbison-personal`
  (for personal emails). Cross-workspace fanout is the rule, not the exception.
- **Audience-tier**: even within one workspace, campaigns split further by
  audience-tier — e.g., one Professional Emails record + one Role Emails
  record + one General Emails record.
- **ESP**: an `| All ESPs` qualifier sometimes appears, suggesting that ESP
  segmentation is an additional split axis.

Empirically, a single logical campaign has produced up to **6 EB records**
(observed in `master-index.json` rows). v1 cannot represent this — `campaign_id`
is singular.

Additionally, the EB-name strings that label these records are **composite**
across at least three orthogonal axes. Eleven distinct composite strings were
observed across the 77-campaign sample:

```
Bar Owners, GMs | General Emails
Bars Owners, GMs | Personal Emails          ← note the "Bars" typo in EB UI
Employees | Professional Emails
Managers+ (Reverified) | All ESPs
Managers+ | All ESPs
Managers+ | Professional Emails | All ESPs
Personal Emails | All ESPs
Professional Emails
Professional Emails | All ESPs
Professional Emails | All ESPs | Direct Question Offer
Role Emails | All ESPs
```

Decomposing these into atomic axes:

| Axis | Slug examples | Cardinality |
|---|---|---|
| **tier** (ESP/email-type, REQUIRED) | `professional`, `role`, `personal`, `general` | 4 |
| **seniority** (job-level filter, OPTIONAL) | `managers-plus`, `employees`, `bar-owners-gms` | 3 |
| **modifier** (orthogonal flag, OPTIONAL list) | `reverified`, `direct-question-offer` | 2 |

A flat enum across all 9 observed strings would conflate three orthogonal
axes into one dimension — making it impossible to ask "show me all
managers-plus campaigns regardless of email type" or "show me all reverified
campaigns regardless of seniority."

## Decision Drivers

- **Data shape**: master-index.json shows the 1:1 assumption is broken in
  practice. The campaign manifest must represent the actual fan-out shape, not
  the original simplification.
- **Auto-classification**: BC-11849 (import-campaign) will reverse-engineer
  EB-records into manifest entries via name-substring matching. Composite
  strings must decompose into multiple axes for the classifier to handle
  novel combinations (e.g., a future `Managers+ (Reverified) | Personal
  Emails`) without an enum explosion.
- **Audit ergonomics**: an SDR auditor asking "which campaigns target
  managers and above?" wants a single field to filter on (`seniority`), not
  a substring search across a flat-enum string.
- **Forward-compatibility**: the modifier axis is open-ended (a future
  experiment may introduce `holiday-anchor` or `q4-pricing` as modifiers).
  Adding a slug to the modifier sub-enum is cheaper than adding a tier slug.
- **Cohort-1 has not launched**: the only existing v1 manifest is
  cohort-1 (Hotels & Resorts × Anchor Audit) at
  `docs/campaigns/labs/hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02/manifest.json`,
  with `campaign_id: null`. Migration is trivial (no live data to reshape).
  The cost of cutting v2 now — before any campaign launches with v1
  expectations — is minimal.

## Decision

**Schema v2 is the new contract** for `docs/campaigns/<entity>/<slug>/manifest.json`,
with two breaking changes against v1:

1. **`email_bison.campaign_id` (singular) is REMOVED.** Manifests that include
   it after migration are rejected by the v2 validator.
2. **`email_bison.campaigns[]` (plural array) replaces it.** Each entry is an
   EB campaign record with `{workspace, campaign_id, esp, audience_tier,
   name, launched_at, status}`. Empty array = not yet launched (the cohort-1
   "null" state).

`email_bison.workspace` is **retained** as the primary-workspace pointer
(where the canonical lead list lives), distinct from each EB record's
`campaigns[].workspace` (where that specific EB record exists).
`email_bison.campaign_name` is **retained** as the logical campaign-name seed
for cross-walks against `salesforce.campaign_name` and the EB auto-classifier.

### Structured audience-tier

The `audience_tier` field on each `campaigns[]` entry is a **structured
object**, not a flat string:

```json
"audience_tier": {
  "tier": "professional",
  "seniority": "managers-plus",
  "modifiers": ["reverified"]
}
```

- **`tier`** (REQUIRED, kebab-case slug): primary axis from the
  `audience_tiers` block in `_manifest.yaml`. Initial enum:
  `professional`, `role`, `personal`, `general`.
- **`seniority`** (OPTIONAL, kebab-case slug or null): job-level filter.
  Initial enum: `managers-plus`, `employees`, `bar-owners-gms`.
- **`modifiers`** (OPTIONAL, array of kebab-case slugs): orthogonal flags.
  Initial enum: `reverified`, `direct-question-offer`.

The slug enum lives in `plugins/marketing/data/canonicals/_manifest.yaml`
under a new top-level `audience_tiers[]` block (one entry per axis-value;
each entry declares `slug`, `axis`, `display`, optional `description`, and
optional `matches[]` substring tokens for the BC-11849 auto-classifier).

### Canonicals manifest bump

The `_manifest.yaml` `schema_version` also bumps `1 → 2` to admit the new
`audience_tiers[]` block. The linter (`lint_canonicals.py`) pins its
`SCHEMA_VERSION` constant to `2` in the same commit. Vertical YAMLs
(`hotels-resorts.yaml`, etc.) are unchanged — the audience-tier taxonomy
lives in `_manifest.yaml`, not in vertical-specific files.

### Worked examples

The 11 distinct observed EB strings decompose as follows:

| Observed EB string | tier | seniority | modifiers |
|---|---|---|---|
| `Professional Emails` | `professional` | `null` | `[]` |
| `Professional Emails \| All ESPs` | `professional` | `null` | `[]` |
| `Role Emails \| All ESPs` | `role` | `null` | `[]` |
| `Personal Emails \| All ESPs` | `personal` | `null` | `[]` |
| `Bar Owners, GMs \| General Emails` | `general` | `bar-owners-gms` | `[]` |
| `Bars Owners, GMs \| Personal Emails` | `personal` | `bar-owners-gms` | `[]` |
| `Employees \| Professional Emails` | `professional` | `employees` | `[]` |
| `Managers+ \| All ESPs` | (defaults from siblings) | `managers-plus` | `[]` |
| `Managers+ (Reverified) \| All ESPs` | (defaults from siblings) | `managers-plus` | `["reverified"]` |
| `Managers+ \| Professional Emails \| All ESPs` | `professional` | `managers-plus` | `[]` |
| `Professional Emails \| All ESPs \| Direct Question Offer` | `professional` | `null` | `["direct-question-offer"]` |

(The `| All ESPs` qualifier is treated as a no-op marker — when present
alone in the seniority-only rows, the tier slot can be backfilled from the
sibling EB record's tier or marked `null` pending operator review per
BC-11849 design.)

### Migration

A migration script at `plugins/marketing/scripts/migrate_manifest_v1_to_v2.py`
handles in-place v1 → v2 conversion. It is **idempotent** — running twice in
a row is safe. The cohort-1 manifest is the only known v1 instance; the
script ships with synthetic fixtures covering: (a) unlaunched campaign with
`campaign_id: null` → empty `campaigns[]`, (b) hypothetical launched campaign
with `campaign_id: 12345` → single-record `campaigns[]` with placeholder
audience-tier, and (c) already-v2 input → no-op.

Per the BC-11852 brief, v1 is **intentionally broken** going forward — new
manifests scaffolded post-merge use v2; the `portfolio-snapshot` reader
accepts both shapes during a one-cycle transition window, then drops v1
support in a future minor bump.

## Consequences

- `/marketing:plan-campaign` (BC-8724) scaffolds v2 manifests directly — no
  migration needed at scaffold time after this BC merges. A follow-up
  edit pins the scaffolder to schema v2 (BC-11857 hardening).
- `/marketing:portfolio-snapshot` reads v2 cleanly; v1 manifests trigger a
  one-time `[BC-11852] manifest is v1, falling back to legacy reader; run
  migrate_manifest_v1_to_v2.py` stderr warning, then degrade gracefully
  (campaigns array empty → no EB pipeline rows for that campaign).
- BC-11849 (`/marketing:import-campaign`) is the primary consumer of v2 —
  it parses EB campaign-name strings into `audience_tier` objects via the
  `_manifest.yaml audience_tiers[].matches[]` mapping table.
- BC-11856 (audit-campaigns drift detector) reads v2 `campaigns[]` directly
  to compare against EB-side state without re-resolving singular
  `campaign_id`.
- BC-11853 (canonicals backfill — 26 vertical YAMLs) does NOT touch
  `audience_tiers[]`; that block lives in `_manifest.yaml` exclusively and
  is sourced from EB observations, not from per-vertical handbook prose.
- Schema versioning per ADR-016 D9: future schema bumps (v2 → v3) migrate
  manifest.json files in the same PR; the linter pins its `SCHEMA_VERSION`
  constant in lockstep.
- The decision to keep `email_bison.workspace` as a primary-workspace
  pointer (rather than deriving from `campaigns[]`) is mildly redundant for
  launched campaigns (the primary workspace is always represented in
  `campaigns[]`) but the field is load-bearing for **unlaunched** campaigns
  (empty `campaigns[]` carries no workspace signal otherwise) — and
  preserving it costs one string per manifest.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| **Flat audience-tier enum** (single string slug across all 9 observed values) | Conflates three orthogonal axes (tier × seniority × modifier) into one dimension; loses the ability to filter by axis; enum-explodes on new combinations; can't represent `null` seniority cleanly. The brief explicitly called this out as "loses the Reverified + Direct Question Offer modifiers." |
| **Keep v1 + add `additional_campaigns[]`** (singular `campaign_id` + plural escape hatch) | Preserves backward-compat at the cost of a permanent two-shape data layer; downstream readers must always merge both fields; the singular field is misleading for the >90% of campaigns that fan out to ≥2 EB records. |
| **Single-axis structured** (`{tier, modifiers}` without seniority) | Matches the brief's "structured" option literally, but the observed data has THREE axes, not two — collapsing seniority into modifiers would force the BC-11849 classifier to enumerate `managers-plus-professional`, `employees-professional`, etc., as separate modifier slugs (the exact flat-enum pathology in alt #1). |
| **Deprecate `email_bison.workspace`** (derive primary workspace from `campaigns[]`) | Unlaunched campaigns have empty `campaigns[]` — there'd be no way to encode "the b2b workspace is where leads will land when this launches." Keeping the field costs one string per manifest. |
| **Per-vertical audience_tier overrides** (each vertical YAML declares its own tiers) | Audience-tier taxonomy is global (an EB-name pattern is the same regardless of vertical); per-vertical declaration would re-state the same enum 27 times and create 27 drift-vectors. The taxonomy belongs in `_manifest.yaml` as one source of truth. |
| **Defer audience-tier decision to BC-11849** (just bump schema_version + ship empty campaigns[]) | BC-11849 needs the enum in place to author its classifier — landing audience-tier here unblocks BC-11849's brief. The reconciliation data (BC-11851, PR #391) gave us the empirical enum candidates; deferring would just push the same decision out by one BC. |

## Cross-references

- BC-11852 — this issue (schema v2 implementation)
- BC-11851 / PR #391 — `master-index.md` / `master-index.json`, source of the observed audience-tier strings
- BC-11849 — `/marketing:import-campaign`, the downstream consumer that maps EB-name strings → `audience_tier` objects via `_manifest.yaml audience_tiers[].matches[]`
- BC-11853 — A3 canonicals backfill (26 vertical YAMLs); does NOT touch `audience_tiers[]`
- BC-11856 — audit-campaigns drift detector; reads v2 `campaigns[]` directly
- BC-11857 — `/marketing:plan-campaign` hardening; pins scaffolder to v2
- [ADR-012](012-gtm-campaign-unit.md) — campaign unit definition (V × P × O × M)
- [ADR-016](016-gtm-plugin-side-canonicals.md) — plugin-side canonicals; v2 extends this by adding `audience_tiers[]` to `_manifest.yaml`
- `plugins/marketing/data/canonicals/schema.json` — `#/definitions/campaign_manifest`, `#/definitions/audience_tier_object`, `#/definitions/audience_tier_entry`
- `plugins/marketing/scripts/migrate_manifest_v1_to_v2.py` — v1 → v2 migration helper (idempotent)
- `plugins/marketing/scripts/lint_canonicals.py` — `SCHEMA_VERSION = 2` pinning + audience_tiers[] validation
