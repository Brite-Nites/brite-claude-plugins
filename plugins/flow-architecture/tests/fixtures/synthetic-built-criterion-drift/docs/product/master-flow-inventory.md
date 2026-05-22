# Master Flow Inventory

Reference inventory for the synthetic-built-criterion-drift fixture
(BC-10730). One H3 section, one sub-flow row, classified ⚠ PARTIAL per
the operator-consumable BUILT criterion (`flow-inventory-codebase-scan`
SKILL.md § 6.1).

Schema follows Q20 amendment 2 (BC-10352): lowercase kebab-case slug +
backtick-wrapped H3 + em-dash separator.

## CORE WORKFLOWS

### `analytics-dashboard` — Analytics & Insights (1 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| analytics-dashboard-01 | Search analytics dashboard | Internal ops | ⚠ partially-implemented (API present at `/api/search-logs/dashboard/route.ts`, no `.tsx` consumer per BC-10730 operator-consumable criterion) |
