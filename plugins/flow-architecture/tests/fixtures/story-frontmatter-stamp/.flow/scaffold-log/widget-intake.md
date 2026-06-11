---
domain: widget-intake
domain_code: WGT
linear_milestone_id: 11111111-1111-4111-8111-111111111111
linear_milestone_name: Widget Intake
created_at: 2026-06-10T00:00:00Z
created_via: /flow-architecture:start-project Phase 4 (BC-13168 story-frontmatter-stamp test fixture)
total_writes: 23
---

# Scaffold log — widget-intake

A multi-edge test scaffold-log. Edges exercised: WGT-02's children `Sub-flow` cell is backticked (the builder must still match via the leading-token, not silently miss → all-`TBD`); WGT-03's Design write errored, leaving one empty cell (degrade to `TBD`, not crash); WGT-04 is parents-only with no children row yet (real parent + all-`TBD` children); **WGT-05's parent `Linear identifier` cell is `err: rate-limited`** — a non-`BC` junk value left by a failed write, containing a YAML metacharacter `:` (the builder must degrade it to `TBD`, never emit it raw → malformed YAML); **WGT-06 has two children rows** (a `skipped-idempotent` re-run followed by an `executed` row — the builder resolves last-wins per SCHEMA.md's in-place-rewrite semantics).

Canonical table shape per `templates/.flow/scaffold-log/SCHEMA.md`, modeled on a real brite-roster produced log. The `Sub-flow` column is the bare `DOMAIN-NN` in the children table and `DOMAIN-NN — <desc> [<annot>]` in the parents table (the builder extracts the leading `^[A-Z]+-\d+` token from both, backticks stripped).

## Milestone (1 × executed)

| # | Type | Linear identifier | Name | Result |
|---|---|---|---|---|
| 1 | milestone | `11111111-1111-4111-8111-111111111111` | Widget Intake | executed |

## Parents (6 rows; WGT-05 write failed)

| # | Sub-flow | Linear identifier | Result |
|---|---|---|---|
| 2 | WGT-01 — Submit widget request | BC-20001 | executed |
| 3 | WGT-02 — Approve widget request [blocked on ADR-0003] | BC-20007 | executed |
| 4 | WGT-03 — Archive widget record | BC-20013 | executed |
| 5 | WGT-04 — Export widget report | BC-20019 | executed |
| 6 | WGT-05 — Bulk widget import | err: rate-limited | failed |
| 7 | WGT-06 — Widget audit trail | BC-20030 | executed |

## Discipline children (WGT-02 Sub-flow backticked, WGT-03 Design errored, WGT-04/05 not yet written, WGT-06 re-run)

| Sub-flow | Story | Engineering | Design | QA | Docs | Result |
|---|---|---|---|---|---|---|
| WGT-01 | BC-20002 | BC-20003 | BC-20004 | BC-20005 | BC-20006 | executed |
| `WGT-02` | BC-20008 | BC-20009 | BC-20010 | BC-20011 | BC-20012 | executed |
| WGT-03 | BC-20014 | BC-20015 | — | BC-20017 | BC-20018 | errored |
| WGT-06 | BC-26001 | BC-26002 | BC-26003 | BC-26004 | BC-26005 | skipped-idempotent |
| WGT-06 | BC-26011 | BC-26012 | BC-26013 | BC-26014 | BC-26015 | executed |

---

*Test fixture for `tests/run-story-frontmatter-vslice.sh` (BC-13168). Not a real domain.*
