# 028. Skill/command engineering discipline — behavioral evals + tiered forward gate

**Status:** Accepted
**Date:** 2026-06-05
**Linear:** [BC-12586](https://linear.app/brite-nites/issue/BC-12586) (ratify + land this ADR; originated in the PR #429 review session, 2026-06-04/05)
**Related ADRs:** [ADR-003](003-plugin-distribution-architecture.md) (distribution), [ADR-013](013-gtm-three-layer-split.md) (HOW/standards layer)
**Companion docs:** [`docs/guides/skill-command-design-standards.md`](../guides/skill-command-design-standards.md) (the canonical checklist), `CONTEXT.md` § Agent tooling & evaluation (terminology)

> **ADR numbering:** This ADR is `028`. It was drafted as `024`, but landed behind a run of concurrently-merging ADRs — `024` was taken first by `024-launch-campaign-verify-emails-swap-deferred.md` (#439), then `025`–`027` by #422's three ADRs during the review window — so it was renumbered to the next free integer (`028`) at land time (precedent: #435 renumbered 022→023). The companion docs (CLAUDE.md index, standards guide, `CONTEXT.md`) reference it as 028; any remaining open PR carrying a stale number renumbers when it merges.

## Context

A review of the marketing plugin's test/eval setup (audit, 2026-06-04) found:

- The tests covering the *prompt-commands/skills* are **~95% structural** — they `read_text()` the `.md` spec and `assert "string" in body`. The flagship `test_plan_campaign_contracts.py` is 100% markdown-grep and is **not run by CI**. "47/47 passing" certifies the prose, not the behavior. This is how green tests coexisted with a command that had **0 real runs and produced 0 Salesforce campaigns**.
- **113 `evals/evals.json` cases across 14 skills are decorative** — no runner, no CI, three incompatible schemas (proof no consumer exists).
- The one real `claude -p` behavioral runner (`test-behavioral.sh`, cron-only) covers 3 unrelated skills and asserts only on *activation*, never on a produced artifact, and never gates a PR.
- Deterministic helpers (slug logic, `canonicals_bootstrap.py`, `portfolio_snapshot.py`) **are** properly unit-tested — that part is sound.

Net: **behavioral coverage of any command/skill output is ~0%.** Mapped against the canonical design principles (Anthropic Agent Skills best-practices + "Building effective agents" + Claude Code docs; see the companion checklist), the plugin *follows* the structural/hygiene canon but *breaks* the highest-leverage principles, all clustered around evaluation: **build-evals-first, eval-scenarios-that-run, test-across-models, start-simplest, and measurement-flywheel.** The mechanical correctness produced an illusion of soundness while the instrument that measures soundness was never built — which is why the system rotted unnoticed and was never adopted.

## Decision Drivers

- **"Evaluations are your source of truth"** (Anthropic Agent Skills best-practices, "Build evaluations first"). We have none for the artifacts that matter.
- **A check nobody is forced to run rots** — proven here twice (the 113 dead eval cases; the cron-only runner). Must-do behavior needs a gate, not prose (Claude Code sub-agents docs; building-effective-agents).
- **Don't repeat the anti-pattern.** Retrofitting evals onto ~20 commands at once is itself the "big-bang, unvalidated" move the canon warns against. Adoption must be incremental and proven.
- **Side-effect-free testability is also a safety win** — a command that can compute its outputs without external writes is both eval-able and dry-runnable.

## Decision

A repo-wide engineering discipline for skills, commands, plugins, and subagents, enforced as a **phased ratchet**.

### D1 — Phased enforcement (ratchet, not big-bang)

- **Phase 1 (now) — forward-only + tiered.** The gate fires only when a skill/command is **created or materially changed**.
  - **Blocking checks:** (a) a side-effecting command sets `disable-model-invocation: true`; (b) a created/changed command ships a **side-effect-free emit mode** + **≥1 runnable behavioral eval** wired into CI.
  - **The eval gate is never unsatisfiable — a structure-first cascade:** (i) assert on the artifact's **deterministic structure** (JSON-schema, required keys, invariants) — this holds even when some fields are LLM-judged, so most judgment-bearing commands still pass *deterministically*; (ii) where the meaningful signal is genuinely open-ended, an `llm-rubric` eval via the reserved LLM tier (D2) counts — but because that tier is off the per-PR path, it lands as an **advisory** eval until it is stood up (a BC-12589 follow-on); (iii) for the rare command where neither is yet possible, a visible `# eval-waiver: <reason>` marker downgrades the gate to advisory for that one command **and** records it on the debt list — explicit, finite, never silent (mirrors the `# lint:not-side-effecting` override).
  - **Advisory checks (WARN):** the rest of the structural canon (body <500 lines, third-person description, no nested refs, fully-qualified MCP names, `${CLAUDE_PLUGIN_ROOT}` paths, etc.) — promotable to blocking later.
  - Existing untouched skills/commands are **grandfathered** onto a tracked **debt list** (= the Phase 2 backlog).
- **Phase 2 (committed follow-up) — retroactive + strict.** Backfill behavioral evals across the grandfathered surface and promote advisory checks to blocking. **Trigger:** the harness has shipped and proven on ≥3 forward commands AND the per-eval authoring cost is known (so the retrofit is estimable). Committing to Phase 2 up front is what stops "forward-only" from becoming "forever-only."

### D2 — What a behavioral eval is (artifact-level via emit mode)

- A behavioral eval **fixtures inputs → runs the command's emit mode → asserts on the produced artifacts** (JSON-schema + key-field assertions + golden-file compare). It asserts on the artifact's **stable structure** (schema, required keys, invariants), **not** on free-text prose or printed preview text — so legitimately-varying LLM-judged fields never make the eval flaky.
- **Emit mode** = a command's side-effect-free run: computes and writes all artifacts (`manifest.json`, issue payloads, copy JSON, …) to a sandbox temp dir, making **no external MCP writes** (no real Linear/SF/EB mutations). (`--dry-run` today exits before the writes; emit mode is the fix and the new testable seam.)
- **Harness (v1 — deterministic tier):** a **native in-repo python/bash runner wired into `validate.sh`/CI** runs the emit mode and applies deterministic JSON-schema + golden-file + key-field assertions, exit-code gated — the repo's established harness idiom (no new build/runtime dependency, no API key on the PR path). For `plan-campaign`, emit mode is realized by **extracting the command's mechanical manifest logic into a deterministic builder** the command delegates to; v1 evaluates that deterministic emit. The first eval — `plan-campaign` — defines the reusable pattern. *(This is the eval-framework research's approach #2 — the claude-evals pattern realized in the existing bash/Python harness.)*
- **Harness (deferred — LLM-orchestration tier):** [promptfoo](https://www.promptfoo.dev) `exec:` + `llm-rubric` (research approach #1) is **reserved** for a later **advisory/nightly** smoke that runs the real `claude -p` command and checks it drives the builder correctly. Non-blocking and off the per-PR path, so non-determinism / cost / API-key never gate a merge. Reserved, not discarded — the day a skill's LLM judgment is the unit under test, this is the harness.

### D3 — `evals/evals.json` deprecated

Stop authoring `evals/evals.json`. The 113 existing cases become **seed material** mined during Phase 2 backfill (mine, don't trust). When a skill gets a real artifact-level eval, its `evals.json` is converted/removed. Interim: a one-line header marks existing files as non-executing seed specs so they aren't mistaken for coverage.

### D4 — Scope: repo-wide

Applies to every plugin (workflows, marketing, revops, cadence, flow-architecture). Phase 1 is forward-only, so it only bites on change — cheap to apply repo-wide. The first harness implementation pilots on `plan-campaign` (marketing); scope of the rule ≠ order of the build.

## Consequences

- Every created/changed command must grow a **side-effect-free emit mode** — a one-time structural cost that also yields safe dry-runs. For `plan-campaign` (the pilot) this is realized by extracting a deterministic manifest **builder** (slug, back-filled dates, the 8-label constant set, the 8+2 issue set, the two-pass `blockedBy` graph, `manifest.json`) the command delegates to — pulling forward what the PRD had deferred, so the v1 eval is deterministic.
- **Detecting "side-effecting" (for the `disable-model-invocation` gate)** is heuristic + non-silent: the lint scans a command's `allowed-tools` + body for mutating-tool patterns (`mcp__*__(save|create|update|delete|deploy|send)_*`, `gh pr create`, `git push|commit|branch`); a hit without `disable-model-invocation: true` is a GATE finding. A false positive is overridden only by a visible `# lint:not-side-effecting <reason>` marker the lint records — no silent opt-out. Having an emit mode does **not** clear the flag (the default run is still the real, mutating one).
- `validate.sh` gains a structural lint (advisory tier) + a behavioral-eval gate (blocking, on changed commands). New deep-module + harness wiring required.
- A **debt list** of un-eval'd existing commands/skills is tracked in a **version-controlled repo file** (planned home `docs/skill-eval-debt.md`), created and populated by **BC-12590** (the M5 gate) and **machine-read by the forward-only gate** to skip grandfathered commands. It is also where Phase-1 **eval-waivers** (D1) are recorded. A concrete file — not an implicit shared understanding — is what keeps the Phase 2 trigger ("proven on ≥3 forward commands AND per-eval cost known") trackable.
- The campaign *product* redesign (issue decomposition, missing deck/script commands, EB-multi-platform, PR #429's fate) is a **separate track**, to be decided *against* the eval once `plan-campaign` has one — not against markdown-grep. **PR #429 should not merge before plan-campaign has a behavioral eval.**
- `docs/guides/skill-command-design-standards.md` becomes the canonical checklist; CLAUDE.md gotchas may reference it.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Retroactive big-bang (eval all ~20 commands before "done") | The "do it all at once, unvalidated" anti-pattern; blocks everything on a huge upfront cost |
| Advisory-only forever (WARN, never block) | "A check nobody is forced to run rots" — proven twice in this very repo |
| Build a runner for the existing `evals.json` format | Three incompatible schemas; they're static declarations, not artifact-level behavioral evals; superseded by the D2 harness |
| A meta-skill that *teaches* the canon (no gate) | More untested prose before the measurement exists — repeats the exact anti-pattern. Deferred until the gate is proven; then folds into existing `write-a-skill`/`best-practices-audit` |
| Assert on `--dry-run` preview text | Tests the plan, not the writes; gameable by editing the print; current dry-run exits before artifacts exist |
| Run the **LLM emit** (`claude -p`) as the per-PR gate | Non-deterministic → golden-compare flaky; needs an `ANTHROPIC_API_KEY` secret + cents/PR + `repeat-min-pass` math; a probabilistic gate is a poor *first* proof for the tracer. `plan-campaign` is ~95% deterministic, so the per-PR gate evaluates the extracted deterministic builder; the live-LLM run is deferred to an advisory/nightly smoke. |
| Adopt **promptfoo** as the v1 harness | Its value (`exec:` wrapping, `llm-rubric`, `repeat`) is for LLM-call-as-unit; with a deterministic builder it reduces to a custom-python-assert plus a node/Action dependency for zero deterministic-assert benefit — "build the thing you don't need yet," the anti-pattern this ADR fights. Reserved for the LLM-smoke tier instead. |

## Cross-references

- Companion checklist: `docs/guides/skill-command-design-standards.md`
- Terminology: `CONTEXT.md` § Agent tooling & evaluation
- Origin: PR #429 review (plan-campaign 2-issue rework) → soundness/eval investigation
