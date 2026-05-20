# BC-10720 — un-hardcode the brite-sandbox alias

Linear: https://linear.app/brite-nites/issue/BC-10720
Branch: `holden/bc-10720-revops-un-hardcode-the-brite-sandbox-alias-in-setup-sandbox`
Worktree: `.claude/worktrees/bc-10720/`

## Context

BC-10278 (parent decision) landed Option A: a **single shared sandbox** with canonical alias **`brite-staging`** (backed by the `britstag` SF sandbox). The brite-salesforce repo side has been updated (PR #235 / ADR-012). The revops plugin still hardcodes `brite-sandbox` and needs to follow.

## Decision: rename, not parameterize

Per BC-10278 Option A, there is one canonical alias — `brite-staging`. The AC clause "if parameterized, document resolution order" is therefore N/A.

## Scope: 8 files

| # | File | Refs |
|---|---|---|
| 1 | `plugins/revops/commands/setup-sandbox.md` | ~17 |
| 2 | `plugins/revops/commands/doctor.md` | ~16 |
| 3 | `plugins/revops/commands/deploy-sandbox.md` | ~10 |
| 4 | `plugins/revops/commands/post-deploy-runbook.md` | 1 |
| 5 | `plugins/revops/skills/sf-deploy/SKILL.md` | 4 |
| 6 | `plugins/revops/skills/sf-deploy/references/deployment-workflows.md` | 1 |
| 7 | `plugins/revops/tests/test_setup_sandbox_contracts.py` | 6 |
| 8 | `plugins/revops/tests/test_doctor_contracts.py` | 5 |

Plus `plugins/revops/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` version bump (0.4.2 → 0.4.3, same commit).

BC-10720 explicitly listed setup-sandbox/doctor + their tests; asked us to "confirm" deploy-sandbox. Answer = **in scope**. If setup-sandbox/doctor authenticate `brite-staging` but deploy-sandbox still references `brite-sandbox`, the dev workflow breaks the moment a fresh dev runs `/revops:setup-sandbox` then tries `/revops:deploy-sandbox`. Same reasoning extends to post-deploy-runbook + sf-deploy skill (the canonical alias-convention doc).

## Username-suffix nuance

`setup-sandbox.md:118` includes "sandbox usernames carry a suffix such as `.bndev`". The example originally referenced the now-defunct `bndev` sandbox. Update to `.britstag` — the actual suffix devs will see when authenticating against the `britstag` sandbox under the new `brite-staging` alias.

## Tasks

1. setup-sandbox.md — substring replace `brite-sandbox` → `brite-staging`; update `.bndev` example to `.britstag`.
2. doctor.md — substring replace.
3. deploy-sandbox.md — substring replace.
4. post-deploy-runbook.md + sf-deploy skill + deployment-workflows.md — substring replace.
5. Contract tests — substring replace (literal asserts).
6. Version bump plugin.json 0.4.2 → 0.4.3 + mirror in marketplace.json.
7. `python3 -c "import test_setup_sandbox_contracts as t; [getattr(t,n)() for n in dir(t) if n.startswith('test_')]"` (and doctor) — expect all-pass.
8. `./scripts/validate.sh` — expect exit 0.

## Acceptance criteria mapping

- [x] BC-10278 decision applied: alias swapped to `brite-staging` (Option A — no per-dev resolution).
- [x] Both commands and contract tests updated consistently; `./scripts/validate.sh` exits 0.
- [x] Not parameterized → resolution-order doc N/A.
- [x] plugin.json + marketplace.json bumped same commit.
