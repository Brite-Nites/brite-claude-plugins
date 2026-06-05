---
description: Bootstrap a new GTM persona in an existing vertical's canonicals. Appends the persona entry to {vertical}.yaml with a titles list and emits a handbook PR draft for operator review. Per ADR-016 (canonicals schema) + vocabulary.md Section 4 (canonical slug rule). Triggers on "new persona", "add persona", "bootstrap persona", or direct /marketing:new-persona invocation.
argument-hint: --vertical <vertical-slug> --slug <persona-slug> --display <Display Name> [--titles "Title One,Title Two"]
allowed-tools: Read, Write, AskUserQuestion, Bash
---

# /marketing:new-persona

> **How this command runs**: model-interpreted spec delegating deterministic IO to `plugins/marketing/scripts/canonicals_bootstrap.py persona`. Operator confirmation via `AskUserQuestion`.

Bootstraps a new persona entry in an existing vertical's canonicals YAML. Validates the vertical exists and the slug is unique within the vertical's personas list. Emits a handbook PR draft the operator pastes into a manual PR.

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
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
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
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
  --canonicals-dir plugins/marketing/data/canonicals \
  persona --vertical "<vertical>" --slug "<slug>" --display "<display>" \
  --titles "<titles>"
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

> Resume plan-campaign with: `/marketing:plan-campaign --vertical={vertical} --persona={slug} ...`
