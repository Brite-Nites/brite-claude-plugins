# synthetic-journey-exists-domain fixture

Used by `run-inventory-only-rescaffold-vslice.sh` (BC-9971) to verify the
classifier returns `journey-exists` (distinct from both `inventory-only`
and `fully-scaffolded-fs`).

State represented: `asset-discovery` has H3 in inventory + journey doc,
but no story docs landed (Phase 5 succeeded, Phase 4 failed-or-deferred).
This is rare in practice but the classifier surface should distinguish it
explicitly so the orchestrator can route to the right Q15 + Q16 skip-if-
exists decisions without re-clobbering the journey doc.

Schema reflects Q20 amendment 2 (BC-10352, 2026-05-22): lowercase
kebab-case slug + backtick-wrapped H3 + em-dash separator.

## Expected classifier output

```
$ flow-classify-domain-state.sh \
    docs/product/master-flow-inventory.md \
    docs/product/flows \
    docs/product/journeys \
    asset-discovery
journey-exists
```
