---
role: <slug>                          # kebab-case; = filename = the story-doc `personas:` value, e.g. installer
device: <primary device(s)>           # e.g. desktop (office) + mobile (jobsite) — load-bearing, drives P2
linear_label: persona/<slug>          # the Linear label that tags this persona's work
last_reviewed: YYYY-MM-DD             # stamp on each substantive edit
---
# <Display name> (<one-clause role descriptor>)

> **Doc type:** Persona (behavioral, per role). One page per persona at
> [`docs/product/personas/<slug>.md`](./<slug>.md); listed in [`INDEX.md`](./INDEX.md). Cross-linked
> from each story doc's `## Actor` and each journey doc's personas-in-scope. The substance reviewer
> (`quality-reviewer`, `doc_kind: persona_doc`) scores this doc against quality-rubric **P1–P5**.
>
> A persona is a **behavioral** profile, not an RBAC/access role: the story-doc `personas:` slug
> names a persona (= this doc's `role:` / filename), never a permission tier (ADR-041).

> One-line summary: who this person is and the job they come to the product to get done. ~15–25 words.

## At a glance

A scannable identity table. The two **bold** rows are load-bearing — they are what separates a
behavioral persona from a demographic one (quality-rubric **P1**): the *mental unit* is the thing the
person actually thinks in (the work and the people it's about, an order, a job-site run) — never the
system's internals (queues, hooks, collections); the *failure they can't absorb* is the one concrete,
domain-consequential outcome that is unrecoverable for them if it happens — not "dislikes bugs."

|  |  |
|---|---|
| **Who** | <role + the real humans who hold it, if known> |
| **Where** | <the surfaces / screens they live on> |
| **Device** | <desktop / mobile / field — and the moment each is used> |
| **Cadence** | <steady state vs the spike / season that defines their hardest day> |
| **Judged on** | <what success means to them — the outcome they are accountable for> |
| **Mental unit** | <the unit of work they think in — domain terms, not machinery> |
| **The failure they can't absorb** | <the one specific outcome they cannot recover from> |

## Day in the life

Two short paragraphs of concrete, unflattering operational narrative — a normal day and the hard day.
Where are they, what pressure shapes their decisions, what they actually do (not what features exist).
Keep it specific to *this* domain's surfaces, never a generic role (quality-rubric P5, domain-specificity).

## How they think

The persona's mental model and working context (quality-rubric **P2**): the device and the moment in the
workday, their physical / mental state, and the mindset they bring — *what question is in their head* as
they act. State the instinct that predicts how they react to an edge case ("after years of X, they
distrust any alert that needs manual follow-up"). This is what makes a persona predict behavior rather
than just label a role.

## What they care about

- <a concrete outcome they optimize for — domain-specific>
- <…>

## What they hate (current pain)

- <what they currently work around or complain about, named to its root friction — not "it's annoying">
- <…>

## What they see — and what they don't

The persona's scope shape (quality-rubric **P3**): what is in their view and — just as load-bearing —
what is deliberately *not*. The "don't see" column is usually the trusted machinery they rely on without
watching (the queue draining, the adapter delivering). Naming it is what stops a reviewer mistaking an
unobserved guarantee for an unbuilt feature.

| They **see** | They **don't** see |
|---|---|
| <a surface / signal in their view> | <a trusted mechanism out of their view> |
| <…> | <…> |

## Tools they use today

- <tool — what for (and whether this build replaces it)>
- <…>

## Hand-offs

Who this persona receives work *from* and hands work *to*, named by the adjacent persona or domain, with
the seam that crosses each boundary (quality-rubric **P4** — every named adjacent persona / domain must
resolve to a real one). This is the persona-level map of the seams a journey's cross-domain stitching and
a story's `## Out of scope` enforce per flow.

- **From <adjacent persona / domain>:** <what arrives, and the seam — a request, a record, a status>.
- **To <adjacent persona / domain>:** <what they produce for the next person, and the seam>.

## Touchpoints in <repo>

- **Journeys:** [<domain>](../journeys/<domain>.md), …
- **Primary flow domains:** <CODES from `master-flow-inventory.md`>
- **Pages they live on:** `/path/*`, …

## Out of scope

What this role explicitly does **not** do — useful for "should this be visible to <role>?" debates. Name
the adjacent persona / domain that *does* own each excluded thing.

- <thing they don't do — owned by [<other persona>](./<other-slug>.md) / `<DOMAIN>`>

## Open questions

- <a genuine unresolved question about this role — a segmentation or tier-split call, not answerable from source>

## In their words

Two or three first-person quotes in the persona's own voice (quality-rubric **P5**) — the sentence they
would actually say about the job, the pain, or the failure they can't absorb. Domain-specific and
concrete; a quote that could come from any user of any product is the failure this section catches.

> "<a real thing this person would say about the job>"

> "<a quote that names the failure they can't absorb>"

<!--
INDEX schema — personas/INDEX.md (one per repo; hand-maintained, sibling to these persona docs):
  frontmatter:  last_reviewed: YYYY-MM-DD
  H1 + 1–2 line preamble (who the product serves; any audience framing).
  Table — exactly these columns:  | Persona | Device | Status | File |
    Status ∈ { Drafted, Reviewed }
    File   = `<slug>.md`
  Optional narrative notes (persona split %, explicitly out-of-scope audiences).
  "How to add a persona" steps: copy this template → fill every <…> → save as
    docs/product/personas/<slug>.md → add an INDEX row → run `bash scripts/verify-docs.sh`.
-->
