# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

This repo is **single-context**: one root `CONTEXT.md` (the domain glossary — it exists) and one ADR log.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the domain glossary. It fixes the vocabulary for
  concepts that recur across plugins (Product, Build Project, Report kind, …).
- **`docs/decisions/`** — this repo's ADR log (`NNN-slug.md`, e.g. `001-cross-repo-import-solution.md`,
  `010-plugin-secret-config-canon.md`). **Not** `docs/adr/`. Read the ADRs that touch the area you're
  about to work in.

If a referenced doc is ever missing, **proceed silently** — don't flag its absence or suggest
creating it upfront. The producer skill (`/grill-with-docs`) maintains `CONTEXT.md` as terms
get resolved.

## File structure

```
/
├── CONTEXT.md            ← domain glossary (maintained by /grill-with-docs)
├── docs/decisions/       ← ADR log (NNN-slug.md)
│   ├── 001-cross-repo-import-solution.md
│   └── 010-plugin-secret-config-canon.md
└── plugins/
```

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a test name),
use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids. If the
concept isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't
use (reconsider), or there's a real gap (note it for `/grill-with-docs`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-010 (plugin secret-config canon) — but worth reopening because…_
