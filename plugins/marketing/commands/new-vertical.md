---
description: Bootstrap a new GTM vertical in canonicals. Adds the slug to _manifest.yaml (alphabetized), creates a skeleton {slug}.yaml, and emits a handbook PR draft for operator review. Per ADR-016 (canonicals schema) + vocabulary.md Section 4 (canonical slug rule). Triggers on "new vertical", "add vertical", "bootstrap vertical", or direct /marketing:new-vertical invocation.
argument-hint: --slug <kebab-slug> --display <Display Name> [--aliases a,b] [--playbook-path <handbook-path>]
allowed-tools: Read, Write, AskUserQuestion, Bash
disable-model-invocation: true
---

# /marketing:new-vertical

> **How this command runs**: model-interpreted spec delegating deterministic IO to `plugins/marketing/scripts/canonicals_bootstrap.py vertical`. Operator confirmation via `AskUserQuestion`.

Bootstraps a new vertical in the GTM canonicals data layer. Creates the manifest entry + skeleton YAML file, then emits a handbook PR draft the operator pastes into a manual PR.

> **`disable-model-invocation: true`** — this command WRITES to the version-controlled GTM canonicals (a source of truth other commands read), so per ADR-028 § 0 the model must not fire it unprompted from a vague request. It stays invocable explicitly (`/marketing:new-vertical …`) and via `Skill` delegation; the Phase-2 `AskUserQuestion` confirm gate is an additional guard before any write.

## Emit mode (behavioral-eval seam)

The behavioral eval (BC-12915, ADR-028 § 5 — the **structure-first / LLM-judged** representative, the canonicals backfill batch) drives the SAME deterministic builder this command delegates to (`canonicals_bootstrap.py vertical`) against a **sandbox copy of a frozen fixture seed** — `canonicals_bootstrap.py --canonicals-dir <sandbox> vertical …` — so the run is **side-effect-free**: no write to the real `data/canonicals/`, no Linear/EB/handbook write, no network. The eval-only harness `plugins/marketing/scripts/build_canonical_emit.py` (shared with new-offer/new-persona) orchestrates this (copy seed → run the builder → run `lint_canonicals.py --canonicals-dir <sandbox>`) and emits a structural matrix (`vertical-emit.json`).

The eval asserts the artifact's deterministic **STRUCTURE** — that the written canonical (the new alphabetized manifest entry + the skeleton `{slug}.yaml`) passes the full 19-check `lint_canonicals` contract (manifest alphabetized + duplicate-free, 1:1 manifest↔file, kebab slug + aliases, valid skeleton) and the new entry's `slug`/`display` match the inputs — and explicitly **NOT** the operator/LLM-chosen content (which vertical/aliases/playbook, the handbook-draft prose). That is the ADR-028 D2 structure-first cascade: a judgment-bearing command still passes *deterministically* on the per-PR gate. Eval data lives under `plugins/marketing/tests/eval/new-vertical.*` + the shared `new-offer-seed/`; harnesses are `scripts/eval/test_eval_harness.sh` + the builder suite `plugins/marketing/scripts/test_canonical_emit.sh`, both wired into `validate.sh`.

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--slug` | yes | Kebab-case vertical slug (e.g., `water-parks`). Validated against `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. |
| `--display` | yes | Human-readable display name (e.g., `Water Parks`). |
| `--aliases` | no | Comma-separated alias slugs (e.g., `waterparks,splash-parks`). Each validated kebab-case. |
| `--playbook-path` | no | Handbook path for the playbook. Default: `marketing/go-to-market/verticals/{slug}/README.md`. |

## Phases

### Phase 1 — Preview

1. Parse input flags. Hard-fail on missing required flags.
2. Run preview via helper:

```bash
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
  --canonicals-dir plugins/marketing/data/canonicals \
  vertical --slug "<slug>" --display "<display>" \
  --aliases "<aliases>" --playbook-path "<path>" --preview
```

3. Parse JSON output. If `ok: false`, report the error and stop.
4. Display the preview to the operator showing what will be created.

### Phase 2 — Confirm

Present the YAML diff preview to the operator via `AskUserQuestion`:
- Show: new manifest entry position + new `{slug}.yaml` skeleton contents.
- Options: "Yes, create this vertical" / "Cancel".
- On cancel, stop with no mutations.

### Phase 3 — Execute

1. Run the helper WITHOUT `--preview`:

```bash
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
  --canonicals-dir plugins/marketing/data/canonicals \
  vertical --slug "<slug>" --display "<display>" \
  --aliases "<aliases>" --playbook-path "<path>"
```

2. Parse JSON output. Verify `ok: true`.

### Phase 4 — Verify + emit

1. Run lint to verify the mutation is clean:

```bash
python3 plugins/marketing/scripts/lint_canonicals.py \
  --canonicals-dir plugins/marketing/data/canonicals
```

2. Extract `handbook_draft` from the helper output. Display to operator:
   - Suggested handbook path
   - Suggested commit message
   - Markdown content to paste

3. Print resume instruction:

> Resume plan-campaign with: `/marketing:plan-campaign --vertical={slug} ...`
