# Brite Claude Plugins

Brite's Claude Code plugin monorepo — process, org, and domain plugins under `plugins/`. This glossary fixes the vocabulary for concepts that recur across plugins and are easy to conflate. It is a glossary only: no implementation detail, no architecture — those live in `docs/decisions/` (ADRs).

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

### Agent tooling & evaluation

> Terminology for how we build and test the plugins themselves (per [ADR-028](docs/decisions/028-skill-engineering-discipline.md)). These were conflated before, which produced false confidence ("tests pass" on a command that never ran).

**Skill**:
A `SKILL.md` (+ optional bundled files) the model loads on demand to perform a
reusable task. Activated by its `description`. In current Claude Code, **custom
slash commands are merged into Skills** — `.claude/commands/x.md` and
`.claude/skills/x/SKILL.md` both create `/x` and behave the same way.
_Avoid_: treating "command" and "skill" as different runtime mechanisms — they're
the same thing; "command" = the slash-invoked framing of a skill.

**Command**:
A slash-invoked skill (`/plugin:name`). Used for operator-triggered, often
side-effecting actions. See Skill.
_Avoid_: implying a command has a separate execution model from a skill.

**Plugin**:
A versioned, namespaced bundle of skills/commands/agents/hooks/MCP servers
distributed via the marketplace. Identity = its `name`, which is also the skill
namespace (`/<name>:<skill>`).

**Subagent**:
An agent that runs in its own context window and returns only a summary. Used to
keep verbose side work out of the main context. One subagent = one task.

**Hook**:
A deterministic enforcement mechanism that fires on an event (e.g. PreToolUse).
The "must-do" lever — reliable where a prose instruction is merely suggestive.
_Avoid_: relying on prose in a skill to GUARANTEE a critical behavior — that's a
should-do; use a hook.

**Structural test**:
A check that greps the spec text, checks a file exists, or lints frontmatter. It
proves the *prose*, not the behavior. Useful for drift, but passing it says
nothing about what the command produces.
_Avoid_: calling a structural markdown-grep a "test" of behavior.

**Behavioral eval**:
The only check that proves behavior: it fixtures inputs, runs the command in
**emit mode**, and asserts on the **produced artifact** (schema + key fields +
golden compare). This is what "is it sound?" actually requires.

**Unit test**:
A test of a deterministic helper's (python/bash) logic. Legitimate and valuable,
but it tests the *gadget*, not the command's behavior.
_Avoid_: counting helper unit tests as behavioral coverage of a command.

**Emit mode**:
A command's side-effect-free run: computes and writes all its artifacts
(`manifest.json`, issue payloads, copy JSON, …) to a sandbox temp dir, making
**no external MCP writes** (no real Linear/SF/EB mutations). The testable seam a
behavioral eval runs against.
_Avoid_: conflating emit mode with the legacy `--dry-run`, which exits before the
artifacts are written.

**Gate**:
A *blocking* CI check (fails the build). Distinct from an **advisory lint**
(WARN only). Per ADR-028, a small set of checks are gates; the rest are advisory
until promoted — one rule at a time, via the BC-12700 ratchet.
_Avoid_: conflating a **Gate** (a check) with a lint **finding** whose `severity`
is `gate` (a tier). The structural lint (`scripts/eval/structural_lint.py`) never
fails a build itself — it computes findings; `eval_gate.py` is what enforces the
`gate`-tier ones: on changed commands (the diff-gate) and across the whole surface
(the full-surface structural gate, ADR-034). Output labels gate-tier findings
`[gate-tier · blocking via eval-gate]`.

**Full-surface structural gate**:
The diff-free enforcement surface for promoted structural rules
(`eval_gate.py --structural`, ADR-034): lints every command + SKILL.md spec and
fails on any gate-tier finding not covered by the structural-debt list. A second
step in the REQUIRED eval-gate CI job. Full-surface because skills never appear
in the diff-gate's changed-set and an R4 nested-refs regression can be introduced
by editing a bundled reference file no spec-file diff would show.
_Avoid_: calling it "the diff-gate" — that is the per-changed-command mode; the
two coexist in one CI job.

**Structural-debt list**:
`docs/structural-lint-debt.md` — the per-rule grandfather record for promoted
structural rules, rows keyed `(file, rule)` (a file can be grandfathered for one
rule and gated on the rest). R2 rows pin a body line-count **baseline** (growth
past it blocks); a row with no live finding is stale and fails the gate.
_Avoid_: conflating it with `docs/skill-eval-debt.md`, which is command-level
*eval* debt — a different axis with different invariants.

**Fixture / Golden file**:
A fixture is a canned input for an eval; a golden file is the expected artifact
the eval compares the produced one against.
_Avoid_: calling `evals/evals.json` "evals" — they are deprecated, non-executing
seed specs (ADR-028 D3), not runnable behavioral evals.

### Salesforce / RevOps

**revops**:
The Salesforce **engineering** layer — a portable plugin bundling SF dev knowledge (skills), deploy discipline (commands), and the org MCP, usable from any repo. Its charter is concerns 1–2 only: SF knowledge + deploy/ops discipline. The CRM-write surface it also hosts (`create-sf-campaign`, `update-sf-campaign-status`) is a **GTM seam owned by `marketing`**, implemented here as commands per [ADR-015](docs/decisions/015-gtm-sigma3-sf-campaign-sync.md) — not part of revops's core identity.
_Avoid_: "the Salesforce plugin" (revops scopes to the revenue-ops function, not one tool — [ADR-007](docs/decisions/007-revops-plugin-design.md) §3.1); "RevOps seat" (was the withdrawn `revenue-rhythm` L10 plugin, not this).

**brite-salesforce**:
Brite's live Salesforce DX (SFDX) metadata **repository** (`github.com/Brite-Nites/brite-salesforce`) — the thing deploys actually ship to. Its own `CLAUDE.md` is the authoritative source for Brite deploy discipline; `revops` mirrors that discipline outward so agents in other repos inherit it. Authority is one-way: brite-salesforce defines, revops reflects.
_Avoid_: "bn-salesforce" (only a local clone's folder name); "the SF repo".

**brite-sandbox / brite-prod**:
The two Salesforce **org aliases** revops commands target. `brite-sandbox` is the deploy/validation target; `brite-prod` is production. Commands always pass `--target-org` explicitly — never the CLI default org. Under the promotion topology, `brite-sandbox` is being renamed **`brite-integration`** (its role becomes the CI-deployed Integration org) — see **Integration (org)**.
_Avoid_: "the org", "default org" (revops never relies on an implicit default).

**Integration (org)**:
The CI-deployed persistent org at the first stage of the promotion topology — the shared target the pipeline rebuilds from `main` on merge, replacing the manual shared-sandbox model. In Phase 1 this is the `bndev` org repurposed; its alias migrates `brite-sandbox` → `brite-integration` ([ADR-026](docs/decisions/026-revops-promotion-topology.md); bn-salesforce ADR-016).
_Avoid_: "the sandbox" — ambiguous now that Integration, UAT, and per-dev orgs are all sandboxes.

**promotion · push · deploy** (keep distinct):
**promotion** = advancing a change up the environment chain (e.g. integration → uat → prod); the order is the topology's invariant. **push** (as in `push-to-production`) = the human command that *triggers* a prod promotion — CI performs the actual deploy. **deploy** = the machine action CI runs. The human promotes/pushes; CI deploys.
_Avoid_: calling the human action "deploy" — under the CI-driven topology the human no longer deploys.

**emergency path**:
The sanctioned break-from-normal route to production (`emergency-deploy-to-production`) — re-triggers the *enforced* CI deploy rather than bypassing it.
_Avoid_: "break-glass" (jargon/idiom — superseded; see the naming convention in [CONTRIBUTING.md](CONTRIBUTING.md)).

**config-gated guardrail**:
A revops guidance/guard mechanism (status line, advisory nudge, pre-flight) that reads a repo-local pipeline config and stays silent where it is absent — so the portable `revops` plugin carries the *capability* while a repo's config *activates* it ([ADR-026](docs/decisions/026-revops-promotion-topology.md)).
_Avoid_: hardcoding brite-salesforce branch names into revops — that breaks portability ([ADR-007](docs/decisions/007-revops-plugin-design.md) §3.1).

**driver · knowledge skill**:
The two halves of the revops skill surface, split by **who runs the command**. A **driver**'s own `SKILL.md` body tells the agent to run something — `sf`, or a bundled script — as a step in its own procedure, wherever the command text happens to sit: inline, in a fenced block, or in a bundled reference the body points the agent to. A **knowledge skill** instead produces an artifact (code, XML, queries, diagrams) or delegates execution to a named sibling skill. Reachability is transitive: a script a `references/` file invokes counts, because the body's Reference Map is part of the procedure. Only drivers are in scope for a least-privilege `allowed-tools` grant ([ADR-042](docs/decisions/042-skill-allowed-tools-mcp-coverage.md) § Amendment BC-16866).
_Avoid_: inferring the split from where `sf` text appears — a skill can direct execution without printing the command, and can print one it never runs (that mistake is what the BC-16866 amendment corrects); reading only `SKILL.md` and stopping, which under-counts every reference-invoked bundled script; and reading "driver" as "reaches an org" — the two axes diverge (`sf-docs` executes, against web docs only).

### Marketing / launch-campaign

> Email-duplicate vocabulary for `/marketing:launch-campaign`. "Dedup"/"duplicate"
> already names several unrelated things in the upload flow; these two fix the
> email-level cases so they never get conflated (BC-14044).

**Input-list dedup**:
Collapsing repeated email addresses *within a single input CSV* to one lead
before upload — case-insensitive, first occurrence kept, the rest set aside to
the skipped-contacts file. A pre-flight pass (Phase 1) that exists because
EmailBison's `POST /api/leads/multiple` silently keeps only the first of a
within-batch repeat (HTTP 201, no error, the dropped rows vanish from the
response) — so the drop happens regardless; doing it client-side makes it visible
and keeps lead-count reconciliation honest.
_Avoid_: confusing it with **Workspace collision** (that's against EB's *existing*
leads, not your file); with **unique-per-lead** (varies merge values, removes
nobody); with the Phase 5 campaign-name duplicate guard (duplicate campaign
*names*); or with the Phase 6 cross-campaign / parallel-send skip (a lead already
in *another campaign*).

**Workspace collision**:
An input email that *already exists as a lead in the target EB workspace*.
`POST /api/leads/multiple` is atomic and non-upserting, so a single collision
returns HTTP 422 and rejects the whole chunk (verified BC-11072). Handled
reactively (Phase 4): on the 422 the command identifies the colliding emails,
sets them aside (skipped-contacts file, reason `workspace_collision`), and asks
before re-uploading the remainder.
_Avoid_: calling it "duplicate" unqualified — it is specifically
*already-in-workspace*, distinct from **Input-list dedup**'s within-file case;
and don't assume EB skips or upserts the collision — it hard-fails the whole batch.
