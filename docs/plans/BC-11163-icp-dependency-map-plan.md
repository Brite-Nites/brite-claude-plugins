# Plan: BC-11163 — canonical Discovery ICP layer + plan-campaign single-source resolution

**Branch**: `drake/plan-campaign-icp-dependency-map` (PR #432, supersedes #416)
**Issue**: BC-11163 — list-building unblock half
**Design session**: grilled 2026-06-04; all decisions below are operator-ratified. Glossary terms in `CONTEXT.md`.

## Design (ratified)

1. **Discovery ICP is per-vertical canonical** — `plugins/marketing/data/canonicals/icp/{vertical}.json`, sibling to `{vertical}.yaml`. The yaml supplies the contact half (personas + title cascades); the icp file supplies the discovery half (industries + geo + size + signals). Campaign-specific narrowing happens in the campaign copy, never upstream.
2. **Segments-only file shape** — no base block. `segments: { "<name>": {block} }`; single-audience vertical = one-segment case. Each segment is a self-contained Discovery ICP (no merge semantics) naming exactly one account universe, with a `persona` cross-ref to the contact cascade it pairs with.
3. **Mandatory for all 27 verticals, lint-enforced (ERROR)** — stub form is `segments: {}` + non-empty `clarifications_needed`; ready form is ≥1 valid segment. Structurally distinguishable; lint enforces the biconditional.
4. **Collapsed single-source resolution in plan-campaign** — `### 2.5` reads only the vertical icp file; reports `ready` or `stub — author before list-build`. No playbook branch, no MISSING state, no campaign-level stub scaffolding. The 6 playbooks remain prose source material cited by their stubs; tam-mapping's playbook auto-load stays as untouched legacy for manual runs.
5. **Copy mechanics** — `--segment` flag (repeatable); auto-pick when the vertical has one segment, AskUserQuestion (multiSelect) when several, skip copy when stub. Copies land uniformly at `docs/campaigns/{entity}/tam/{slug}/{segment}/icp.json` (per-segment subdir = per-segment tam run + intact resume detection). Chosen segments recorded as optional `segments[]` in campaign manifest.json.
6. **Segment block schema** — icp-definition.md keys verbatim (`industries`, `geo`, `size_band`, `tech_signals`, `intent_signals`, `exclusions`) + `display`, `persona`, `seed_accounts: [{name, domain?}]`. Seeds are durable market knowledge, vertical-level; campaign copies may prune/extend.
7. **flagship-retail is an alias** — `aliases: [flagship-retail]` on shopping-centers.yaml; the existing campaign keeps its lived slug (`flagship-retail-vp-marketing-custom-illuminated-artwork-fy26-m07`) across Linear/EB/SF; backfilled manifest says `vertical: shopping-centers`. No external renames.
8. **Out of scope** — `docs/marketing-context.md` (follow-up issue; 2.5 WARN is the standing reminder), phantom copy/angles artifacts (not needed — EB drafts are the live source), any Step 9 edits (#429's territory), authoring real content for the other 26 verticals.

## Tasks

### Task 1 — ADR-024: canonical Discovery ICP layer
**File**: `docs/decisions/024-gtm-canonical-discovery-icp.md` (next free number; match repo ADR format)
Record decisions 1–5 + alternatives rejected (per-campaign home; base+segments; optional files; playbook dual-path; flat copy paths).
**Verify**: `./scripts/validate.sh`.

### Task 2 — Schema: `#/definitions/discovery_icp`
**File**: `plugins/marketing/data/canonicals/schema.json`
Top-level icp-file shape (`vertical`, `source`, `clarifications_needed`, `segments`) + `#/definitions/icp_segment` (block per design 6, `additionalProperties: false`). Add optional `segments[]` to `#/definitions/campaign_manifest`. `$comment` cross-refs ADR-024.
**Verify**: JSON parses; linter tests (Task 3) consume it.

### Task 3 — Linter: icp file family
**File**: `plugins/marketing/scripts/lint_canonicals.py` (+ its test file if one exists; else inline `--self-test` pattern per repo convention)
New checks, ERROR level: every `_manifest.yaml` vertical has `icp/{vertical}.json`; every icp file's filename resolves to a canonical vertical (through aliases); stub biconditional (empty segments ⇔ non-empty clarifications_needed); segment required keys; every segment `persona` resolves to a persona slug in the sibling `{vertical}.yaml`; `seed_accounts` entries have `name`. Confirm (and fix if needed) that campaign-manifest `vertical` resolution honors `aliases`.
**Verify**: linter passes on the new tree; deliberately-broken fixtures fail.

### Task 4 — 27 icp files
**Files**: `plugins/marketing/data/canonicals/icp/*.json` (new dir)
- `shopping-centers.json` — REAL: two segments per design. `flagship-brands` (persona `vp-marketing`) + `destination-centers` (persona `center-owner-asset-manager`). **Draft-and-redline**: drafted from handbook shopping-centers ICP-1, BC-11163 brief, anchor-tenant offer page, corporate-campuses territory list; low-confidence values marked; operator redlines seeds/size-bands/geo before ship. Unresolved redlines → `clarifications_needed`.
- 26 stubs — empty segments, `source` pointer (playbook path for the 6 playbook verticals; handbook README for the rest), `clarifications_needed` listing the operator-fill items (category/segment, size band, geography, fit signals, seeds, exclusions).
**Verify**: `python plugins/marketing/scripts/lint_canonicals.py` green; operator redline sign-off on shopping-centers.

### Task 5 — Canonicals: flagship-retail alias
**File**: `plugins/marketing/data/canonicals/shopping-centers.yaml`
Add `aliases: [flagship-retail]` + history line.
**Verify**: linter green (alias collision checks pass).

### Task 6 — plan-campaign: `### 2.5 — ICP-source resolution` + copy step + surfacing
**File**: `plugins/marketing/commands/plan-campaign.md`
- `### 2.5` (Step 2, after 2.4): read `data/canonicals/icp/{vertical}.json`; resolve segments per design 5; report `ready (segments: …)` / `stub`; WARN once if `docs/marketing-context.md` absent (pointer to `/marketing:product-marketing-context`).
- Step 1 flag table: `--segment` row (repeatable; auto-pick/prompt semantics).
- Step 5 preview: `ICP source:` line (file + chosen segments + ready/stub).
- Step 7: copy chosen segment blocks (flattened to criteria-file root) → `docs/campaigns/{entity}/tam/{slug}/{segment}/icp.json`; record `segments[]` in manifest.
- 11.3 handoff: per-segment criteria-file paths + status in the tam-mapping/list-building pointer.
**Heading note**: `### 2.5` is lint-safe (sequence lint only matches headings starting with literal `Step`).
**Verify**: `./scripts/validate.sh`; contract tests (Task 8).

### Task 7 — tam-mapping SKILL.md: one-line Labs path update
**File**: `plugins/marketing/skills/tam-mapping/SKILL.md`
Update the Labs path line to the per-segment form `docs/campaigns/labs/tam/{slug}/{segment}/{icp.json,tam-config.json}` + one pointer line to `campaign-file-dependencies` reference. No other edits.
**Verify**: `./scripts/validate.sh`.

### Task 8 — Reference doc + contract tests
**Files**: `plugins/marketing/references/campaign-file-dependencies.md` (new); `plugins/marketing/tests/test_plan_campaign_contracts.py`
- Reference doc: the 3-input dependency map table, updated for the collapsed resolution (Input 3 = vertical icp file, always present, ready-vs-stub) + contact-half/discovery-half nuance + segment semantics.
- Tests: `test_icp_source_resolution_documented` (2.5 + canonical icp path), `test_segment_flag_documented`, `test_icp_source_in_preview` (`ICP source:` in Step 5), `test_segment_copy_path_documented` (per-segment subdir format in Step 7), `test_marketing_context_warn_documented`.
**Verify**: `python -m pytest plugins/marketing/tests/ -q` green.

### Task 9 — Version bump + follow-up issue
- `plugins/marketing/.claude-plugin/plugin.json` 0.10.2 → **0.11.0** + matching marketplace.json entry, same commit as command/skill edits (CLAUDE.md gotcha).
- Linear follow-up issue: "Create docs/marketing-context.md via /marketing:product-marketing-context" (the one remaining system-wide gap).
**Verify**: `./scripts/validate.sh` full pass.

## PR #429 collision posture

Edits confined to Steps 1/2/5/7/11 + new files; #429 owns Step 9. Expected conflicts: flag table (both add rows), Step 5 preview block (both add lines), version number, command `description:`. All additive-line conflicts; second-to-merge reconciles. Follow-up after both land: render per-segment criteria into #429's `lead-list.md` "ICP / account filters" section.

## Execution order

1 (ADR) → 2 (schema) → 3 (linter) → 4+5 (data; redline gate here) → 6+7 (command/skill) → 8 (docs+tests) → 9 (bump+ship). Tasks 2–3 and 4–5 pair naturally; 6–8 parallelizable after 4.
