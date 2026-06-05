# Brite Plugins — Context

Glossary for the Brite plugin bundle. Captures terms that are easy to confuse
across the bug-reporting / feedback / triage surface area and the Brite product
landscape they route into. Glossary only — no implementation details.

## Language

### Reporting & feedback

**Product**:
A shippable Brite software surface that a report can be filed against — e.g.
Brite Base, Brite Sites, Brite Supply (Web Platform + PIM), a Brite Labs site.
Each Product resolves to exactly one Linear destination (team + project) and
zero or more GitHub repos. This is the report *target* of the feedback command.
_Avoid_: app, site, build (when you mean the thing being reported on, say Product)

**Build Project**:
An existing Brite Linear taxonomy term — a Linear Project whose Type is
"Build Project" (as opposed to "Workstream" or Field-Ops), sized S/M/L and
governed by the appetite gate. NOT a synonym for Product: a Product is reported
*against*; a Build Project is a unit of planned work. The feedback command keys
off Product, not this type.
_Avoid_: using "build project" to mean "a product we ship" — that's a Product

**Report target**:
The Product a given report is filed against, resolved repo-context-first:
inside a known Product repo it is assumed; otherwise it is guessed and then
confirmed with the reporter (by Product name or GitHub repo).

**Report kind**:
The two reporter-facing buckets intake offers — a **Bug** (something is broken)
or an **Idea/Feedback** (a request, improvement, or UX observation). Bug →
`type:bug` (CDR-016 requires a Reproduction section); Idea/Feedback → `type:task`,
the CDR-016 default for non-bug work. These are intake buckets, not the whole type
axis: CDR-016 also defines `type:spike` / `type:chore` / `type:doc`, which the
triage stage may re-type to. Both kinds enter triage via `needs-triage`.
_Avoid_: "feature request" / "enhancement" as a distinct Brite type — that is an
Idea/Feedback (`type:task`); and don't call Bug/Idea "the two CDR-016 types"
(there are five)

**Severity (of a Bug)**:
Per CDR-018 the canonical signal is the `severity:sevN` label (sev0–sev3, required
on `type:bug`, default sev2). Linear **priority** (Urgent/High/Normal/Low) is a
parallel native-field signal, not a replacement. Asked for Bugs only. Intake
applies `severity:sevN` when that label group exists in the target team (and sets
priority too); where the group isn't provisioned yet (CDR-018 is mid-rollout),
priority carries it in the interim.
_Avoid_: claiming priority replaces `severity:*` — they are distinct axes

**Intake**:
The act of getting a report onto the tracker as a well-formed issue. The
`/workflows:raise-a-ticket` command is the single **front door**: it first asks
whether the report is about a **Brite Product** or the **agent tooling itself**
(a skill/command/hook), then routes. The **product** branch produces a thin
`needs-triage` issue — routing, the Bug/Idea fork, canonical labels, duplicate
check, secret redaction, draft preview — and hands deeper work to Triage. The
**agent-tooling** branch hands off to `/workflows:report-issue`, which classifies
the misbehavior and generates a regression test; `report-issue` is also reachable
directly as an expert alias. Both branches enter through the one door.
_Avoid_: doing reproduction, grilling, or agent-brief writing during product Intake
(that is Triage's job); and don't call the agent-tooling branch "a kind of product
feedback" — it is tooling misbehavior, a distinct branch of the same door

**Triage**:
The downstream, maintainer-facing stage (the `/triage` skill) that moves an
existing issue through the state machine (`needs-triage` → `needs-info` /
`ready-for-agent` / `ready-for-human` / `wontfix`), reproducing bugs, grilling
for detail, and writing the Agent Brief. Distinct from Intake.

**Ticket**:
The reporter-facing word for what `/workflows:raise-a-ticket` files — a single
Linear issue (Bug or Idea/Feedback) created during Intake. "Raise a ticket" is
the action; the artifact is a normal Linear issue. There is no separate
ticketing system.
_Avoid_: implying "ticket" is a different object type than a Linear issue
