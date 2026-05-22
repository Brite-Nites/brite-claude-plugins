# Discoveries promotion workflow

How category-tagged signals emitted to `docs/campaigns/{entity}/{slug}/discoveries.json` flow into handbook canonicals + prose via PR. Per Phase 2 architectural pivot (`memory/project_gtm_campaign_architecture.md`) + BC-8722.

## Where the data lives

- **Schema** — `plugins/marketing/data/discoveries-schema.json` (JSON Schema draft-07; pinned `schema_version: 1`).
- **Lint** — `plugins/marketing/scripts/lint_discoveries.py` (stdlib-only enforcement; no `jsonschema` dependency). Wired into `scripts/validate.sh § GTM Discoveries Lint`. Empty case (no `discoveries.json` files anywhere) is a clean pass.
- **Per-campaign-run signal file** — `docs/campaigns/{entity}/{slug}/discoveries.json` (one file per campaign run; created on first emit; never auto-created on a fresh campaign scaffold).
- **Promotion target — handbook canonicals** — `plugins/marketing/data/canonicals/{vertical}.yaml` (the data layer that `personas[].titles[]`, `offers[].status`, and `personas[]` schema mutate against). See [ADR-016 § Plugin-side canonicals.yaml](../../../docs/decisions/016-gtm-plugin-side-canonicals.md) and [`lint_canonicals.py`](../scripts/lint_canonicals.py) for the canonical-data contract.
- **Promotion target — handbook prose** — vertical playbooks and offer pages under `/brite-nites/handbook/marketing/`. Prose-only promotions (e.g., a new ICP nuance that updates a vertical playbook's persona description) flow via handbook PR — this plugin does not write to the handbook directly.

## The four categories

| Category | Producer skill | Promotion target | Downstream consumer |
|---|---|---|---|
| `title-discovery` | `list-building` | `canonicals/{vertical}.yaml` → `personas[].titles[]` | `/marketing:icp-refinement-review` (BC-8726) |
| `icp-refinement` | `campaign-debrief` | `canonicals/{vertical}.yaml` (persona carve / sub-segment) + handbook playbook prose | `/marketing:icp-refinement-review` (BC-8726) |
| `offer-retirement` | `campaign-debrief` | `canonicals/{vertical}.yaml` → `offers[].status: retired` (+ optional `replaced_by:`) | `/marketing:icp-refinement-review` (BC-8726) |
| `persona-discovery` | `campaign-debrief` | `canonicals/{vertical}.yaml` → new `personas[]` entry | `/marketing:icp-refinement-review` (BC-8726) |

The 4-category lock is intentional. A 5th category (e.g., `vertical-discovery`) is V3-gated and would ship as a follow-up BC; do not add categories without an ADR or BC ratifying the addition.

## End-to-end lifecycle

```
┌─ EMIT ─────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Producer skill (list-building / campaign-debrief)                     │
│      AskUserQuestion 2-call gate ─→  append signal to                  │
│                                       discoveries.json                 │
│                                       (promotion_status: pending)      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─ REVIEW ───────────────────────────────────────────────────────────────┐
│                                                                        │
│  Human operator + /marketing:icp-refinement-review (BC-8726)           │
│      Read pending signals across runs, grouped by                      │
│      {category} × {vertical} × {persona}                               │
│      Operator decisions per signal:                                    │
│        • Accept → promotion_status: promoted (+ canonicals PR drafted) │
│        • Reject → promotion_status: rejected (with note)               │
│        • Defer  → promotion_status stays pending; revisit next cycle   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─ PROMOTE ──────────────────────────────────────────────────────────────┐
│                                                                        │
│  Handbook PR (operator-driven; this plugin does NOT write to handbook) │
│      Canonicals PR  → plugins/marketing/data/canonicals/{vertical}.yaml│
│      Prose PR       → /brite-nites/handbook/marketing/<page>.md        │
│      Lint gates     → lint_canonicals.py + lint_discoveries.py both    │
│                       must pass in scripts/validate.sh                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Promotion-status invariants

`promotion_status` is a 3-state lifecycle: `pending` → `promoted` | `rejected`. The schema does not require the field at emit time — absence is treated as `pending` by consumers. Once set to `promoted` or `rejected`, signals should not transition back to `pending`; an operator who changes their mind on a previously-rejected signal should append a NEW signal (mirrors the append-only invariant `campaign-debrief` enforces on `learnings.md`).

## Guarantees + non-guarantees

**Guaranteed by this layer:**

- The schema lock + lint catch shape drift (wrong category enum, missing required field, schema_version mismatch).
- The 4-category enum is the source of truth for what categories exist; producers and consumers both read from it.
- `discoveries.json` is operator-touched only via the confirm gates in the producer skills (one `AskUserQuestion` + one `Write` per emit) — no skill silently appends.

**Not guaranteed by this layer (downstream responsibility):**

- **Per-category payload-shape enforcement.** The schema holds `payload: { type: object }` open by design so each category can evolve without a schema bump. Per-key constraints described in producer-skill SKILL.md sections (e.g., `title-discovery.payload.occurrences ≥ 2`) are advisory — the lint accepts any object. Human review at promotion time (BC-8726) is the enforcement layer for payload-shape soft-rules.
- Cross-signal deduplication (e.g., the same `title-discovery` for the same vertical/persona/title appearing in 5 runs) — `/marketing:icp-refinement-review` (BC-8726) is responsible for grouping + dedup at review time.
- Handbook PR drafting + merging — handled by the operator at promotion time, with `/marketing:icp-refinement-review` (BC-8726) shaping the PR content downstream.
- Retroactive emission from past campaign runs — discoveries are forward-emitting only; existing campaigns predating BC-8722 do not auto-backfill.

## Until BC-8726 ships

`/marketing:icp-refinement-review` is a separate shipping unit (task #23, BC-8726, blocked by this issue BC-8722). Until it lands, pending signals accumulate in `discoveries.json` files; promoting them is a manual operator workflow (read the file, draft the canonicals PR by hand). The lint still enforces shape correctness in the meantime, so emit-side discipline holds even pre-BC-8726.

## See also

- [`plugins/marketing/data/discoveries-schema.json`](../data/discoveries-schema.json) — the JSON Schema contract.
- [`plugins/marketing/scripts/lint_discoveries.py`](../scripts/lint_discoveries.py) — stdlib-only runtime enforcement.
- [`plugins/marketing/skills/list-building/SKILL.md`](../skills/list-building/SKILL.md) § Discoveries — `title-discovery` emit gate.
- [`plugins/marketing/skills/campaign-debrief/SKILL.md`](../skills/campaign-debrief/SKILL.md) § Discoveries — `icp-refinement` / `offer-retirement` / `persona-discovery` emit gates.
- [ADR-016](../../../docs/decisions/016-gtm-plugin-side-canonicals.md) — canonicals.yaml plugin-side decision.
- `memory/project_gtm_campaign_architecture.md` § "discoveries.json pattern (category-tagged)" — Phase 2 architectural pivot context.
- Linear BC-8726 — downstream review-command shipping unit (task #23).
