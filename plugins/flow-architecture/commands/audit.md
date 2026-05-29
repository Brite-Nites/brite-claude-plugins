---
description: Flow-Driven Architecture quality-gate runner — three-phase pipeline (verify-docs → filesystem gates → Linear MCP gates) emitting markdown or --json over Q29's 36-gate stack
---

# /flow:audit

Utility command. Single-purpose runner for the Q29 36-gate quality-gate stack (`plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md`; post-Q29 amendment 2 adding the 6th cross-cutting gate `cross-domain-deps-bidirectional`). Three phases / **zero user-confirmation gates between internal steps** (utility, not orchestrator) / **READ-MOSTLY** — read-only against the filesystem and Linear MCP except for the single breadcrumb `overrides[]` append on user-selected Override per Q29 sub-decision 5 (see § Override mechanism for the write contract). Default wall ≈ 14s on a 28-domain Brand-Hub-shape project (Q38 sub-decision 3 batched-list-issues optimization); ~125s without batching.

> **Scope:** UI-bearing FDA projects (CDR-023). Non-UI-bearing work uses CDR-014's Phase Pattern + `/workflows:fix-milestone --migrate ...`, not this audit. The audit assumes the consuming project has been bootstrapped through `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap) and has FDA artifacts on disk; absent artifacts surface as Q29.1 phase-transition gate failures, not infrastructure errors.

> **DO NOT re-derive** the gate manifest, hard/soft classification, override mechanism, or three-section reporting format. All seven sub-decisions of Q38 are locked at `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:713` with a refinement audit trail at `:729`. Q38 sub-decision 4's deferred-decision resolution is at `:743`. Q29's full 35-gate manifest is locked at `:240` (sub-decisions 1-7 — including Q29.6 three-section reporting format at `:271` and Q29.7 verify-docs.sh integration at `:273`), Q29 amendment 1 (`preflight-complete` gate, locked 2026-05-11 per BC-7066) at `:275`, and Q29 amendment 2 (`cross-domain-deps-bidirectional` gate, locked 2026-05-26 per BC-10729) immediately above amendment 1. Post-Q29 amendment 2 the canonical total is 36 distinct gate types (8 + 22 + 6). Surfaced via `_shared/artifact-gate-pattern.md`; this command is the runner for that manifest, not a re-statement of it.

> **Boundary contract with `/flow:review`** lives at `plugins/flow-architecture/CLAUDE.md` § Boundaries (Q52 sub-decision 4) — `/flow:audit` is process-compliance (36-gate stack); `/flow:review` is diff-level code review. v1.1 `--audit-preflight` flag for `/flow:review` is parking lot #48.

## Architecture overview

```
  /flow:audit — three-phase, halt-aware pipeline
  ═══════════════════════════════════════════════════════════════════════

   ┌─ Phase A ──────────┐    ┌─ Phase B ──────────┐    ┌─ Phase C ──────────┐
   │ verify-docs.sh     │───►│ deterministic       │───►│ Linear MCP gates    │
   │ (mechanical:        │    │ filesystem gates    │    │ (Q29.3 cross-       │
   │  build/lint/test    │    │ (Q29.2 22 per-flow  │    │  cutting + Q29.2    │
   │  + internal links   │    │  checks + Q29.1     │    │  Eng/Design/Docs    │
   │  + orphan flow IDs  │    │  file-existence     │    │  state checks via   │
   │  + front-matter     │    │  phase-transition   │    │  batched list_issues│
   │  + stale dates)     │    │  gates)             │    │  per-domain)        │
   └────────┬───────────┘    └────────┬────────────┘    └────────┬───────────┘
            │ exit !=0                │                          │
            ▼                         ▼                          ▼
   Phase B+C marked          Hard-gate fail (Phase B or C) →
   skipped + exit 2          override AskUserQuestion (Q29.5)
   immediately               Fix now (caller exits) /
   (NO override AUQ —        Override with reason
   only halt-on-fail in      ({gate, reason, timestamp,
   the pipeline)             scope} → breadcrumb
                             overrides[]; counted as pass
                             per Q38 sub-decision 6) /
                             Halt (exit 1)
                                              ↓
                                    Render Q29.6 three-section
                                    markdown (or --json) +
                                    Summary line + Overrides
                                    section (with stale-override
                                    re-evaluate sub-section)
```

The pipeline is **halt-aware** at the Phase A boundary only: a non-zero exit from `verify-docs.sh` marks Phase B+C as skipped (`skipped (verify-docs failed)`) without running them — exit code 2; **no override `AskUserQuestion` fires for Phase A failure**. Within Phases B and C, hard-gate failures do NOT halt the run; they accumulate in the report and trigger the override `AskUserQuestion` per Q29 sub-decision 5 / Q38 sub-decision 6.

**Render is unconditional.** Both the success path (no failures) and the override-prompt branches in the diagram converge at the "Render Q29.6 three-section markdown (or `--json`)" terminal — the diagram lays it out under the override branch only for visual flow but the runner always renders the report at end-of-run regardless of which branch fired.

## Invocation

`/flow:audit [--domain=<CODE>] [--flow=<DOMAIN-NN>] [--discipline={story|eng|design|qa|docs}] [--gate=<id>] [--json] [--no-verify-docs]`

All args are flag-based (vs positional) per Q38 sub-decision 1 — explicit naming + composability. Defaults: full-project markdown report.

| Flag | Purpose |
|---|---|
| `--domain=<CODE>` | Filter to one domain's gates. Example: `--domain=TEAM` runs only TEAM's per-flow + cross-cutting gates that touch TEAM. |
| `--flow=<DOMAIN-NN>` | Filter to a single flow. Example: `--flow=TEAM-09` runs only TEAM-09's 22 per-flow gates. |
| `--discipline={story\|eng\|design\|qa\|docs}` | Filter to one discipline's child-completion gates across the selected scope. Composable with `--domain` and `--flow`. |
| `--gate=<id>` | Re-run a single gate by stable ID (useful for fix-and-verify cycles). Example: `--gate=parent-l3-summary-populated`. |
| `--json` | Emit machine-readable output for CI scripting. See § Output formats. |
| `--no-verify-docs` | Skip Phase A. **Debugging only** — bypasses the mechanical-layer pre-flight; downstream gate output may be misleading if mechanical issues exist. |

**Filter composition.** Filters compose intersectionally: `--domain=TEAM --discipline=eng` runs TEAM's [Eng] gates only (Q29.2 4 checks per flow × N TEAM flows + the relevant cross-cutting subset). `--flow=TEAM-09 --gate=parent-l3-summary-populated` re-runs that single gate against TEAM-09's parent.

**Phase A is project-wide and not scope-filterable.** Phase A always runs in full unless `--no-verify-docs` is set; the filter args (`--domain`, `--flow`, `--discipline`, `--gate`) scope only Phase B + Phase C output. This matches `verify-docs.sh`'s "owned by the consuming project" framing in § Phase A — the mechanical-layer pre-flight is not a per-discipline or per-flow concept.

**Valid `--gate=<id>` IDs.** The canonical enumeration is the union of all backticked gate names in `_shared/artifact-gate-pattern.md` § Phase-transition gates + § Cross-cutting consistency gates plus the per-flow check IDs derived from this file's Phase B section (Story / Eng / Design / QA / Docs sub-checks). An invalid `--gate=<id>` value exits 64.

**Invalid args** — surface a clear usage error and exit 64 (`os.EX_USAGE`).

## Auto-invocation contract

`/flow:audit` is both **user-invocable** and **auto-invocable**. Per Q38 sub-decision 5:

- **Called by `/flow:ship`** (Q53) as a ship-readiness check — hard-gate failures halt the ship. The ship command invokes `/flow:audit --domain=<DOMAIN>` scoped to the affected domain.
- **Called by `/flow:plan-{discipline}`** (Q43 children) pre-completion, scope-filtered to that discipline child. Example: `/flow:plan-eng` invokes `/flow:audit --flow=<DOMAIN-NN> --discipline=eng` before generating plan content.
- **NOT called by orchestrators** (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`) — orchestrators have their own per-phase artifact-existence gates per Q7's filesystem-artifact-existence semantics, and double-firing during scaffold would be expensive without informational benefit (the gates are already evaluated at scaffold time).
- **NOT called by `/flow:session-start`** (Q51) — frequency × Linear MCP cost (~14s on a 28-domain project) is non-trivial; the user can run `/flow:audit` explicitly when they want a project-health snapshot.

**Cross-invocation cost (parking lot v1.1).** A single `/flow:session-start` could trigger up to 5 plan-X audits + a final `/flow:ship` audit = 6 invocations × ~14s Phase C ≈ 84s of redundant Linear MCP I/O per session. v1 ships without a cross-invocation cache because no Q-lock backs the cache contract; the cache shape (TTL + invalidation key on git HEAD sha + `.flow/config.json` mtime + scope filters) is parking-lot v1.1 territory. Workaround in v1: explicit `/flow:audit` runs are user-controlled; auto-invocations cost what they cost. v1.1 candidate: a `.flow/audit-cache.json` (config-shaped, NOT a `docs/plans/` run-artifact — Q31.4 locks `.flow-phase-state.json` as the single transient run-artifact path; admitting a sibling cache file in `docs/plans/` would require a Q31 amendment, so the cache lives under `.flow/` instead) keyed by `{HEAD sha, config mtime, filter scope}` with a 60s TTL for Linear data + an until-HEAD-changes TTL for `verify-docs.sh` stdout, opt-out via `--no-cache`.

**Auto-invocation override-prompt contract.** When auto-invoked by `/flow:ship` or `/flow:plan-{discipline}`, hard-gate failure surfaces the override `AskUserQuestion` (`Fix now / Override with reason / Halt` — see § Override mechanism for the canonical option set) to the user inline; the auto-invoking command waits. The selected option is honored by the parent caller — **Halt** → caller exits with audit's exit code (1); **Override with reason** → mutates `overrides[]` and the caller proceeds with the override active for the remainder of the parent flow; **Fix now** → caller exits cleanly with a pointer to the failing gate. This is the gate-respect contract precedent (cadence BC-5866; sibling orchestrators `start-project.md` § Gate-respect contract). The auto-invoked path NEVER silently swallows hard-gate failures — every override is surfaced exactly once at the AskUserQuestion and re-surfaces at the parent caller's own audit-summary echo.

## Phase A — verify-docs.sh

Run the consuming project's mechanical-layer documentation verifier from the project root:

```bash
(cd "$(git rev-parse --show-toplevel)" && bash scripts/verify-docs.sh)
```

The `cd $(git rev-parse --show-toplevel)` discipline pins execution to the consuming-project repo root regardless of the user's CWD when `/flow:audit` was invoked — same convention as `flow-resume-breadcrumb.sh`'s `resolve_default_path()` helper. This is **CWD-confusion safety**: the script always runs against the repo-root copy of `scripts/verify-docs.sh`, never an unrelated nested copy that happens to share the path (e.g., a vendored sub-project shipping its own `scripts/verify-docs.sh` under `vendor/foo/scripts/`). Adversarial defense — an attacker who already controls the repo root has owned everything regardless — is not the framing.

`verify-docs.sh` is **owned by the consuming project**, not the FDA plugin (the plugin assumes BriteBase / Brand Hub / equivalent infrastructure provides it). Per Q29.7 lock: leverage existing infrastructure rather than duplicating it. The script's contract: build / lint / test + internal-link integrity + orphan-flow-IDs check + front-matter presence + stale-date detection. Output goes to stdout; exit code is the signal.

**Stdout shape assumption (cross-contract).** Phase B's per-doc lookups (story doc + customer doc) parse the cached stdout to determine pass/fail per file. The expected shape is one line per checked file with a leading status token + path (e.g., `PASS docs/product/flows/TEAM/TEAM-09.md` or `FAIL docs/product/customer-docs/TEAM/TEAM-09.md: <reason>`). When the consuming project's `verify-docs.sh` does not emit per-file structured output, Phase B's `[Story]` 5th check + `[Docs]` 4th check downgrade to `gate.status: indeterminate (verify-docs.sh stdout shape unrecognized)` rather than synthesizing a pass — preserves the leverage-existing-infrastructure framing without inventing structure the project doesn't provide.

**On non-zero exit:**

- Mark Phase B + Phase C entries as `skipped (verify-docs failed)` in the audit report.
- Render the audit summary with the skip annotation.
- Set the process exit code to `exit 2` (Phase B+C skipped due to verify-docs.sh failure).
- The user fixes the mechanical issues first, then re-runs `/flow:audit`.
- **No override `AskUserQuestion` fires** — Phase A failure is the only halt-on-fail in the pipeline (see Architecture overview § halt-aware boundary). The override surface is reserved for Phase B/C hard-gate failures (Q29 sub-decision 5).

**On zero exit:** proceed to Phase B.

**Stdout caching contract.** Capture `verify-docs.sh` stdout into memory once on first invocation; **on first lookup, parse it once into a `{path → pass|fail}` dict** so subsequent per-doc checks are O(1) rather than O(N) string-search. Phase B's per-doc "re-checked from Phase A output" lookups consume the dict. **Never re-invoke `verify-docs.sh`** for individual story-doc / customer-doc lookups — the script is a single project-wide invocation per audit run.

**Per-doc parse cache.** Across the entire audit run, read each touched story doc + customer doc + parse front-matter ONCE; cache `{path → {raw_body, frontmatter_dict}}` in memory; all per-flow + cross-cutting checks against that file consume the cached structure. The same story doc is touched by 5 [Story] checks + the `linear-children-match` cross-cutting gate; without caching, that's 6 redundant file-reads + 6 YAML parses per flow per audit run.

**`--no-verify-docs` skip path** (debugging only): skip Phase A entirely; do NOT mark Phase B+C as skipped (run them normally). This flag exists for fix-and-verify cycles where the user knows mechanical issues remain but wants a B+C snapshot anyway. Surface a warning in the report header: `WARNING: --no-verify-docs in effect; mechanical-layer pre-flight skipped.`

When `--no-verify-docs` is set, the Phase B checks that depend on the cached Phase A stdout emit `gate.status: skipped (no Phase A cache)` rather than evaluated — they do not fall back to a synthesized pass and they do not contribute to `exit 1`. Concretely: `[Story]` 5th check (`story-verify-docs-pass`), `[Docs]` 4th check (`docs-customer-verify-docs-pass`), `[Eng]` 2nd check (`eng-build-lint-test-pass` — Phase A delegates the `npm run build && npm run lint && npm test` invocation), and the `verify-docs.sh` orphan-flow-IDs half of `inventory-complete`.

## Phase B — deterministic filesystem gates

Run the Q29.2 22 per-flow discipline-child checks plus the Q29.1 phase-transition gates that don't require Linear MCP. These are pure filesystem-artifact-existence + regex-match checks, scriptable, deterministic, re-runnable per Q7 (`docs/design-rationale/fda-plugin-interview.md:60`).

**Q29.1 phase-transition file-existence gates evaluated in Phase B (no Linear MCP needed):**

- `preflight-complete` — `.flow/config.json` exists with the v1 fields per Q12.4 (added per Q29 amendment 1, locked 2026-05-11 per BC-7066).
- `intent-exists` — `docs/product/intent.md` exists with required sections (per Q41).
- `inventory-complete` — `master-flow-inventory.md` has ≥1 domain section + `verify-docs.sh` orphan-flow-IDs check passes (faithful echo of canon at `_shared/artifact-gate-pattern.md:20`). Implementation note: the `verify-docs.sh` half is satisfied by Phase A; only the section-count half is re-evaluated in Phase B.
- `scaffold-complete` per domain — `.flow/scaffold-log/<domain>.md` has rows for 1 milestone + N parents + 5N children with `result: executed` or `skipped-idempotent`. (Linear-side state is verified in Phase C.)
- `story-docs-complete` per domain — N story-doc files at `docs/product/flows/<domain>/*.md` for all N flows in the domain.
- `journey-complete` per domain — `docs/product/journeys/<domain>.md` exists.
- `index-complete` — `INDEX.md` `generated_at` >= the most recent breadcrumb's `run_started_at`. Read `docs/plans/.flow-phase-state.json` **once per audit run** and cache the entire parsed object in memory; both `run_started_at` (this gate) and `overrides[]` (the override mechanism + stale-override scan) consume the cached copy. **Cache invalidation is lazy:** after every `flow-resume-breadcrumb.sh write` returns, mark the cache stale; the next `overrides[]` access (a second hard-gate Override prompt later in the same run, or the end-of-run stale-override scan) re-reads the file. If the breadcrumb is absent, the gate is informational-only (no breadcrumb means no orchestrator run to compare against).

`env-ready` — the 8th Q29.1 phase-transition gate (`Linear MCP reachable + repo root + gh auth`) is **runtime-implicit** in `/flow:audit`, not a discrete Phase B step: Linear MCP reachability is exercised by the first Phase C `list_issues` call (failure → Phase C `SKIPPED` per § Failure semantics); repo-root + `gh` auth are inherited from the consuming project's environment (orchestrator preflight already confirmed them when `.flow/config.json` was first written). The gate is reported as `pass` whenever Phase C completes without auth/connectivity errors and as `skipped (env-ready)` when Phase C is skipped for those reasons. **`--gate=env-ready` special case:** when invoked as a single-gate re-run via `--gate=env-ready`, `/flow:audit` skips Phase B entirely, runs Phase C without any per-flow scope, and reports Phase C's auth/connectivity outcome as the sole gate result.

**Q29.2 per-flow discipline-child checks** (22 per flow). The check enumeration below is a derivative pointer to `_shared/artifact-gate-pattern.md` § Discipline-child-completion gates — that file is the canonical source for check definitions; this section adds only the `[Linear MCP — Phase C]` annotations that mark which checks route through Phase C's batched `list_issues` call. If a check description below diverges from canon, canon wins and this file should be amended via the schema-discipline amendment pattern.

- **[Story] (5 checks)** — story doc exists at `docs/product/flows/<domain>/<flow-id>.md`; required front-matter populated; **story-frame present (frame-agnostic + line-form-agnostic per rubric D11)** — within the **story-frame region** (the `## Job story` section, or — for the leaner heading-less docs — the title + summary blockquote up to the first `## Acceptance` heading) the doc carries EITHER the human job-story markers (`**When**` + `**I want to**` + `**so I can**`) OR, for a non-human / infrastructure actor (crawler, sitemap/robots, cron, webhook, CDN, ISR, canonical, CSP), the constraint-spec markers (`**Given**` + `**MUST**` + `**so that**`). The check is **region-scoped** (title → first `## Acceptance`), so the markers may span one line OR the canonical brite-base multi-line blockquoted form (`> **When** …` / `> **I want to** …` / `> **so I can** …`); a single-line regex would reject the multi-line GOLD format. AC has 3-5 Gherkin `Scenario:` blocks; story doc passes `verify-docs.sh` (re-checked from cached Phase A stdout). _(The `story-job-story-regex` gate ID is retained for Q29 gate-stack stability; only its accepted frame set + line-form widened — BC-11988 / T0-4.)_
- **[Eng] (4 checks)** — Linear [Eng] child `state.type == "completed"` `[Linear MCP — Phase C]`; `npm run build && npm run lint && npm test` pass on `main` (delegated to `verify-docs.sh` in Phase A); sandbox URL HTTP 200 `[Linear MCP — Phase C HTTP smoke-test]`; story-doc front-matter `children.engineering` populated.
- **[Design] (3 checks)** — Linear [Design] child `state.type == "completed"` `[Linear MCP — Phase C]`; `figma:` field with node ID matches `figma\.com/file/.*\?node-id=` (filesystem regex); story-doc front-matter `children.design` populated.
- **[QA] (5 checks)** — story-doc front-matter `qa_status: signed-off`; valid `qa_last_signed_off` ISO-8601; QA history table has ≥1 row with `signed-off`; structured QA-run comment posted on Linear QA child via `list_comments` signature match `[Linear MCP — Phase C]`; story-doc front-matter `children.qa` populated.
- **[Docs] (5 checks)** — customer-doc file exists at `docs/product/customer-docs/<domain>/<flow-id>.md`; customer-doc front-matter populated per Q28 schema; `user_docs_url` non-TBD; customer-doc passes `verify-docs.sh` (re-checked from cached Phase A stdout); story-doc front-matter `children.docs` populated.

Phase B emits one `gate.status` entry per evaluated check into the report. Filter args (`--domain`, `--flow`, `--discipline`) gate which checks fire — unfiltered checks are simply not evaluated (not marked skipped — they are out of scope for the requested audit).

**Per-flow row aggregation** happens after Phase C completes — Phase B records its filesystem checks immediately to the in-memory `gate.status[]` accumulator, then waits for Phase C to fold in Linear-state results before rendering the per-flow row to stdout. The "immediate emit" is internal-only (to the accumulator), not streaming to stdout — the entire per-flow grid renders as one block after Phase C completes. Phase C is where the actual `list_issues` call lives; Phase B owns the row aggregation. This is the meaning of the "intermixed" framing in the cross-cutting consistency section below.

**`--gate=<id>` valid-ID enumeration** (the canonical universe `--gate=<id>` accepts; an unrecognized value exits 64). If a row below diverges from the prose check enumeration in this section, the prose wins and the table should be regenerated:

| Category | Stable IDs |
|---|---|
| Phase-transition (Q29.1) | `env-ready`, `preflight-complete`, `intent-exists`, `inventory-complete`, `scaffold-complete`, `story-docs-complete`, `journey-complete`, `index-complete` |
| Per-flow [Story] | `story-doc-exists`, `story-front-matter-populated`, `story-job-story-regex`, `story-ac-gherkin-count`, `story-verify-docs-pass` |
| Per-flow [Eng] | `eng-linear-completed`, `eng-build-lint-test-pass`, `eng-sandbox-http-200`, `eng-children-engineering-populated` |
| Per-flow [Design] | `design-linear-completed`, `design-figma-node-id`, `design-children-design-populated` |
| Per-flow [QA] | `qa-status-signed-off`, `qa-last-signed-off-iso8601`, `qa-history-row-signed-off`, `qa-comment-signature-match`, `qa-children-qa-populated` |
| Per-flow [Docs] | `docs-customer-doc-exists`, `docs-customer-frontmatter-q28`, `docs-user-docs-url-non-tbd`, `docs-customer-verify-docs-pass`, `docs-children-docs-populated` |
| Cross-cutting (Q29.3 + amendment 2) | `inventory-story-doc-id-match`, `index-story-doc-status-match`, `linear-children-match`, `parent-l3-summary-populated`, `milestone-subflows-table-match`, `cross-domain-deps-bidirectional` |

## Phase C — Linear MCP gates

Run the Q29.3 cross-cutting consistency gates plus the Q29.2 [Eng]/[Design]/[QA]/[Docs] state-completion checks that need Linear MCP reads ([QA] routes through `list_comments` for the structured QA-run comment signature match). All read-only.

**Q38 sub-decision 3 — Linear MCP batching (inline implementation).** Use batched `list_issues({label: "domain:<slug>"})` per domain instead of naive per-child `get_issue`. Wall-time delta on a 50-flow / 28-domain project: ~14s batched vs ~125s naive. Implementation is a ~10-line inline re-implementation of Q18.3's batching pattern, NOT a shared utility — parking lot #27 reserves promotion to `_shared/linear-batched-list-pattern.md` for v1.1 only if a third caller (Q43 plan-X dispatcher, Q53 ship, or Q46 writeback) needs the pattern.

The Linear MCP `list_issues` schema takes `label` as a **single string** (not a list); compose multiple FDA labels into separate calls per domain — there is no native multi-label intersection in v1. Cross-check against the workflows-plugin `list_issues` tool registration before drift; if the schema upgrades to list-form `labels:`, fold this batching into a single call per the schema-discipline amendment pattern. (Canon Q38 sub-decision 3 + Q29.3 use the older `labels: [...]` form descriptively; this file echoes the actual workflows MCP signature `label: <str>`. Track as **Q38 amendment 2 candidate** if the divergence persists past Brand Hub dogfood.)

Concretely, for each in-scope domain:

```
batched_issues_for_domain[<slug>] = list_issues({
  team: <linear_team_key from .flow/config.json>,
  label: "domain:<slug>",        # single label per Linear MCP signature
  limit: 250,                     # see paging guard below
})
```

Then evaluate per-child gates against the batched response in memory — never per-child `get_issue` for the routine state checks. **Single `get_issue` calls are restricted to single-issue-scope `--gate=<id> --flow=<DOMAIN-NN>` re-runs.** A `--gate=<id>` invocation **without** a `--flow=` filter MUST batch via `list_issues` per in-scope domain; it MUST NOT degrade to per-issue `get_issue` across N domain parents.

**Pagination guard (correctness, not just performance).** If `len(response) >= 250` for any domain, fail-loud with `Domain <slug> exceeded list_issues batch cap (250); pagination not yet implemented — file a follow-up against parking lot #27 to add cursor paging`. Silent truncation would produce false-pass verdicts on hard gates (children silently absent from the in-memory response → child-existence checks never trip). v1 ships with the loud-guard; v1.1 adds the cursor-paging loop (`while response.has_next: response = list_issues(..., after: response.cursor)`) when a real domain crosses the threshold.

**Per-QA `list_comments` calls** (the `[QA]` 4th check) issue per-QA-child since Linear MCP has no batched-comments primitive. Fire them **in parallel within each domain** (≤5 concurrent per-domain QA-child set, capped at the per-domain count to stay below MCP rate-limit thresholds), and sequence the per-domain batches; total in-flight `list_comments` therefore caps at ~5 at any moment. 5s per-call soft-timeout. Sequential per-flow execution would add ~10s wall on a 50-flow project; per-domain parallelization holds total Phase C wall to roughly the slowest per-domain batch. v1.1 parking lot: a multi-issue `list_comments` MCP tool would let this fold into the per-domain batch.

**Sandbox URL HTTP smoke-tests** (the `[Eng]` 3rd check) similarly fire per-flow. Parallelize with a 3s per-URL HTTP-HEAD timeout; cache by URL within the audit run (different flows can share a sandbox URL); cap in-flight requests at **8 per unique hostname AND 32 globally** (per-host cap protects a single sandbox from rate-limit cascades; global cap protects local socket / fd exhaustion when a project uses many distinct preview hostnames — e.g., per-flow Vercel preview URLs). Transient 5xx (and 429) counts as `gate: unknown` per § Failure semantics, not as hard-fail.

**Q29.3 cross-cutting consistency gates (6 post-Q29 amendment 2):**

- `inventory-story-doc-id-match` — every story doc's `flow_id` front-matter exists as a row in `master-flow-inventory.md`. **Filesystem-only — evaluated in Phase B** (no Linear MCP requirement); rendered in this section for cross-cutting report grouping. Continues to render even when Phase C is skipped due to Linear MCP auth failure.
- `index-story-doc-status-match` — `INDEX.md` Status column matches story-doc front-matter `status` field. Filesystem-only — evaluated in Phase B; rendered here for grouping.
- `linear-children-match` — story-doc `children.*` BC numbers match the actual Linear `parentId` chain. Uses the batched response per domain.
- `parent-l3-summary-populated` — Linear parent issue body contains `## L3 review summary` section with 5 discipline headlines (Q23 mod 2). This is the **L3 review coverage gate** — see § L-review coverage clarification below for the L1/L2/L3/L4 routing.
- `milestone-subflows-table-match` — Linear domain milestone description's Sub-flows table matches actual children of that milestone (Q22 schema).
- `cross-domain-deps-bidirectional` — every story-doc `## Cross-domain dependencies` bullet (Q27 amendment 1 mod 4) of shape `<this-flow-id> blockedBy <other-flow-id>` has a matching Linear `blockedBy` relation on this flow's parent issue, and every Linear `blockedBy` relation between two FDA sub-flow parents (both endpoints carry `domain:*` label) has a matching doc-side bullet in the blocked flow's story doc. `gates` bullets are validated as the symmetric inverse (the OTHER flow's story doc should carry the matching `blockedBy` bullet). Same-domain sibling blockedBy (tracked via `related_flows` front-matter) and discipline-child relations are excluded. Reuses the per-domain `list_issues({label: "domain:<slug>"})` batched response that backs `linear-children-match` + `parent-l3-summary-populated` — no additional Linear round-trips. **Added per Q29 amendment 2 (LOCKED 2026-05-26 per BC-10729).**

**Q29.2 [Eng]/[Design]/[QA]/[Docs] Linear-state checks** — the `list_issues` (and `list_comments` for [QA]) calls live here in Phase C; the per-flow row aggregation owned by Phase B (per the "Per-flow row aggregation" note in the Phase B section) consumes the cached Phase C response. A single per-flow discipline grade aggregates filesystem + Linear-state checks for that discipline.

## Output formats

### Markdown (default per Q29.6)

Three-section report plus Summary line plus Overrides section:

```
# /flow:audit report — <project name>

Run started: <ISO-8601>
Filters: <flag echo or "none">
Mode: <verify-docs ran | --no-verify-docs in effect>

## Phase status

| Phase | Status | Notes |
|---|---|---|
| A — verify-docs.sh | <PASS/FAIL/SKIPPED> | <stdout snippet on fail> |
| B — filesystem gates | <PASS/PARTIAL/SKIPPED> | <count: X pass / Y soft / Z hard-fail / W overridden / V skipped> |
| C — Linear MCP gates | <PASS/PARTIAL/SKIPPED> | <count: X pass / Y soft / Z hard-fail / W overridden / V skipped> |

## Per-flow discipline grid

Q25 legend: ✓ pass | 🚧 in progress | ⏳ pending | ❌ fail | — n/a | ⚠ soft warn

| Flow | Story | Eng | Design | QA | Docs |
|---|---|---|---|---|---|
| TEAM-01 | ✓ | ✓ | ⚠ | ✓ | ⏳ |
| TEAM-02 | ✓ | ❌ | ✓ | ⚠ | ✓ |
| ... |

## Cross-cutting consistency

- inventory-story-doc-id-match: ✓
- index-story-doc-status-match: ⚠ (TEAM-03 INDEX status drifted from story-doc — see line 47)
- linear-children-match: ✓
- parent-l3-summary-populated: ❌ (TEAM-04 parent missing 2 of 5 discipline headlines)
- milestone-subflows-table-match: ✓

## Summary

<N> hard pass · <N> hard fail · <N> soft warn · <N> overrides · exit <code>

## Overrides

| Gate | Reason | Timestamp | Scope |
|---|---|---|---|
| <gate-id> | <user-supplied reason> | <ISO-8601> | <flow / domain / project> |

### Stale overrides — re-evaluate

| Gate | Reason | Timestamp | Why stale |
|---|---|---|---|
| <gate-id> | <reason> | <ISO-8601 (>30 days ago)> | timestamp older than 30-day threshold |
| <gate-id> | <reason> | <ISO-8601> | underlying condition has changed (file now exists) |
| <gate-id> | <reason> | <ISO-8601> | out-of-scope deferred (cap-50 hit; re-run /flow:audit unfiltered to evaluate) |
```

The Overrides section omits the `## Stale overrides — re-evaluate` subsection when there are no stale overrides. The Overrides section omits the entire section when `overrides[]` is empty.

### `--json` (CI scripting)

Structured shape per Q38 sub-decision 4:

```json
{
  "gates": [
    {
      "id": "<stable gate ID e.g. parent-l3-summary-populated>",
      "type": "phase-transition | per-flow | cross-cutting",
      "status": "pass | soft-warn | hard-fail | skipped | overridden | unknown",
      "scope": "project | domain:<slug> | flow:<DOMAIN-NN> | discipline:<name>",
      "message": "<human-readable detail; URL on Linear-side findings>"
    }
  ],
  "summary": {
    "hard_pass": <int>,
    "hard_fail": <int>,
    "soft_warn": <int>,
    "overrides": <int>,
    "exit_code": <int>
  }
}
```

**No file write by default.** stdout is terminal-reviewable; the user redirects to a file via shell (`/flow:audit --json > audit.json`) when they want persistence. Q38 sub-decision 4's "stays strictly local in v1" resolution applies — see § v1 boundary note below.

## Exit codes

Per Q38 sub-decision 6 — exit codes are CI-significant and follow `os.EX_USAGE` convention for arg errors:

- `exit 0` — All hard gates pass (overrides counted as pass per Q29.5 override-counts-as-pass behavior). Soft-gate failures do NOT affect this exit code (informational only).
- `exit 1` — At least one hard gate failed AND was not overridden. The audit report enumerates which gate(s) failed.
- `exit 2` — `verify-docs.sh` failed (Phase A non-zero exit). Phase B + Phase C were marked skipped. The user fixes mechanical issues first, then re-runs.
- `exit 64` — Invalid args (`os.EX_USAGE` convention). Examples: unknown flag, malformed `--gate=<id>` reference, `--flow` value that doesn't match any inventory row, `--discipline` value outside the 5-element enum.

**Override-counts-as-pass (Q38 sub-decision 6, citing Q29 sub-decision 5).** When a hard gate fails and the user picks `Override` via `AskUserQuestion`, the gate is recorded in the breadcrumb's `overrides[]` slot with `{gate, reason, timestamp, scope}` and downstream phases proceed as if the gate had passed — including this exit-code calculation. The override is auditable: every override row is preserved in the breadcrumb and surfaces in `--json` summary + the markdown Overrides section. (CLAUDE.md § Quality gate stack reference uses the same Q38 sub-decision 6 attribution — keep the citations aligned across the two files.)

**`--strict` flag — parking lot v1.1 only — NOT in v1** (Q38 sub-decision 6 parking-lot disposition): would cause `exit 1` whenever overrides are present regardless of pass/fail. Deferred until Brand Hub dogfood reveals override accumulation as a problem.

## Override mechanism

Per Q29.5 (mirrors cadence linear-housekeeping § 6 precedent): on hard-gate failure, fire `AskUserQuestion` with three options — **Fix now** / **Override with reason** / **Halt**.

- **Fix now** — exit the audit, return control to the user with a clear pointer to the failing gate. User fixes, re-runs `/flow:audit`.
- **Override with reason** — fire a follow-up `AskUserQuestion` collecting the reason. Cap the captured reason at 500 characters and strip control characters before persisting (defense against accidental ballooning + report-table corruption — the captured text is rendered into every subsequent audit's Overrides table). Append `{gate, reason, timestamp, scope}` to `docs/plans/.flow-phase-state.json` `overrides[]` (Q31.1 schema). Continue evaluating remaining gates. The override persists across runs until either (a) the user picks `Re-evaluate / Keep / Discard` → `Discard` at the staleness re-evaluate prompt (only fires when stale per § Stale-override detection — see that section for the canonical option set), or (b) the user manually edits the breadcrumb. No auto-clear.
- **Halt** — exit the audit immediately with `exit 1`. No breadcrumb mutation.

`/flow:audit` is **read-mostly** — the only write it ever performs is appending to `overrides[]` when the user picks Override. It never writes `current_phase`, `completed_phases[]`, `status`, or the breadcrumb's per-phase artifact-state slots — those are owned by orchestrators. Append-to-`overrides[]` goes through `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write <state-path> <input-path>` (BC-6956 helper, Q31.5 atomic-rename contract as amended by BC-9027 file-arg refactor) just like every other breadcrumb write — see `skills/_shared/checkpoint-pattern.md` § Write-then-verify or any orchestrator's Phase 1 example for the canonical worked recipe.

## Stale-override detection

Per Q38 sub-decision 7 — extend Q29.5 with a re-evaluate prompt for entries that may no longer be load-bearing.

On every audit run, after evaluating Phase B + Phase C, scan the breadcrumb's `overrides[]` for three staleness outcomes (the third is induced by the out-of-scope re-eval cap below):

1. **Timestamp older than 30 days.** Compare each entry's `timestamp` field against `now - 30 days`. The 30-day threshold is an arbitrary first cut per the Q38 sub-decision 7 lock; tune via Brand Hub dogfood feedback.
2. **Underlying gate condition has changed.** For each override, re-evaluate the gate that was overridden. If the gate now passes (e.g., overridden gate was `journey-complete` for FOO domain when the file was missing, but the journey doc now exists), the override is structurally stale. **Skip-if-fresh:** if the overridden gate was already evaluated in this run's filter scope (Phase B or Phase C produced a fresh pass/fail), reuse **the underlying gate-check result** (NOT the override-masked status — `overridden` is a meta-status that hides the underlying check) as the staleness signal — do not re-evaluate. Only re-evaluate when the override's `scope` falls outside the current `--domain` / `--flow` / `--discipline` / `--gate` filter set. **Out-of-scope re-eval bound:** group out-of-scope overrides by domain and fold their child-state lookups into the same per-domain `list_issues` batch already firing in Phase C (never per-override `get_issue`); cap total out-of-scope re-evals at 50 per audit run; surface remainder as `stale: indeterminate (out-of-scope re-eval deferred; re-run /flow:audit unfiltered to evaluate)` so the audit's I/O budget can't silently expand beyond the user's filter scope. Note: the domain-fold batches DO inflate Phase C wall-time on heavily-filtered runs that carry many out-of-scope-domain overrides — the wall can approach the unfiltered baseline (~14s on a 28-domain project) when out-of-scope override domains overlap most of the project; this is the deliberate trade against per-override `get_issue` cost.

The 30-day literal in condition (1) above must remain verbatim in this section (BC-6969 grep anchor — do not paraphrase to "thirty days" or "monthly").

Each stale override surfaces in the markdown report's `### Stale overrides — re-evaluate` subsection of the Overrides section, with a `Why stale` annotation distinguishing **three** outcomes: (a) timestamp older than 30 days, (b) underlying gate condition has changed, (c) cap-50 deferred (out-of-scope re-eval skipped this run). In `--json`, stale overrides have `status: "overridden"` plus a `stale: "true" | "indeterminate"` tri-state field on the gate entry plus a `why_stale: "timestamp" | "condition-changed" | "out-of-scope-deferred"` typed reason — CI scripts can grep for `stale: "true"` to gate on actionable staleness and for `stale: "indeterminate"` to surface the deferred-by-cap remainder for an unfiltered re-run.

**No auto-clear.** Stale overrides are surfaced for human review only. Removing an override is always a deliberate user action — either via the interactive `AskUserQuestion` (`Re-evaluate / Keep / Discard`) per stale entry when the user runs `/flow:audit` interactively, or via manual breadcrumb edit. `/flow:audit` does NOT auto-mutate `overrides[]` to remove entries. The three options behave: **Re-evaluate** re-runs the underlying gate now and (if it now passes) removes the override; **Keep** preserves the override and refreshes its timestamp to suppress the staleness flag for another 30 days; **Discard** removes the override unconditionally (the next audit will re-surface the underlying gate as a hard-fail if it still fails).

## L-review coverage clarification

Per Q38 sub-decision 2 + Q54 (L-review scoping):

- **L3** — covered via Q29.3 `parent-l3-summary-populated` cross-cutting gate (5 discipline headlines on parent issue body per Q23 mod 2).
- **L2** — intentionally NOT gated. Q26 mod 2 locks `## L2 review summary` on journey docs as optional, so a missing L2 section is not a hard-gate fail.
- **L1** — coverage will fold in when Q41 (PROJECT-INTENT.md template) lands and tightens Q29.1's `intent-exists` required-sections list. Until then, no L1 gate fires.
- **L4** — JIT during `/flow:session-start` Step 5 → `/flow:plan-{discipline}` and is not orchestrator-driven; the per-discipline plan-section content is what each L4 reviewer returns and is captured via Q46 markers, not via `/flow:audit`.

(See plugin CLAUDE.md § L-review pattern for the full per-scope reviewer matrix and four-mode outcome contract; this section is the audit-side projection of the same routing.)

## v1 boundary note

Per Q38 sub-decision 4's deferred-decision resolution (locked 2026-05-07 per Q46 lock; user-confirmed at `:730`): `/flow:audit` stays **strictly local** in v1. stdout markdown + `--json` only; no Linear writeback in v1.

The `audit-concerns marker reserved` in `_shared/linear-writeback-pattern.md`'s v1 type registry is **registered but UNUSED in v1** — explicitly preserved as a future-promotion slot, not an active code path. v1.1 only — promotion via a `--linear-surface[=parent|milestone]` flag on `/flow:audit` (Q38 amendment territory; would constitute Q38 amendment 1 if/when authored). The flag would route audit findings into Q46 via `linear_writeback({type: 'audit-concerns', surface: ..., content: ...})`. Until then, no Linear writes. (This is the v1.1 promotion path.)

**Why this resolution.** /flow:audit auto-fires from /flow:ship + /flow:plan-{discipline} (sub-decision 5); routing those auto-fires to Linear would generate ~5+ comments per ship cycle per sub-flow — notification spam. /flow:ship already routes `ship-summary` as the team-facing checkpoint; `audit-concerns` is developer-internal pre-flight. Most reversible architectural choice — preserves Q38's "stdout-only by default" framing exactly. v1.1 only — no Q38 sub-decision 4 amendment needed in v1.

## Failure semantics summary

| Source | Behavior |
|---|---|
| `verify-docs.sh` non-zero | Phase B+C marked skipped; `exit 2`; no override AskUserQuestion fires |
| Phase B hard-gate fail (predicate fail; mechanical layer passed) | Fire override `AskUserQuestion` per Q29.5 / Q38 sub-decision 6; if Halt or unoverridden → contributes to `exit 1` |
| Phase B soft-gate fail | Surface in report only; no exit-code impact |
| Phase C hard-gate fail (predicate mismatch; Linear MCP succeeded) | Fire override `AskUserQuestion` per Q29.5 / Q38 sub-decision 6; if Halt or unoverridden → contributes to `exit 1` |
| Phase C soft-gate fail | Surface in report only; no exit-code impact |
| Phase C Linear MCP error (transient) | Treat as gate `unknown` in report; surface in summary; do NOT count as hard fail |
| Phase C Linear MCP error (persistent / auth missing) | Surface as Phase C status `SKIPPED` in Phase status table; do NOT contribute to `exit 1` (no signal); user fixes auth, re-runs |
| Phase C HTTP smoke-test error (transient 5xx, 429 rate-limit, or 3s timeout) | Treat as gate `unknown` in report; surface in summary; do NOT count as hard fail |
| Invalid arg (unknown flag, malformed value, `--gate=<id>` not in valid-ID enum) | Surface usage error to stderr; `exit 64` |
| User halt at override prompt | Stop run; `exit 1` |
| `list_issues` returns ≥250 results for any in-scope domain (paging cap hit) | Hard-fail with `Domain <slug> exceeded list_issues batch cap (250); pagination not yet implemented`; no override prompt fires (this is a runner-correctness issue, not a gate predicate) → `exit 1` |

## See also

- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:713` — Q38 lock (canonical source; seven sub-decisions + refinement audit trail at `:729`).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:743` — Q38 sub-decision 4 deferred-decision resolution (stays strictly local in v1; `audit-concerns marker reserved` for v1.1 promotion).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:240` — Q29 35-gate manifest lock (pre-amendment-2; canonical post-amendment total is 36).
- Q29 amendment 2 (LOCKED 2026-05-26 per BC-10729) — adds the 6th cross-cutting gate `cross-domain-deps-bidirectional` (cross-ref consistency between story-doc `## Cross-domain dependencies` section and Linear `blockedBy` relations on sub-flow parent issues); sibling to Q27 amendment 1 (story-doc template adding mod 4 `## Cross-domain dependencies` section).
- `plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md` — gate manifest reference (categories + counts; canonical source for re-derivation prevention).
- `plugins/flow-architecture/skills/_shared/linear-writeback-pattern.md` — Q46 layer; `audit-concerns` marker enum entry.
- `plugins/flow-architecture/skills/_shared/checkpoint-pattern.md` — `overrides[]` breadcrumb slot + `flow-resume-breadcrumb.sh` helper contract.
- `plugins/flow-architecture/commands/start-project.md` — sibling orchestrator (BC-6962). Distinct shape: orchestrator owns breadcrumb writes; `/flow:audit` does not.
- `plugins/flow-architecture/commands/add-sub-flow.md` — sibling orchestrator (BC-6965). Distinct shape: gate placement inside sub-skills; `/flow:audit` has no within-skill gates.
- `plugins/flow-architecture/CLAUDE.md` § Quality gate stack reference — runtime overview of this command in plugin context.
- Handbook CDR-023 — Flow-Driven Architecture (the policy this command implements).
- Parking lot #27 — v1.1 promotion of batched-list-issues pattern to `_shared/linear-batched-list-pattern.md` if a third caller emerges.
- Parking lot #48 — v1.1 `--audit-preflight` flag for `/flow:review` if Brand Hub dogfood reveals demand.
