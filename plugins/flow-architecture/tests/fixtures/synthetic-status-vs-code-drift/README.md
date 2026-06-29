# synthetic-status-vs-code-drift fixture

Used by `run-status-vs-code-vslice.sh` (BC-12909, C3 of the BC-12905 PRD) to
lock the **symmetric status-vs-code cross-check** added to `/flow:audit`
(`commands/audit.md` § Status-vs-code advisory) + the reframed
`agents/codebase-inferrer.md` § Conventions "Status is a provisional scan bias"
bullet (US-14).

The cross-check is an **advisory soft-warn**, agent-backed (it dispatches the
existing `codebase-inferrer`), human-adjudicated, and **outside the 37-gate hard
stack** — so this v-slice does **not** execute inference (an LLM agent's output
is not byte-deterministic). It defends the prose contract + the fixture *shapes*
each scenario stands for, exactly the way `run-built-criterion-fixture-vslice.sh`
(BC-10730) defends the operator-consumable BUILT rubric without running the
classifier.

## The four scenarios

Each subdir is a minimal FDA repo. The declared `status:` is the story-doc
front-matter value; the inferred status is what a fresh `codebase-inferrer` scan
of the code tree would conclude. Drift = the two disagree.

| Subdir | Declared `status:` | Code tree | Inferred | Cross-check verdict |
|---|---|---|---|---|
| `deflation/` | `NOT_STARTED` | impl + test present (`src/audit/audit-log.*`) | BUILT | ⚠ **deflation** (doc under-sells shipped work — the roster ACL-02/03/04 case) |
| `inflation/` | `BUILT` | code root present, **no** impl for the flow | NOT_STARTED | ⚠ **inflation** (doc over-claims) |
| `agreeing/` | `BUILT` | impl + test present (`src/team/invite-teammate.*`) | BUILT | ✓ agree — **no warn** |
| `doc-only/` | `BUILT` | **no `src/` and no `app/`** | n/a | — skipped (`no code tree to diff`) — **no warn** |

## Why deflation is the costly direction

`deflation/` mirrors brite-roster: `ACL-02` shipped (an audit-log write hook +
its test) but the code lives at `src/audit/audit-log.ts` — it carries **no
`ACL-02` token**, and the `NOT_STARTED` doc cites no evidence paths, so a
deterministic flow_id→path map finds nothing and would agree-but-wrong. Only a
semantic read of the tree recovers the build. That is exactly why C3 rides the
LLM `codebase-inferrer` rather than a deterministic re-scan, and why the finding
is advisory (a coarse proxy that auto-failed would cry wolf and train an override
reflex — BC-12905 US-13).

## Assertions locked by the v-slice

1. All four scenario subdirs carry a story doc with the declared `status:` value
   named above.
2. `deflation/` has impl + test under `src/` whose filenames do **not** contain
   the flow_id (the unmapped-build shape); its doc says `NOT_STARTED`.
3. `inflation/` has a code root (`src/` exists) but no implementation file for
   the flow; its doc says `BUILT`.
4. `agreeing/` has impl + test under `src/`; its doc says `BUILT`.
5. `doc-only/` has **neither** `src/` **nor** `app/`; its doc says `BUILT` (the
   repo-level skip precondition).
6. `commands/audit.md` encodes the cross-check: the `## Status-vs-code advisory`
   section, both directions (`deflation` / `inflation`), the code-root skip
   precondition (`no code tree to diff`), the `advisory soft-warn` /
   never-hard-fail altitude, the `status-vs-code-agreement` `--json` gate id, and
   the `outside the 37` ledger note.
7. `agents/codebase-inferrer.md` reframes the convention: `provisional scan bias`
   `reconciled at the /flow:audit status-vs-code` cross-check, and the phantom
   `next manual gate` line is **gone**.

## Cross-reference

- BC-12909 — this issue (C3 symmetric status-vs-code cross-check).
- BC-12905 — the parent PRD (§ C3 / User Stories 11-15 / Testing Decisions).
- `commands/audit.md` § Status-vs-code advisory — the prose contract.
- `agents/codebase-inferrer.md` § Conventions — the reframed scan-bias convention.
- `tests/run-built-criterion-fixture-vslice.sh` — the sibling prose+shape v-slice.
