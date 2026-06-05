# synthetic-linear-graph fixtures

Synthetic **Linear-state snapshots** for the WS-A Linear-graph lints
(`scripts/lib/flow_linear_lint.py`, runner `scripts/flow-linear-lint.sh`, harness
`tests/run-flow-linear-lint-vslice.sh`). Each fixture isolates one lint.

| Fixture | Trips | What it models |
|---|---|---|
| `pass` | nothing | 2 clean FDA domains; one cross-domain `blockedBy` mirrored in the doc |
| `fail-label-contamination` | **A-4** | `BC-102` titled `[Design]` carries `type:eng` |
| `fail-no-milestone` | **A-6** | parent w/ no milestone + child `NO_MILESTONE` + child milestone-mismatch |
| `fail-dup-child` | **A-7** | parent `BC-100` has two `[Design]` children (DRO-586/588 shape) |
| `fail-blockedby-orphan` | **A-5** | doc dep with no Linear edge **and** Linear edge with no doc bullet |

These lints need *Linear* data, so — exactly like the `cross-domain-deps-bidirectional`
gate (BC-10729) and its `synthetic-cross-domain-deps` fixtures — CI feeds a static
JSON snapshot and the **live** evaluation reads the same shape from Linear MCP.

## Snapshot schema (`.flow/linear-state-mock.json`)

```jsonc
{
  "parents": {                       // FDA sub-flow PARENT issues
    "<issue-id>": {
      "flow_id":   "<domain>-NN" | "<domain>/<slug>",  // inventory flow-ID
      // A-5 caveat: the `## Cross-domain dependencies` bullet parser (the BC-10729
      // predicate this reuses) matches only the `<...>-NN` flow-id form (e.g.
      // `seo-foundation-01`). A slash-form `<domain>/<slug>` flow_id is valid for
      // A-8/A-9 but will not be matched by A-5's doc-bullet mirror.
      "domain":    "<domain-slug>",                     // for cross-domain A-5
      "title":     "<DOMAIN-NN: ...>",
      "milestone": "<milestone name>" | null,           // A-6 inheritance source
      "blockedBy": ["<issue-id>", ...],                 // A-5 (parent-to-parent)
      "labels":    ["type:parent", "domain:<slug>", ...]
    }
  },
  "children": {                      // FDA discipline-child issues (5N)
    "<issue-id>": {
      "parent":    "<parent-issue-id>",
      "title":     "[Story|Eng|Design|QA|Docs] <DOMAIN-NN ...>",  // A-4/A-7 discipline
      "milestone": "<milestone name>" | null,                     // A-6
      "labels":    ["type:<discipline>", "domain:<slug>", ...]    // A-4
    }
  }
}
```

Field provenance: the discipline title-prefix ↔ `type:*` label mapping is Q24 mod 3
(`templates/scripts/lib/fda-title.mts` `TITLE_DISCIPLINE_TO_TYPE_LABEL`); the
cross-domain `blockedBy` semantics are the BC-10729 gate's.

## WS-E serialize contract (live → snapshot)

The WS-E remediation skill (and a future `/flow:audit` Phase C gate) builds this
JSON from live Linear before running the lint. The field mapping below was
verified against the **workflows Linear MCP** (`list_issues` / `get_issue`)
response shapes on 2026-05-29 — do not assume raw-GraphQL field names.

1. **Enumerate per domain.** For each domain slug in
   `docs/product/master-flow-inventory.md`, call
   `list_issues({ label: "domain:<slug>", project: "<project>", limit: 250 })`,
   paginating on the returned `cursor`. **Note the param is `label` (a single
   string), not `labels: [...]`** — the latter is silently ignored. One domain
   sweep returns the parent and its 5N children together.
   `list_issues` items already carry everything A-4/A-6/A-7 need:
   `id`, `title`, `labels` (a flat array of **name strings**, e.g.
   `["type:eng","domain:seo"]`), `parentId`, and `projectMilestone: {id, name}`
   (present only when the issue is assigned to a milestone).
2. **Classify** each issue by its `type:*` label: `type:parent` → `parents`,
   `type:{story,eng,design,qa,docs}` → `children`.
3. **Map fields straight from `list_issues`:** `id → key`, `title`, `labels`
   (pass the name-string array through unchanged), `parentId →
   children[].parent`, `projectMilestone.name → milestone` (omit/`null` when the
   `projectMilestone` field is absent). For `parents[].flow_id` / `domain`, use
   the master-flow-inventory row keyed by the issue's `DOMAIN-NN` title prefix.
4. **`blockedBy` (the one field `list_issues` does NOT return).** Linear
   relations are only exposed by `get_issue`. For **each parent** (not every
   issue — A-5 compares the cross-domain *parent* graph only), call
   `get_issue(<parent-id>, { includeRelations: true })` and take
   `relations.blockedBy[].id`. Keep only the ids that resolve to another FDA
   parent already in the snapshot; drop non-parent and discipline-child blockers.
   This is `N_parents` extra calls on top of the per-domain sweep — **not** a
   single batched call. **A-4/A-6/A-7 need no `get_issue` follow-up at all**; only
   A-5 requires it, so skip step 4 entirely when running the label/milestone/dup
   lints without the cross-domain check.
5. **Run**: `scripts/flow-linear-lint.sh <snapshot.json> <repo>/docs/product/flows`
   (the `flows-dir` argument is what enables A-5; omit it to skip A-5).

The lib parses only what the fixtures contain; extra Linear fields are ignored, so
the serializer may over-fetch safely.
