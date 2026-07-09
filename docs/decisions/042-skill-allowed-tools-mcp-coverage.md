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

## Alternatives considered

| Alternative | Rejected because |
|---|---|
| Standalone `lint_skill_frontmatter.py` + a new `validate.sh §2b` section + parallel debt file | The ADR-034 structural engine already walks every skill, filters gate findings against `docs/structural-lint-debt.md`, and runs in the REQUIRED CI job. A parallel lint would duplicate the walker, the debt mechanism, and the gate wiring for no gain. |
| Classify on the `sf` CLI / any side-effecting Bash too (the decision's "spirit") | The prose-vs-code trap is fatal: sf-apex/sf-soql show `sf` in *examples* but are code-gen skills — a CLI detector false-mandates them. It also broadens toward "every Bash skill needs `allowed-tools`" and exceeds the recorded decision. The genuine Bash axis is a separate follow-up. |
| Raw-presence mandate on every non-reference skill (the audit's literal numbers) | Blunt over-mandate — forces noise `allowed-tools` declarations onto pure knowledge skills, the exact noisy/toothless failure this rule must avoid, and would demand backfilling ~36 skills (version bumps). |
| `user-invocable: false` as the exempt signal | All 14 revops skills carry it — it would exempt precisely the set the audit worried about. Tool-invocation, not invocability, is the correct axis. |
| Enforce the `metadata:` block shape too | The per-plugin divergence encodes real upstream provenance (ADR-007); normalizing it erases information and closes no security gap. |
