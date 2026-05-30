---
flow_id: <DOMAIN-NN>           # e.g. QUO-17
domain: <DOMAIN>               # e.g. QUO
status: NOT_STARTED | IN_PROGRESS | BUILT | QA_SIGNED_OFF | SHIPPED | BLOCKED
parent_issue: BC-XXXX
children:                       # backfilled once flow-linear-scaffold creates the 5N issues; TBD until then
  story: BC-XXXX
  engineering: BC-XXXX
  design: BC-XXXX
  qa: BC-XXXX
  docs: BC-XXXX
personas: [<role>]
related_flows: [<DOMAIN-NN>, <DOMAIN-NN>]
figma: <frame-url or TBD>
sandbox_url: <relative-path or TBD>     # e.g. /sandbox/quote-creation/quote-builder — base URL in docs/README.md
staging_url: TBD
real_app_url: TBD                       # populated for SHIPPED flows post-auth-restoration
e2e_test: TBD                           # path to test file if exists
user_docs_url: TBD                      # path to docs/product/customer-docs/<domain>/<flow-id>.md once Docs child ships
qa_status: not-tested | signed-off | rework-needed | blocked       # published delivery mirror → INDEX.md (Linear QA child is orchestration SoT)
qa_last_signed_off: null                # date string when set
eng_status: not-started | in-progress | done | blocked | n/a       # published delivery mirror → INDEX.md
design_status: not-started | in-progress | done | blocked | n/a    # published delivery mirror → INDEX.md
docs_status: not-started | in-progress | done | blocked | n/a      # published delivery mirror → INDEX.md
intent: ../../intent.md                 # FDA: project-intent cross-link (Q27 mod 1)
last_reviewed: YYYY-MM-DD
---
# <DOMAIN-NN>: <Inventory title>

> **Doc type:** Job story (per atomic action). Pairs 1:1 with a row in
> [`docs/product/master-flow-inventory.md`](../../master-flow-inventory.md). Coordinates the
> 5-discipline rollout (parent issue + Story / Engineering / Design / QA / Docs children) under
> the parent journey at [`docs/product/journeys/<domain>.md`](../../journeys/<domain>.md).

> One-line mechanical-contract summary (quality-rubric D8): what triggers this flow, what changes in
> the data layer, what the user observes as confirmation. ~15–25 words.

## Job story

**Default — human actor (JTBD frame, Alan Klement):**

> **When** <situation — the user's context when this action becomes relevant>,
> **I want to** <motivation — the capability the flow delivers>,
> **so I can** <outcome — a concrete next action it unblocks, never a feeling and never the flow title>.

Don't use "As a [role]…" — the persona is the `## Actor` section. The `so I can` names a real next
move ("review and send the invoice in seconds instead of retyping line items"), not "stay organized"
and not "100-400 pages are available" (the title jammed into the slot — the grammar-collapse fail).

**Non-human / infrastructure actor (constraint-spec frame — the D11 / EARS rule):**

A crawler, CDN invalidation, cron, webhook receiver, sitemap/robots generation, canonical-URL
resolution, redirect rule, CSP enforcement, ISR/revalidation, schema.org emission, or page-generation
run gets a **constraint spec in this same `## Job story` section** — the heading stays:

> **Given** <context — the system event/state>,
> the system **MUST** <behavior the system guarantees>,
> **so that** <a human-serving outcome>.

The subject is the system, never first-person "I". "When I'm a search-engine crawler, I want a
sitemap…" is the canonical D11 failure. A flow that mixes a human trigger and a system guarantee
(a form submit that fires a webhook) leads with the human job story and captures the system half as a
clearly-labelled constraint-spec AC below.

## Status notes (sometimes)

Include **only** when `status` is partial, there is status drift (engine ships but UI doesn't; field
exists but no surface exposes it), or there is cut/pilot/blocking context worth a reviewer's
attention. Omit entirely for a clean NOT_STARTED or a clean BUILT.

## Actor

Which RBAC role(s) take this action — name the role first and cross-link the canonical persona doc
([`docs/product/personas/<role>.md`](../../personas/<role>.md)) rather than restating it. Then add
the role's **posture** (working context + the failure modes it won't tolerate) as a secondary clause
— that posture drives which negative ACs matter (quality-rubric D7). For a **constraint-spec flow**,
name the system process that acts (route handler, cron, crawler-facing surface) and the human it
serves downstream, in place of an RBAC role.

## Preconditions

What must be true to start. Keep to ≤3 bullets — capture only the genuinely required state, not
every prior step.

- <preconditional state, e.g. "User is on a quote with at least one section">
- <preconditional state>

## Acceptance criteria

3–5 Gherkin Given/When/Then scenarios: the happy path plus the most likely meaningful variants
(a validation rejection, a permission/tenant boundary, a cross-entity case). Testable from the AC
alone — name exact field names, enum values, function names, or verbatim error strings when code
corroborates them; otherwise assert observable behavior in domain terms and `<!-- TODO: AC — <what> -->`
any specific identifier engineering hasn't chosen. Never emit the placeholder clauses
(`Then the outcome described in 'So I can …' holds true`); label an unbuilt scenario
`(<STATUS> — gap to close)`. For a constraint-spec flow the `When` is a system event firing and the
`Then` asserts an observable system guarantee (exact meta-tag values, canonical targets, sitemap
include/exclude rules, HTTP status codes, redirect chains, revalidation windows, idempotency).

```gherkin
Scenario: <happy path scenario name>
  Given <preconditional state>
  When <user action OR system event>
  Then <observable outcome — concrete>
  And <additional observable outcome>

Scenario: <negative / boundary / edge case>
  Given <preconditional state>
  When <action>
  Then <observable outcome>
```

## Out of scope / no-gos

What this flow explicitly does **not** cover. Reference the adjacent flow ID that owns each excluded
behavior (quality-rubric D6) — "out of scope" with no named owner is a boundary-drift fail.

- <out-of-scope behavior — owned by `<DOMAIN-NN>`>
- <out-of-scope behavior — owned by `<DOMAIN-NN>`>

## Cross-domain dependencies (sometimes)

**Include this section ONLY when this flow has a cross-domain blocker** (Q27 amendment 1 mod 4). It
must mirror the Linear `blockedBy` relations on this flow's parent issue **1:1** — the
`/flow:audit` `cross-domain-deps-bidirectional` gate fails on any drift between this section and
Linear. Omit the section entirely when there is no cross-domain dependency.

- **Blocked by `<OTHER-DOMAIN-NN>`** ([BC-XXXX](https://linear.app/brite-nites/issue/BC-XXXX)) — <why>.

## Status

The rollup build verdict + grounding. For a BUILT / IN_PROGRESS flow, state the verdict and list
**evidence anchors** — real `path:symbol` references a reviewer can open (this serves quality-rubric
D5 honest-status + D10 no-fabrication; cite only paths confirmed in `code_signals`). Capture genuine
per-flow open questions here (an Eng `Confirm:` on a drift you found). For a NOT_STARTED flow, state
`NOT_STARTED — no implementation yet` and the nearest evidence (a stub route, a schema field).

**<STATUS> — <one-line verdict>.**

Evidence anchors:
- [`src/...`](../../../../src/...) — <symbol / what it implements>

## Cross-references

- **Parent journey:** [`docs/product/journeys/<domain>.md`](../../journeys/<domain>.md)
- **Related flows** (in this domain or upstream/downstream):
  - `<DOMAIN-NN>` — <inventory title> *(story doc TBD or [📄](./other-flow-id.md))*
- **Cross-scenario journey:** `<scenario name>` — <stage this flow contributes to> *(scenario doc TBD or [link](../../journeys/<scenario-slug>.md))*
- **Linear parent issue:** [BC-XXXX](https://linear.app/brite-nites/issue/BC-XXXX)
- **Master inventory row:** [`docs/product/master-flow-inventory.md` row `<DOMAIN-NN>`](../../master-flow-inventory.md)

## QA history

Curated summary — **Linear is the source of truth** for full test runs (see the QA child issue's
comment thread). Update this table on each sign-off cycle; it is the in-doc surface for the
`qa_status` frontmatter mirror.

| Date | Status | Tester(s) | Notes / follow-ups |
|---|---|---|---|
| YYYY-MM-DD | not-tested | — | — |
