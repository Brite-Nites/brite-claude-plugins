# Changelog

All notable changes to the Brite Claude Plugins bundle will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- **workflows 3.32.0:** context7 MCP server, SessionStart context7-instruction hook, and all skill/agent/command paths that depended on it (BC-11891). ADR-001 marked Withdrawn. CDR compliance reviewer + handbook lookups + org-level precedent search degrade with skip-and-continue narration (URL-resolution work in cdr-compliance-reviewer is unaffected). The `handbook-drift-check` skill is unaffected — it already used `gh api` directly. A future gbrain-based replacement will be documented in a separate ADR. Notes: precedent-search SKILL.md.tmpl renumbered Phase 5 → Phase 4; cdr-compliance-reviewer agent's spec sections wrapped in a "deferred pending CDR INDEX wire-up" callout.
- Haiku LLM PreToolUse hooks from `workflows` plugin (BC-11889 — workflows 3.30.2 → 3.31.0)
  - Dropped `type: "prompt"` security review on every Bash call (10s timeout, false-positive prone)
  - Dropped `type: "prompt"` security review on every Write/Edit content scan
  - Deleted `scripts/test_security_hook_classifier.sh` (dead-code test for removed classifier)
  - Removed `validate.sh` Section 2d (invoked the deleted test)
  - **Behavior change**: regex-only gating retained (`rm -rf`, `git push --force`/`-f`, `DROP TABLE`, `chmod 777`, piped downloads, common secret patterns). `git push --force-with-lease` now passes on all branches including `main` (was branch-aware via BC-11117 LLM carve-out).

### Added
- Health scoring rubrics for 10 inner-loop skills (BC-2468)
  - LLM-as-judge rubric YAML format with weighted dimensions and pass thresholds
  - `scripts/score-skill-output.sh` and `scripts/score-behavioral.sh` scoring harnesses
  - Rubric helper library at `scripts/_lib/rubric-helpers.sh`
- Anti-slop quality guardrails for 5 inner-loop skills (BC-2470)
  - 13-pattern detection across 3 layers: self-check, machine script, rubric integration
  - PL1–PL4 severity namespace to avoid P1/P2/P3 collision with review findings

## [3.29.0] - 2026-03-28

### Added
- Skill usage telemetry and analytics dashboard (BC-2467)
  - `scripts/telemetry-log.sh` event logging with start/end/outcome tracking
  - `scripts/brite-analytics.sh` dashboard with duration, success rates, frequency analysis
  - `/workflows:analytics` command for viewing usage data
- Template-driven skill documentation pipeline (BC-2466)
  - `scripts/gen-skill-docs.py` generates docs from skill YAML frontmatter
  - `scripts/gen-skill-docs.sh` wrapper with `--skill` single-skill mode
  - Section 14 in validate.sh for `%PARAM%` placeholder detection
- Deep gstack architectural analysis for Brite adoption (BC-2465)
  - Research document at `docs/research/gstack-analysis.md`
  - Pattern mapping: 26 gstack skills → Brite adoption priorities
- Report-issue command for plugin misbehavior capture (BC-2527)
  - `/workflows:report-issue` creates Linear issues with regression test cases
- Runtime behavioral test framework (BC-2462)
  - `scripts/test-behavioral.sh` with test case registry and scoring
  - Subprocess isolation for realistic skill execution testing
- Behavioral testing evaluation research (BC-2458)
  - Evaluation of 4 approaches: subprocess, mock, snapshot, hybrid
- Context audit trail and flywheel metrics commands (BC-1964, BC-1965)
  - `/workflows:audit-trail` for per-issue context history
  - `/workflows:flywheel-metrics` for compound knowledge dashboard
- Precedent promotion workflow command (BC-1958)
  - `/workflows:promote-precedent` reviews and promotes project precedents to org handbook
- CDR compliance review agent (BC-1963)
  - New Tier 2 review agent checking code against Company Decision Records
- Handbook drift detection skill (BC-2204)
  - Auto-detects when shipped changes diverge from handbook content
- Precedent-search skill — INDEX + Context7 two-tier search (BC-1961)
- Precedent INDEX format — templates, conventions, contract (BC-1959)
- Structured instrumentation in executing-plans subagent prompt (BC-1962)
- E2E scenario validation for project-start (BC-2005)
- Trait evolution mechanism — hybrid auto-detect + manual (BC-2012)
- Brownfield support in project-start (BC-1951)
- Trait definition validation in validate.sh (BC-1954)
- Express mode for project-start (BC-1950)
- Post-setup verification in project-start (BC-1952)
- Execution trace emission in executing-plans (BC-1956)
- Decision trace extraction in compound-learnings (BC-1957)
  - CDR/ADR cross-reference via Context7 MCP with graceful degradation
  - Precedent storage in docs/precedents/ with INDEX.md
- Decision trace format specification (BC-1955)
  - Execution trace YAML and decision trace markdown schemas
  - Accumulation flow: emit → extract → store → promote
- Context-skill standard specification (BC-1966)
  - Formal contract for domain plugin context-skills
  - YAML contract block in workflow-spec.md (section 3e)
  - Domain plugin template skeleton with context-skill placeholder

### Changed
- Instruction coherence audit — extract contributor docs, sync routing tables (BC-2461)
- Instruction coherence audit methodology research (BC-2459)

### Removed
- Visual-explainer skill and 6 visual generation commands (BC-2460)

## [3.28.0] - 2026-03-19

### Added
- Dynamic MCP verification in project-start (BC-1949)
  - Two-tier: global MCPs (Linear, Sequential-thinking, Context7) + trait-gated (`involves-data` → data warehouse)
  - Non-blocking WARN with setup instructions; missing MCPs noted in generated CLAUDE.md
- Trait-based classification system in project-start (BC-2127)
  - Three-phase interview methodology (Discovery → Classification → Configuration)
  - 11 project traits with detection signals and evidence tracking
  - Trait-conditional documentation scaffolding from shared templates
  - Trait-to-infrastructure dispatch (Git, Linear, CI/CD gated by traits)
- GitHub repo creation + pre-commit hooks + VS Code settings (BC-1946)
- JTBD/MI/SPIN interview methodology rewrite (BC-1943)
- Trait validation tests + docs update (BC-2132)
- Trait label creation step (BC-2129)
- Trait output wiring for downstream consumption (BC-2131)
- Unified trait-conditional template (BC-2130)
- Trait-conditional doc scaffolding + templates (BC-1944)
- Trait classification + confirmation step (BC-2126, BC-2128)
- Trait model validation against 5 real Brite projects (BC-2124)
- Freshness tracking in session-start (BC-1938)
- Context budget management strategy (BC-2003)
- Context loading cascade architecture (BRI-2006)

### Changed
- Version bump: 3.27.0 → 3.28.0

## [3.27.0] - 2026-03-16

### Added
- CDR-check pattern in writing-plans (BRI-1939)
  - Plans reference Company Decision Records for architectural compliance
  - Context7 MCP lookup for relevant CDRs during plan generation

### Changed
- Version bump: 3.26.0 → 3.27.0

## [3.26.0] - 2026-03-13

### Added
- Company Context Interview in session-start (BRI-1941)
  - New Step 2: interactive interview gathers initiative, goal, team, related projects, handbook topics
  - Produces `## Company Context` metadata block in CLAUDE.md (~5-10 lines of pointers)
  - Skills query Linear and Context7 on-demand using these pointers
  - `<!-- no-company-context -->` marker to opt out, auto-refresh after 90 days
  - Shared template at `skills/_shared/company-context-template.md`
  - Degrades gracefully: Linear-only, manual-only, or full (Linear + Context7 + Handbook)
- Context7 MCP check in session-start Step 0 (non-blocking)
  - Reports Context7 + Handbook availability status
  - WARN if unavailable, continues with degraded experience
- Context7 company knowledge rule (`~/.claude/rules/context7.md`)
  - Documents Brite Handbook at `/brite-nites/handbook` for company-specific queries
- Context7 Setup step in onboarding checklist (new Step 8)
- Workflow guide: Context7 configuration section, updated session-start step table (0-8)

### Changed
- session-start steps renumbered: 0-7 → 0-8 (new Step 2 inserted)
- workflow-spec.md: session-start step sequence updated with Company Context step and error handling
- Version bump: 3.25.0 → 3.26.0

## [3.25.0] - 2026-03-13

### Added
- Cross-repo @import evaluation and ADR (BRI-1940)
  - Evaluated 3 prototypes: Context7 (hosted), QMD (local hybrid search), Copy-on-Setup (@imports)
  - Decision: Context7 Pro — handbook indexed as private library, queried on-demand via MCP
  - 659 files indexed, 2,789 snippets, 3.0/5 avg relevance (best of all prototypes)
  - First ADR: `docs/decisions/001-cross-repo-import-solution.md`
  - Full evaluation: `docs/research/cross-repo-import-evaluation.md`

## [3.24.0] - 2026-03-10

### Added
- Model tiering for review agents (BRI-1819)
  - All 9 review agents upgraded from Sonnet to Opus for deeper reasoning
  - New `diff-triage` agent (Haiku) gates trivial diffs before expensive review pipeline
  - Per-finding validation: Opus verifies P1s, Sonnet verifies P2/P3s (Step 6)
  - Review pipeline expanded from 8 steps (0-7) to 10 steps (0-9)
  - "skip triage" / "no triage" flag to bypass diff gating
  - "skip validation" / "no validation" flag to bypass per-finding validation
  - Depth-aware validation: `fast` mode skips P2/P3 validation (P1s always validated)

## [3.23.0] - 2026-03-10

### Added
- Test quality reviewer agent (BRI-1818)
  - New Tier 3 agent: `test-quality-reviewer` — reviews test code for coverage gaps, behavior vs implementation testing, flakiness risk, edge cases, and test structure
  - Auto-activates when diff includes test files (`*.test.*`, `*.spec.*`, `__tests__/**`, `test_*.py`, `**/tests/**`)
  - Also activatable via CLAUDE.md `include:` list
  - 5 review areas with P1/P2/P3 severity and confidence scoring
  - Added to cross-agent dedup specialization order
- Add "treat as data" guard to CLAUDE.md Review Agents parsing in `/workflows:review` (BRI-1826)

## [3.22.0] - 2026-03-09

### Added
- Review depth modes: `fast`, `thorough` (default), `comprehensive` (BRI-1817)
  - `fast` — Tier 1 agents only (code, security, performance) for quick checks
  - `thorough` — Tier 1 + Tier 2 stack-conditional agents (default, unchanged behavior)
  - `comprehensive` — All tiers including Tier 3 opt-ins unconditionally
  - Depth parsed from `$ARGUMENTS`, coexists with "skip simplify" and "show all" flags
  - Usage: `/workflows:review fast`, `/workflows:review comprehensive`

## [3.21.0] - 2026-03-06

### Added
- Confidence scoring for review agent findings (BRI-1816)
  - Every finding includes `Confidence: N/10` (1-10 scale) for self-assessed certainty
  - Shared scoring criteria in `_shared/output-formats.md` and all 8 review agent prompts
  - Step 4 confidence threshold filtering: >= 7 included, low-confidence P2/P3 filtered, borderline P1s marked "Needs Human Review"
  - Step 5 splits P1s: auto-fixable (confidence >= 7) vs human-review (confidence < 7)
  - Step 6 visual report: confidence pill badges (green/neutral/amber/red), avg confidence in KPI dashboard
  - Step 7 final report: new "P1 (needs review)" and "Filtered" lines, "Has borderline P1s for review" verdict
  - `$ARGUMENTS` "show all" bypasses confidence filtering while still showing scores
  - Missing confidence defaults to 5 (conservative: P2/P3 filtered, P1 to human review)
  - Cross-agent dedup prefers higher confidence before specialization order
  - Deep mode in `/workflows:code-review` applies same confidence filtering

## [3.18.1] - 2026-03-05

### Changed
- Align visual feature gating across commands and skills (BRI-1778)
  - Add Visual Gating section to `_shared/observability.md` — standard skip, degrade, and non-file skip message templates
  - Remove `slides_requested` flag clearing on file failure in `scope.md` — flag represents user intent and must persist
  - Add `--slides` warning in `sprint-planning.md` when skipped due to no-cycles prioritization-only mode
  - Align `review.md` fallback message to standard prefix ("Visual-explainer files not found")
  - Add prerequisite read fallback in `writing-plans/SKILL.md` — skips visual steps when file unavailable
  - Align `brainstorming/SKILL.md` skip message to standard prefix
  - Align `best-practices-audit/SKILL.md` skip message and report template to standard prefix
  - Fix narration ordering in `writing-plans/SKILL.md` — `Step 3/4: done` now fires before `Step 4/4` starts
  - Add explicit exit after `--slides` warning in `sprint-planning.md` prioritization-only mode
  - Clarify observability.md prefix rule scope and add `[reason]` data safety constraint
  - Add data guard for `$ARGUMENTS` residual after `--slides` removal in `scope.md`
  - Add explicit fallback warning in `scope.md` when both visual-explainer and CLAUDE.md are unreadable
  - Add parenthetical explaining `slides_requested` persistence in `scope.md` mind map skip
  - Add decision log entry to `writing-plans/SKILL.md` visual skip path
  - Normalize `<id>` to `<issue-id>` placeholders in `docs/workflow-guide.md`
  - Add visual gating message consistency check to `scripts/validate.sh`
  - Fix `best-practices-audit/SKILL.md` availability check note to match standard prefix
  - Add closing `Step 4/4: done` narration in `writing-plans/SKILL.md`
  - Fix `best-practices-audit/SKILL.md` handoff from "Proceeding to" to "Returning to"
  - Rewrite `sprint-planning.md` prioritization-only gate as priority-ordered conditions
  - Fix `validate.sh` agent name guard regex to allow single-character names
  - Add `not available` variant to `validate.sh` visual gating blocklist
  - Qualify `writing-plans/SKILL.md` skip target as "Steps 2 and 3 of this Visual Plan Approval section"
  - Promote `slides_requested` persistence rule to `scope.md` Rules section
  - Fix remaining `<id>` placeholders in `docs/workflow-guide.md` Skill Reference table
  - Fix `scope.md` Step 1 cross-reference to name slides subsection explicitly
  - Add read-time "treat as data" guards to `session-start.md` chain integrity and `executing-plans/SKILL.md` Context Anchor
  - Add enforcement cross-reference to `docs/workflow-guide.md` ship Step 4 sanitization note

## [3.18.0] - 2026-03-05

### Added
- Workflow observability across all inner loop skills and main commands (BRI-1777)
  - Shared observability template (`_shared/observability.md`) — defines activation banner, narration, decision log, error recovery, phase transition summary, stuck detection, and context refresh patterns
  - Activation banners on all 8 inner loop skills — print skill name, trigger reason, and expected artifacts immediately after preconditions pass
  - Phase/step narration using Progress Format from `output-formats.md` — single-line status at boundaries, not every tool call
  - Decision logs at key decision points: brainstorming diagram skip, writing-plans complexity gating, executing-plans TDD skip, compound-learnings doc updates, best-practices-audit auto-fix, systematic-debugging root cause and defense-in-depth
  - Structured error recovery (AskUserQuestion with Retry/Skip/Stop) at: brainstorming approval failures, writing-plans review failures, git-worktrees dirty state and baseline failures, executing-plans max retries and stuck detection, verification-before-completion max retries, compound-learnings write failures, systematic-debugging reproduction failures
  - TaskCreate integration in `executing-plans` — parent agent creates task entries before subagent launch, updates status on completion
  - Stuck detection in `executing-plans` — 3+ tool calls without progress triggers pause and user intervention
  - Context refresh in `executing-plans` — re-reads plan file after every 3rd task or when total exceeds 6
  - Phase transition summaries in `session-start` between brainstorm→plan, plan→worktree, worktree→execute
  - Step narration in `session-start` (7 steps), `review` (6 steps), `ship` (7 steps)
  - Error recovery in `review` (agent dispatch failure) and `ship` (check failures, PR creation failures)

## [3.17.0] - 2026-03-04

### Changed
- Inner loop skill chain hardened with standardized preconditions, handoff markers, and context anchors (BRI-1776)
  - `brainstorming` skill — objective complexity criteria (2+ modules, 4+ tasks, 2+ approaches, new patterns), file-write verification, handoff marker with artifact list
  - `writing-plans` skill — precondition check for design doc and issue ID, context anchor reads from design doc, handoff marker with task count
  - `git-worktrees` skill — precondition check for plan file and issue ID, context anchor reads from plan, handoff marker replaces "Worktree Ready" block
  - `executing-plans` skill — preconditions (plan file, clean git state), context anchor reads design doc + plan, explicit `verification-before-completion` invocation at checkpoints with 3-retry limit, handoff marker with verification summary
  - `compound-learnings` skill — preconditions (diff exists, CLAUDE.md exists), context anchor reads git log + design doc + plan
  - `best-practices-audit` skill — precondition (CLAUDE.md exists), handoff marker
  - `systematic-debugging` skill — completion marker with "Returning to the calling workflow"
- `session-start` command — Step 4 uses objective complexity checklist instead of subjective judgment, Step 7 says verification is "explicitly invoked", new chain integrity rule in Rules section
- `ship` command — Step 1 context anchor (restates issue, decisions, review result from files), Steps 4-5 note skills verify own preconditions

## [3.16.0] - 2026-03-04

### Added
- `retrospective` command — optional visual retro slide deck (Step 4) with delivery dashboard, what went well/needs improvement, and action items. Opt-in via `--slides` flag or AskUserQuestion prompt (BRI-1735)
- `scope` command — automatic Mermaid mind map diagram of themes and features (Step 3 item 6), plus optional session summary slides (Step 6 sub-section) via `--slides` flag (BRI-1735)
- `architecture-decision` command — automatic before/after architecture diagrams with Mermaid (Step 5b) showing component changes and options comparison cards. Context section fact-check (Step 7d) verifies file paths, function names, and architecture claims against the codebase before writing (BRI-1735)
- `sprint-planning` command — optional sprint overview slides (Step 6 sub-section) with velocity dashboard, committed issues, dependency graph, and capacity analysis via `--slides` flag (BRI-1735)

### Fixed
- `scripts/validate.sh` — orphan agent detection now scans commands in addition to skill frontmatter. Resolves false-positive warnings for agents dispatched by commands (e.g., review agents) (BRI-1735)

## [3.15.0] - 2026-03-04

### Changed
- `compound-learnings` skill — new Phase 2 "Verify Existing CLAUDE.md Accuracy" inserted before CLAUDE.md updates. Fast grep-and-stat pass verifies file paths, commands, function refs, and config values against the codebase. Auto-removes confirmed-stale entries, flags ambiguous cases. Phase 6 report includes fact-check results (BRI-1734)
- `best-practices-audit` skill — new Dimension 8 "Accuracy Validation" complements Dimension 7 staleness check with surgical claim verification. Flags stale references as "Needs your input" (no auto-fix). Optional visual HTML audit report when visual-explainer skill is available (BRI-1734)
- `ship` command — Steps 4 and 5 descriptions updated to reflect new accuracy pass and Dimension 8

## [3.14.0] - 2026-03-03

### Changed
- `writing-plans` skill — Plan Approval section replaced with Visual Plan Approval: 4-step flow that generates visual HTML artifacts (visual plan + plan-review) before asking for approval (BRI-1732)
  - Step 1: Complexity check — plans with < 4 tasks skip visual steps (optional offer via AskUserQuestion)
  - Steps 2-3: Render `generate-visual-plan` (Step 2) and `plan-review` (Step 3) HTML pages using visual-explainer skill, write to `~/.agent/diagrams/`. Step 3 is higher-priority — if skipping one for speed, skip Step 2
  - Issue ID sanitization (dots removed from regex), untrusted title paraphrasing with surf guard, file path announcements, re-save on iteration
  - Distinct output filenames (`<id>-visual-plan.html`, `<id>-plan-review.html`) prevent artifact collision
  - Plan file existence fallback, visual-explainer read-once optimization
  - Step 4: Approval with iteration support (regenerates visuals on plan changes)

## [3.13.0] - 2026-03-03

### Changed
- `review` command — auto-generates a visual HTML review page (Step 5) after agents complete (BRI-1733)
  - 6 sections: executive summary, KPI dashboard, module architecture (Mermaid), agent findings (P1/P2/P3 cards with severity + agent badges), file map, test suite status
  - Delegates styling to visual-explainer skill (reads SKILL.md + architecture.html template). Falls back to plain semantic HTML when skill files are unavailable
  - Terminal final report (Step 6) retains P1 summary and adds the HTML file path

## [3.12.0] - 2026-03-03

### Added
- 7 visual-explainer commands ported from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer) (MIT): `/workflows:generate-web-diagram`, `/workflows:generate-slides`, `/workflows:generate-visual-plan`, `/workflows:fact-check`, `/workflows:diff-review`, `/workflows:plan-review`, `/workflows:project-recap`. All adapted with `$ARGUMENTS` sanitization, absolute skill paths, and input validation (BRI-1730). Command total: 24

### Changed
- `visual-explainer/SKILL.md` — removed planned-feature note (added in 3.11.0 for BRI-1730), added `/workflows:` prefix to command references

## [3.11.0] - 2026-03-03

### Added
- `visual-explainer` skill — generates styled, self-contained HTML pages for diagrams, architecture overviews, data tables, and slide decks. Ported from [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer) (MIT). Includes 4 HTML reference templates (architecture, data-table, mermaid-flowchart, slide-deck) and 4 reference docs (css-patterns, libraries, responsive-nav, slide-patterns). Anti-slop design guidelines prevent generic AI output (BRI-1729). Skill total: 22

### Fixed
- Pin CDN versions to exact patches in libraries.md and templates: mermaid@11.12.3, @mermaid-js/layout-elk@0.2.0, chart.js@4.5.1 (BRI-1729)
- Add nodeLabel/edgeLabel color CSS overrides to mermaid-flowchart.html for dark/light mode correctness (BRI-1729)
- Fix window listener leaks in mermaid-flowchart.html and slide-deck.html zoom/pan code — scope mousemove/mouseup inside mousedown (BRI-1729)
- Fix SlideEngine cross-scope issue in slide-deck.html — use custom event bridge between module and classic scripts (BRI-1729)
- Fix uninitialized touchY in slide-deck.html touchend handler (BRI-1729)
- Add aria-label and focus-visible styles to zoom control buttons in both Mermaid templates (BRI-1729)
- Convert SlideEngine from prototype-based to ES class syntax in slide-deck.html (BRI-1729)
- Replace emoji with styled monospace abbreviations in architecture.html source pills (BRI-1729)
- Add cross-browser summary::marker reset in data-table.html collapsible sections (BRI-1729)
- Add NaN guard to parseInt(el.dataset.count) in libraries.md anime.js example (BRI-1729)
- Fix hardcoded /tmp path in slide-patterns.md image generation — use mktemp (BRI-1729)
- Add ID sanitization comment in responsive-nav.md (BRI-1729)
- Add planned-feature note for /generate-slides and --slides flag in SKILL.md (BRI-1729)

## [3.10.0] - 2026-03-03

### Added
- pytest testing patterns in `testing-strategy` skill — 7 new rules across 2 categories (pytest Fundamentals, pytest Advanced Patterns). Covers fixtures, parametrize, conftest layering, mocking, async testing, markers, and parallel execution with xdist. Cross-references python-best-practices for FastAPI-specific patterns. Skill now has 46 rules across 12 categories (BRI-1739)

## [3.9.0] - 2026-03-03

### Added
- Playwright E2E testing patterns in `testing-strategy` skill — 7 new rules across 2 categories (Playwright Fundamentals, Playwright CI & Advanced). Covers page objects, accessible selectors, test isolation, fixtures, network mocking, visual regression, and CI config. Skill now has 39 rules across 10 categories (BRI-1738)

## [3.8.0] - 2026-03-03

### Added
- `testing-strategy` skill — core testing patterns + Vitest guidance. 32 rules across 8 categories (test structure, mocking strategy, Vitest patterns, React Testing Library, MSW, fixtures, CI, snapshots). SKILL.md quick reference + AGENTS.md full compiled rules with code examples (BRI-1737)

## [3.7.0] - 2026-02-28

### Added
- `/workflows:architecture-decision` command — interactive ADR generator using sequential-thinking for structured options analysis. Writes to `docs/decisions/NNN-kebab-title.md`, auto-appends `@` import to CLAUDE.md (BRI-1624)
- ADR generation step in `/workflows:project-start` — after interview and plan, extracts every major tech decision and generates ADRs (BRI-1624)
- `## ADR Convention` section in CLAUDE.md documenting the `@` import pattern

### Changed
- Path A (non-technical) in project-start now creates ADRs in `docs/decisions/` instead of a TECHNICAL.md file

## [3.6.0] - 2026-02-28

### Added
- `/workflows:retrospective` command — review completed cycles, facilitate structured retro discussion (what went well, what needs improvement, action items), post Linear project status update with health indicator, optionally create follow-up issues. Supports mid-sprint mode via `current` argument (BRI-1625)

## [3.5.0] - 2026-02-27

### Changed
- **Rebrand from "Britenites" to "Brite"** — org/brand name simplified across all files
- **Plugin renamed from `britenites` to `workflows`** — all commands now `/workflows:*` (e.g., `/workflows:session-start`)
- **Repo renamed from `britenites-claude-plugins` to `britenites-claude-plugins`** — GitHub auto-redirects old URLs
- **Linear project renamed to "Brite Plugin Marketplace"**
- MCP tool namespace updated from `mcp__plugin_britenites_*` to `mcp__plugin_workflows_*`

## [3.4.0] - 2026-02-27

### Added
- `/britenites:create-plugin` command — scaffold new domain plugins from template with marketplace registration (BRI-1628)
- `templates/domain-plugin/` — template directory with plugin.json, example command, example skill, hooks stub, README, CHANGELOG
- Multi-plugin validation — `scripts/validate.sh` discovers plugins from marketplace.json and validates each independently

### Changed
- `scripts/validate.sh` refactored from single-plugin to multi-plugin: sections 3-11 extracted into `validate_plugin()` function, `agents/` and `hooks/` now optional warnings instead of failures
- `.github/workflows/validate-plugin.yml` simplified — delegates to `scripts/validate.sh` instead of inline per-plugin steps
- `scripts/check-prereqs.sh` iterates over marketplace.json plugin sources instead of hardcoded path
- `scripts/test-plugin-load.sh` accepts `$1` for plugin directory, derives expected commands from `commands/` directory

## [3.3.0] - 2026-02-27

### Added
- `/britenites:sprint-planning` command — pull backlog, review team velocity, interactively select issues, assign to Linear cycles (BRI-1623)
- Sprint-planning added to SessionStart banner key commands

## [3.2.0] - 2026-02-27

### Changed
- **session-start issue picker scoped to repo's Linear project** — Step 2 now reads `## Linear Project` from CLAUDE.md to resolve the project name, queries only that project, falls back to both Todo and Backlog states if no in-progress issues, and shows an empty-state prompt if no issues exist at all (BRI-1654)
- Added `## Linear Project` section to CLAUDE.md with project mapping convention

## [3.1.0] - 2026-02-27

### Added
- **python-best-practices skill** — 38-rule architectural guide for FastAPI, Pydantic v2, and SQLAlchemy 2.0 covering async correctness, dependency injection, database patterns, error handling, API design, testing, and project structure (BRI-1339)
- `code-review.md` Section 4 defers to python-best-practices skill for full backend audit
- Backend Skills subsection in CLAUDE.md Skill Routing

## [3.0.1] - 2026-02-27

### Changed
- **Best-practices reference rewrite** — `claude-code-best-practices.md` expanded from 84 to 178 lines with memory hierarchy, modular rules, @import syntax, hooks system, custom slash commands, Model Context Protocol, and multi-project setup (BRI-1640)
- `setup-claude-md/SKILL.md` size guidance corrected from 150 to 100 lines to match Anthropic's current recommendation

### Fixed
- `best-practices-audit/SKILL.md` — reference path changed from ambiguous relative path to installed convention (`.claude/skills/setup-claude-md/claude-code-best-practices.md`)
- `git-worktrees/SKILL.md` — DESCRIPTION derivation now collapses consecutive hyphens and strips leading/trailing hyphens; validation regex tightened to `^[a-z0-9][a-z0-9-]*[a-z0-9]$`; derivation block moved before code block so agents read rules before using the variable

## [3.0.0] - 2026-02-26

### Added
- **8 new Inner Loop skills** — Full superpowers-equivalent methodology:
  - `brainstorming` — Socratic discovery before planning (BRI-1636)
  - `writing-plans` — Bite-sized tasks with exact files, TDD, verification (BRI-1617)
  - `git-worktrees` — Isolated workspace per task with Linear issue ID in branch name (BRI-1637)
  - `executing-plans` — Subagent-per-task execution with TDD enforcement (BRI-1618)
  - `compound-learnings` — Knowledge capture and compounding after each session (BRI-1619)
  - `systematic-debugging` — 4-phase root cause analysis (BRI-1620)
  - `best-practices-audit` — CLAUDE.md audit + auto-fix against Anthropic guidelines (BRI-1638)
  - `verification-before-completion` — 4-level verification before marking tasks done (BRI-1639)
- `/britenites:scope` command — Collaborative creative scoping sessions that produce Linear issues (BRI-1641)
- 6 new Linear issues created for v3 milestone items (BRI-1636 through BRI-1641)

### Changed
- **Plugin philosophy refactor** — Reframed as superpowers + compound engineering + Linear integration
- `/britenites:session-start` — Now drives the full inner loop: brainstorm → plan → worktree → execute
- `/britenites:ship` — Now invokes compound-learnings and best-practices-audit skills, adds worktree cleanup
- Plugin description updated to "Process + Org plugin — structured workflow methodology with Linear integration"
- Keywords updated: removed design-system/react/ui-ux, added process/workflow/tdd/compound-engineering
- Hook regex tests expanded from 24 to 37 (added git commit detection, force-push variants)
- ROADMAP.md rewritten with three-workflow model (Greenfield, Inner Loop, Scoping)
- Milestone 2 (Inner Loop) expanded with 5 new issues
- Milestone 3 renamed from "The Outer Loop" to "Scoping & Discovery" with scope command
- README.md updated: 13 commands, 19 skills, full inner loop diagram
- CLAUDE.md updated: complete skill routing tables, inner loop documentation
- Version bumped to 3.0.0 in plugin.json and marketplace.json

## [2.3.0] - 2026-02-25

### Added
- `/britenites:security-audit` command — comprehensive project-wide security audit with automated checks (dependency vulnerabilities, secret scanning, env config) and security-reviewer agent dispatch
- `/britenites:deployment-checklist` command — pre-deployment validation checklist
- `/britenites:bug-report` command — standardized bug reporting with Linear integration
- `code-quality` skill — ESLint, Prettier, Ruff, mypy, TypeScript strict enforcement
- Pre-commit quality hook (PreToolUse) — intercepts `git commit`, runs ESLint/tsc/Ruff on staged files by project type
- `scripts/pre-commit.sh` — standalone git pre-commit hook for direct installation
- `/britenites:smoke-test` command — in-session diagnostic for env, MCP, hooks, agent dispatch
- Step 0 prerequisite guards in `session-start` (Linear + sequential-thinking MCP), `review` (agent dispatch), `ship` (gh auth)
- `scripts/test-hooks.sh` — 24 regex tests for security hook patterns (CI + local)
- `scripts/check-prereqs.sh` — runtime prerequisite verification
- `scripts/test-plugin-load.sh` — command registration test (terminal/CI only)
- `docs/test-protocol.md` — manual flow verification checklist (7 tests)

### Changed
- SessionStart hook now shows environment health checks (git, node, gh, npx status)
- CI workflow runs `test-hooks.sh` alongside structural validation

### Security
- Fixed PostToolUse hook file path injection vulnerability
- Replaced `echo` with `printf` in security hook command pipes
- Fixed force-push regex to catch `--force-with-lease`
- Pinned MCP server package version in `.mcp.json`

## [2.0.1] - 2026-02-24

### Fixed
- SessionStart hook `echo` replaced with `printf` for portable newline handling across shells
- Version bumped to bust stale plugin cache (Claude Code caches by version key)

## [2.0.0] - 2026-02-24

### Added
- 3 new commands: `session-start` (pick a Linear issue and plan work), `review` (run review agents in parallel, fix P1s), `ship` (create PR, update Linear, compound learnings)
- 3 new agents: `code-reviewer` (P1/P2/P3 code quality), `security-reviewer` (OWASP Top 10, secrets exposure), `typescript-reviewer` (type safety, React/Next.js patterns)
- Two-layer hook security: regex command hooks (deterministic, first) + haiku prompt hooks (fallback, second) for both Bash and Write/Edit
- `agents` directory declaration in plugin.json for explicit agent discovery
- Plugin-namespaced MCP tool references in agents and skills

### Changed
- Hook architecture from single-layer prompt hooks to two-layer regex+prompt
- `pluginRoot` removed from marketplace.json (was causing double-pathing)
- `hooks` field removed from plugin.json (Claude Code auto-loads hooks.json)
- MCP tool names updated to plugin-namespaced format (`mcp__plugin_britenites_*`)

### Fixed
- Plugin source path resolution in marketplace.json
- Agent discoverability via explicit plugin.json declaration

## [1.5.0] - 2026-02-23

### Added
- ARCHITECTURE.md with Mermaid diagrams, runtime flow, skill routing, hook execution, agent delegation, design decisions
- CONTRIBUTING.md with quick reference, frontmatter standard, branch/commit conventions, CI checks
- docs/getting-started.md for plugin development setup
- docs/troubleshooting.md for common issues and solutions

### Changed
- ROADMAP.md rewritten with 7-phase lifecycle vision, coverage map, competitive context, and detailed development phases
- README.md updated: version 1.4.0 → 1.5.0, added Vision section, post-plan skills in matrix, Documentation table, current plugin.json example, simplified Contributing

## [1.3.0] - 2026-02-23

### Added

- Post-plan workflow: `refine-plan`, `create-issues`, `setup-claude-md`, `post-plan-setup` skills
- 4 custom agents: `plan-refiner`, `issue-creator`, `claude-md-generator`, `post-plan-orchestrator`
- Shared validation/retry pattern for skills (`skills/_shared/validation-pattern.md`)
- `/code-review` command with frontend, backend, and data engineering checklists
- `/onboarding-checklist` command for new developer environment setup
- CHANGELOG.md, ROADMAP.md documentation
- SKILL.md frontmatter standard documented in CLAUDE.md
- Skill coverage matrix and MCP server docs in README

### Changed

- Standardized frontmatter across all 10 skills (explicit `user-invocable`, plain string descriptions)
- Renamed `vercel-react-best-practices` skill to `react-best-practices` to match directory name
- Improved README with prerequisites, quick start, and verification steps
- Registered `commands` and `agents` directories in plugin.json

## [1.2.0] - 2026-01-27

### Added

- 5 new skills: `frontend-design`, `ui-ux-pro-max`, `web-design-guidelines`, `find-skills`, `agent-browser`
- Skills cover frontend design, UI/UX intelligence, design review, skill discovery, and browser automation

## [1.1.0] - 2026-01-21

### Added

- `/tech-stack` command for technology stack decisions
- Technical collaborator path in `/project-start` command

## [1.0.0] - 2026-01-15

### Added

- Plugin bundle with marketplace configuration
- `/project-start` command with guided interview for non-technical users
- `react-best-practices` skill (45 Vercel Engineering rules for React/Next.js)
- Sequential-thinking MCP server
- Linear MCP server for project management integration
- CLAUDE.md and README.md documentation

### Changed

- Linear MCP server renamed from `linear` to `linear-server`
- Linear MCP URL updated from `.dev` to `.app`

[Unreleased]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.29.0...HEAD
[3.29.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.28.0...v3.29.0
[3.28.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.27.0...v3.28.0
[3.27.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.26.0...v3.27.0
[3.26.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.25.0...v3.26.0
[3.25.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.24.0...v3.25.0
[3.24.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.23.0...v3.24.0
[3.23.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.22.0...v3.23.0
[3.22.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.21.0...v3.22.0
[3.21.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.20.0...v3.21.0
[3.18.1]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.18.0...v3.18.1
[3.18.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.17.0...v3.18.0
[3.17.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.16.0...v3.17.0
[3.16.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.15.0...v3.16.0
[3.15.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.14.0...v3.15.0
[3.14.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.13.0...v3.14.0
[3.13.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.12.0...v3.13.0
[3.12.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.11.0...v3.12.0
[3.11.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.10.0...v3.11.0
[3.10.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.9.0...v3.10.0
[3.9.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.8.0...v3.9.0
[3.8.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.7.0...v3.8.0
[3.7.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.6.0...v3.7.0
[3.6.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.5.0...v3.6.0
[3.5.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.4.0...v3.5.0
[3.4.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.0.1...v3.1.0
[3.0.1]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v2.3.0...v3.0.0
[2.3.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v2.0.1...v2.3.0
[2.0.1]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v1.3.0...v1.5.0
[1.3.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Brite-Nites/britenites-claude-plugins/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Brite-Nites/britenites-claude-plugins/releases/tag/v1.0.0
