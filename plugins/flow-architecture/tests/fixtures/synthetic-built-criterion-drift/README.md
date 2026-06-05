# synthetic-built-criterion-drift fixture

Used by `run-built-criterion-fixture-vslice.sh` (BC-10730) to lock the
tightened **operator-consumable BUILT criterion** introduced in plugin
1.2.2 (`skills/flow-inventory-codebase-scan/SKILL.md` § 6.1 +
`skills/flow-inventory-add/SKILL.md` § 7).

State represented: an `analytics-dashboard-01`-shaped sub-flow where
the API route exists at `src/app/api/search-logs/dashboard/route.ts`
but **no `.tsx` page consumes it**. Mirrors the iter-3 batch 2
correction logged in `docs/design-rationale/brand-hub-dogfood-findings.md`
§ "Iter-3 cumulative outcome summary" --- the inventory previously
marked this shape ✓ BUILT; under the tightened criterion it must be
⚠ PARTIAL.

## Criterion

> **BUILT** = an operator can consume the sub-flow through its
> intended surface, not merely that the API is callable.

The `route.ts` file is callable from `curl` or another API client, but
no operator-facing page / dialog / menu item routes to it. By the
operator-consumable criterion the row downgrades from ✓ BUILT to
⚠ PARTIAL.

## Expected classification

| ID | Fixture reference inventory says | Why |
|---|---|---|
| `analytics-dashboard-01` | ⚠ partially-implemented | API present at `/api/search-logs/dashboard/route.ts`, no `.tsx` consumer |

## Assertions locked by the vslice

1. All four fixture files exist (README, master-flow-inventory.md, route.ts, page.tsx).
2. The API route file matches a minimal Next.js route handler shape.
3. No `.tsx` file inside the fixture references `/api/search-logs/dashboard` as a literal substring.
4. The reference inventory contains `partially-implemented` and does NOT contain the literal strings `✓ BUILT` or `✓ implemented`.
5. Both SKILL.md files (`flow-inventory-codebase-scan` + `flow-inventory-add`) encode the criterion across three load-bearing checks: the catchphrase `operator can consume`, the structural clause `user-facing entry point`, and the negative-case rejection `API existence alone`.
6. Both SKILL.md files cross-reference this fixture path.

## Cross-reference

- BC-10730 --- the v1.1.x rubric-tightening that authored this fixture.
- `docs/design-rationale/brand-hub-dogfood-findings.md` § Iter-3 cumulative outcome summary --- the 6-correction evidence base.
- `tests/run-built-criterion-fixture-vslice.sh` --- the harness consuming this fixture.
