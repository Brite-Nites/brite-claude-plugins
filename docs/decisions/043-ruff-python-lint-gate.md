# 043. Python lint gate: ruff, bug-rules-only, grandfathered per file

**Status:** Accepted
**Date:** 2026-07-29
**Linear:** [BC-16867](https://linear.app/brite-nites/issue/BC-16867) (spawned from [BC-16387](https://linear.app/brite-nites/issue/BC-16387)) under [BC-16394](https://linear.app/brite-nites/issue/BC-16394)
**Related ADRs:** [ADR-034](034-structural-ratchet-full-surface-gate.md) (the grandfather-then-ratchet idiom this copies), [ADR-042](042-skill-allowed-tools-mcp-coverage.md) (sibling forward-only gate; this ADR was split out of its grill), [ADR-007](007-revops-plugin-design.md) (the vendored revops subtree that owns most of the debt)

> **ADR numbering:** claimed as 043 per CDR-025. 042 is the highest on `main`; no branch history and none of the 10 open PRs claim 043 at claim time.

## Context

The repo has **162 Python files** and, since [BC-16371](https://linear.app/brite-nites/issue/BC-16371), **no Python lint gate anywhere**. The only ruff invocation was in `scripts/pre-commit.sh`, gated on `[ -f pyproject.toml ]` — and the root `pyproject.toml` it keyed on was a *leaked lint fixture* (a stub with a fake project table) that BC-16371 correctly deleted. Removing the fixture silently disarmed the linter: `is_python` has been false ever since, so the branch never runs.

The Python surface keeps growing and is load-bearing — `scripts/eval/*.py` implements the ADR-034 structural gate, `scripts/_lib/*.py` the version/ADR/test-wiring lints, and `plugins/*/skills/**/hooks/scripts/*.py` the revops PreToolUse validators that gate Salesforce operations.

Two things constrain the shape of any gate here:

- **`validate.sh` is deliberately stdlib-only / no-pip.** A ruff section there would be a silent no-op for every developer who hasn't installed ruff — the same class of silent-disarm that got us here.
- **Fixing violations is version-bump-bearing.** Measured on `53f1c966`: **51 of the 54** files carrying findings live under `plugins/*/skills/**`, where `scripts/pre-commit.sh` *enforces* a plugin version bump. A "just run `--fix`" PR would touch ~100 files and drag four plugin version bumps into what should be a config change.

Rule-set size decides everything downstream. Measured with ruff 0.16.0:

| Rule set | Findings | Files |
| -- | -- | -- |
| Broad default (E/W/F/UP/B/SIM/PERF/FURB/…) | 1252 | many |
| `E9` + `F` (syntax errors + pyflakes) | **130** | 54 |
| `E9` alone (syntax errors) | 0 | 0 |

## Decision

**Ruff, `select = ["E9", "F"]`, grandfathered per file, enforced by a dedicated CI job.**

1. **Config lives in a real root `pyproject.toml` with `[tool.ruff]` and nothing else.** No `[project]`, no `[build-system]` — this is a plugin monorepo, not a Python package, and those tables would invite pip/setuptools to try to build it. `plugins/revops/pyproject.toml` keeps its own pytest/black/isort config; ruff config is centralized at the root so one gate covers all 162 files.

2. **Rules are `E9` (syntax/IO errors) + `F` (pyflakes) only** — undefined names, unused imports, unused variables, duplicate dict keys. Real-bug rules. Style, import-order and modernization rules are excluded on purpose: at 1252 findings they would mean grandfathering ten times the debt and churning nearly every Python file on first touch. Widening is a deliberate future decision, not a default.

3. **Today's 130 findings are grandfathered per file, per code**, in `[tool.ruff.lint.per-file-ignores]` — each row silences only the codes that file already violates, so a *new* violation of any other selected rule in those same files still blocks. This is the ADR-034 grandfather-then-ratchet idiom applied to a second surface, and it is what makes this PR config-only: **zero code edits, therefore zero plugin version bumps**.

4. **The gate is a dedicated blocking `python-lint` CI job**, not a `validate.sh` section, for the no-pip reason above. Ruff is **pinned** (`ruff==0.16.0`) so an upstream release cannot add rules to `E9`/`F` and red the gate on an untouched tree; bumping the pin is deliberate and re-runs the snapshot.

5. **Re-arming the local path is intended, not incidental.** A real root `pyproject.toml` flips `is_python` back on in `scripts/pre-commit.sh` and the workflows PreToolUse hook. Under the grandfather block both are green on today's tree, so they fire only on new violations — restoring the local fast feedback BC-16371 removed, without blocking anyone on legacy debt.

## Consequences

- The gate is green from day one and blocks new pyflakes bugs repo-wide. Verified both directions: a fresh `F821` in a clean file blocks, and a *new* `F811` in an already-grandfathered file blocks (the ignores are code-scoped, not file-blanket).
- **The debt is not paid, only fenced.** 130 findings across 54 files stay silent — F401 unused-import (63), F541 empty f-string (40), F841 unused-variable (25), F601 (2). Almost all of it is the vendored revops `sf-skills` subtree. Burn-down is a separate ticket, per plugin, where the version bumps belong.
- Burning down debt requires regenerating the block; the recipe is in `pyproject.toml`'s comment. There is deliberately no committed generator script — one more unwired script to maintain for a once-per-burn-down operation.
- Ruff respects `.gitignore`, and `.claude/worktrees/` is ignored (`.gitignore:41`), so a local run from the repo root does not descend into sibling worktrees.
- **Rejected — big-bang fix** (`ruff --fix` clears 104 of 130, hand-fix the rest): leaves a genuinely clean tree, but lands ~100 changed files and 4 plugin version bumps inside a lint PR, and F401 removals need per-case judgment where an import is a re-export.
- **Rejected — broad rule set + grandfather:** higher long-run value, but a 1252-entry snapshot is an unreviewable artifact and every touched file inherits a large cleanup.
- **Rejected — changed-files-only gate** (lint only files changed vs `origin/main`, no debt file): no ledger to maintain, but "changed file" is coarser than "changed line", so a one-line edit to a legacy file would force cleaning that whole file before the PR could go green.
