---
domain: <DOMAIN>                   # e.g. QUO
milestone: BC-XXXX                 # the Linear milestone this domain maps 1:1 to
linear_project_id: <LINEAR_PROJECT_ID>  # FDA: the Linear project the milestone lives in (auto-substituted at scaffold)
personas: [<role>, <role>]
flow_ids_in_scope: [<DOMAIN-01>..<DOMAIN-NN>]
status: not-started | in-progress | shipped   # the doc's AUTHORING lifecycle, NOT the domain's delivery state (delivery is aggregated per-flow in INDEX.md)
figma: <domain-hub-frame-url or TBD>
intent: ../../intent.md            # FDA: project-intent cross-link (Q26 mod 1)
last_reviewed: YYYY-MM-DD
---
# <DOMAIN>: <Display name — e.g. Quote Building>

> **Doc type:** User journey (per-domain). Aligns 1:1 with the Linear milestone for this domain.
> For cross-domain scenario narratives that span multiple domains (e.g. "Sales → Quote → Acceptance"
> spanning APPT + SURV + QUO + QLIFE + CPUB), use [`docs/templates/journey.md`](./journey.md) instead.

## Title + domain code

`<DOMAIN> — <Display name>` (e.g. `QUO — Quote Building`).

## Actor / Persona

Which RBAC role anchors this journey. One paragraph describing them in the context of this domain
— working context (device, moment in the workday, physical/mental state), the scope shape they
have (what they see vs. don't), and the failure they cannot absorb. **Behavioral, not demographic**
(quality-rubric J2): a persona that could be pasted unchanged into the adjacent domain's journey is
a fail. Link to the canonical persona doc: [`docs/product/personas/<role>.md`](../personas/<role>.md).

For an **infrastructural / generation-plane domain** (its flows are predominantly non-human /
automated actors — domain routing, sitemap/SEO infra, page generation, hosting), anchor the persona
on the **operator** who configures, runs, and trusts the system, and name the **system itself** as a
second actor narrated through a constraint lens (what it must guarantee) — never a forced human
end-user. "When I'm the crawler…" is the journey-scale echo of the story-doc D11 failure.

## Scenario + Expectations

The situation being mapped (one paragraph) and what the user expects to get out of this journey
(one paragraph). The **scenario** sets context — when does this journey begin, what triggered it,
what state is the user in when they arrive. The **expectations** set the success target — what
"good" looks like from the user's POV, regardless of whether the product currently delivers it.

> **Profile D (programmatic-SEO / generation-plane) — narrate two arcs, kept separate, here:**
> the **generation-lifecycle arc** (operator-facing: feed → template → run → quality gate → publish →
> sitemap → verify) and the **searcher-discovery arc** (anonymous crawler/searcher consuming the
> rendered output). The persona stays anchored on the operator; the system is the second actor,
> always narrated as a constraint. The arcs intersect at the stable identifier contract — name it.

## Journey phases

4–8 high-level chapters of the user's experience through this domain. Each phase carries narrative
content (mindset, the lived experience, pain points, opportunities) and ends with a per-phase table
mapping job stories to status. Phase **count is whatever fits the domain** — do not pad or truncate
to hit a number.

### Phase 1 — <Phase name — verb-led, e.g. "Create the quote">

*Persona:* <role>
*Mindset:* "<one-line internal monologue — what the user is thinking>"

Narrative description (~2 paragraphs). What the user does, what they're thinking, what they feel.
Reference job story IDs inline ("In `<DOMAIN-NN>` they …"). This narrative is the WHY; the job
story doc is the WHAT-TO-SHIP — link to it, do **not** restate its acceptance criteria here.

**Pain points:**
- <friction observed in research or anticipated — with a named *root cause*, not "this is annoying">
- <friction, root-caused>

**Opportunities:**
- <product/eng direction — what to build, at what scope (v1 vs deferred), tracked by flow ID/issue>
- <opportunity, scoped + tracked>

**Job stories in this phase:**

| ID | Job story | Status | Story doc |
|---|---|---|---|
| `<DOMAIN-NN>` | <inventory title — one line> | NOT_STARTED | [📄](../flows/<domain>/<flow-id>.md) |
| `<DOMAIN-NN>` | <inventory title — one line> | BUILT | [📄](../flows/<domain>/<flow-id>.md) |

### Phase 2 — <Phase name>

…

(Repeat per phase. Pain points / opportunities / job-story tables live **per phase** — do not also
maintain duplicate domain-level "Pain points" / "Opportunities" / consolidated "Job stories"
sections; the per-phase tables ARE the index.)

## Decision points (sometimes)

Forks in the journey where the user's experience diverges by role, data state, or input. Each fork
names the **condition**, the **enforcement layer**, and the **user consequence** (quality-rubric J6).
Skip this section only if the journey is genuinely linear (most non-trivial domains have ≥1 fork).

- **<Decision>:** <condition> → <enforcement layer> → <outcome>
- **<Decision>:** <condition> → <enforcement layer> → <outcome>

## Out of scope

What this domain explicitly doesn't cover — usually the boundary with adjacent domains. Name the
owning domain/flow for each excluded concern.

- <out-of-scope item — owned by [<DOMAIN-X>](./<domain-x>.md)>
- <out-of-scope item>

## Related domains and cross-scenario journeys

- **Cross-scenario journeys this is part of:** [<scenario name>](./<scenario-slug>.md)
- **Adjacent domains:**
  - [<DOMAIN-X> — <name>](./<domain-x>.md) (upstream) — names the specific seam (data event / UI
    handoff / status transition) crossing the boundary, not just "feeds into".
  - [<DOMAIN-Y> — <name>](./<domain-y>.md) (downstream) — the specific seam.

## Open questions

Genuine blocking uncertainties — design decisions, data-model choices, scope calls unresolvable
without human input. Each names **who resolves it** and **what artifact resolves it**. Questions
answerable by reading source do not belong here (quality-rubric J8).

- <question> — resolver: <Linear issue / discipline child / owner>

## See also

- **Master flow inventory:** [`docs/product/master-flow-inventory.md`](../master-flow-inventory.md)
- **Job story docs in this domain:** [`docs/product/flows/<domain>/`](../flows/<domain>/)
- **Personas in scope:** [`docs/product/personas/<role>.md`](../personas/<role>.md)
- **Cross-domain index:** [`docs/product/flows/INDEX.md`](../flows/INDEX.md)

## L2 review summary

<!-- FDA-additive section. Populated by the L2 L-review composer (CEO + Design reviewers) via Q46
     idempotency markers after the inventory phase fires. Leave the placeholder until review runs;
     the composer clobbers between the markers. Keep `## Open questions` ABOVE as the authored
     home for genuine blockers — this section is the machine-written review record, not a substitute. -->

_Pending L2 review._
