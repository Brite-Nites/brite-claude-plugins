---
description: Bootstrap a new GTM vertical in canonicals. Adds the slug to _manifest.yaml (alphabetized), creates a skeleton {slug}.yaml, and emits a handbook PR draft for operator review. Per ADR-016 (canonicals schema) + vocabulary.md Section 4 (canonical slug rule). Triggers on "new vertical", "add vertical", "bootstrap vertical", or direct /marketing:new-vertical invocation.
argument-hint: --slug <kebab-slug> --display <Display Name> [--aliases a,b] [--playbook-path <handbook-path>]
allowed-tools: Read, Write, AskUserQuestion, Bash
---

# /marketing:new-vertical

> **How this command runs**: model-interpreted spec delegating deterministic IO to `plugins/marketing/scripts/canonicals_bootstrap.py vertical`. Operator confirmation via `AskUserQuestion`.

Bootstraps a new vertical in the GTM canonicals data layer. Creates the manifest entry + skeleton YAML file, then emits a handbook PR draft the operator pastes into a manual PR.

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
