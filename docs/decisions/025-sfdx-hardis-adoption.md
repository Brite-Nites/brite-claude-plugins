# 025. sfdx-hardis: selective adopt-as-tool

**Status:** Accepted
**Date:** 2026-06-02
**Linear:** [BC-12346](https://linear.app/brite-nites/issue/BC-12346) (keystone child of [BC-12345](https://linear.app/brite-nites/issue/BC-12345))
**Decided by:** Kells Nixon (driving), **Holden Halford (lead/owner) co-signing** — both present for the 2026-06-02 deploy-integrity session.
**Related:** [ADR-007](007-revops-plugin-design.md) (revops design), [ADR-009](009-sf-capability-adoption.md) (the 6-check this ADR runs), [ADR-015](015-gtm-sigma3-sf-campaign-sync.md); `CONTEXT.md` (authority arrow); `brite-salesforce/CLAUDE.md` (private, authoritative deploy discipline).

## Context

The deploy-integrity epic ([BC-12345](https://linear.app/brite-nites/issue/BC-12345)) found Brite's Salesforce deploy foundation strong (git source-of-truth, PR/branch discipline, source format, validate-before-prod instinct) but structurally gapped: one shared `brite-sandbox` doing three jobs, human-checkbox correctness gates, no drift/back-promotion, no scripted data-migration reconciliation. The motivating incident is the Podium load reaching prod with silently-empty `Message_Content__c` *despite* a genuine sandbox visual check ([BC-12200](https://linear.app/brite-nites/issue/BC-12200) / [BC-7424](https://linear.app/brite-nites/issue/BC-7424) / [BC-11888](https://linear.app/brite-nites/issue/BC-11888)) — a human check is a *sample* + a *proxy*, not a population-level assertion.

[sfdx-hardis](https://github.com/hardisgroupcom/sfdx-hardis) (an `sf` CLI plugin by Cloudity / Nicolas Vuillamy, AGPL-3.0) provides, out of the box, much of what the epic would otherwise build: delta/smart deploy, CI/CD pipeline generation, monitoring + drift detection, validate→quick-deploy, SFDMU-backed data migration, and quality/security checks. This is the **keystone** decision: if Brite adopts hardis, large parts of F1/F2/F3 + the promotion topology become *configure-the-tool* rather than *build-into-revops*.

### The authority arrow (why this needs Holden)

`CONTEXT.md` locks a one-way authority arrow: **`brite-salesforce` defines deploy discipline; `revops` mirrors it outward.** Adopting a DevOps *backbone* (CI, topology, drift) is a `brite-salesforce`-side, org-level call — not something a revops contributor can originate. This ADR is legitimate to make Brite-wide **only because Holden Halford (the lead/owner) co-decided it in-session**; the arrow's origin was present. Kells drove the analysis; Holden cosigned the adoption.

## Method

Per [ADR-009](009-sf-capability-adoption.md), run the 6-check — but **per-capability**, not monolithically (hardis is a toolbox of ~7 capability clusters whose domain-fit differs), and with checks 1/3/4/5 **reinterpreted to their underlying intent**, because the framework is MCP-server-shaped and hardis is a CLI plugin that registers nothing in `.mcp.json` and adds zero tool-schema context cost.

| Check | Literal (MCP-shaped) | Intent behind it | CLI-tool reading |
|---|---|---|---|
| 1 · Runtime Model | Agentforce vs external MCP | Runs in an environment **we** invoke? | CLI = ours ✓ — but the **VS Code GUI is human-runtime, not agent ✗** |
| 2 · License | MIT/Apache/BSD safe | Commercial-safe to depend on | AGPL: safe to *call*, not to embed/fork |
| 3 · Plugin Slot | MCP-server budget (~5–6) | Operational footprint we take on | a global npm dep + version pin + install/CI friction (no `.mcp.json` slot) |
| 4 · Toolset Breadth | tool-schema context cost | Surface we expose & maintain | zero schemas in context; cost = "how much we teach agents" |
| 5 · GA Gate | SF GA vs beta/pilot | Maturity we're willing to rely on | OSS maturity: release cadence, maintainer health, breaking-change risk |
| 6 · Domain Fit | SF-dev vs SF-data tooling | Matches Brite's actual work | per-capability — **the real discriminator** |

## The 6-check, run

### Tool-wide checks (capability-invariant)

- **Check 2 — License: PASS for adopt-as-tool.** AGPL-3.0. *Calling* a CLI ≠ conveying or forking its code; AGPL's network-copyleft clause is not triggered by local invocation; the repo is private (internal use). **Fails only** if Brite vendors/forks hardis source into the MIT-declared plugin.
- **Check 4 — Surface: PASS.** It's a Bash command — zero MCP tool schemas enter context. Cost is bounded to "how much we teach agents," limited by adopting only ~4 command groups (below).
- **Check 5 — Maturity (reinterpreted GA-gate): PASS, pin a version.** v7.15.0 shipped 2026-05-24 (8 days before this decision) across 627 releases; Cloudity-maintained (Nicolas Vuillamy), 347★ / 96 forks / 20+ contributors. Rapid cadence → **pin a specific version** and treat upgrades as a standing-monitor, exactly as `@salesforce/mcp` is pinned ([BC-5787](https://linear.app/brite-nites/issue/BC-5787)).

### Per-capability checks (1 runtime · 3 footprint · 6 domain-fit)

```
 capability cluster              epic gap            Ck1     Ck3 footprint    Ck6 fit      verdict
 ──────────────────────────────  ──────────────────  ──────  ───────────────  ───────────  ─────────────────────────
 smart/delta deploy + Q-deploy   P1-4                CLI ✓   low              HIGH         ADOPT
 CI/CD pipeline generation       P0-1 · P1-3 · F3    CLI ✓   med (CI + org)   HIGH         ADOPT (backbone)
 SFDMU data import/export        P0-2 + mig. disc.   CLI ✓   med              HIGH         ADOPT
 quality / legacy-API / security F2-adj · P2-8       CLI ✓   low              MED          ADOPT (CI gate)
 org monitoring / backup / drift P1-5                CLI ✓   HIGH (Grafana)   HIGH         ADOPT — phase 2
 interactive wizards + VS GUI    "dev guardrails"    GUI ✗   low              LOW (agent)  SKIP → recommend to humans
 package management              P3-10               CLI ✓   low              LOW          SKIP
 ─ .forceignore silent-skip      F1 / BC-12347       —— not a hardis capability ——          BUILD (revops pre-flight)
```

The reinterpreted **Check 1 earned its keep**: the VS Code GUI fails it (built for a human in an editor, not a Claude agent), so the GUI is SKIP *from revops's agent-facing charter* while remaining a legitimate **recommendation to the human dev team** for the "less-experienced dev guardrails" need — that aid is not revops's to host.

**F1 is not inherited.** hardis's "overwrite protection" (`packageNoOverwritePath`, `packageXmlOnChange.xml`) solves a *different* problem — *don't clobber existing components* — not `.forceignore` silent-drop. Nothing in the docs claims hardis warns when a changed component is `.forceignore`'d; the underlying `sf project deploy` still skips it silently. So the cheap pre-flight local pattern-match ([BC-12347](https://linear.app/brite-nites/issue/BC-12347)) stays a revops build, per "catch at the cheapest correct layer."

## Decision

Brite adopts sfdx-hardis as a **selective, per-capability tool dependency** (adopt-as-tool — not wrap, not skip):

- **Adopt now:** smart/delta deploy + validate→quick-deploy; CI/CD pipeline generation; SFDMU data import/export; quality/legacy-API/security checks as CI gates.
- **Adopt, phase 2:** org monitoring / backup / drift — fit is HIGH, but the real Grafana-stack infra cost defers it; it does not disqualify it.
- **Skip from revops:** the VS Code GUI + interactive wizards (human-runtime) — recommend the VS Code extension separately to the human dev team. Package management (happy-soup is acceptable per P3-10).
- **Pin** a specific hardis version; upgrades are a standing-monitor decision, not auto-adopt.

## Downstream impact on BC-12345

- **Inherit** (configure hardis): F3, P0-1, P1-3, P1-4, P1-5, P0-2.
- **Build** in revops: **F1 ([BC-12347](https://linear.app/brite-nites/issue/BC-12347))** — pre-flight `.forceignore` guard.
- **Mixed — F2:** hardis quality checks help pre-deploy, but the post-deploy *verification-scope* gap (verification covers < deploy scope) is still revops's to close; confirm during F2 design. [BC-12348](https://linear.app/brite-nites/issue/BC-12348) (doctor CLI ≥ 2.135.7) is unaffected — it stays a revops build.
- **Deferred** to the promotion-topology ADR (open decision #2): rewriting `/revops:deploy-sandbox` / `/revops:deploy-prod` to delegate to `sf hardis:project:deploy:smart`, and the dual-vs-single deploy-path question. BC-12346 records the verdict only; it is not a command redesign.

## Consequences

### Flags carried forward
1. **ADR-009 needs a generalization pass (flagged, not done here).** 4 of 6 checks required reinterpretation for a non-MCP CLI artifact. Per ADR-009's own Consequences ("add a seventh check via a follow-up ADR rather than amending this one in place"), a future ADR should add an **artifact-class dimension** (MCP server · CLI plugin · skill library · …) so the framework scores CLI tools natively. ADR-009 is **not amended** by this decision.
2. **brite-salesforce reflection (follow-up, different repo).** The backbone half (CI/topology) must be reflected with a one-line note in `brite-salesforce/CLAUDE.md` — its authoritative home for deploy discipline (`CONTEXT.md` authority arrow). This ADR cannot make that edit from `brite-claude-plugins`.
3. **AGPL boundary.** Safe while Brite *calls* hardis. Do **not** vendor or fork its source into the MIT-declared revops plugin — that would re-open the license analysis (and matter again if the repo ever returns to public).

### Positive
- Most of the epic's heaviest gaps (topology, CI-deployed Integration, drift, quick-deploy, scripted data migration) become *configure*, not *build*.
- The tool is actively maintained and already moving into the Claude Code skill ecosystem (`hardis:project:skills:import`), so adoption is aligned, not foreign.

### Negative / mitigations
- New external dependency on a community OSS tool. Mitigation: pin a version; the standing-monitor pattern already exists for `@salesforce/mcp`.
- Phase-2 monitoring carries a Grafana-stack operational cost. Mitigation: explicitly deferred, decided on its own merits later.

## Rejected alternatives

- **Wrap (hardis as a swappable internal detail).** Rejected: once Brite standardizes on hardis's CI/topology backbone, an abstraction layer adds maintenance with no swap we actually intend; adopt-as-tool is the honest commitment.
- **Skip / build everything in revops.** Rejected: re-implements delta deploy, CI pipeline generation, drift, and SFDMU orchestration that a maintained tool provides — high cost, no differentiation.
- **Monolithic adopt/skip.** Rejected: averages over capabilities whose domain-fit differs (deploy engine vs VS Code GUI) and can't drive the epic's per-gap build-vs-inherit triage.
- **Adopt the GUI/wizards into revops.** Rejected via reinterpreted Check 1: human-runtime, not agent-facing — recommended to the human dev team instead.

## Reversibility

- **Per-capability**, each adopt is individually reversible — drop a capability by removing its CI/config wiring; revops's own commands remain functional on raw `sf`.
- **Tool-wide**, hardis is invoked, not embedded: removing it is uninstalling an `sf` plugin + reverting CI config. No revops code is coupled to hardis internals (the command-delegation question is deferred precisely to keep that boundary clean until the topology ADR decides it).
