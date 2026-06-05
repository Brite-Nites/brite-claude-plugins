# 023. Artifact-class dimension for the SF capability-adoption framework

**Status:** Proposed
**Date:** 2026-06-05
**Linear:** [BC-12345](https://linear.app/brite-nites/issue/BC-12345) (deploy-integrity epic, item #4)
**Decided by:** Kells Nixon (driving). **Proposed — pending Holden Halford (lead/owner) ratification.** Unlike [ADR-021](021-sfdx-hardis-adoption.md) (co-signed in-session), this ADR is authored solo, so it stays Proposed until the owner ratifies.
**Related:** [ADR-009](009-sf-capability-adoption.md) (the 6-check this **extends, not supersedes**), [ADR-021](021-sfdx-hardis-adoption.md) (§Consequences flag #1 + the reinterpretation table that exposed the gap), [ADR-022](022-revops-promotion-topology.md), [ADR-010](010-plugin-secret-config-canon.md) (the stdio-vs-HTTP MCP axis this ADR deliberately does **not** fold in).

## Context

[ADR-009](009-sf-capability-adoption.md) defined a 6-check framework for deciding whether to adopt a Salesforce capability. It was written when every artifact Brite had scored was an **MCP server** (`@salesforce/mcp`), so 4 of its 6 checks are phrased in MCP-server terms:

- **Check 1 (Runtime Model)** — "Agentforce runtime vs external MCP consumer"
- **Check 3 (Plugin Slot)** — "MCP-server budget, soft cap ~5–6 per plugin"
- **Check 4 (Toolset Breadth)** — "tool-schema context cost"
- **Check 5 (GA Gate)** — "Salesforce GA vs beta/pilot"

When [ADR-021](021-sfdx-hardis-adoption.md) ran the framework on **sfdx-hardis** — an `sf` **CLI plugin** that registers nothing in `.mcp.json` and adds zero tool-schema context — those same 4 checks had to be **reinterpreted to their underlying intent**, by hand, in a reinterpretation table. ADR-021 §Consequences flag #1 deferred the fix to a follow-up ADR, honouring [ADR-009](009-sf-capability-adoption.md)'s own Consequences note: *"add a seventh check via a follow-up ADR rather than amending this one in place."* **This is that follow-up.**

### Shape: a dimension, not a seventh check

ADR-009's note proposed a *"seventh check."* But the lived problem ADR-021 hit was not a missing question — it was that **4 of the existing 6 checks read wrong for a non-MCP artifact.** A 7th check would merely *classify* the artifact; it would leave checks 1/3/4/5 still MCP-shaped, so the reinterpretation step would survive. A 7th check would not have let sfdx-hardis score natively.

The fix that actually closes the gap is a **cross-cutting dimension**: classify the artifact *first*, then let each existing check read itself in that class's column. This promotes ADR-021's ad-hoc reinterpretation table from "something we improvised once" to "the framework's standing structure." ADR-009's *"seventh check"* phrasing predates the CLI case that exposed the problem as cross-cutting; ADR-021 already hedged it to *"seventh check / artifact-class dimension."* This ADR commits to the **dimension** reading and records the why so a future reader does not think ADR-009's note was ignored.

## Decision

Add an **artifact-class dimension** to the [ADR-009](009-sf-capability-adoption.md) framework. **ADR-009 is not amended** — its 6 checks stand verbatim as the native MCP-server reading. This ADR layers a Step-0 classification on top.

### Step 0 — classify the artifact

Before running the 6 checks, label the capability with its **artifact class**. Three classes today (open-ended — a genuinely new class, e.g. a GitHub Action, can be added by a later ADR without re-opening this one):

```
🤖 MCP server     a server that clips onto the agent and exposes tool schemas
                  (registered in .mcp.json)                e.g. @salesforce/mcp
⌨️  CLI plugin     a command the agent invokes via the shell; no .mcp.json slot,
                  no tool schemas in context               e.g. sfdx-hardis (sf plugin)
📄 skill library   a body of markdown skills the agent reads to learn a capability
                  (ported / vendored)                      e.g. Jaganpro/sf-skills
```

Two things that *look* like they need their own class but do **not**:

- **A human-facing GUI / wizard is not a fourth class.** It is the **Check-1 (Runtime Model) FAIL outcome for any class** — Check 1 already asks "does an *agent* invoke this?" ADR-021 handled hardis's VS Code GUI exactly this way: SKIP-via-Check-1-fail, recommended to the human dev team instead of hosted in revops.
- **stdio-MCP vs HTTP-MCP is not a sub-split of the MCP class.** That distinction is a *secret-config* concern owned by [ADR-010](010-plugin-secret-config-canon.md) (`bw-run.sh` env vs the BC-5551 header-substitution exception). Checks 1/3/4/5/6 read identically for both transports, so the adoption framework treats them as one class.

### The 6 checks, by class

The class selects each check's **reading**. **4 checks vary by class; 2 are invariant** (same question regardless of class — shown spanning all columns).

| Check | 🤖 MCP server | ⌨️ CLI plugin | 📄 skill library |
|---|---|---|---|
| **1 · Runtime Model**<br>*"does an agent we run invoke it?"* | External-MCP-consumer-friendly **PASS**; Agentforce-runtime-only **FAIL** | Invoked by us via the shell **PASS** — but a human GUI/wizard mode **FAILS** (built for a human in an editor, not an agent) | Markdown the agent reads — runtime-agnostic; **FAILS** only if the skill assumes a runtime we lack (e.g. presumes in-platform Agentforce execution rather than portable external-MCP use) |
| **2 · License** | *Invariant question* — **"commercial-safe for Brite's usage mode?"** The **class sets the usage mode**, and the mode conditions the answer: MCP server = *run/depend* · CLI plugin = *call, don't embed* · skill library = *vendor/port*. Same question throughout; e.g. AGPL **PASSES** for "call a CLI" but **FAILS** for "fork into our MIT plugin." ||| |
| **3 · Footprint** (was *Plugin Slot*)<br>*"operational footprint we take on?"* | MCP-server budget — soft cap ~5–6 per plugin; measure startup-latency Δ `< 2s` + context Δ `< 500 tokens` | No `.mcp.json` slot — a global npm / `sf`-plugin dependency + version pin + install/CI friction | No slot, no dependency — files we vendor/port + ongoing maintenance (the sf-skills port's *13-retained / 22-dropped* **is** this budget call) |
| **4 · Surface** (was *Toolset Breadth*)<br>*"surface we expose & must teach/maintain?"* | Tool-schema context cost (tools × schema size); reject if it doubles tool count or blows the `< 500-token` budget | Zero tool schemas in context — cost is "how much we teach agents," bounded by adopting only the command groups we need | Cost is `SKILL.md` sizes + how many skills load into context (not schemas), bounded by retaining only in-scope skills |
| **5 · Maturity** (was *GA Gate*)<br>*"maturity we'll rely on?"* | Salesforce **GA vs beta/pilot**; Brite GA-only posture ([BC-5534](https://linear.app/brite-nites/issue/BC-5534)); standing monitor for upcoming-GA | OSS maturity — release cadence, maintainer health, breaking-change risk → **pin a version**, treat upgrades as a standing-monitor (as `@salesforce/mcp` is pinned) | Upstream repo maturity + **license stability** (the ADLC-vs-main fork choice was exactly this) |
| **6 · Domain Fit** | *Invariant question* — **"SF-dev vs SF-data tooling, and does it match Brite's actual work?"** Run **per-capability** where the artifact is a toolbox (see *orthogonal axes* below). ||| |

### Artifact class ⊥ capability granularity (two orthogonal axes)

The class axis does **not** decide whether you run the checklist once or many times. That is a *second, independent* axis — **capability granularity** — set by the artifact's internal shape, not its class:

```
 AXIS 1 · artifact class (this ADR)        AXIS 2 · capability granularity (ADR-021)
 ──────────────────────────────────        ────────────────────────────────────────
 WHAT KIND is it?                           is it ONE thing or a TOOLBOX?
 🤖 MCP / ⌨️ CLI / 📄 skill                  → if a toolbox, run Check 6 (and Check 1)
                                              per cluster
 → sets the READING of each check           → sets HOW MANY TIMES you run the
                                              (class-shaped) checklist
```

A CLI plugin can be one tool or a toolbox; a skill library is usually many skills. **Do not infer that a CLI tool must be scored monolithically** — sfdx-hardis is a CLI plugin *and* a toolbox, scored per-capability.

### Scope: this stays inside SF capability adoption

This ADR generalizes **only the artifact-class axis**. The checks themselves remain Salesforce-specific (Checks 1/5/6 are SF-flavoured by design). The **skill-library** class means **SF skill libraries** (e.g. sf-skills) — **not** Brite's marketing or workflows skills, which have never been run through this framework and are out of scope. If a future non-SF adoption question arises, *that* ADR lifts the framework out of SF — with a real example to validate it, rather than inventing generality on spec.

## Worked re-run — sfdx-hardis through the generalized framework

The proof that the dimension works: the 4 reinterpretations ADR-021 did by hand become *"read the CLI column."*

**Step 0 — classify:** sfdx-hardis = **⌨️ CLI plugin** (an `sf` plugin; nothing in `.mcp.json`; zero tool schemas).

**Tool-wide checks, read straight from the CLI column** — no "reinterpret to intent" prose required:

```
 Check 2 · License    → CLI column: "call, don't embed" → AGPL PASS (calling ≠ conveying/forking;
                        fails only if vendored into the MIT plugin)
 Check 4 · Surface     → CLI column: zero schemas in context; cost = teaching ~4 command groups → PASS
 Check 5 · Maturity    → CLI column: OSS cadence/maintainer health → pin v7.15.0, standing-monitor → PASS
```

These are exactly ADR-021's tool-wide verdicts — but where ADR-021 had to *argue its way* from the MCP-shaped wording to the CLI reading, ADR-023 just reads the column. **Same verdicts, zero improvisation.**

**Per-capability checks (Check 1 + Check 6)** drop out unchanged via Axis 2. The per-cluster ADOPT / ADOPT-phase-2 / SKIP table (smart-deploy, CI/CD, SFDMU, quality → ADOPT; monitoring → phase 2; **VS Code GUI → SKIP via Check-1 FAIL**; package-mgmt → SKIP) lives in [ADR-021 §"The 6-check, run"](021-sfdx-hardis-adoption.md) and is referenced, not re-derived here — it is unaffected by the generalization.

## Consequences

**Positive**

- A non-MCP artifact (CLI plugin, skill library) now scores **natively** — no reinterpretation step, no risk that someone re-runs the raw MCP-shaped checklist on a CLI tool and re-improvises ADR-021's table.
- ADR-021's reinterpretation table is preserved as durable structure rather than a one-off.
- The GUI-as-Check-1-fail and class ⊥ granularity rules are pinned, so future adoptions don't re-litigate them.

**Negative / mitigations**

- The matrix can age as new artifact classes appear (e.g. a GitHub Action) — mitigated by the open-ended *"…"*: add a class via a later ADR, don't amend this one in place (same discipline ADR-009 set for itself).
- The skill-library column is derived from a single lived example (the sf-skills MIT-vs-ADLC port, ADR-009 Example 2) — mitigated by marking it the *reading*, refreshable when a second skill-library adoption tests it.

**Relationship to ADR-009**

- ADR-009 stays **Accepted** and verbatim; this ADR **extends** it. A one-line forward `Related:` link is added to ADR-009's header for discoverability — its Context / Decision / Consequences are untouched. ADR-009's Consequences line still reads *"add a seventh check"*; that phrasing is reconciled by this ADR's *"a dimension, not a seventh check"* section above, not by editing 009.

## Reversibility

Pure documentation. The dimension is additive — removing it reverts to running ADR-009's 6 checks in their native MCP reading (with per-non-MCP reinterpretation, as ADR-021 did). No code or config is coupled to this ADR.
