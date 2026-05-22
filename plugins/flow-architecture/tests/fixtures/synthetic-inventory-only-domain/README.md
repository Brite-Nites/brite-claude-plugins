# synthetic-inventory-only-domain fixture

Used by `run-inventory-only-rescaffold-vslice.sh` (BC-9971) to exercise the
filesystem-side of the Q20 amendment 1 classifier
(`flow-classify-domain-state.sh`).

State represented: the `asset-discovery` domain has been inventoried (H3
section + 3 sub-flow rows in `docs/product/master-flow-inventory.md`) but
not yet scaffolded — no Linear milestone, no journey doc at
`docs/product/journeys/asset-discovery.md`, no story docs under
`docs/product/flows/asset-discovery/`. Mirrors the Brand Hub state circa
2026-05-15 captured in [[project-bc-6998-brand-hub-dogfood]] memory; the
exact gap BC-9971's fix is designed to handle.

Schema reflects Q20 amendment 2 (BC-10352, 2026-05-22): lowercase
kebab-case slug + backtick-wrapped H3 + em-dash separator — matches Brand
Hub iter-2's actual shipped inventory shape.

## Expected classifier output

```
$ flow-classify-domain-state.sh \
    docs/product/master-flow-inventory.md \
    docs/product/flows \
    docs/product/journeys \
    asset-discovery
inventory-only
```

See `plugins/flow-architecture/scripts/flow-classify-domain-state.sh` for
the four-outcome classification table.
