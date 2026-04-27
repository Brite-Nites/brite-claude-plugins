# BC-5786 — SF capability adoption framework as ADR-009

**Linear:** https://linear.app/brite-nites/issue/BC-5786
**Branch:** `holden/bc-5786-sf-capability-adoption-framework`
**Worktree:** `.claude/worktrees/bc-5786/`
**Milestone:** RevOps Plugin (closes 23/23)
**Priority:** Low

## Brainstorm decisions (2026-04-26)

| Decision | Choice | Rationale |
|---|---|---|
| Format | New ADR `docs/decisions/009-sf-capability-adoption.md` + salesforce.md `@import`-style cross-link | Matches ADR-007/008 precedent; keeps salesforce.md focused on live integration; ADR is the proper home for reusable decision frameworks |
| Worked examples | All three (Headless 360 / Jaganpro ADLC / @salesforce/mcp 0.31+) | Each demonstrates a different check (Runtime Model / License / GA Gate). Cost: ~15 lines; payoff: framework reads concretely instead of as an abstract checklist |
| Discovery surfaces | All three (CLAUDE.md ADR list + salesforce.md cross-link + master-plan back-ref) | Each surface reaches a different audience (cross-cutting agents / SF tooling users / RevOps planning). Marginal cost ~3 lines each |

ADR-008 is taken (`tam-mapping-enrichment-pluggability`) → next free slot is **009**.

## Tasks

### Task 1 — Draft ADR-009

**File:** `docs/decisions/009-sf-capability-adoption.md` (new)

**Shape:** matches ADR-008 frontmatter precedent. Sections: Context → Decision Drivers → The Six Checks → Worked Examples → Consequences. **See shipped artifact for canonical content:** [`docs/decisions/009-sf-capability-adoption.md`](../decisions/009-sf-capability-adoption.md).

<details>
<summary>Original draft scaffold (kept for plan-doc completeness; shipped ADR is source of truth)</summary>

```markdown
# 009. Salesforce Capability Adoption Framework

**Status:** Accepted
**Date:** 2026-04-26
**Linear:** [BC-5786](https://linear.app/brite-nites/issue/BC-5786)
**Origin:** `docs/plans/revops-plugin-master-plan.md` §6 Issue 0.3
**Related:** [ADR-007](007-revops-plugin-design.md), BC-5534, BC-5787, BC-5789

## Context
[Why we keep re-deriving "should we adopt this SF capability?" — Headless 360 was the third such re-derivation in 6 months. Capture once.]

## Decision Drivers
- Every SF capability announcement triggers an ad-hoc adoption decision
- Decisions involve cross-cutting concerns (runtime, license, plugin budget, context budget, GA posture, domain fit) that are easy to forget
- Without a framework, important checks get skipped (e.g., a plugin-budget oversight could push us past the soft-cap)

## The Six Checks

### 1. Runtime Model check
**Question:** Is this capability built for agents running INSIDE Salesforce's Agentforce runtime, or for external MCP consumers like us?
**Pass:** External-MCP-consumer-friendly (e.g., @salesforce/mcp tools).
**Fail:** Agentforce-runtime-only (e.g., Headless 360 server-side coding skills).

### 2. License check
**Question:** Is the artifact commercial-safe for Brite's use?
**Pass:** MIT, Apache 2.0, BSD, ISC, CC0.
**Fail:** CC BY-NC, GPL with copyleft concerns, proprietary EULA, custom non-commercial.

### 3. Plugin Slot check
**Question:** Do we have MCP-server budget for this in the target plugin?
**Constraint:** Soft cap ~5–6 servers per plugin; user-level registrations don't count.
**Method:** Measure startup-latency Δ (`< 2s`) and context-budget Δ (`< 500 tokens`) against clean-session baseline. See `docs/research/tam-map-port-policy.md` § 1.

### 4. Toolset Breadth check
**Question:** What's the tool-schema context cost of adding this toolset?
**Method:** Count tools × average schema size; compare to existing toolsets in `.mcp.json`.
**Reject signal:** A toolset that doubles the plugin's tool count for marginal value.

### 5. GA Gate check
**Question:** Is the capability Generally Available, or beta/pilot/closed-preview?
**Brite posture (BC-5534 ADR 2):** GA-only. Reject beta/pilot adoption even when the feature is compelling.
**Allowed exception:** Standing monitoring (e.g., BC-5787) for capabilities expected to land in upcoming GA releases.

### 6. Domain Fit check
**Question:** Is this SF *development* tooling or SF *data consumption* tooling, and does that match Brite's actual work?
**Brite SF work today:** ~80% development (metadata, Apex, flows, deploys), ~20% data consumption (audience views, lead enrichment).
**Reject signal:** A capability that solves a problem Brite doesn't have (e.g., Industries Cloud verticalization, Vlocity integration).

## Worked Examples

### Example 1 — Headless 360 announcement (TDX 2026, 2026-04-15) → REJECTED via Runtime Model
SF announced "60+ new MCP tools + 30+ preconfigured coding skills" for Agentforce. The skills run inside SF's Agentforce runtime, not via external MCP. Check 1 fails: our agents are external MCP consumers. Decision: skip Headless 360 server-side coding skills; standing monitor (BC-5787) tracks landing of any toolsets that DO expose to external consumers.

### Example 2 — Jaganpro/sf-skills ADLC variant → REJECTED via License
The ADLC fork of sf-skills offered a richer skill set than the MIT main branch but was licensed CC BY-NC (non-commercial). Check 2 fails: Brite is a commercial entity. Decision: ported from main (MIT) instead. Captured in BC-5789 audit decisions.

### Example 3 — @salesforce/mcp 0.31+ adoption → GATED via GA
The Headless 360 announcement promised tools landing in 0.31+. As of plan filing, latest npm release is 0.30.5. Check 5 (GA Gate): we don't auto-adopt; standing monitor (BC-5787) re-runs BC-5534 Appendix A inventory diff when a new GA version lands. Decision: pinned at 0.30.5; revisit on landing.

## Consequences

**Positive**
- Future SF capability announcements get evaluated against a fixed checklist instead of ad-hoc reasoning
- Plugin-budget and context-budget concerns are first-class checks, not afterthoughts
- GA-only posture is enforced consistently

**Negative / mitigations**
- Rigid framework risks rejecting genuinely valuable capabilities — mitigated by treating the framework as a structured prompt, not a hard gate
- Worked examples may age — refresh annually or when re-cited

## References
- BC-5534 SF MCP adoption research (Appendix A baseline)
- BC-5786 (this ADR's filing issue)
- BC-5787 (active monitoring of @salesforce/mcp 0.31+)
- BC-5789 (Jaganpro filtering — produced License check signal)
- `docs/research/salesforce-mcp-findings.md`
- `docs/research/tam-map-port-policy.md` § 1 (plugin-budget measurement methodology)
```

</details>

**Verify:**
- File exists at `docs/decisions/009-sf-capability-adoption.md`
- Frontmatter (Status / Date / Linear / Origin / Related) matches ADR-008 shape
- All 6 checks named exactly: "Runtime Model", "License", "Plugin Slot", "Toolset Breadth", "GA Gate", "Domain Fit"
- All 3 worked examples present

### Task 2 — Add salesforce.md cross-link section

**File:** `plugins/marketing/tools/integrations/salesforce.md`

**Insertion point:** After `## Tool inventory` section (line ~180), before `## Common workflows`. Reasoning: tool inventory is "what's in the box," capability adoption framework is "what to do when SF ships something new" — sequence reads naturally.

**Content:** see shipped section in [`plugins/marketing/tools/integrations/salesforce.md`](../../plugins/marketing/tools/integrations/salesforce.md) under `## Capability Adoption Framework` (1-paragraph summary + ADR-009 link).

**Verify:**
- Section present in salesforce.md
- Link path resolves (`../../../../docs/decisions/009-sf-capability-adoption.md` from `plugins/marketing/tools/integrations/`)

### Task 3 — Add CLAUDE.md ADR-009 entry

**File:** `CLAUDE.md` (line ~39, after ADR-008 entry)

**Insertion:** see shipped [`CLAUDE.md`](../../CLAUDE.md) `## Architecture Decisions` list (1 line, link + dash + 1-clause summary, matches ADR-007/008 style).

**Verify:**
- Entry present in `## Architecture Decisions` list
- Link resolves
- Style matches ADR-007/008 entries

### Task 4 — Add master-plan §6 Issue 0.3 back-reference

**File:** `docs/plans/revops-plugin-master-plan.md` (line ~339, end of Issue 0.3 block before `---` separator)

**Insertion:** 1-line `**Resolved by:** [ADR-009](...)` back-ref immediately above the `---` separator at end of Issue 0.3 block. See shipped [`docs/plans/revops-plugin-master-plan.md`](./revops-plugin-master-plan.md) §6 Issue 0.3.

**Verify:**
- Line present immediately above the `---` that closes Issue 0.3
- Link resolves

### Task 5 — Run verify gates T1-T5

| Test | Command | Pass criteria |
|---|---|---|
| T1 | `grep -E "Runtime Model\|License\|Plugin Slot\|Toolset Breadth\|GA Gate\|Domain Fit" docs/decisions/009-sf-capability-adoption.md` | All 6 names present |
| T2 | `grep -E "Headless 360\|ADLC\|@salesforce/mcp" docs/decisions/009-sf-capability-adoption.md` | ≥1 worked example (target: 3) |
| T3 | `./scripts/validate.sh` | Exit 0 |
| T4 | `./scripts/check-guardrails.sh --claude-md CLAUDE.md` | No anti-slop violations |
| T5 | `grep -F "ADR-009" CLAUDE.md` | ADR-009 referenced from CLAUDE.md |

## Out of scope

- Revisiting any BC-5534 finding
- Evaluating any specific new capability against the framework (framework only)
- Refactoring existing ADR-007 to reference the framework retroactively

## Definition of done

- ADR-009 written and validated against the 5 verify gates
- 3 cross-links present (CLAUDE.md / salesforce.md / master-plan)
- `validate.sh` and `check-guardrails.sh` pass
- BC-5786 ready to close → RevOps Plugin milestone reaches 23/23
