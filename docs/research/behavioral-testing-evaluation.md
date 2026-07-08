# Runtime Behavioral Testing for Agent Harnesses

**Issue:** BC-2458
**Consumes:** Promptfoo, gstack, Skillgrade, Anthropic skill-creator, Contradish, pytest-aitest
**Consumed by:** BC-2462 (Build runtime behavioral test framework)
**Date:** 2026-03-25

---

## 1. Current State

The Brite plugin has **304 structural tests** across 4 automated scripts, plus a manual 6-layer testing guide (96 cases). Zero behavioral tests exist — nothing validates that skills produce correct output when invoked by a real Claude session.

| Script | Tests | Type | Runtime |
|--------|-------|------|---------|
| `scripts/validate.sh` | ~200 | JSON, frontmatter, cross-refs, schema | <5s, $0 |
| `scripts/test-hooks.sh` | 37 | Security regex matching | <1s, $0 |
| `scripts/test-skill-triggers.sh` | 40 | Keyword trigger matching | <1s, $0 |
| `scripts/test-scenarios.sh` | 225 | Trait→artifact mapping | <2s, $0 |
| `scripts/probe-plugin-load.sh` | 21 | CLI integration (`claude -p`) | ~30s, ~$0.05 |

**Bridge pattern:** `probe-plugin-load.sh` (line 92) already invokes `claude -p` as a subprocess:
```bash
output=$(claude --plugin-dir "$PLUGIN_DIR" -p \
  "List every slash command available that starts with /$plugin_name:. ..." \
  2>&1) || true
```
This is the same pattern gstack uses for Tier 2 E2E tests. The behavioral test framework should extend this, not replace it.

**Key gaps:**
- No skill activation testing under real Claude sessions
- No output quality evaluation (LLM-as-judge)
- No regression baselines
- No cost tracking per test run

---

## 2. Framework Evaluation

### 2.1 Promptfoo

**What:** MIT-licensed CLI for prompt evaluation. 18.5k GitHub stars. Acquired by OpenAI (March 2026), remains open source.

**Subprocess support:** Yes — `exec:` provider prefix runs any shell command. The prompt is passed as argument 1:
```yaml
providers:
  - 'exec: bash scripts/run-claude-test.sh'
tests:
  - description: "Brainstorming activates for multi-module redesign"
    vars:
      prompt: "I need to redesign the auth system, it spans 3 modules"
    assert:
      - type: contains
        value: "Design Document"
      - type: llm-rubric
        value: "Output contains clarifying questions and explores alternatives"
        threshold: 0.7
```

**LLM-as-judge:** 13 assertion types including `llm-rubric` (general), `model-graded-closedqa`, `factuality`, `trajectory:goal-success`. Configurable grading model at global, suite, or per-assertion level. Custom rubric prompts supported.

**CI integration:** Official GitHub Action (`promptfoo/promptfoo-action@v1`) with PR comment posting, before/after comparison, and failure thresholds.

**Runtime:** Requires Node.js. Can run via `npx promptfoo@latest eval` (no `package.json` or `node_modules` in your repo). JS custom providers live in-repo as standalone files.

**Cost:** Tool is free. You pay only for LLM API calls (grading model + test provider).

**Strengths:**
- Rich assertion library (deterministic + LLM-judged)
- Declarative YAML config — non-engineers can edit test cases
- Built-in caching, retry, and parallel execution
- Active open-source community

**Weaknesses:**
- Requires Node.js on the machine (CI needs `actions/setup-node`)
- YAML config is a new format to learn (not bash)
- `exec:` provider passes prompt as shell argument — needs careful escaping for multiline prompts
- Overhead for a small test suite (~10 cases)

### 2.2 gstack E2E Pattern

**What:** Custom Bun/TypeScript test harness in garrytan/gstack. MIT license. The reference architecture for Claude Code plugin testing.

**Subprocess pattern:** `SessionRunner` spawns:
```
sh -c 'cat "<promptFile>" | claude -p --model <model> --output-format stream-json --verbose'
```
Prompts written to temp files (avoids shell escaping). Streams NDJSON for real-time progress. Default model: `claude-sonnet-4-6`, overridable via `EVALS_MODEL`.

**LLM-as-judge:** Two judge functions:
1. **`judge()`** — Documentation quality. Three dimensions (1-5): clarity, completeness, actionability. Graded by `claude-sonnet-4-6`.
2. **`outcomeJudge()`** — Planted-bug detection. Compares QA reports against ground-truth fixtures. Returns `detected[]`, `missed[]`, `false_positives`, `detection_rate`, `evidence_quality`.

**Results storage:** `~/.gstack/projects/$SLUG/evals/{version}-{branch}-{tier}-{timestamp}.json`. Incremental `_partial` writes survive crashes. `compareEvalResults()` computes per-test status changes with investigation guidance.

**Cost:** Tier 1 free, Tier 2 ~$3.85/run (~20 min), Tier 3 ~$0.15/run (~30s). 12 parallel CI suites, 25 min timeout each.

**Strengths:**
- Battle-tested on a production plugin (26 skills)
- Sophisticated regression comparison with per-test deltas
- Planted-bug methodology validates real skill output
- Machine-readable diagnostics (`exit_reason`, `timeout_at_turn`, `last_tool_call`)

**Weaknesses:**
- Requires Bun runtime + `package.json` + TypeScript dependencies
- Heavily coupled to gstack's specific test infrastructure
- Not reusable as a library — patterns must be adapted, not installed

### 2.3 Skillgrade (Minko Gechev)

**What:** MIT-licensed CLI purpose-built for testing SKILL.md files. Reads your skill, auto-generates `eval.yaml` with tasks and graders.

**How it works:**
1. `skillgrade init` reads SKILL.md, generates `eval.yaml` with test tasks
2. `skillgrade run` executes tasks against a real agent (Gemini, Claude, or OpenAI)
3. Two grader types: **deterministic** (bash scripts returning JSON scores) and **LLM rubric** (qualitative judgment)
4. Three presets: `--smoke` (5 trials), `--reliable` (15 trials), `--regression` (30 trials)
5. `--ci` flag exits non-zero if pass rate < threshold (default 0.8)

**CI integration:** `--ci` flag for GitHub Actions. Configurable pass threshold.

**Runtime:** Node.js 20+, installed via `npm i -g skillgrade`.

**Strengths:**
- **Purpose-built for SKILL.md** — reads your skill file directly, auto-generates evals
- Deterministic graders can be bash scripts (aligns with existing pattern)
- Multiple trial presets handle non-determinism natively
- Simplest path from zero to behavioral tests

**Weaknesses:**
- npm dependency (global install, not in repo)
- Tests individual skills, not multi-skill interactions or command flows
- Newer tool — smaller community than Promptfoo
- Less control over subprocess invocation than custom scripts

### 2.4 Anthropic Skill-Creator Evals

**What:** A meta-skill in the official [anthropics/skills](https://github.com/anthropics/skills) repository. Runs inside Claude Code — not a standalone CI tool.

**Eval methodology (gold standard for trigger testing):**
- **Positive/Should-Trigger** (8-10 queries): Different phrasings of same intent, cases where skill isn't named but clearly needed, uncommon use cases
- **Negative/Should-Not-Trigger** (8-10 queries): Near-misses sharing keywords, adjacent domains, ambiguous phrasing — emphasis on genuinely tricky negatives
- **Edge Cases:** Boundary conditions folded into positive/negative sets

**Pipeline:** 4 parallel subagents — executor, grader, comparator (blind A/B between skill versions), analyzer (surfaces patterns stats miss).

**Assertion format:** `{ text, passed, evidence }` — worth adopting regardless of tooling.

**Strengths:**
- Best eval methodology found — the positive/negative/edge taxonomy is directly applicable
- A/B comparison between skill versions enables iterative improvement
- Runs against real Claude with full plugin context

**Weaknesses:**
- **Not CI-compatible** — runs interactively inside Claude Code, can't be scripted in a pipeline
- Python scripts for aggregation/viewing add light dependency
- Designed for skill description optimization, not output quality testing

**Adoption path:** Extract the eval methodology (trigger taxonomy, assertion format) without using the tool itself.

### 2.5 Contradish

**What:** SaaS product + Python CLI (`pip install contradish`). Detects cases where the same LLM produces contradictory answers under different phrasings of the same question.

**Fit:** Narrow. Tests instruction consistency, not skill activation or output quality. CI regression "coming soon." Requires Python + API key.

**Verdict:** Methodology is interesting (generate paraphrase variants, check consistency), but too narrow for primary evaluation and not pipeline-ready. Can be replicated manually in a custom test.

### 2.6 pytest-aitest

**What:** MIT-licensed pytest plugin for testing MCP servers, tools, and agents. Python 3.11+.

**Fit:** Poor. Requires Python + pytest as hard dependencies. Designed for MCP server testing, not markdown instruction files. Powerful semantic assertions (`llm_assert`, `llm_score`, tool invocation checks) but targets a different problem.

**Verdict:** Wrong tool for a markdown-only plugin. Worth revisiting if the plugin ever ships its own MCP server.

### 2.7 Custom Bash (Extend Existing)

**What:** Write `scripts/test-behavioral.sh` following the same `pass()`/`fail()`/`section()` pattern as existing scripts. Extend the `claude -p` invocation from `probe-plugin-load.sh`.

**How it works:**
```bash
# Read test cases from JSON fixture
# For each test case:
output=$(claude --plugin-dir "$PLUGIN_DIR" -p "$prompt" 2>&1) || true
# Check expected markers
if echo "$output" | grep -qi "$expected_marker"; then pass "..."; else fail "..."; fi
# Optional: pipe to LLM-as-judge via API call
score=$(curl -s https://api.anthropic.com/v1/messages -d '...' | jq '.content[0].text')
```

**Strengths:**
- Zero new dependencies — pure bash, extends existing patterns
- Full control over subprocess invocation, output capture, and scoring
- Maintainable by anyone who can read the existing test scripts
- Aligns with project philosophy (no build process)

**Weaknesses:**
- Must build LLM-as-judge from scratch (curl + jq + parsing)
- No built-in caching, retry, or parallel execution
- No assertion library — reinventing what Promptfoo/Skillgrade provide
- Shell escaping for multiline prompts requires care

---

## 3. Comparison Matrix

| Criterion | Promptfoo | gstack | Skillgrade | Skill-Creator | Contradish | pytest-aitest | Custom Bash |
|-----------|-----------|--------|------------|---------------|------------|---------------|-------------|
| **Markdown plugin fit** | Good (exec provider) | Adapted (custom harness) | **Excellent** (purpose-built) | Good (interactive only) | Poor | Poor | **Excellent** |
| **Bash integration** | Partial (YAML config) | None (TypeScript) | Partial (bash graders) | None | None | None | **Native** |
| **LLM-as-judge** | **Built-in** (13 types) | Custom (2 judges) | **Built-in** (rubric type) | Built-in (grader subagent) | N/A | Built-in | DIY (curl) |
| **Cost per run (10 tests)** | ~$2-5 (LLM only) | ~$4.00 | ~$2-5 | ~$2-5 | ~$1-2 | ~$2-5 | ~$2-5 |
| **CI integration** | **Official GitHub Action** | Custom workflow | `--ci` flag | **None** | Coming soon | pytest | Manual |
| **Setup complexity** | Low (npx, YAML) | High (Bun, TS, pkg) | Low (npm -g) | Medium (inside Claude) | Medium (pip, API) | High (Python, pytest) | **Lowest** |
| **Skill activation testing** | Via assertions | Via SessionRunner | **Native** | **Native** (trigger evals) | No | Indirect | Via grep |
| **Output quality testing** | **Best** (rubric + threshold) | Good (3-dim scoring) | Good (LLM rubric) | Good (grader agent) | No | Good (llm_assert) | DIY |
| **Non-determinism handling** | Retry + threshold | N trials manually | **3 presets** (5/15/30) | Blind A/B comparison | Variant generation | N/A | DIY (run N times) |
| **Dependencies added** | Node.js (npx, no pkg.json) | Bun + pkg.json + deps | Node.js (global) | None (interactive) | Python + pip | Python + pytest | **None** |
| **Learning curve** | Medium (YAML + assertions) | High (custom codebase) | **Low** (init + run) | Medium (subagent model) | Low | Medium (pytest + async) | **Low** (bash) |

---

## 4. Recommended Approach

### Primary: Hybrid — Skillgrade + Custom Bash

**Phase 1 (immediate):** Use **Skillgrade** for per-skill behavioral testing.
- Install globally: `npm i -g skillgrade` (dev-only, not in repo)
- Run `skillgrade init` in each skill directory to auto-generate eval configs
- Use `--smoke` (5 trials) for quick iteration, `--regression` (30 trials) for pre-release
- Deterministic graders (bash scripts) for structural checks, LLM rubric for quality
- CI: `skillgrade run --ci --threshold 0.8` in a separate GitHub Actions workflow

**Phase 2 (follow-on):** Extend **custom bash** for multi-skill integration tests.
- `scripts/test-behavioral.sh` for tests that span multiple skills or validate command flows
- Tests that Skillgrade can't cover: command sequences, inner loop flow, precedence behavior under real Claude sessions
- LLM-as-judge via `curl` to Anthropic API for output quality scoring
- JSON fixtures in `tests/fixtures/behavioral-registry.json`

**Future upgrade path:** If the test suite grows beyond ~30 cases or needs richer assertions, migrate from custom bash to **Promptfoo** YAML configs. The `exec:` provider wraps the same `claude -p` subprocess. This is a smooth migration — test case logic stays the same, only the runner changes.

### Rationale

1. **Skillgrade is purpose-built.** It reads SKILL.md directly, auto-generates evals, and handles non-determinism with trial presets. No other tool offers this.
2. **Custom bash fills the gap.** Skillgrade tests individual skills. Multi-skill interactions, command flows, and integration scenarios need the `claude -p` subprocess pattern we already have.
3. **Zero in-repo dependencies.** Skillgrade is a global install. Custom bash has no dependencies. Neither adds `package.json` or `node_modules` to the repo.
4. **Gradual adoption.** Start with Skillgrade for 3-5 high-value skills, add custom bash for integration scenarios, then optionally adopt Promptfoo if the suite outgrows bash.

### Methodology Adoption (from Anthropic Skill-Creator)

Regardless of tooling, adopt these patterns from the skill-creator eval methodology:
- **Trigger taxonomy:** Every skill gets 8-10 positive prompts, 8-10 negative prompts, and edge cases
- **Assertion format:** `{ text: string, passed: boolean, evidence: string }` — machine-parseable
- **Iterative improvement:** Run evals after description changes, compare before/after scores

---

## 5. Architecture Design

### 5.1 Three-Tier Model

```
Tier 1: Structural ($0, <5s)                 ← EXISTS
├── validate.sh (JSON, frontmatter, cross-refs)
├── test-hooks.sh (security regex)
├── test-skill-triggers.sh (keyword matching)
└── test-scenarios.sh (trait→artifact mapping)

Tier 2: E2E Behavioral (~$2-5, ~15-25min)   ← NEW
├── skillgrade (per-skill evals)
│   ├── skills/brainstorming/eval.yaml
│   ├── skills/systematic-debugging/eval.yaml
│   └── skills/frontend-design/eval.yaml
└── test-behavioral.sh (multi-skill integration)
    └── tests/fixtures/behavioral-registry.json

Tier 3: LLM-as-Judge (~$0.10-0.20, ~30s)   ← NEW
└── score-behavioral.sh (quality scoring)
    ├── Judges Tier 2 outputs
    ├── 3 dimensions: clarity, completeness, actionability (1-5 scale)
    └── Threshold: ≥4/5 per dimension
```

### 5.2 File Structure

```
scripts/
  test-behavioral.sh          # NEW: Tier 2 multi-skill integration tests
  score-behavioral.sh          # NEW: Tier 3 LLM-as-judge scoring
tests/
  fixtures/
    scenario-registry.json     # EXISTS: Tier 1 trait→artifact fixtures
    behavioral-registry.json   # NEW: Tier 2 test case definitions
plugins/workflows/skills/
  brainstorming/
    SKILL.md                   # EXISTS
    eval.yaml                  # NEW: Skillgrade config (auto-generated)
  systematic-debugging/
    SKILL.md
    eval.yaml
  frontend-design/
    SKILL.md
    eval.yaml
.github/workflows/
  validate-plugin.yml          # EXISTS: Tier 1 (every push)
  behavioral-tests.yml         # NEW: Tier 2+3 (manual/nightly)
```

### 5.3 CI Integration

**Tier 1 (existing):** Runs on every push via `validate-plugin.yml`. Free, fast.

**Tier 2+3 (new):** Separate workflow `behavioral-tests.yml`:
```yaml
name: Behavioral Tests
on:
  workflow_dispatch:           # Manual trigger
  schedule:
    - cron: '0 6 * * 1,4'     # Mon+Thu 6am UTC (2x/week)
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
jobs:
  skillgrade:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm i -g skillgrade
      - run: |
          for skill_dir in plugins/workflows/skills/*/; do
            [ -f "$skill_dir/eval.yaml" ] || continue
            skillgrade run "$skill_dir" --ci --threshold 0.8
          done
  integration:
    runs-on: ubuntu-latest
    needs: skillgrade
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/test-behavioral.sh
      - run: bash scripts/score-behavioral.sh
```

Budget safeguard: Limit Skillgrade to skills with `eval.yaml` (opt-in). Start with 3-5 skills.

---

## 6. Cost Model

### Per-Tier Costs

| Tier | Per-Test | Per-Run (10 tests) | Duration | Trigger |
|------|----------|-------------------|----------|---------|
| 1 (Structural) | $0 | $0 | <5s | Every push |
| 2a (Skillgrade, --smoke) | ~$0.15 | ~$1.50 | ~10 min | Dev iteration |
| 2a (Skillgrade, --reliable) | ~$0.45 | ~$4.50 | ~25 min | Pre-merge |
| 2a (Skillgrade, --regression) | ~$0.90 | ~$9.00 | ~45 min | Pre-release |
| 2b (Integration, claude -p) | ~$0.25-0.50 | ~$2.50-5.00 | ~15-25 min | Manual/nightly |
| 3 (LLM-as-judge) | ~$0.01-0.02 | ~$0.10-0.20 | ~30s | After Tier 2 |

### Monthly Projections

| Cadence | Skillgrade (smoke) | Integration | Judge | Total |
|---------|-------------------|-------------|-------|-------|
| 2x/week (CI) | $12/mo | $20-40/mo | $0.80/mo | **$33-53/mo** |
| Daily (aggressive) | $45/mo | $75-150/mo | $3/mo | **$123-198/mo** |
| Pre-merge only (~8/mo) | $12/mo | $20-40/mo | $0.80/mo | **$33-53/mo** |

**Recommended starting cadence:** 2x/week automated (Mon+Thu), plus manual trigger before major PRs. ~$33-53/month.

### Assumptions

- Tier 2 per-test: Sonnet input ~2K tokens prompt + ~10K skill context, output ~2-5K tokens
- Tier 3 per-test: Haiku judge input ~3K tokens output + rubric, output ~200 tokens
- Skillgrade --smoke: 5 trials per test case (5x base cost)
- Integration tests use `claude -p` with `--plugin-dir` flag
- Costs scale linearly with test count; prioritize high-value skills first

---

## 7. Seed Test Cases

Ten concrete test cases covering activation, non-activation, precedence, and output quality. These align with the existing `trigger-registry.json` test cases but operate at the behavioral level (real Claude sessions) rather than the keyword-matching level.

### JSON Fixture Format

```json
{
  "version": "1.0.0",
  "description": "Behavioral test registry for Brite plugin skills",
  "consumed_by": "scripts/test-behavioral.sh",
  "test_cases": [
    ...
  ]
}
```

### Test Case Schema

```json
{
  "id": "B01",
  "description": "Human-readable test purpose",
  "tier": 2,
  "prompt": "The exact prompt sent to claude -p",
  "expected_skill": "skill-name or null",
  "expected_markers": ["strings that MUST appear in output"],
  "not_expected_markers": ["strings that must NOT appear"],
  "not_expected_skills": ["skills that should NOT activate"],
  "judge_rubric": {
    "clarity": 4,
    "completeness": 4,
    "actionability": 4
  },
  "estimated_cost": "$0.30",
  "notes": "Why this test exists"
}
```

### Seed Cases

| ID | Description | Prompt (abbreviated) | Expected Skill | Key Markers | Judge? |
|----|-------------|---------------------|----------------|-------------|--------|
| B01 | Brainstorming activates for multi-module redesign | "I need to redesign the auth system, it spans 3 modules and there are multiple approaches" | brainstorming | "Design Document", clarifying questions | Yes |
| B02 | Brainstorming does NOT activate for trivial change | "Rename the README.md title to 'Project Guide'" | null | No skill banners | No |
| B03 | Systematic debugging activates on bug report | "The login form submits but the session cookie isn't being set, users get logged out immediately" | systematic-debugging | "Reproduce", "Isolate", "Analyze", "Fix" (4-phase) | Yes |
| B04 | frontend-design activates, NOT ui-ux-pro-max | "Build a login form component with email and password fields using React and Tailwind" | frontend-design | React/JSX code output, component definition | Yes |
| B05 | ui-ux-pro-max activates, NOT frontend-design | "Choose a color palette and font pairing for our SaaS analytics dashboard" | ui-ux-pro-max | palette/color recommendations, font names | Yes |
| B06 | web-design-guidelines beats frontend-design | "Review the current UI for accessibility compliance and audit the design" | web-design-guidelines | accessibility findings, compliance references | No |
| B07 | Precedence: debugging beats brainstorming | "I want to explore alternatives for the payment service but there's also a production bug with error reports" | systematic-debugging | 4-phase debugging output | No |
| B08 | code-quality activates for linting setup | "Set up ESLint and Prettier for this TypeScript monorepo" | code-quality | Config file content (.eslintrc, .prettierrc) | No |
| B09 | No skill fires for irrelevant prompt | "What's the capital of France?" | null | Direct answer, no skill activation banner | No |
| B10 | Output quality: brainstorming clarity/completeness | "We need to add real-time notifications — it touches the API, WebSocket layer, and React frontend" | brainstorming | design doc with sections, alternatives explored | Yes (≥4/5) |

### Skillgrade Eval.yaml Examples

For skills using Skillgrade, the `eval.yaml` is auto-generated by `skillgrade init` but can be customized. Example for brainstorming:

```yaml
# plugins/workflows/skills/brainstorming/eval.yaml
skill: ./SKILL.md
tasks:
  - prompt: "I need to redesign the auth system, it spans 3 modules"
    graders:
      - type: deterministic
        command: "bash -c 'echo $OUTPUT | grep -qi \"design document\" && echo {\"score\":1} || echo {\"score\":0}'"
      - type: rubric
        criteria: "Output asks clarifying questions and explores at least 2 alternative approaches"
        weight: 2
  - prompt: "Rename the README.md title"
    graders:
      - type: deterministic
        command: "bash -c 'echo $OUTPUT | grep -qi \"design document\" && echo {\"score\":0} || echo {\"score\":1}'"
        # Score 1 if the skill does NOT produce a design document (should not activate)
threshold: 0.8
trials: 5  # --smoke preset
```

---

## 8. Gaps from Planning Phase

The BC-2458 issue description listed Promptfoo, Skillgrade, Contradish, Anthropic skill-creator, gstack, and pytest-aitest. Planning-phase research referenced these but missed several critical considerations:

### Gap 1: Non-Determinism Handling

Planning-phase research treated tests as deterministic. Behavioral tests are inherently non-deterministic — the same prompt can produce different skill activations or output structures across runs.

**Mitigation:** Skillgrade handles this natively with trial presets (5/15/30 runs). For custom bash tests, run each test case N times and require M/N passes. Recommended: N=5, M=4 (80% pass rate) for smoke, N=15, M=12 for regression.

### Gap 2: Regression Detection

Structural tests have a fixed expected output. Behavioral tests need baselines and drift detection.

**Mitigation:** Store Tier 2+3 results as JSON artifacts in CI. Compare current run against the previous run's artifact. Flag regressions: any test that passed last run but fails now. Adopt gstack's `compareEvalResults()` pattern for per-test delta reporting.

### Gap 3: Test Isolation

Each `claude -p` invocation loads the full plugin. Questions:
- Does Claude retain session state between invocations? (Answer: No — `claude -p` is stateless)
- Do auto-memory files affect test results? (Yes — use `--no-memory` or run in a clean `$HOME`)
- Do other installed plugins interfere? (Possible — use `--plugin-dir` to load only the test plugin)

**Mitigation:** Use `claude --plugin-dir ./plugins/workflows -p --no-memory "..."` for isolated invocations. Create a test-specific `$HOME` (tmpdir) to avoid auto-memory contamination.

### Gap 4: Model Version Pinning

Claude model updates can change skill activation behavior. Tests that pass on Sonnet 4.5 may fail on Sonnet 4.6.

**Mitigation:** Pin the model in test invocations: `claude -p --model claude-sonnet-4-6 "..."`. Record model version in test results JSON. When comparing across runs, flag model version changes as a variable.

### Gap 5: Plugin Hook Limitation

PreToolUse/PostToolUse hooks don't fire from plugins (upstream bug [#6305](https://github.com/anthropics/claude-code/issues/6305)). Behavioral tests cannot validate hook behavior — only skills and commands.

**Mitigation:** Document this limitation. Test hooks via `test-hooks.sh` (regex matching) and the manual Layer 5 tests in `docs/testing-guide.md`. Revisit when #6305 is resolved.

### Gap 6: Cost Scaling

As skills grow from 23 to 50+, testing all skills becomes expensive. Need a prioritization strategy.

**Mitigation:** Define a **smoke subset** — the 5-7 highest-value skills that get tested on every behavioral run. Full suite runs only pre-release. Prioritize by: user-facing skills > inner-loop skills > utility skills.

### Gap 7: Skillgrade (Not Previously Evaluated)

Planning-phase research did not include Skillgrade (Minko Gechev), which launched in March 2026. It is purpose-built for SKILL.md testing and is the strongest fit for per-skill behavioral evaluation.

---

## 9. Implementation Roadmap for BC-2462

### Phase 1: Foundation (1-2 sessions)

1. Install Skillgrade globally: `npm i -g skillgrade`
2. Run `skillgrade init` on 3 high-value skills: `brainstorming`, `systematic-debugging`, `frontend-design`
3. Customize the generated `eval.yaml` with Brite-specific test tasks
4. Run `skillgrade run --smoke` to validate the setup works
5. Create `tests/fixtures/behavioral-registry.json` with the 10 seed test cases
6. Create `scripts/test-behavioral.sh` skeleton (pass/fail/section pattern, reads fixture JSON)

### Phase 2: Integration Tests (1-2 sessions)

7. Implement `scripts/test-behavioral.sh` — iterate over `behavioral-registry.json`, invoke `claude -p`, check markers
8. Implement `scripts/score-behavioral.sh` — curl Anthropic API for LLM-as-judge scoring
9. Run full Tier 2+3 locally, fix any test infrastructure issues
10. Add `eval.yaml` files for 2 more skills: `writing-plans`, `web-design-guidelines`

### Phase 3: CI Integration (1 session)

11. Create `.github/workflows/behavioral-tests.yml` with Skillgrade + integration jobs
12. Add `ANTHROPIC_API_KEY` to repository secrets
13. Run first automated pipeline, verify results
14. Set up artifact storage for regression comparison

### Phase 4: Maturity (ongoing)

15. Expand to all 23 skills (as capacity allows)
16. Implement regression comparison (current vs. previous run)
17. Add Tier 3 scoring to CI pipeline
18. Evaluate Promptfoo migration if suite exceeds ~30 test cases

---

## Sources

| Source | URL | What we used |
|--------|-----|--------------|
| Promptfoo docs | promptfoo.dev/docs | exec: provider, llm-rubric assertions, CI integration |
| gstack source | github.com/garrytan/gstack | SessionRunner pattern, LLM-as-judge, eval-store, cost model |
| Skillgrade | github.com/mgechev/skillgrade | SKILL.md eval generation, trial presets, CI mode |
| Anthropic skill-creator | github.com/anthropics/skills | Trigger taxonomy (positive/negative/edge), assertion format |
| Contradish | contradish.com | Consistency testing methodology (reference only) |
| pytest-aitest | github.com/sbroenne/pytest-aitest | Semantic assertions (reference only) |
| Brite instruction-audit-methodology | docs/research/instruction-audit-methodology.md | 3-tier detection model, defect taxonomy |
| Brite testing-guide | docs/testing-guide.md | 6-layer test model, existing coverage map |
| Brite probe-plugin-load.sh | scripts/probe-plugin-load.sh | Existing `claude -p` subprocess pattern |
| Brite trigger-registry.json | plugins/workflows/skills/_shared/trigger-registry.json | 40 existing keyword tests, skill definitions |
