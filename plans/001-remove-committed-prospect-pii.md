# Plan 001: Remove committed prospect PII from the public repo and block re-introduction

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 04d87b12..HEAD -- docs/campaigns/brite-labs/tam/flagship-retail/ .gitignore`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `04d87b12`, 2026-07-02

## Why this matters

`docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv`
contains ~98 rows of real, enrichment-provider-sourced personal data — full
names, work emails, **personal mobile numbers**, and LinkedIn URLs of prospects
at real companies. The GitHub repo `Brite-Nites/brite-claude-plugins` is
**PUBLIC** (verified via `gh repo view --json visibility` on 2026-07-02).
This is a standing personal-data exposure (GDPR/CCPA data-minimization
problem) and it also publishes Brite's outbound targeting list to competitors.
The tracking of this CSV was deliberate under PR #511's "lightweight
deliverables stay tracked" policy, but that policy predates anyone considering
that the repo is publicly visible — this plan corrects the policy for
person-level data specifically, not the whole policy.

## Current state

- `docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv`
  — 99 lines (1 header + ~98 data rows). Header:
  ```
  region,company_name,domain,first_name,last_name,title,email,email_deliverable,email_is_role,mobile,linkedin_url,source,confidence,flag
  ```
  Rows carry real individuals (source=openmart enrichment). THIS FILE IS THE
  TARGET. Do not open/print its data rows beyond confirming the header — never
  copy row contents into any output, commit message, or report.
- `docs/campaigns/brite-labs/tam/flagship-retail/lists/all-accounts-for-clay.csv`
  — 231 rows of **company-level** data only (company_name, domain, segment,
  persona_side, title_filter, state, category). NOT PII. Stays tracked. Do not
  touch.
- `docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-luxury-targets.csv`
  — contains exactly 1 email-bearing line. Inspect the *column headers and that
  one row's shape only* (e.g. `head -1` plus `grep -c "@"`): if the email
  belongs to a person (has first/last name columns populated on that row),
  treat this file the same as regional-contacts-found.csv (remove); if it is a
  generic role address attached to a company row, leave it and note that in
  your report.
- `.gitignore` (repo root) — already has a "Labs TAM" policy block ending
  around these lines:
  ```
  docs/campaigns/brite-labs/tam/**/*.py
  docs/campaigns/brite-labs/tam/**/*.log
  docs/campaigns/brite-labs/tam/**/*.zip
  docs/campaigns/brite-labs/tam/**/*.xlsx
  docs/campaigns/brite-labs/tam/**/_*
  ```
  The policy comment above it says "Curated artifacts (icp/tam-config/manifest
  .json, *.csv, *.md) stay tracked" — this plan carves person-level contact
  CSVs out of that rule.
- `docs/campaigns/brite-labs/tam/flagship-retail/RESUME-HERE-regional-enrichment.md`
  and `regional-luxury-targets.md` — resume/audit docs that may reference the
  CSV by name. References to the *filename* are fine; verify they don't inline
  contact rows (grep for `@` — if a doc inlines person emails+names, redact
  those lines to `[removed — person-level data lives out-of-repo]`).
- Repo convention: macOS APFS is case-insensitive; after ADDING any gitignore
  rule, run `git check-ignore -v` on files that must stay tracked to confirm
  the new pattern doesn't over-match (existing gotcha in `CLAUDE.md`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full validation gate | `bash scripts/validate.sh` | exit 0, `0 errors` in summary |
| Confirm file untracked | `git ls-files docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv` | empty output |
| Confirm ignore works | `git check-ignore -v docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv` | prints the new rule |
| Confirm company CSV still tracked | `git check-ignore docs/campaigns/brite-labs/tam/flagship-retail/lists/all-accounts-for-clay.csv; echo $?` | exit 1 (not ignored) |

## Scope

**In scope** (the only files you should modify):
- `docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv` (delete from tracking)
- `docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-luxury-targets.csv` (conditional — see Current state)
- `.gitignore` (add pattern + policy comment)
- `docs/campaigns/brite-labs/tam/flagship-retail/RESUME-HERE-regional-enrichment.md`, `regional-luxury-targets.md` (redaction only if they inline person rows)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):
- `docs/campaigns/brite-labs/tam/flagship-retail/lists/all-accounts-for-clay.csv` — company-level, deliberately tracked.
- `docs/dogfood/**` test-leads CSVs — synthetic fixtures (`dogfood-test-NN@…`), verified not real PII.
- `plugins/revops/skills/sf-data/assets/csv/contact-import.csv` — upstream sample data.
- Any git-history rewrite (`filter-repo`, `filter-branch`, force-push) — see STOP conditions.
- The rest of the PR #511 tracking policy (icp.json, tam-config.json, manifest.json, *.md stay tracked).

## Git workflow

- **This repo's primary checkout is BARE** — the root directory is a stale
  snapshot and `git status` fails there. Create a fresh worktree first:
  `git worktree add <path> -b fix/remove-tam-contact-pii origin/main` and work
  inside it. Never run `git reset --hard` or bare `git stash pop` (shared
  refs/stash — repo gotchas).
- Commit style: conventional commits, e.g.
  `fix(campaigns): remove person-level TAM contact CSV from tracking (PII)`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Remove the contact CSV from tracking

In the worktree:
`git rm docs/campaigns/brite-nites... ` — careful, exact path:
`git rm "docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv"`

**Verify**: `git status --short` → shows `D` for exactly that path, nothing else.

### Step 2: Classify and handle regional-luxury-targets.csv

Run `head -1 <file>` and `grep -c "@"` on
`docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-luxury-targets.csv`.
Apply the rule from Current state (person row → `git rm` it too; company-level
role address → leave tracked, note in report).

**Verify**: decision recorded in your report; `git status --short` matches the decision.

### Step 3: Add the gitignore carve-out

In `.gitignore`, append to the existing "Labs TAM run scratch" block (after the
`docs/campaigns/brite-labs/tam/**/_*` line):

```
# Person-level contact exports (names/emails/mobiles) must never be tracked —
# repo is public. Company-level lists (accounts, segments) remain tracked per
# the PR #511 policy. Enriched contact rows live in the CRM / EB, not git.
docs/campaigns/**/lists/*contacts*.csv
docs/campaigns/**/*contacts-found*.csv
```

**Verify**:
`git check-ignore -v docs/campaigns/brite-labs/tam/flagship-retail/lists/regional-contacts-found.csv` → prints one of the new rules.
`git check-ignore docs/campaigns/brite-labs/tam/flagship-retail/lists/all-accounts-for-clay.csv; echo $?` → `1`.

### Step 4: Redact any inlined person rows in the sibling .md docs

`grep -n "@" docs/campaigns/brite-labs/tam/flagship-retail/*.md` — for any line
that pairs a person's name with an email/phone, replace the line with
`[removed — person-level data lives out-of-repo]`. Filename references and
aggregate counts stay.

**Verify**: re-run the grep → remaining `@` hits are non-person (or zero).

### Step 5: Run the full gate and commit

`bash scripts/validate.sh` → exit 0. Commit all staged changes with the message
from Git workflow. The commit message must NOT contain any contact's name,
email, or number.

**Verify**: `git show --stat HEAD` → only in-scope files.

## Test plan

No test framework applies; the machine checks are the gitignore verifications
above plus `bash scripts/validate.sh` (exit 0). The durable regression guard is
the `.gitignore` pattern itself; Step 3's verify commands are the test.

## Done criteria

- [ ] `git ls-files | grep -c "regional-contacts-found"` → 0
- [ ] `git check-ignore` confirms new pattern matches the removed path
- [ ] `all-accounts-for-clay.csv` still tracked (`git ls-files` lists it)
- [ ] `bash scripts/validate.sh` exits 0
- [ ] No contact name/email/mobile appears in the diff context, commit message, or report
- [ ] `plans/README.md` row updated; report records the Step-2 decision and flags the history question (below)

## STOP conditions

Stop and report back (do not improvise) if:

- You are tempted to rewrite git history or force-push: **history purge is a
  maintainer decision** (the data is already public in history; purging
  requires coordinating a force-push across all worktrees and clones, and
  GitHub support for cached views). Deliverable includes flagging this, not
  doing it.
- `regional-contacts-found.csv` no longer exists at the cited path (drifted).
- Any gitignore pattern you add causes `git check-ignore` to match a file the
  Out-of-scope list says must stay tracked.
- You find MORE person-level CSVs beyond the two named (report the paths — do
  not expand scope unilaterally).

## Maintenance notes

- The real fix for the workflow is upstream: TAM enrichment outputs should
  land in Salesforce/Email Bison or a private data store, with only aggregate
  audit counts in git. The marketing `tam-mapping`/`list-building` skills'
  output-path instructions are where that change would go (deferred; out of
  scope here).
- Reviewer should scrutinize: that the gitignore glob doesn't swallow legit
  company-level lists on case-insensitive APFS, and that the commit/diff leaks
  no row data.
- Deferred follow-up: maintainer decision on (a) git-history purge vs accept-
  as-burned, (b) whether the repo should remain public at all — file a Linear
  issue for each (BC- prefix, Brite Plugin Marketplace project).
