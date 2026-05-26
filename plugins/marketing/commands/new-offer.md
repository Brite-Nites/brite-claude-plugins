---
description: Bootstrap a new GTM offer in an existing vertical's canonicals. Appends the offer entry to {vertical}.yaml and emits a handbook PR draft for operator review. Validates posture against the 4-value enum (knowledge / free-asset / pilot / risk-reversal) per ADR-017 + vocabulary.md Section 4. Triggers on "new offer", "add offer", "bootstrap offer", or direct /marketing:new-offer invocation.
argument-hint: --vertical <vertical-slug> --slug <offer-slug> --display <Display Name> --posture <posture> [--status draft|active|retired]
allowed-tools: Read, Write, AskUserQuestion, Bash
---

# /marketing:new-offer

> **How this command runs**: model-interpreted spec delegating deterministic IO to `plugins/marketing/scripts/canonicals_bootstrap.py offer`. Operator confirmation via `AskUserQuestion`.

Bootstraps a new offer entry in an existing vertical's canonicals YAML. Validates the vertical exists, the slug is unique, and the posture is one of the 4 canonical values (ADR-017). Emits a handbook PR draft the operator pastes into a manual PR.

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--vertical` | yes | Existing vertical slug (must be in `_manifest.yaml`). |
| `--slug` | yes | Kebab-case offer slug (e.g., `holiday-anchor-audit`). Unique within the vertical. |
| `--display` | yes | Human-readable display name (e.g., `Resort Holiday Anchor Audit`). |
| `--posture` | yes | One of: `knowledge`, `free-asset`, `pilot`, `risk-reversal`. Per ADR-017 / vocabulary.md Section 1. |
| `--status` | no | One of: `draft`, `active`, `retired`. Default: `draft`. |

## Phases

### Phase 1 — Preview

1. Parse input flags. Hard-fail on missing required flags.
2. Run preview via helper:

```bash
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
  --canonicals-dir plugins/marketing/data/canonicals \
  offer --vertical "<vertical>" --slug "<slug>" --display "<display>" \
  --posture "<posture>" --status "<status>" --preview
```

3. Parse JSON output. If `ok: false`, report the error and stop.
4. Display the preview to the operator showing the entry that will be added.

### Phase 2 — Confirm

Present the YAML diff preview to the operator via `AskUserQuestion`:
- Show: the offer entry that will be appended to `{vertical}.yaml`.
- Options: "Yes, add this offer" / "Cancel".
- On cancel, stop with no mutations.

### Phase 3 — Execute

1. Run the helper WITHOUT `--preview`:

```bash
python3 plugins/marketing/scripts/canonicals_bootstrap.py \
  --canonicals-dir plugins/marketing/data/canonicals \
  offer --vertical "<vertical>" --slug "<slug>" --display "<display>" \
  --posture "<posture>" --status "<status>"
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

> Resume plan-campaign with: `/marketing:plan-campaign --vertical={vertical} --offer={slug} ...`
