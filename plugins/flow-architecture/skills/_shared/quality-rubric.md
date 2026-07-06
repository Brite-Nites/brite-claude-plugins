# Flow-Doc Quality Rubric — Substance Spine

Reference contract for the FDA quality-reviewer agent and for the two author agents (`story-doc-author`, `journey-doc-author`) that should write *to* this bar. It judges what a doc **says**, not that its sections exist — front-matter fields and section order are the fidelity-reviewer's job (`fidelity-reviewer`, Q13.3). Do not re-check structure here.

This file is **principles**, not a shape to copy. It is calibrated against general JTBD and PRD practice plus shipped-app norms (the Mobbin corpus that informs the app-type profiles); BriteBase is one lived witness, not the template. Any app type can produce a high-scoring doc. App-specific tightening lives in the companion `app-type-profiles.md` — apply the profile that matches the project's app type **on top of** this spine, never instead of it.

Two layers of the same spine: **story dimensions** (D1–D11) judge a single sub-flow's outcome spec; **journey dimensions** (J1–J8) judge a domain's end-to-end arc one layer up. A quality-reviewer scoring a story doc uses D1–D11; scoring a journey doc uses J1–J8.

## How to score

Each dimension carries either a **1–5 scale** or a **pass / concern / fail** verdict. The split is deliberate: dimensions where quality is genuinely graded (specificity, testability, persona depth) get 1–5; dimensions that are closer to a contract being met or not (boundary clarity, fabrication, frame correctness) get pass/concern/fail.

The rubric is gameability-resistant by construction. The failure mode each dimension names is a **thin shell that survives superficial review** — boilerplate ACs, copy-pasted personas, status inflation, fabricated identifiers. A doc that fills every section but says nothing specific scores low; a doc that is terse but concrete scores high. When you can score a dimension high without re-reading the source, the doc has done its job; when you must reconstruct meaning from the codebase, it has not.

- **Score 3+ to pass** on 1–5 dimensions. A 1–2 is a **P1 finding** (blocks).
- A **concern** is a P2 (note it, don't block). A **fail** is a P1.
- Cite the specific clause or scenario that earns the score. A bare number is not a review.

---

# Story dimensions (per sub-flow)

## D1 — Job-story specificity

**Definition.** The "so I can" clause names a concrete, time-bounded downstream **action** the user takes as a direct consequence — not a feeling, a state, or a restatement of the flow title.

**Good signal.** "so I can triage twenty-five-plus invoices in ten minutes without bouncing through the admin or asking sales which client owns which proposal." The clause implies a measurable before/after: there was friction, now there isn't, and the next physical step is clear.

**Failure mode it catches.** Grammar collapse — the slot is filled with the flow title, a feeling ("so I can feel confident"), a non-action ("so I can have consistent navigation"), or a verb-less fragment ("so I can 100-400+ pages"). These pass a glance but reveal an author who does not know *why* the user wants the feature.

**How to judge (1–5).**
- 5 — names a specific observable next action; implies a measurable before-state.
- 4 — names an action but slightly abstract ("manage my schedule" vs "plan my route for the day").
- 3 — describes an outcome but no clear next action.
- 2 — names a feeling or state; no action.
- 1 — absent, circular, or grammatically broken.

---

## D2 — AC testability

**Definition.** Each scenario names exact field names, enum values, function names, or verbatim error strings when code corroborates them; otherwise asserts observable behavior in domain terms. A scenario is testable if an engineer can write the test from the AC alone without re-reading the source.

**Good signal.** "Given a Sent quote with 3 applications, 2 options, full line-item breakdown / When the salesperson clicks Generate PDF / Then a PDF artifact is created and stored in private blob storage / And the PDF matches the proposal-view content 1:1 (cover, scope summary, applications, line items, totals, T&Cs)." Concrete inputs, concrete observable outputs.

**Failure mode it catches.** Circular boilerplate — "Then the outcome described in 'So I can…' holds true," identical across every scenario, lets anything pass. Also catches scenarios referencing implementation internals not confirmed in code (fabricated identifiers; see D10).

**How to judge (1–5).**
- 5 — every scenario has specific inputs + observable outputs; enums and function names match confirmed source; negative and boundary cases use concrete data.
- 4 — most scenarios concrete; one or two loose ("the error is shown") but recoverable.
- 3 — scenarios name actors and actions but omit field values or expected outputs; a test author would read source to fill gaps.
- 2 — predominantly abstract or circular ("the system behaves correctly").
- 1 — no scenarios, or every scenario copies the job-story clause.

---

## D3 — Edge and negative coverage

**Definition.** The scenario set runs 4–6 total; negative, permission, tenant-boundary, and cross-entity cases outnumber happy-path scenarios. Where the domain has multi-tenancy, permissions, or a state machine, at least one scenario of each present type appears.

**Good signal.** A login flow with bad-credentials-without-enumeration, empty-submission client rejection, already-signed-in redirect, session persistence. The happy path is one of four, not the only one.

**Failure mode it catches.** Happy-path tunneling — two or three affirmative scenarios, no rejection test, no tenant or permission boundary. The doc looks complete but leaves the most exploitable and most-frequently-broken behaviors unspecified.

**How to judge (pass / concern / fail).**
- Pass — 4+ scenarios; at least one negative (validation, bad-input, rejection); at least one permission or boundary check if the flow touches auth or tenancy.
- Concern — 3 scenarios or no negative case; acceptable only if the domain genuinely has no permission surface (a purely additive utility flow).
- Fail — only happy paths, or the flow touches permissions/tenancy but no boundary scenario appears.

---

## D4 — NOT_BUILT gaps are specified

**Definition.** Every in-scope path that is NOT_STARTED or only partially built has at least one scenario or explicit narrative note saying what the gap means for the user today. Gaps are never silently omitted.

**Good signal.** "Scenario: Smart scheduling is not yet available" — asserts the form shows no slot-suggestion UI and the booker picks a time manually. This contract stops a future build from treating omission as "no requirement."

**Failure mode it catches.** Silent gap — an author lists a related flow as NOT_STARTED in the inventory but writes zero scenarios for the unbuilt path. Implementers have no spec to test against; QA cannot confirm the absence is intentional.

**How to judge (pass / concern / fail).**
- Pass — every in-scope NOT_STARTED or partial path is either excluded with an explicit out-of-scope note OR has a labeled NOT_BUILT scenario.
- Concern — some gaps noted in prose but no scenario captures the expected degraded behavior.
- Fail — gaps are absent from the doc despite the flow referencing them.

---

## D5 — Honest status annotation

**Definition.** The front-matter `status` carries an inline qualifier when partially true — when the engine ships but the UI doesn't, or a field exists but no surface exposes it. A bare `BUILT` on a flow with significant missing surface is a lie; a bare `NOT_STARTED` on a fully-implemented schema misrepresents the work remaining.

**Good signal.** `status: NOT_STARTED` with `# GET /api/invoices ships + getInvoices query exists; no /invoices route under (app) — office staff cannot reach the list outside the admin`. The comment makes the distinction legible.

**Failure mode it catches.** Status inflation — `BUILT` when only the API layer exists, concealing a build gap from stakeholders who prioritize by status. Also catches deflation (IN_PROGRESS on a shipped flow, causing wasted sprint overhead).

**How to judge (pass / concern / fail).**
- Pass — status matches observable state; when partial, an inline qualifier names which layer ships and which doesn't.
- Concern — status is technically defensible but omits nuance a reviewer would want.
- Fail — status contradicts the narrative or AC content, or is bare when the narrative reveals a partial build.

---

## D6 — Cross-domain boundary clarity

**Definition.** Every out-of-scope item names the owning flow ID or domain — not "out of scope" as a vague deflection. Related flows are identified by ID in the out-of-scope list or cross-references section. Seams between adjacent domains are explicit.

**Good signal.** "Capturing applications during the survey. Owned by SURV; APPT ends at the appointment-detail page's 'Add Application' affordance, which opens the SURV-owned ApplicationFormDialog." The boundary is pinned to a UI affordance and an owner.

**Failure mode it catches.** Boundary drift — out-of-scope items as vague aspirations ("no analytics" / "no bulk operations") with no named owner. Future authors then duplicate or contradict the boundary when writing the adjacent domain's doc.

**How to judge (pass / concern / fail).**
- Pass — every out-of-scope item names the owning flow ID or domain; adjacent-domain seams name specific downstream triggers.
- Concern — most items named but one or two vague; identifiable domain but not a specific flow ID.
- Fail — generic out-of-scope language with no ownership; no cross-references section, or it is empty.

---

## D7 — Behavioral persona

**Definition.** The actor section describes posture, working context, and tolerances — what the person is physically doing, what device they hold, what failure they cannot absorb — not demographics. A behavioral persona predicts how the user reacts to edge cases.

**Good signal.** "The salesperson's working device is a phone or tablet held one-handed in a truck cab or on a front porch; their second device is the office desktop at end of day. They are scoped to their own appointments." This generates testable device constraints and scope expectations.

**Failure mode it catches.** Demographic copy-paste — a single generic block ("Commercial buyer / Newsletter subscriber") repeated across unrelated domains, predicting nothing. Also catches role-only descriptions ("office_staff is the anchor role") that state permission level without explaining behavior.

**How to judge (1–5).**
- 5 — device context, timing/mindset, and what the persona cannot tolerate; predicts testable constraints.
- 4 — device or working context, but no tolerances or mindset.
- 3 — beyond role name but stays abstract ("manages the schedule").
- 2 — role name plus permission level only.
- 1 — copy-pasted from another doc, or absent.

---

## D8 — Mechanical contract summary

**Definition.** A dense blurb — in the opening callout, actor section, or preconditions — states what triggers the flow, what changes in the data layer, and what the user observes as confirmation. Not a design spec; the minimum shared mental model for Story + Eng + QA + Docs.

**Good signal.** "A salesperson or office_staff opens the Appointments page and sees their scheduled visits sorted by start time, with filter chips and pagination, ready to tap into a row." Trigger (opens the page) + data state (visits sorted, filtered by tenant+role) + observable output (chips + pagination rendered).

**Failure mode it catches.** Spec without a contract — five scenarios and a job story but no summary of what the system does. Each discipline reads a different section and builds an incompatible model. The AC and job story together rarely substitute for an explicit trigger-data-observation summary.

**How to judge (pass / concern / fail).**
- Pass — a single callout or intro states trigger + data change + user observation.
- Concern — trigger and user observation present but the data-layer change is implicit or missing.
- Fail — no summary; the reader reconstructs the system model entirely from scenarios.

---

## D9 — Decomposition grain

**Definition.** The flow addresses exactly one actor performing one action against one data surface in one context. Splitting by actor, trigger, or distinct discipline assignment is correct decomposition. Under-decomposition fuses unrelated actors or triggers; over-decomposition clones near-identical docs for one shared pattern.

**Good signal.** Separate flows for "View appointment list" (read path, one surface), "Filter appointments" (filter-chip interaction, distinct trigger axis), "Create appointment" (write path, different mutation). Each is teachable to one discipline team.

**Failure mode it catches.** Under-decomposition — one flow owning "view, filter, create, edit, delete," untestable as a unit. Over-decomposition — six near-identical "Add [Entity] Application" flows sharing one pattern, generating redundant docs. Both inflate the inventory without adding signal.

**How to judge (pass / concern / fail).**
- Pass — maps to one atomic actor-action pair; splitting further or merging with a sibling would not improve clarity.
- Concern — handles two actor perspectives on the same surface (acceptable if the behavioral difference is documented in AC scenarios, not just implied).
- Fail — conflates multiple triggers/actors without differentiating them, or is one of 5+ near-identical siblings with no distinguishing behavior.

---

## D10 — No fabrication

**Definition.** Every file path, symbol, function, collection, column, and metric cited is either confirmed against a code reference or explicitly flagged "TBD" / "per [Eng] child." No invented identifier is presented as traced-to-source.

**Good signal.** Paths formatted as links to real repo paths; function names with line references when precise; honest TBD when the implementation is unconfirmed.

**Failure mode it catches.** Fabricated identifiers — a doc cites `createAppointmentFlow()` or `appointmentService.ts:42` when neither exists. The reader trusts it, the engineer follows it, it is wrong. Invented identifiers look identical to real ones in markdown, so they slip past any review that doesn't `grep` the claim.

**How to judge (pass / concern / fail).**
- Pass — every cited path/symbol resolves to real code or is explicitly marked TBD.
- Concern — one or two identifiers unverifiable but the claim is qualified ("exact column is TBD — capture on the [Eng] child").
- Fail — one or more identifiers stated as confirmed fact but not found in the codebase.

---

## D11 — Right story frame for the flow type

**Definition.** Human-actor flows use the When / I want to / so I can JTBD frame. Infrastructure flows, automated processes, and non-human actors (crawlers, CDN invalidations, cron jobs, webhook receivers, CSP rules) use an engineering-constraint spec frame: "Given [context], the system MUST [behavior], so that [operator/user outcome]."

**Good signal.** An email-confirmation send authored as "Given an appointment is created with status=scheduled AND the tenant has APPT-14 enabled, the system MUST dispatch a templated message within 30 seconds, so that the homeowner receives confirmation before the salesperson ends the call." The actor is the system; the outcome serves a human.

**Failure mode it catches.** Frame mismatch — a cron job or webhook authored as "When I'm a search engine crawler, I want to…" Putting a non-human actor in the first-person job-story frame produces untestable, incoherent ACs and signals the author did not distinguish user-facing from system-facing surfaces.

**How to judge (pass / concern / fail).**
- Pass — human-actor flows use the job-story frame; infra/automated flows use the constraint-spec frame.
- Concern — an infra flow uses the job-story frame but its scenarios are otherwise concrete and testable.
- Fail — an infra/automated flow is forced into a first-person job-story frame and produces circular or untestable scenarios.

---

# Journey dimensions (per domain)

Journey docs sit one layer above story docs: they narrate the arc a persona lives across all the flows in a domain, explain the domain's data substrate, name pain points with root-cause reasoning, and surface actionable opportunities. A journey that merely lists flows and statuses fails; one that gives a reviewer a working mental model of the domain succeeds.

## J1 — Domain substrate clarity

**Definition.** The preamble identifies what the domain owns (primary entity, key fields, state machine if any), what it does not own (upstream triggers and downstream consumers named by domain code), and the scope boundary separating this domain from the next.

**Good signal.** "APPT is the appointment-lifecycle domain bracketing the property visit — it owns scheduling, salesperson assignment, status transitions, outcome capture, but stops short of on-site data capture (SURV territory). The unit of work is one SalesAppointment row tied to one Property and one Client, with a five-state lifecycle (scheduled → in_progress → completed | cancelled | no_show)." Entity, fields, state machine, and boundary in one paragraph.

**Failure mode it catches.** Substrate opacity — narrating the user experience without revealing the data model. Eng and QA cannot reason about the domain and end up re-reading source instead of using the journey as a reference.

**How to judge (1–5).**
- 5 — primary entity with key fields; state machine enumerated; upstream and downstream named by code; scope boundary explicit.
- 4 — entity and state machine present; upstream/downstream named but not pinned to codes.
- 3 — entity named; fields implied by narrative not enumerated; no state-machine summary.
- 2 — functional terms only ("manages invoices"); no entity or state machine.
- 1 — no substrate; the narrative assumes the reader knows what data exists.

---

## J2 — Behavioral persona (journey scope)

**Definition.** Each anchoring persona carries working context (device, moment in the workday, physical/mental state), scope shape (what they see vs don't), and the failure they cannot absorb — not role plus permission level.

**Good signal.** "The office_staff is the dispatcher/scheduler. They handle the inbound call that creates the lead (CLI territory), book the first appointment, and own daily-schedule mechanics — reassigning when someone calls in sick, chasing no-shows, fielding reschedules. Full access: all appointments in the tenant, including the salesperson filter chip. Desktop, treating the list as a Kanban-adjacent workboard." Context, scope, device, and intolerance (ambiguity over slot ownership) all present.

**Failure mode it catches.** Persona copy-paste — a generic block reused across journeys with no behavioral differentiation. A persona that reads identically in the APPT and QUO journeys tells reviewers nothing about either domain.

**How to judge (1–5).**
- 5 — working context (device, moment, state), scope shape, and intolerance, all specific to this domain's surfaces.
- 4 — working context and scope; intolerance implied not stated.
- 3 — beyond role+permission but abstract; no device or moment.
- 2 — role name + permission level only.
- 1 — copy-pasted from another journey, or absent.

---

## J3 — Rich phase narrative with root-cause pain points

**Definition.** Each phase has a named persona mindset, a concrete scenario of what the user actually does (not what features exist), pain points with a root-cause explanation (not "this is annoying"), and opportunities naming a specific design or engineering direction.

**Good signal.** "No conflict detection: a salesperson with two overlapping appointments gets no warning at save. The booker spots it visually." Root cause: no server-side overlap query. Opportunity: "Roll the two createAppointment actions into one canonical implementation; add a conflict-detection query before commit." Cause and specific fix both named.

**Failure mode it catches.** Thin journey — pain points that restate the flow list ("smart scheduling is NOT_STARTED"), opportunities that say "improve the UX" with no direction, phases that summarize feature availability instead of the lived experience. A thin journey reads like an inventory report, not a design brief.

**How to judge (1–5).**
- 5 — every phase has a mindset label, a scenario describing the user's physical/cognitive experience, pain points with named root causes, and opportunities specifying a concrete direction.
- 4 — scenarios and pain points present; root-cause reasoning partial; opportunities directional not specific.
- 3 — scenarios and pain points but root causes implicit; opportunities vague ("ship APPT-13" without naming the v1 scope).
- 2 — phases summarize availability (BUILT / NOT_STARTED lists) without narrative; pain points are feature requests without root causes.
- 1 — no phase structure; a flow-status table with a short intro.

---

## J4 — Cross-domain stitching

**Definition.** The journey names the upstream domain that triggers its start, the downstream domain(s) that consume its output, and the specific seam (a data event, UI handoff, link, or status transition) crossing each boundary. Multi-domain arcs are identified by name.

**Good signal.** "Part of the canonical Sales → Quote → Acceptance scenario spanning APPT → SURV → QUO → QLIFE → CPUB." And: "The 'Create Quote' link on a completed appointment opens /sales/quotes/new with clientId, propertyId, seasonYear pre-filled as URL params."

**Failure mode it catches.** Island journey — a domain described in isolation, no mention of how data enters or where it goes. Adjacent domains listed as "related" with no handoff mechanism. The multi-domain reviewer can't tell where domain A's test responsibility ends and B's begins.

**How to judge (pass / concern / fail).**
- Pass — upstream trigger named with a specific handoff mechanism; downstream consumer named with specific data or UI link; cross-scenario journey name stated if applicable.
- Concern — domains named but handoff mechanisms vague ("feeds into QUO").
- Fail — no upstream/downstream named, or the cross-references list domain codes without explaining the seam.

---

## J5 — Status honesty at domain scale

**Definition.** The domain-level status (front-matter `status` and preamble) reflects the aggregate build state — which layers are built (schema, API, UI, permissions), which partial, which NOT_STARTED. When the journey includes NOT_STARTED flows, the narrative describes what the user experiences today in their absence, not what they will experience when those flows ship.

**Good signal.** "Three Phase-1 flows ship today as wishlist placeholders: APPT-13 (smart scheduling), APPT-14 (auto-confirmation SMS), APPT-15 (Google Calendar sync). None are wired. Their absence is the dominant pain point — the office_staff *is* the SMS, the routing logic, and the calendar bridge."

**Failure mode it catches.** Status conflation — a journey marked `shipped` when 30% of its flows are NOT_STARTED and the narrative doesn't distinguish them; or a phase describing a flow as built when only the schema exists. Stakeholders form a false picture of launch readiness.

**How to judge (pass / concern / fail).**
- Pass — domain status qualified; NOT_STARTED flows identified in the narrative with their user-visible absence described; per-phase tables carry status labels.
- Concern — status plausible but one or two NOT_STARTED flows described in present tense as if built.
- Fail — domain status contradicts the flow-level labels in the per-phase tables, or NOT_STARTED flows are narrated with no gap signal.

---

## J6 — Decision points are explicit

**Definition.** The journey captures meaningful branching logic — where the user's experience diverges by role, data state, or input — as named decision points with the condition stated. This is the domain-level map of "where behavior forks," distinct from story-doc AC scenarios.

**Good signal.** "Status-transition validity. VALID_TRANSITIONS enforces the lifecycle server-side. The matrix is a strict tree: scheduled is the only start state; completed / cancelled / no_show are terminal; no un-completing or un-cancelling." Condition, enforcement layer, and user consequence all named.

**Failure mode it catches.** Hidden fork — a domain with a meaningful state machine or role-based behavior difference never surfaced. A new team member cannot predict what the system does at the branch and must read source. Costly for QA, who needs the fork map to write test cases.

**How to judge (pass / concern / fail).**
- Pass — all meaningful forks named as decision points with condition + enforcement layer + user consequence.
- Concern — major forks mentioned in narrative but not collected into a decision-points section; a careful reader can infer them.
- Fail — a state machine or significant role-based difference is never mentioned; branching is implicit.

---

## J7 — Opportunity specificity

**Definition.** Each phase's opportunities name a specific build direction: what to implement, at what scope (v1 heuristic vs v2 full), and which Linear issue or flow ID tracks it. Opportunities are engineering and design directions a capable team could start from the journey alone — not wishes or complaints.

**Good signal.** "Ship APPT-13 with a proximity-only heuristic in v1: rank candidate slots by driving distance from the salesperson's adjacent same-day appointments. Defer multi-rep optimization to v2." Scope, direction, and deferral all stated.

**Failure mode it catches.** Aspirational bloat — an Opportunities section of "improve this" / "make this faster" / "add notifications," vague enough to mean anything. These survive planning rounds unchanged because no one can act on them without a second design meeting.

**How to judge (1–5).**
- 5 — every opportunity names a direction, a scope boundary (v1 vs deferred), and a tracking reference (flow ID or open question).
- 4 — most specific; one or two directional but not scoped.
- 3 — relevant and meaningful but none scoped or tracked.
- 2 — restates the NOT_STARTED list; no direction.
- 1 — no opportunities section, or identical to the pain-points section.

---

## J8 — Open questions are actionable

**Definition.** Open questions are genuine blocking uncertainties — design decisions, data-model choices, or scope calls unresolvable without human input. Each names who resolves it and what artifact resolves it. Questions answerable by reading source do not belong here.

**Good signal.** "Native Maps deep-link for APPT-17 — maps:// for iOS and geo: for Android, or a Universal Link? Resolves with APPT-17 [Design] / [Eng]." A genuine design choice; the resolver is named.

**Failure mode it catches.** Pseudo-question — one already answerable from source ("Does the API support pagination?" when the route is quoted in the doc showing pagination params). These crowd out real blockers and make the section feel like an uncleaned first draft.

**How to judge (pass / concern / fail).**
- Pass — every open question is a genuine unresolved call; each names a resolver (Linear issue, discipline child, or owner).
- Concern — most genuine; one or two answerable from the codebase but kept as a hedge.
- Fail — questions are predominantly answerable from source, or the section is absent in a domain with known unresolved decisions.

---

## References

- `app-type-profiles.md` (sibling) — the four app-type profile modifiers + how to select one.
- `four-mode-framework.md` (sibling) — the scope-axis outcome contract reviewer agents return; this rubric judges doc substance, that file judges scope recommendation.
- `app-classifier-pattern.md` (sibling) — the inventory-time classifier whose app-category signal feeds profile selection.
- JTBD job-story frame (When / I want / so I can) and PRD acceptance-criteria practice are the governing external sources. BriteBase examples here are one calibration witness, not the required shape.
