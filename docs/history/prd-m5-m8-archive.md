# PRD M5-M8 Archive — Brite Agent Platform (2026-Q1 framing)

**Status:** ARCHIVED 2026-05-27. Superseded by the 4-layer architecture re-org.

This document captures what the original PRD M5-M8 milestones meant, why their visions evolved, and where the surviving capability now lives. It accompanies the wholesale-cancel decision made during the 2026-05-27 marketplace cleanup interview.

For the new framing, see `docs/designs/brite-agent-platform.md` (header retrofitted with supersession notice).

---

## The original PRD framing (2026-02 through 2026-04)

The Brite Plugin Marketplace project was originally scoped as a **4-layer agent platform** with an **8-milestone roadmap** (M1-M8), plus two lateral workstreams that lived in the same Linear project without M-numbers:

**8 PRD-numbered milestones** (canonical names from `docs/designs/brite-agent-platform.md`):

1. M1 — Company Knowledge Layer
2. M2 — Project-Start Redesign
3. M3 — Decision Trace Architecture
4. M4 — Plugin Ecosystem Foundation
5. M5 — Domain Plugin Expansion — **this archive**
6. M6 — Context Refresh Pipeline — **this archive**
7. M7 — Symphony Autonomous Execution — **this archive**
8. M8 — Context Governance & Observability — **this archive**

**2 lateral workstreams** (no M-number, lived alongside the PRD milestones in the same Linear project):

- Marketing Function — empty stub, never had child issues; `[ARCHIVED]` 2026-05-27
- (Note: Domain Plugin Expansion is M5 above, not a lateral — included in the 4 archived below.)

**Linear-vs-PRD milestone-name drift.** During execution, the Linear project's actual milestones diverged from the PRD's canonical M1-M8 names. Linear's shipped milestones used operational labels like "Foundation & Quick Wins" (Feb 2026), "The Inner Loop" (Mar), "The Outer Loop" (Apr), "Orchestration" (May), "Plugin Ecosystem" (Jun) — these aren't 1:1 maps of PRD M1-M4 names. Throughout this archive, the M-numbers reference the PRD-canonical names; references to Linear milestone state use the Linear names.

The PRD's M1-M4 outcomes shipped (Linear milestones 100% across Feb-Jun 2026). M5-M8 did not. Energy moved into per-plugin milestones (Cadence, FDA, RevOps, Marketing GTM, Revenue Rhythm, Mission Control, Runtime Context Loading) that emerged organically.

The empirical lesson: per-layer milestones decayed when the architecture itself was still in flight. Per-plugin milestones survived because the plugin was the actual shipping unit. The 2026-05-27 cleanup formalizes this — see `~/.claude/plans/2026-05-27-plugin-marketplace-cleanup.md`.

---

## M7 — Symphony Autonomous Execution

**Original PRD vision:** Poll-Dispatch-Resolve-Land daemon. Elixir/BEAM concurrency. Custom Linear states. Workpad pattern. Brite review agents as quality gates. Compound-learnings persistence across autonomous runs. Cost management.

**14 child issues** (BC-1352, BC-1979 through BC-1990 inclusive, BC-2007 — all cancelled 2026-05-27).

**Why it didn't ship:** The daemon-shape framing assumed a heavy custom runtime (Elixir fork, BEAM supervision trees, polled state machine) before Brite had clarity on which orchestration substrate to build on. In the intervening months:

- **OpenAI Symphony** shipped publicly — `Linear board IS the orchestration substrate`. Tickets in, PRs out. Codex inside the workspace. Brite's actual stack aligns with this pattern: Linear-as-substrate + Claude Code inside the worktree. The daemon was the wrong shape.
- **gbrain Minions** (Garry Tan, Q1 2026) bid to be its own orchestration plane — Postgres LISTEN/NOTIFY + Minion job dashboard. Different substrate, same orchestration question.
- **Mission Control Plugin v0.1** codified a lighter-weight tracker+worker pattern (one mission-control session keeps state + dispatches worker briefs + integrates paste-backs; multiple worker sessions in worktrees execute single-scope work). Not Symphony-class, but proved value of the parallel-tracker pattern without needing a daemon.

**Where the vision lives now:** **Brite Orchestration Layer** project (Layer A in the new 4-layer architecture). New milestones:

- Symphony-Style Linear-as-Substrate Orchestration Research
- L4 Auto-Routing (CI auto-tickets + Slack emoji + Linear label triggers — Cognition/Stripe pattern)
- L3 Coordinator Skill (Managed-Devins-style coordinator dispatching sub-skills)
- Block-Style L2 Intelligence Layer Research (customer world model + capability composer)

The Linear-as-substrate decision (vs gbrain-Minions or Hermes-runtime) remains an open strategic choice. Tracked in the Symphony research milestone.

---

## M6 — Context Refresh Pipeline

**Original PRD vision:** Automated BigQuery + Salesforce → handbook context with temporal trends and PII handling. GitHub Actions refresh analytical context weekly with delta computation and automated PRs.

**6 child issues** (BC-1972, 1973, 1975, 1976, 1977, 1978 — all cancelled 2026-05-27).

**Why it didn't ship:** Two reasons.

1. **BigQuery scope was wrong.** Brite uses Snowflake as the data warehouse, not BigQuery. The PRD's 90d trend computation, temporal diff library, and PII handling sections all cited BigQuery throughout. Wholesale rescoping would have been needed even to start. Captured in `memory/feedback_snowflake_not_bigquery.md`.

2. **gbrain made the pattern obsolete.** The "refresh pipeline" was a workaround for not having a brain — a way to materialize SoR data into handbook markdown so agents could read it. gbrain (Garry Tan, MIT-licensed personal/team knowledge base — Q1 2026) ingests handbook directly via `gbrain sync --repo <handbook>` on push-to-main + weekly cron. The brain is the substrate now. BC-11006 registered the gbrain-team HTTP MCP in `plugins/workflows/.mcp.json`; BC-11153 shipped preamble injection via SubagentStart hooks. Already operational.

**Where the vision lives now:** **Brite Knowledge Layer** project (Layer D in the new 4-layer architecture). New milestones:

- gbrain Provisioning + Team Brain on Supabase (the unblocker for everything else — partial work at `~/.claude/plans/bc-10520-*`)
- L2/L3/L4 Spec Stratification (INITIATIVE.md + PLAN.md + Issue Body Spec formats — per 2026-05-27 user notes)
- Handbook Tier 0/1/2 Backfill (applies_to frontmatter for FDA + Track A/B fork)

Snowflake → handbook analytical-context piping (the survivable part of the original scope) can re-emerge as a Layer D sub-milestone IF and WHEN the gbrain knowledge layer has stabilized enough to expose the gap. Not currently a near-term priority.

---

## Domain Plugin Expansion (PRD lateral, between M4 and M5)

**Original PRD vision:** Four new domain plugins — Engineering, Design, Sales, Product — each with an extracted skill set from the workflows plugin plus new domain-specific context-skills and tools.

**7 child issues** (BC-1343, 1968, 1969, 1970, 1971, 2009 — all cancelled 2026-05-27).

**Why it didn't ship:** The 4 plugins never started. By the time the energy was available, the workflows plugin (Layer C — Skill Packs) had already ABSORBED most of what they would have provided:

- `react-best-practices`, `python-best-practices`, `testing-strategy`, `code-quality` — live in `plugins/workflows/skills/`
- `frontend-design`, `ui-ux-pro-max`, `web-design-guidelines` — live in `plugins/workflows/skills/` via gstack pattern import
- API design (BC-1343) — never had a unique-enough scope to justify a separate skill
- Sales/Product domain context — no near-term consumer demand

The 4-plugin extraction would have created duplication overhead (4 plugins with their own .mcp.json, plugin.json schemas, version bumps) without proportional value at Brite's current scale (10-engineer team).

**Where the vision lives now:** Held open. If any of these 4 plugin ideas re-emerges as worth doing (e.g., Path D MVP — `/brite:propose-skill` for non-engineer authoring — creates demand for a `sales-context` skill from sales/ops/customer-facing folks), it'll get a fresh milestone in **Brite Skill Packs** (Layer C) with current-thinking scope. Not on any roadmap as of 2026-05-27.

---

## M8 — Context Governance & Observability

**Original PRD vision:** CDR governance, quality dashboard, flywheel monitoring, governance review agent. Tracks freshness, CDR coverage, precedent hit rate, flags drift.

**5 child issues** (BC-1782, 1991, 1992, 1993, 1994 — all cancelled 2026-05-27).

**Why it didn't ship:** Partial absorption already happened, and the rest depended on M6 (Context Refresh) being real.

- **`workflows:cdr-compliance-reviewer` agent** already exists in `plugins/workflows/agents/`. Covers part of the "governance review agent" scope (BC-1994 territory).
- **Behavioral test framework** (BC-1782) — DELIVERED by BC-2462 (runtime behavioral test framework) + BC-2463 (cross-skill contract validator) via a different approach: LLM-as-judge + 3-tier architecture instead of programmatic step DAG parsing. Original BC-1782 description carries a "superseded ~70%" memo from when that fact was discovered.
- **Flywheel monitoring** (BC-1993), **CDR governance model** (BC-1991), **quality dashboard** (BC-1992) — would have built atop the M6 refresh pipeline and the M3 decision-trace architecture. Both subsumed by the gbrain knowledge layer pivot.

**Where the vision lives now:** The valuable pieces fold into **Brite Knowledge Layer** (Layer D) milestones (primarily gbrain provisioning + Tier 0/1/2 backfill). No standalone "governance" milestone in the new framing.

---

## What survives, what doesn't

| PRD vision element | Status in new framing |
|---|---|
| Linear-board-as-substrate orchestration | **Survives** as a Layer A research milestone |
| Polled daemon, Elixir/BEAM, custom Linear states | **Cancelled** — wrong shape |
| Codex-style workpad pattern | **Folded** into Mission Control v0.1 (lighter-weight tracker+worker) |
| Symphony review-agents-as-quality-gates | **Already shipped** in workflows plugin (10-agent tiered review per `plugins/workflows/agents/*reviewer.md`) |
| Compound-learnings autonomous integration | **Already operational** in workflows:ship pipeline |
| BigQuery → handbook pipeline | **Cancelled** — wrong data warehouse + gbrain superseded |
| Salesforce → handbook pipeline | **Held open** — could re-emerge as gbrain-side ingestion if needed |
| Temporal diff library | **Cancelled** — gbrain handles temporal via page versions |
| PII handling in refresh | **Cancelled** — gbrain-side concern now |
| Engineering / Design / Sales / Product domain plugins | **Cancelled** — workflows plugin absorbed the core skill content |
| API design skill | **Cancelled** — no unique scope |
| CDR governance model | **Held open** — folds into Knowledge Layer if needed |
| Quality dashboard | **Cancelled** — gbrain-side observability now |
| Flywheel monitoring | **Cancelled** — premature for current scale |
| Governance review agent | **Already exists** as `workflows:cdr-compliance-reviewer` |
| Behavioral test framework | **Delivered** via BC-2462 + BC-2463 (different approach) |

---

## References

- 2026-05-27 cleanup manifest: `~/.claude/plans/2026-05-27-plugin-marketplace-cleanup.md`
- New 4-layer architecture: `docs/designs/brite-agent-platform.md` (retrofitted with supersession header)
- gbrain integration: `plugins/workflows/.mcp.json` (gbrain-team HTTP MCP), `plugins/workflows/scripts/gbrain-team-broker.sh`, commit `4dcc7625` (BC-11153, SubagentStart preamble injection)
- Brite memory notes: `memory/feedback_snowflake_not_bigquery.md`, `memory/project_brite_agent_platform.md`
- Symphony reference: https://github.com/openai/symphony
- gbrain reference: `~/code/gbrain` (Garry Tan, MIT)
- gstack reference: `~/.gstack/` (Garry Tan, MIT)
- Brite's competitive bet (from user notes 2026-05-27): owns Layer C (5 plugins, floor met); delegates Layer B to Claude Code; uses Linear+terminal as channel surface; provisioning Layer D via gbrain on Supabase; distinctive Layer A bet = **schedule-driven (cadence:weekly) + phase-driven (workflows pipeline) hybrid orchestration via Linear-board-as-substrate**.
