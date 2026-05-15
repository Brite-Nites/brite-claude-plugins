# BC-8718 — Backfill 27 canonicals.yaml + _manifest.yaml — Execution Plan

**Issue**: [BC-8718](https://linear.app/brite-nites/issue/BC-8718) (GTM T3-G)
**Milestone**: GTM Campaign Orchestration v1.0
**Complexity**: M (data entry + cross-reference)
**Branch**: `holden/bc-8718-canonicals-backfill`
**Worktree**: `.claude/worktrees/bc-8718-canonicals/`

## Locked decisions (no design work this task)

- **D7 thin schema** (slug + display + personas[] + offers[]) — ADR-016
- **D11 all 27 day-1** — skeleton entries acceptable for non-Active
- **ADR-016** plugin-side at `plugins/marketing/data/canonicals/`; `titles[]` required ≥1 per persona (drives list-building cascade); optional fields `aliases`, `playbook_path`, `target_personas`, `replaced_by`, `iterates_from`, `prose_path`
- **T5-L / ADR-017** offer posture vocabulary: `knowledge | free-asset | pilot | risk-reversal`
- **T3-G AC** offer status vocabulary: `draft | active | retired`
- **Cohort-1 memory** — `hotels-resorts` stays SKELETON. BC-8727 explicitly uses Path A (canonicality-gate-fails-first) to introduce its persona+offer at runtime via `/marketing:new-persona` + `/marketing:new-offer`. Pre-populating would defeat the BC-8727 dogfood walk.

## Vertical inventory (from handbook @main:marketing/go-to-market/verticals/README.md)

**Active (7) → full ≥1 persona + ≥1 offer:**
1. Municipalities
2. HOAs
3. Landscape Lighting
4. Landscape Architects
5. Builders & Developers (slug: `builders`)
6. Universities
7. Hospitals

**Exploring + Future (20) → SKELETON (slug + display only, empty arrays):**
amusement-parks, apartments, aquariums, auto-dealerships, bars-restaurants, botanical-gardens, casinos, churches, corporate-campuses, country-clubs, event-venues, historic-sites, hotels-resorts, shopping-centers, ski-resorts, sports-stadiums, theaters, tribes-reservations, wineries-breweries, zoos

## Plugin-version-bump check

`scripts/pre-commit.sh:124` regex anchors to `^plugins/[^/]+/(commands|skills|hooks|agents)/`. This task touches:
- `plugins/marketing/data/canonicals/**` — NOT a trigger
- `plugins/marketing/scripts/lint_canonicals.py` — NOT a trigger
- `scripts/validate.sh` — top-level, not under plugins/, NOT a trigger

**Conclusion**: No plugin.json or marketplace.json version bump required.

## Tasks

### T1: Schema authoring (5 min)
**File**: `plugins/marketing/data/canonicals/schema.json`
- JSON Schema draft-07
- Required: `slug` (kebab-case pattern), `display` (string), `personas` (array, may be empty), `offers` (array, may be empty)
- Optional: `aliases` (array of kebab-case strings), `playbook_path` (string)
- Persona item: required `slug` (kebab-case), `display` (string), `titles` (array ≥1 string); persona slug pattern enforces kebab-case
- Offer item: required `slug` (kebab-case), `display` (string), `status` (enum draft|active|retired), `posture` (enum knowledge|free-asset|pilot|risk-reversal); optional `target_personas` (array), `replaced_by` (string), `iterates_from` (string), `prose_path` (string)

**Verify**: file is valid JSON; `python3 -c "import json; json.load(open('plugins/marketing/data/canonicals/schema.json'))"` exits 0.

### T2: Manifest authoring (3 min)
**File**: `plugins/marketing/data/canonicals/_manifest.yaml`
- `schema_version: 1`
- `verticals:` list — all 27 slugs alphabetized

**Verify**: 27 verticals listed; alphabetical order.

### T3: Active 7 vertical YAMLs (30 min)
**Files**: 7 files under `plugins/marketing/data/canonicals/`
Author each from handbook prose (fetch via `gh api repos/brite-nites/handbook/contents/marketing/go-to-market/verticals/<slug>/README.md`):
- `municipalities.yaml` — Public Works Director persona, free ROP audit offer
- `hoas.yaml` — Board President persona, exterior-lighting offer
- `landscape-lighting.yaml` — Property Manager persona, design-consult offer
- `landscape-architects.yaml` — Senior LA persona, specification-package offer
- `builders.yaml` — VP Construction persona, model-home-package offer
- `universities.yaml` — Director of Events persona, campus-walk-through offer
- `hospitals.yaml` — Facilities Director persona, holiday-experience offer

Each gets ≥1 persona (with ≥1 title) + ≥1 offer (with status + posture). Use handbook persona titles verbatim where available; if handbook doesn't enumerate offers, mark `status: draft` and use a placeholder offer derived from prose. Document any prose-derived inference inline in the PR.

**Verify**: each file parses; lint passes.

### T4: Skeleton 20 verticals (5 min)
**Files**: 20 files under `plugins/marketing/data/canonicals/`
Each follows the template:
```yaml
slug: <kebab-slug>
display: "<Display Name>"
playbook_path: "marketing/go-to-market/verticals/<slug>/README.md"
personas: []
offers: []
```

Include `hotels-resorts.yaml` as skeleton (per cohort-1 memory — Path A bootstrap is the BC-8727 dogfood).

**Verify**: 20 files; each parses; lint passes (empty arrays allowed by schema).

### T5: Lint script (20 min)
**File**: `plugins/marketing/scripts/lint_canonicals.py`
- Python 3 stdlib only (no PyYAML — per CLAUDE.md `No PyYAML in test scripts`)
- Regex YAML parser modeled on `scripts/_lib/parse_rubric.py` (simple flat structure, no anchors, no multi-doc)
- Or: shell out to `python3 -c "import yaml"` only if PyYAML happens to be installed in the env — but stdlib regex is the canon
- Validates:
  1. Every `{vertical}.yaml` has required keys per schema
  2. `_manifest.yaml` `verticals[]` is alphabetized
  3. Every slug in `_manifest.yaml` has a matching `{slug}.yaml` file (1:1)
  4. No duplicate vertical slugs
  5. Every persona slug is kebab-case (`^[a-z][a-z0-9-]*$`)
  6. Every offer slug is kebab-case
  7. Every offer `status` ∈ {draft, active, retired}
  8. Every offer `posture` ∈ {knowledge, free-asset, pilot, risk-reversal}
  9. Every persona has `titles` with ≥1 entry (per ADR-016)
- Exit 0 on success, exit 1 with line-level error report on failure
- Locate canonicals dir relative to script (so it works from any cwd)

**Verify**: `python3 plugins/marketing/scripts/lint_canonicals.py` exits 0 against the authored files.

### T6: Wire into validate.sh (5 min)
**File**: `scripts/validate.sh`
- Add a step that invokes `python3 plugins/marketing/scripts/lint_canonicals.py`
- Mirror the ruff/python check pattern already in the file (skip with WARN if python3 absent)
- Increment `errors` on non-zero exit
- Place after existing python checks, before final summary

**Verify**: `./scripts/validate.sh` runs the lint step and exits 0.

### T7: Smoke + commit (10 min)
- Run `./scripts/validate.sh` end-to-end — must exit 0
- Run AC checks:
  - `ls plugins/marketing/data/canonicals/*.yaml | wc -l` → 28
  - `python3 plugins/marketing/scripts/lint_canonicals.py` → exit 0
  - `grep -c '^  - ' plugins/marketing/data/canonicals/_manifest.yaml` → 27
- Stage + commit on `holden/bc-8718-canonicals-backfill`
- Push + open PR via `/workflows:ship` (separate session step; not part of this plan)

## Risk register

- **R1 — handbook fetch quota**: Context7 quota is exhausted this session. Fall back to `gh api` for each of the 7 Active vertical READMEs. If `gh api` rate-limits, cache locally to `$CLAUDE_JOB_DIR`.
- **R2 — handbook prose ambiguity**: If a vertical playbook does not enumerate a concrete offer slug, mark the YAML's offer entry `status: draft` and use the closest "free audit" / "starter audit" placeholder. Note the inference in the PR description.
- **R3 — APFS case-collision**: 27 slug filenames are all-lowercase kebab. No collision risk. `git check-ignore -v` on first written file as a defensive check.
- **R4 — YAML parser robustness**: stdlib regex parser handles flat structure only. If a vertical YAML grows nested keys later, lint must be re-evaluated. For now, schema-locked flat shape per D7.
- **R5 — concurrent worktree**: This worktree is on branch `holden/bc-8718-canonicals-backfill`. No other agent should touch `plugins/marketing/data/canonicals/` while this is in flight.

## Validation Criteria (from issue)

- [x] (target) `ls plugins/marketing/data/canonicals/*.yaml | wc -l` returns 28
- [x] (target) `_manifest.yaml` lists all 27 vertical slugs alphabetized
- [x] (target) 7 Active verticals have ≥1 persona + ≥1 offer
- [x] (target) `python3 plugins/marketing/scripts/lint_canonicals.py` exits 0
- [x] (target) `./scripts/validate.sh` includes the lint and exits 0
- [x] (target) No persona slug uses snake_case or camelCase
