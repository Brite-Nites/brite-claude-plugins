---
description: Bootstrap a new GTM persona in an existing vertical's canonicals. Appends the persona entry to {vertical}.yaml with a titles list and emits a handbook PR draft for operator review. Per ADR-016 (canonicals schema) + vocabulary.md Section 4 (canonical slug rule). Triggers on "new persona", "add persona", "bootstrap persona", or direct /marketing:new-persona invocation.
argument-hint: --vertical <vertical-slug> --slug <persona-slug> --display <Display Name> [--titles "Title One,Title Two"]
allowed-tools: Read, Write, AskUserQuestion, Bash
disable-model-invocation: true
---

# /marketing:new-persona

> **How this command runs**: model-interpreted spec delegating deterministic IO to `plugins/marketing/scripts/canonicals_bootstrap.py persona`. Operator confirmation via `AskUserQuestion`.

Bootstraps a new persona entry in an existing vertical's canonicals YAML. Validates the vertical exists and the slug is unique within the vertical's personas list. Emits a handbook PR draft the operator pastes into a manual PR.

> **`disable-model-invocation: true`** — this command WRITES to the version-controlled GTM canonicals (a source of truth other commands read), so per ADR-028 § 0 the model must not fire it unprompted from a vague request. It stays invocable explicitly (`/marketing:new-persona …`) and via `Skill` delegation; the Phase-2 `AskUserQuestion` confirm gate is an additional guard before any write.

## Emit mode (behavioral-eval seam)

The behavioral eval (BC-12915, ADR-028 § 5 — the **structure-first / LLM-judged** representative, the canonicals backfill batch) drives the SAME deterministic builder this command delegates to (`canonicals_bootstrap.py persona`) against a **sandbox copy of a frozen fixture seed** — `canonicals_bootstrap.py --canonicals-dir <sandbox> persona …` — so the run is **side-effect-free**: no write to the real `data/canonicals/`, no Linear/EB/handbook write, no network. The eval-only harness `plugins/marketing/scripts/build_canonical_emit.py` (shared with new-offer/new-vertical) orchestrates this (copy seed → run the builder → run `lint_canonicals.py --canonicals-dir <sandbox>`) and emits a structural matrix (`persona-emit.json`).

The eval asserts the artifact's deterministic **STRUCTURE** — that the written canonical passes the full 19-check `lint_canonicals` contract (schema validity, kebab slugs, filename-stem==slug, ≥1 non-empty title, no duplicate persona slug) and the appended entry's `slug`/`display` match the inputs (`titles` is golden-locked) — and explicitly **NOT** the operator/LLM-chosen content (which persona/titles, the handbook-draft prose). That is the ADR-028 D2 structure-first cascade: a judgment-bearing command still passes *deterministically* on the per-PR gate. Eval data lives under `plugins/marketing/tests/eval/new-persona.*` + the shared `new-offer-seed/`; harnesses are `scripts/eval/test_eval_harness.sh` + the builder suite `plugins/marketing/scripts/test_canonical_emit.sh`, both wired into `validate.sh`.

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--vertical` | yes | Existing vertical slug (must be in `_manifest.yaml`). |
| `--slug` | yes | Kebab-case persona slug (e.g., `director-of-resort-experience`). Unique within the vertical. |
| `--display` | yes | Human-readable display name (e.g., `Director of Resort Experience`). |
| `--titles` | no | Comma-separated title strings. Default: uses `--display` as the sole title. |

## Phases

### Phase 1 — Preview

1. Parse input flags. Hard-fail on missing required flags.
2. Run preview via helper:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/canonicals_bootstrap.py" \
  --canonicals-dir plugins/marketing/data/canonicals \
  persona --vertical "<vertical>" --slug "<slug>" --display "<display>" \
  --titles "<titles>" --preview
```

3. Parse JSON output. If `ok: false`, report the error and stop.
4. Display the preview to the operator showing the entry that will be added.

### Phase 2 — Confirm

Present the YAML diff preview to the operator via `AskUserQuestion`:
- Show: the persona entry that will be appended to `{vertical}.yaml`, including the titles list.
- Options: "Yes, add this persona" / "Cancel".
- On cancel, stop with no mutations.

### Phase 3 — Execute

1. Run the helper WITHOUT `--preview`:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/canonicals_bootstrap.py" \
  --canonicals-dir plugins/marketing/data/canonicals \
  persona --vertical "<vertical>" --slug "<slug>" --display "<display>" \
  --titles "<titles>"
```

2. Parse JSON output. Verify `ok: true`.

### Phase 4 — Verify + emit

1. Run lint to verify the mutation is clean:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint_canonicals.py" \
  --canonicals-dir plugins/marketing/data/canonicals
```

2. Extract `handbook_draft` from the helper output. Display to operator:
   - Suggested handbook path
   - Suggested commit message
   - Markdown content to paste

3. Print resume instruction:

> Resume plan-campaign with: `/marketing:plan-campaign --vertical={vertical} --persona={slug} ...`
