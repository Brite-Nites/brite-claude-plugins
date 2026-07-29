# 042. Skill frontmatter contract + `allowed-tools` coverage gate (R8, MCP-invocation classifier)

**Status:** Accepted
**Date:** 2026-07-08
**Linear:** [BC-16387](https://linear.app/brite-nites/issue/BC-16387) (audit 2026-07-05 · task 2.2) under [BC-16394](https://linear.app/brite-nites/issue/BC-16394)
**Related ADRs:** [ADR-028](028-skill-engineering-discipline.md) (skill-engineering discipline this extends), [ADR-034](034-structural-ratchet-full-surface-gate.md) (the full-surface structural gate + `(file, rule)` debt list R8 plugs into), [ADR-007](007-revops-plugin-design.md) (augment-not-replace — the revops upstream subtree at the centre of the premise correction below)

> **ADR numbering:** claimed as 042 per CDR-025. 035 was free on `main` but held by an unmerged branch (`035-campaign-lifecycle-eb-draft-staging-boundary.md`); 036–041 are taken. 042 is the lowest number free on `main` and unclaimed across all branch history at claim time.

## Context

The 2026-07-05 repo audit (`docs/audits/002-repo-audit-2026-07-05.md` § Architecture + Theme 4) flagged that skill frontmatter diverges per plugin along two axes:

1. **`allowed-tools` coverage** — raw presence by plugin: flow-architecture 11/11, marketing 14/18, cadence 2/2, workflows 5/24, **revops 1/14**. A skill with no `allowed-tools` inherits **unrestricted** tool access — a least-privilege gap.
2. **metadata-block shape** — revops `metadata:{version,author,upstream,scoring}` + top-level `license`; marketing `metadata:{version,category,upstream}`; flow-architecture adds `disable-model-invocation` + q-locks; workflows/cadence flat.

The recorded HITL decision (BC-16387 comment, 2026-07-08) was to **mandate `allowed-tools` for tool-invoking skills, exempt pure-reference skills**, and enforce it forward-only with an ADR-034-style debt file — on the stated premise that "revops 1/14 is drift, not a deliberate exemption" for "revops skills that deploy metadata / run Apex."

**Building it surfaced a factual correction to that premise.** Measured across all 69 skills at `dee2814f`:

- **Zero skills** reference a `mcp__…` tool in their body while lacking `allowed-tools`. Every skill that actually invokes an MCP tool (e.g. `marketing/email-bison`, the 5 tool-driving workflows skills) **already declares `allowed-tools`**. The genuine least-privilege gap — an MCP-invoker with unrestricted access — is **empty**.
- The **revops SF skills invoke no MCP tool**. They are either knowledge/code-generation skills (sf-apex "generates & reviews Apex, 150-pt scoring"; sf-soql "SOQL generation"; sf-docs "doc-retrieval guidance") or they shell out to the **`sf` CLI via Bash** (sf-deploy has 31 `sf` mentions, zero `mcp__` tokens). On the MCP axis they correctly need no `allowed-tools`.
- **`user-invocable: false` is not a usable exempt signal** — all 14 revops skills carry it, so keying exemption on it would exempt exactly the set the decision meant to catch.

So the audit's coverage table measures raw *presence*, which conflates "declares `allowed-tools`" with "should declare it." The real drift on the MCP axis is nil; revops's low count is mostly legitimate exemption (knowledge skills), and the `sf`-CLI-driving skills are a **Bash least-privilege axis** the decision did not actually address.

## Decision

**One frontmatter contract, one new gate rule, MCP-invocation as the classifier.**

1. **Contract (documented in `docs/guides/skill-command-design-standards.md`).** Frontmatter keys: `name` (must match the skill dir, validate.sh §7/§8), `description` (required, third-person — R3), optional `user-invocable`, `disable-model-invocation`, `allowed-tools`, `license`, and a `metadata:` block. **The `metadata:` block shape is legitimately per-plugin** (upstream provenance differs — revops carries `upstream`/`scoring` from the `Jaganpro/sf-skills` subtree per ADR-007; marketing carries `category`) and is **document-only, not linted** — normalizing it would erase real provenance and buy nothing.

2. **`allowed-tools` is mandatory for a skill that invokes an MCP tool.** "Invokes an MCP tool" = the `SKILL.md` **body** references a fully-qualified `mcp__…` name (the same name shape R5 validates). This is a **presence** mandate (declare *some* `allowed-tools`), not a coverage check that the declared set matches the tools used — the stronger check, plus cross-validating declared servers against `.mcp.json`, is deferred (see Consequences). Pure knowledge/reference skills that invoke no tool are **exempt**; declaring `allowed-tools` on them would be noise.

3. **Enforced as R8 in the existing structural-lint engine, skills-only, gate-tier.** `rule_r8_allowed_tools_required` joins a new `SPEC_RULES_SKILL_ONLY` list in `scripts/eval/structural_lint.py` (symmetric with R1's command-only list). Detecting invocation from static text can't distinguish a real call from a documentation *mention*, so — exactly like R1 — a non-silent `# lint:no-mcp-invocation <reason>` marker (via the canonical `parse_marker`) downgrades the gate to advisory. R8 is **skills-only**, mirroring R4's enforcement model: the changed-set diff-gate is commands-only (`COMMAND_GLOB`) and never sees skills, so R8 is enforced full-surface by `eval_gate.py --structural` (ADR-034) alone — no per-rule wiring in `eval_gate.py`, it flows through `lint_spec` → `scan_surface` automatically.

4. **The skill surface is clean at flip time (0 R8 findings), so R8 carries no `docs/structural-lint-debt.md` rows.** Its value is **forward-only**: it blocks a *future* MCP-wired skill that ships without `allowed-tools`. Introducing a net-new gate rule with a clean surface is consistent with ADR-034's "a rule flips to gate only after its surface is clean or grandfathered" — R8 is net-new, NOT part of the completed R2–R6 ratchet.

5. **Commands are out of scope for this rule.** 16 commands invoke `mcp__…` tools in-body without `allowed-tools` (e.g. `workflows/ship`, `flow-architecture/review`) — some genuine invocations, some orchestrators naming tools only to specify **subagent dispatch**. Distinguishing those is a per-command triage of its own, filed as a follow-up; the existing `[ADV] allowed-tools scoped` guidance for commands (standards § 3) stays advisory.

## Consequences

- **No version bump.** The change touches only `scripts/eval/` + `docs/` — nothing under `plugins/<p>/{skills,commands,agents,hooks}/`. The forward-only-with-debt design is precisely what avoids backfilling `allowed-tools` into skill files (which *would* touch `plugins/*/skills/` and trigger per-plugin bumps). **Do not backfill; the mandate is prospective.**
- **The audit's revops "1/14 = drift" framing is corrected, not fixed.** Most of that 14 is legitimate exemption. Two real follow-up gaps remain, filed separately: (a) the **`sf`-CLI Bash least-privilege** axis for revops skills that drive deploys/queries; (b) the **16 command** MCP-without-`allowed-tools` gaps (triage genuine-vs-subagent-spec, then gate/grandfather). A third optional follow-up: promote presence → **coverage** (declared `allowed-tools` ⊇ invoked tools) + the `.mcp.json` cross-check (a skill listing an unregistered server fails silently at runtime — `docs/gotchas.md`).
- **A false-positive path exists and is handled non-silently.** A future skill that *documents* an `mcp__…` name without invoking it (e.g. a skill teaching MCP conventions) trips R8; the author clears it with a reasoned `# lint:no-mcp-invocation <reason>` marker rather than a debt row. An empty marker does not suppress (a silent-bypass attempt raises its own advisory) — the same discipline as R1.
- **R8 is high-precision, partial-recall — a documented limitation.** The classifier keys on a full `mcp__…` path in the body, which is an unambiguous invocation. But the skill-tool-integration guide (`docs/guides/skill-tool-integration-pattern.md` § PR checklist) prescribes *bare semantic* tool names in bodies (`list_teams`, not the `mcp__` path); a bare name is indistinguishable from prose without a per-server tool inventory, so R8 cannot detect a bare-name invoker that omits `allowed-tools` (only review catches that). Broadening to bare names would be hopelessly false-positive (words like `query`/`search`/`get_issue` appear in prose). Measured: of 33 skills that declare `allowed-tools`, 12 name full `mcp__` paths in-body (the pattern R8 gates going forward) and 21 use bare names (R8-silent, and correctly so — they already declare `allowed-tools`). R8 gates the detectable pattern; it does not claim total recall.
- **R8 is enforced by the REQUIRED eval-gate job** (`eval_gate.py --structural`) and `validate.sh §15a`, so a new violation blocks the PR that trips it even in a merge race — the standard ADR-034 trade-off, and the fix is local.

## Amendment 2026-07-29 (BC-16865) — R8 graduates to the command surface

Decision item 5 above deferred commands, on the stated expectation that the 16
MCP-referencing commands were a mix — "some genuine invocations, some orchestrators
naming tools only to specify **subagent dispatch**" — and that separating them was a
per-command triage.

**That triage ran, and the mixed premise did not survive it. All 16 are genuine direct
invocations; zero are subagent tool-specs.** Every hit reads as an instruction to the
command itself — `Call mcp__…`, `Use mcp__…`, `Query mcp__…`. The flow-architecture
orchestrators, the suspected subagent-spec class, are the most explicit of all: they say
"**the orchestrator** owns the `LINEAR_ISSUE_COUNT` env-var … Call the Linear MCP
`mcp__plugin_workflows_linear-server__list_issues` … **before dispatching the skill**."
`cadence/weekly` makes the distinction itself, contrasting its own paginated Linear call
with the `Agent` fan-out it runs alongside. This is the same shape as the revops premise
correction in Context above: the deferral was sound, its stated reason was not.

Since there is no second class to separate, the mandate is identical on both surfaces:

1. `rule_r8_allowed_tools_required` moves from `SPEC_RULES_SKILL_ONLY` to
   `SPEC_RULES_ALL`. The finding message now names the surface it fired on
   (`command body invokes…` / `skill body invokes…`); a command finding that said
   "skill" would send the reader to the wrong file type. `SPEC_RULES_SKILL_ONLY` is
   kept but empty, so the next skills-only rule is a one-line append.
2. **All 16 current gaps are grandfathered** as `(file, R8-allowed-tools-required)`
   rows in `docs/structural-lint-debt.md`. Value is forward-only — the 17th
   MCP-invoking command cannot ship without `allowed-tools`.
3. **No `# lint:no-mcp-invocation` markers were added to command bodies.** That would
   edit `plugins/*/commands/**` and force three plugin version bumps (cadence,
   flow-architecture, workflows) inside a lint change — and the markers would be
   *wrong*, since every one of these is a real invocation, not a documentation mention.
   Debt rows carry the exemption instead; the marker path stays for genuine mentions
   (a command fixture covers it).
4. **Still no version bump** — `scripts/eval/` + `docs/` only, for the same reason
   decision item 4 gives.

Actually closing the gaps — adding real least-privilege `allowed-tools` to the 16 — is
deliberately *not* this change: it is a per-plugin pass that carries version bumps and
per-command judgment about which tools each genuinely needs. It is tracked separately, and
the debt rows are the ledger for it.

## Amendment 2026-07-29 (BC-16866) — the revops `sf`-CLI Bash axis, classified

Context above established that revops SF skills invoke **no** MCP tool, so R8 correctly
does not cover them, and that the genuine least-privilege question for them is a **Bash
axis**: a skill that runs `sf project deploy` with no `allowed-tools` inherits
unrestricted tool access. This amendment records the audit that question needed, and
separates the classification (settled here) from the frontmatter change (deliberately
not made here — see § Why the frontmatter change is a separate step).

### Method: fenced-code invocation in the SKILL.md body, not raw mentions

The trap the follow-up named is real — `sf-apex` and `sf-soql` *display* `sf` commands in
examples while being code generators, so any "mentions `sf`" test false-mandates them.
The criterion used is **`sf` invoked at the start of a line inside a fenced code block of
the `SKILL.md` body**, counted separately from raw mentions anywhere in the body.

**Scope limitation, stated because it changes how much the counts prove:** this scans
`SKILL.md` bodies only, not the bundled `references/*.md` those bodies progressively
disclose. Scanning the references too finds fenced `sf` invocations in **8 of the 9**
skills classified as knowledge — `sf-metadata` 87, `sf-soql` 38, `sf-testing` 36,
`sf-connected-apps` 20, `sf-apex` 19, `sf-integration` 16, `sf-permissions` 6,
`sf-diagram-mermaid` 5.

That does **not** flip the classification, and the reason matters: those hits concentrate
in files named `cli-reference.md`, `cli-commands.md`, `field-and-cli-reference.md` —
lookup tables *documenting* the CLI for a human or for code generation. Treating them as
invocation is the prose-vs-code trap one level deeper: reference material about a CLI is
the single most likely place for a command to appear without anyone running it.

What it does mean is that the counts below bound *the skill's own procedure*, not
everything an agent might encounter while following it — so a classification for any
skill whose references are CLI-heavy should be confirmed by a run, not by the number.
`sf-testing` is the sharpest case: 36 fenced invocations across its references,
25 of them in `references/cli-commands.md`.

### Classification of all 14 skills

**`sf`-CLI drivers (5)** — execute `sf` in fenced blocks:

| Skill | fenced `sf` | `sf` verbs | other shell |
| -- | -- | -- | -- |
| `sf-deploy` | 18 | `apex`, `data`, `org`, `project` | `references/deploy.sh` (bundled) |
| `sf-debug` | 4 | `apex`, `data` | — |
| `sf-flow` | 3 | `flow` | — |
| `sf-lwc` | 3 | `lightning` | — |
| `sf-data` | 1 | `sobject` | `jq` |

**Knowledge / code-generation (9)** — zero fenced `sf` invocations, correctly exempt:
`sf-apex`, `sf-connected-apps` (already declares `allowed-tools`), `sf-diagram-mermaid`,
`sf-docs`, `sf-integration`, `sf-metadata`, `sf-permissions`, `sf-soql`, `sf-testing`.

**Flagged for a second look during the hardening pass.** Five of the nine also mention
`sf` in inline backticks inside gotcha/knowledge prose — `sf-testing` ("Live tests via
`sf apex run test --wait 10 --target-org <alias>`"), `sf-metadata`, `sf-integration`,
`sf-apex`, `sf-permissions` — and, per the scope limitation above, eight of the nine carry
fenced `sf` in their references. The fenced-SKILL.md criterion reads all nine as
knowledge, which is the defensible call.

#### `sf-testing` — resolved, and why it needs no declaration

It is the one knowledge skill whose *subject matter* is CLI execution, so it deserves an
explicit answer rather than a flag. Its `SKILL.md` is structured as **nine numbered
conventions** under "Brite Test Discipline" (coverage targets, `@TestSetup` static-state
semantics, Queueable re-entry, `@TestVisible` gates) — a discipline document, not a
procedure. Both `sf` mentions are descriptive, not imperative: § 8 documents what *CI* does
("Scratch-org-per-PR validates deploys before merge. Live tests via `sf apex run test …`"),
and § "When This Skill Owns the Task" lists "`sf apex run test` workflows" as a **routing
trigger** — the skill's activation criteria, not a step it performs. Its 25 fenced
invocations live in `references/cli-commands.md`, a lookup table.

So: **knowledge, and it receives no `allowed-tools` declaration.** That is the safe
resolution by construction, not a deferral — a skill with no declaration is *unrestricted*,
exactly today's behavior, so it cannot be broken by an under-enumeration. The risk here runs
one way only: adding a too-narrow declaration to a CLI-adjacent skill breaks it, while
adding none preserves the status quo. `sf-testing` is therefore **explicitly out of scope
for the hardening pass** until someone dogfoods it and demonstrates the skill itself
executing `sf` — which BC-17743 carries as a blocking criterion, not a note.

The same reasoning covers the other four inline-mention skills: no declaration, no
restriction, no breakage, and no false claim of least privilege where none was applied.

### Two premises corrected

1. **Restricted `Bash` IS expressible and already precedented here.** The follow-up
   framed `allowed-tools: Bash(sf:*), Read` as hypothetical. In-tree precedent already
   exists: `workflows/agent-browser` declares `Bash(agent-browser:*)`, and
   `workflows/{setup-claude-md, post-plan-setup}` declare `Bash(find:*), Bash(cat:*),
   Bash(ls:*)`. So a meaningful scoping is available — a bare `Bash` grant, which is what
   `revops/sf-connected-apps` and every flow-architecture/cadence skill declare, would be
   presence without least privilege.
2. **`Read` is required by all five drivers, though only `sf-lwc` says so.** Each leans
   on bundled `references/*.md` for progressive disclosure — 16 to 38 mentions apiece — so
   an enumeration derived only from explicit tool names would under-grant and break them.

### Why the frontmatter change is a separate step

**No gate in this repo can verify an `allowed-tools` restriction.** `validate.sh` checks
its *format* (§ `allowed-tools` format) and R5 checks that MCP names are fully qualified;
neither can tell whether a declared set is sufficient for what the body actually does. An
under-enumeration therefore fails at **agent runtime**, silently, on the Salesforce deploy
path — and `sf-deploy` is the worst case: 18 invocations across four `sf` verbs plus a
bundled `references/deploy.sh`, so a `Bash(sf:*)`-only grant would break it. (Its mention
of `scripts/prepare-scratch-deploy.sh` is **not** a bundled script and not something this
skill runs — SKILL.md:283 names it as `brite-salesforce/scripts/…`, invoked by that repo's
GitHub Actions workflow. Out of scope for this skill's grant.)

That makes the frontmatter edit a dogfood-gated change, not a static one: each driver
needs one real run against an org after its declaration lands. It is filed as a follow-up
carrying this enumeration, so that work starts from the audit rather than repeating it.
This amendment is docs-only and carries no version bump; the frontmatter change will carry
a revops bump when it lands.

**No lint rule** is proposed, per the follow-up's own reasoning: a static detector for
"drives the `sf` CLI" is the prose-vs-code trap in rule form. The fenced-code criterion
above is good enough for a one-time audit by a human reader, and too brittle to gate on.

## Alternatives considered

| Alternative | Rejected because |
|---|---|
| Standalone `lint_skill_frontmatter.py` + a new `validate.sh §2b` section + parallel debt file | The ADR-034 structural engine already walks every skill, filters gate findings against `docs/structural-lint-debt.md`, and runs in the REQUIRED CI job. A parallel lint would duplicate the walker, the debt mechanism, and the gate wiring for no gain. |
| Classify on the `sf` CLI / any side-effecting Bash too (the decision's "spirit") | The prose-vs-code trap is fatal: sf-apex/sf-soql show `sf` in *examples* but are code-gen skills — a CLI detector false-mandates them. It also broadens toward "every Bash skill needs `allowed-tools`" and exceeds the recorded decision. The genuine Bash axis is a separate follow-up. |
| Raw-presence mandate on every non-reference skill (the audit's literal numbers) | Blunt over-mandate — forces noise `allowed-tools` declarations onto pure knowledge skills, the exact noisy/toothless failure this rule must avoid, and would demand backfilling ~36 skills (version bumps). |
| `user-invocable: false` as the exempt signal | All 14 revops skills carry it — it would exempt precisely the set the audit worried about. Tool-invocation, not invocability, is the correct axis. |
| Enforce the `metadata:` block shape too | The per-plugin divergence encodes real upstream provenance (ADR-007); normalizing it erases information and closes no security gap. |
