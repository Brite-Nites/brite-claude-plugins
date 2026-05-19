# synthetic-journey-exists-domain fixture

Used by `run-inventory-only-rescaffold-vslice.sh` (BC-9971) to verify the
classifier returns `journey-exists` (distinct from both `inventory-only`
and `fully-scaffolded-fs`).

State represented: `ASSET-DISCOVERY` has H3 in inventory + journey doc,
but no story docs landed (Phase 5 succeeded, Phase 4 failed-or-deferred).
This is rare in practice but the classifier surface should distinguish it
explicitly so the orchestrator can route to the right Q15 + Q16 skip-if-
exists decisions without re-clobbering the journey doc.

## Expected classifier output

```
$ flow-classify-domain-state.sh \
    docs/product/master-flow-inventory.md \
    docs/product/flows \
    docs/product/journeys \
    ASSET-DISCOVERY
journey-exists
```
