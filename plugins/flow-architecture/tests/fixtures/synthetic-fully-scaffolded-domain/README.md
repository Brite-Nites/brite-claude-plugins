# synthetic-fully-scaffolded-domain fixture

Used by `run-inventory-only-rescaffold-vslice.sh` (BC-9971) to verify the
classifier returns `fully-scaffolded-fs` and to exercise the orchestrator's
no-op-with-warning branch (Q20 amendment 1).

State represented: `asset-discovery` has H3 in inventory + journey doc at
`docs/product/journeys/asset-discovery.md` + at least one **story-doc-
shaped** `*.md` at `docs/product/flows/asset-discovery/asset-discovery-01.md`.
"Story-doc-shaped" follows Q15 / Q20.4 (as amended by Q20 amendment 2)
naming `<domain>-NN.md`; non-canonical files (`README.md`, `INDEX.md`) in
the same dir do NOT flip the classifier to `fully-scaffolded-fs` per
BC-9971 review fix. Re-running `/flow:add-domain` against this state
should hit the `fully-scaffolded-fs` branch and prompt the user before
clobbering.

Schema reflects Q20 amendment 2 (BC-10352, 2026-05-22): lowercase
kebab-case slug + backtick-wrapped H3 + em-dash separator. Story doc
filename mirrors lowercase canon (BC-10352 align).

## Expected classifier output

```
$ flow-classify-domain-state.sh \
    docs/product/master-flow-inventory.md \
    docs/product/flows \
    docs/product/journeys \
    asset-discovery
fully-scaffolded-fs
```
