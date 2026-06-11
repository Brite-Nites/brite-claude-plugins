# Skill / Command / Plugin / Subagent — design standards

Canonical checklist for building agent tooling in this repo. Derived from Anthropic's Agent Skills best-practices, "Building effective agents," and the Claude Code docs (skills / sub-agents / plugins), reconciled with this repo's hard-won gotchas. Enforcement model: **[ADR-028](../decisions/028-skill-engineering-discipline.md)** (phased ratchet). Terminology: `CONTEXT.md` § Agent tooling & evaluation.

**Enforcement tags**:
- **[GATE]** — blocking (fails CI): on a created/changed command via the eval-gate diff-gate, and — once a rule is promoted — across the whole commands+skills surface via the full-surface structural gate (`eval_gate.py --structural`, [ADR-034](../decisions/034-structural-ratchet-full-surface-gate.md); grandfathered exceptions live in `docs/structural-lint-debt.md`).
- **[GATE-existing]** — already-enforced blocking check that pre-dates ADR-028 (e.g. plugin-layout, version-bump); not new, listed here for completeness.
- **[ADV]** — advisory WARN; promoted to [GATE] one rule at a time (the BC-12700 Phase-2 ratchet, flip order R3→R5→R6→R2→R4), each only after its surface is clean or grandfathered.
- **[REF]** — reference principle; not linted, but reviewers should apply it.

---

## 0. The two non-negotiables (Phase 1 gates)

- **[GATE] A side-effecting command sets `disable-model-invocation: true`.** If running it creates/edits/sends/deploys anything (Linear issues, SF records, emails, git/PRs), the model must not be able to fire it unprompted. **Detection (M1):** the lint scans `allowed-tools` + body for mutating-tool patterns (`mcp__*__(save|create|update|delete|deploy|send)_*`, `gh pr create`, `git push|commit|branch`); a hit without the flag is a GATE finding. Override a false positive only with a visible `# lint:not-side-effecting <reason>` marker — no silent opt-out. An emit mode does **not** clear the flag (the *default* run still mutates).
- **[GATE] A created/changed command ships a side-effect-free emit mode + ≥1 behavioral eval in CI.** The eval fixtures inputs → runs emit mode → asserts on the produced artifact's **stable structure** (schema + key fields + golden compare), not free-text prose. See §5. **The gate is never unsatisfiable:** assert on deterministic structure first (covers most LLM-judged commands); an `llm-rubric` eval via the reserved LLM tier counts as an *advisory* eval; a rare genuinely-unevaluable command uses an explicit `# eval-waiver: <reason>` marker (advisory + debt-listed, never silent).

---

## 1. Agent Skills (recipe cards)

- **[ADV] Progressive disclosure.** Layer: `description` (always loaded) → `SKILL.md` body (on trigger) → bundled reference files (only when read). Unused content costs zero tokens.
- **[ADV] Body < ~500 lines.** Once loaded, every line is a recurring per-session token cost. Split into reference files when it grows.
- **[REF] Context is a public good.** Only add what the model doesn't already know. Challenge each line's token cost.
- **[GATE] Description: third person, states what it does AND when to use it, with trigger terms, key use case first.** It's the routing signal; vague/first-person descriptions break discovery. (Listing budget truncates ~1.5k chars — front-load.) *Promoted R3, BC-13213 (ratchet 1/5): the lint gates the enforceable core — a first-person description blocks; the rest of this bullet stays reviewer guidance.*
- **[ADV] File references one level deep; TOC on any reference file > 100 lines.** Chained refs get partially read.
- **[REF] Match degrees of freedom to fragility.** Exact scripts/steps for fragile/consistency-critical ops; prose for open-ended judgment.
- **[REF] Deterministic work → code, not tokens.** Sorting/validation/fixed transforms belong in a helper script, not model generation. Make execution-vs-reference intent explicit.
- **[ADV] Fully-qualified MCP tool names** (`mcp__plugin_<plugin>_<server>__*`); **[ADV] `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` paths** (never hardcoded/absolute/backslash).
- **[REF] One word per concept; single default + escape hatch; no magic constants** (document every number).
- **Anti-patterns:** vague/first-person descriptions; deeply nested refs; verbose explanation of things the model knows; too many options with no default; non-descriptive filenames.

## 2. Plugins

- **[REF] Plugin vs standalone:** plugin when you need to share/version/distribute; standalone `.claude/` for personal/single-project.
- **[GATE-existing] Only `plugin.json` in `.claude-plugin/`;** components (`skills/`, `agents/`, `hooks/`, `.mcp.json`) at the plugin root. (Already enforced.)
- **[GATE-existing] Bump `version` in the same commit as any change under `plugins/<p>/{skills,commands,agents,hooks}/`** — clients cache by version. Bump both `plugin.json` and the `marketplace.json` entry.
- **[REF] Strict `plugin.json` schema** — unrecognized fields fail silently; never add `agents`/`hooks`/`mcpServers`-as-path.
- **[REF] MCP soft cap ~5–6 per plugin** (startup latency + context budget; measure before exceeding).

## 3. Commands (slash-invoked skills)

- **[GATE] `disable-model-invocation: true` on side-effecting commands** (see §0).
- **[ADV] `allowed-tools` scoped to exactly what the command needs** (it pre-approves without prompting).
- **[REF] `$ARGUMENTS`/positional args + `argument-hint`;** inject live context with `` !`cmd` `` so the prompt is grounded in real state.
- **[REF] Few, intuitive commands** — shortcuts for frequent prompts, not a private DSL.

## 4. Subagents

- **[REF] One subagent = one task** (single responsibility, focused system prompt).
- **[REF] Use for verbose side work** you won't reference again; returns only a summary. Prefer the main conversation for tight back-and-forth.
- **[ADV] Trigger-laden `description`; least-tool access** (`tools` allowlist / `disallowedTools`; a read-only reviewer denies Write/Edit).
- **[REF] Cheapest capable `model` per agent;** concrete numbered operating procedure in the body. Watch returned-result volume (many large returns defeat the context saving). Subagents can't spawn subagents.

## 5. Evaluation & testability (the discipline)

- **[GATE] Behavioral eval before merge** for created/changed commands (§0). Shape: **fixture → emit mode → assert on artifact.**
  - Emit mode: compute + write artifacts to a sandbox temp dir, **no external MCP writes**. Where the artifact is deterministic given the inputs (e.g. `plan-campaign`'s manifest), realize emit mode by delegating to an extracted **deterministic builder** so the eval is reproducible.
  - Harness (v1, deterministic tier): a **native in-repo python/bash runner wired into `validate.sh`**, exit-code gated — JSON-schema + golden-file + key-field asserts. No new build/runtime dependency, no API key on the PR path.
  - Harness (deferred, LLM tier): promptfoo `exec:` + `llm-rubric` is **reserved** for a later advisory/nightly smoke that runs the real `claude -p` command and checks it drives the builder correctly — off the per-PR path so non-determinism/cost never gate a merge.
- **[REF] Build evals first.** Baseline without the artifact, write ≥3 scenarios with expected-behavior rubrics from observed failures, then write the minimal instructions to pass them. "Evaluations are your source of truth."
- **[REF] Develop with the Claude-A authors / Claude-B uses loop;** test across every model you'll deploy on (Haiku/Sonnet/Opus).
- **[REF] Start with the simplest thing;** add agentic complexity only when a simpler approach measurably falls short. Workflow (fixed path) for well-defined tasks; autonomous agent only when steps can't be predicted.
- **[REF] Enforce must-do rules with hooks, not prose.** Prose is should-do.
- **[REF] Measurement → improve → re-measure** from real usage; no feedback loop = the same mistakes recur (and adoption failures go unseen).
- **Test taxonomy (don't conflate):** *structural* (greps the spec — proves prose), *unit* (deterministic helper logic — legit but not behavioral), *behavioral* (emit mode → artifact — the only proof of behavior). See `CONTEXT.md`.
- **Deprecated:** `evals/evals.json` — non-executing seed specs (ADR-028 D3), not runnable evals. Do not author new ones.
- **Implemented (Phase 1, M1):** the structural lint at `scripts/eval/structural_lint.py` emits `findings[]` (`{rule_id, severity: gate|advisory, message, file, line?}`) over every command/`SKILL.md` and `evals.json`, wired **advisory (WARN-only)** into `validate.sh` § 15a-bc-12588 (BC-12588). `severity: gate` is a tier label that flips to build-failing in the M5 gate (BC-12590), which consumes these findings. The R1 side-effecting heuristic there is the canonical executable copy of the § 0 prose (distinct from the destructive-command security regex in `scripts/test-hooks.sh`).
- **Implemented (Phase 1, M5 — the flip to blocking):** the forward-only gate at `scripts/eval/eval_gate.py` (BC-12590) consumes the M1 `findings[]` + the M2 `ADAPTERS` registry. On a `pull_request` a dedicated CI job (`validate-plugin.yml` § eval-gate, `fetch-depth: 0`) **blocks** any command *changed* vs `origin/main` when (Split A′): its `severity: gate` structural finding fires — R1, on **any** changed command — **or** it lacks a passing behavioral eval **and** a debt-list grandfather **and** a `# eval-waiver: <reason>`. The grandfather + waiver record is `docs/skill-eval-debt.md`; its integrity invariant (`debt ∩ ADAPTERS == ∅`, `debt ∪ ADAPTERS == the command surface`) is wired **blocking** into `validate.sh` § 15a-bc-12590 via `eval_gate.py --check` (diff-free, so it runs in the shallow `validate` checkout where the live diff-gate can't). Untouched commands stay grandfathered; the Phase-2 backfill trigger lives in the debt-list header.

---

## Self-audit snapshot (2026-06-05, marketing plugin)

From the originating audit: behavioral coverage ≈ 0% (prompt-command tests are ~95% structural; `test_plan_campaign_contracts.py` is markdown-grep and not in CI); 113 decorative `evals.json` cases across 14 skills; one cron-only `claude -p` runner covering 3 skills (activation only). Deterministic helpers are properly unit-tested. The mechanical canon (§1–4 hygiene) is largely followed; the §5 eval discipline is the gap ADR-028 closes. First harness pilot: `plan-campaign`.
