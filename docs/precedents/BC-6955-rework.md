# BC-6955 rework — re-author flow-architecture `skills/_shared/` utility kit

> **Related:** BC-6955 (original ship; PR #263 + #265 — superseded contract content for the same issue), BC-7066 (Q29 amendment 1 reconciliation that was line-shifted out of the original cite range), BC-6958 task-2 + task-3 (precedents this session counts as **4th surface** for), BC-6957 task-2 + task-3 (2nd surface) + BC-7050 task-2 + task-3 (3rd surface, same-day cluster).
> **Linear:** [BC-6955](https://linear.app/brite-nites/issue/BC-6955/flow-architecture-implement-skills-shared-utility-kit) — issue is Done; this rework lands as corrective PR.
> **PR:** [#272](https://github.com/Brite-Nites/brite-claude-plugins/pull/272)
> **Date:** 2026-05-11

<a id="BC-6955-rework-task-1"></a>
## task-1 — Rework-as-fresh-authorship on a Done issue: overwrite-in-worktree, ship as corrective PR (do NOT revert)

**Decision:** When a user directs "treat this Done issue as brand-new untouched", the corrective path is **author fresh from canonical source in a new worktree, overwriting the prior shipped files in place, then open a new PR on top of `main`** — NOT revert the prior PR, NOT amend the prior PR's commits, NOT branch from the prior PR's branch. The prior content stays in `main`'s history; the new PR is a clean replacement that supersedes it. Line-citation drift in pattern-reference docs (7 wrong line cites in the prior shipped version, discovered during review of the rework) is a recurring failure mode that a fresh authorship + per-cite verify catches cheaply.

**Category:** pattern-choice

**Confidence:** 8/10

**Inputs:**
- User direction on BC-6955: "it was started, but was done incorrectly. please treat it as a brand-new untouched issue and continue".
- Prior shipped PRs #263 (main impl) + #265 (BC-7066 follow-up sync) both merged 2026-05-11 — visible in `git log` at session start; would block a same-branch reuse strategy.
- BC-6955 issue body acceptance criteria still apply verbatim: 22 grep checks across 6 files.
- /workflows:review caught 7 line-citation errors in the rework: `:281` was actually the BC-7066 derivative-resync note (not Q30.2); `:318` and `:323` were Q31 sub-decisions 4 + 6 (not amendment slots); Q46 range `:986-1048` overshot start and undershot end; Q46 sub-decision 1 was off-by-one (header vs body); Q31 range `:300-325` straddled two Q-locks; 12-field schema enumeration in checkpoint-pattern.md self-contradicted the file's own "do not re-define the schema here" rule.
- The 7 wrong cites had survived the original PR #263 review pipeline AND the BC-7066 sync (PR #265) AND a `/workflows:ship` cycle on the prior version — none of those caught them. Validator subagents confirmed each one independently in this rework's review.

**Alternatives Considered:**
1. (Chosen) Worktree off `origin/main` with a new branch name (`holden/bc-6955-rework-skills-shared`), Read each existing file (to satisfy the Edit-tool precondition), then Write to overwrite with fresh authorship from canonical memory. Ship as new PR on top of `main`. Reason: cleanest history; preserves the prior PRs' audit trail; lets `/workflows:review` re-validate end-to-end; the rework PR's diff vs `main` is exactly the corrective delta.
2. Revert PR #263 + #265 first, then re-author on top. Rejected — destroys the audit trail of the original sessions (including BC-6955.md and BC-7066 traces that legitimately captured first-surface decisions). The wrong cites are easier to fix than to revert.
3. Branch from the prior PR's merged-into-main commit and amend. Rejected — same-branch reuse is impossible once the branch is merged + deleted, and reusing the prior branch name would confuse the GitHub history.
4. Treat the user's "treat as brand-new" literally — delete the 6 files in the worktree before authoring fresh. Rejected — Edit/Write tools require a Read first, and there is no integrity gain from deleting then recreating vs overwriting in place. The diff-against-main shows the same corrective delta either way.

**Precedent Referenced:**
- BC-5795 (revert+reship beats forward-fix when post-merge review confirms P1 factual errors in agent-invoked skill) — adjacent but distinct: BC-5795 was a P1 factual-error revert; this is a user-directed quality rework of contract docs that already shipped without P1s. The shared root is "fix the substance, not the history."
- BC-6957 task-1 (SKILL.md pseudocode for filesystem mutations must mirror sibling helper-script's contract exactly) — analogous discipline at a different surface: spec-mirrors-canonical-impl vs pattern-reference-docs-mirror-canonical-cite. Both are about cite-fidelity.
- None at this exact surface (rework-an-already-Done-issue-as-fresh) — first time recording the worktree-overwrite-then-new-PR shape.

**Tags:** rework-as-fresh, cite-fidelity, line-citation-drift, contract-doc-discipline, supersedes-prior-pr

**Outcome:**
- Files changed: 8 (2 version bumps + 6 `_shared/` markdown contracts).
- Tests: 22 AC grep checks pass; `scripts/validate.sh` 0 errors / 21 optional warnings. /workflows:review thorough with 4 review agents + 3 simplify agents + 7 validation subagents → 0 P1 confirmed, 3 P2 confirmed (all line-citation), 4 P3 confirmed (all line-citation or self-contradiction), 1 dismissed (security hallucination), 5 downgraded.
- Approved by: auto-verified (4-level verification: simplify pass + 4 review agents + per-finding validator subagents + final acceptance re-run post-fix).

**Generalization:** When the user re-opens a Done issue with "treat as brand-new", the worktree-overwrite-then-new-PR shape is the right path **only if** the substance (here: contract docs cited by other skills) can be safely re-authored without invalidating downstream references. Test that gate at start of session: confirm whether the prior shipped artifact's identifiers (file paths, locked taxonomy strings, public exports) are stable across the rework. In BC-6955's case the file paths + 22 grep-required strings were stable, so the rework was safe.

---

<a id="BC-6955-rework-task-2"></a>
## task-2 — 4th surface of BC-6958 task-2 worktree-rebase-before-PR

**Decision:** Pre-push rebase onto `origin/main` is now a 4th-surface execution of the BC-6958 task-2 pattern (BC-6958 1st → BC-6957 2nd → BC-7050 3rd → this rework 4th). This session: rebased cleanly when BC-7050 PR #271 (marketing/tam-map/spider_crawl.py) merged during the rework; no conflicts because the touched paths were disjoint (this PR touches only `plugins/flow-architecture/skills/_shared/*` + 2 JSON version bumps; BC-7050 touched `plugins/marketing/scripts/tam-map/`). Pattern advances toward "ready for promotion at 6th surface" — counter at **4/6**.

**Category:** pattern-application

**Confidence:** 8/10

**Inputs:**
- BC-6958 task-2 precedent text (rebase-before-PR; cross-PR drift; ship-step-1 enhancement candidate).
- BC-6957 task-2 (2nd surface, same-day 2026-05-11).
- `git fetch origin main && git log HEAD..origin/main` output showed 4 new commits during BC-6955 rework work (`0bb20ca` + `eabec69` + `874ff3c` + `bd23d15`, all BC-7050).
- `git rebase origin/main` → clean (no conflicts; `.claude-plugin/marketplace.json` touched on both sides, but different plugin entries — flow-architecture vs marketing).

**Alternatives Considered:**
1. (Chosen) Rebase before push. Reason: BC-6958 task-2 prescribed it; BC-6957 task-2 validated it once; this 3rd-surface validation extends the streak.
2. Push without rebase. Rejected — stale-base PR diff would shift the marketplace.json plugin-entry context, potentially confusing reviewers reading the diff for the wrong flow-architecture version.
3. Merge `origin/main` into the branch instead. Rejected — linear-history convention per repo precedent.

**Precedent Referenced:**
- BC-6958 task-2 — 1st surface (2026-05-11)
- BC-6957 task-2 — 2nd surface (2026-05-11)
- BC-7050 task-2 — 3rd surface (2026-05-11)
- This session — 4th surface (2026-05-11; same-day cluster — 4 surfaces in one day strongly suggests this is high-velocity-multiagent-plugin-work shape-dependent, not temporal)

**Tags:** worktree-rebase, 4th-surface, ship-step-1, pre-push-discipline, BC-6958-cluster

**Outcome:**
- Files changed: none directly (process precedent; affects commit ordering, not content).
- Tests: post-rebase `scripts/validate.sh` 0 errors; all 22 AC greps still PASS; plugin.json + marketplace.json version-bump preserved at 0.2.4.
- Approved by: auto-verified (clean rebase + clean post-rebase validate + 22 AC re-greps).

**Generalization:** At 4 of 6 surfaces toward promotion. Two more clean surfaces (or one with a non-trivial conflict resolved cleanly) and this becomes baked into `/workflows:ship` Step 1 as a default rebase action. The 4-surface same-day cluster is the strongest signal yet — propose early promotion if a 5th surface lands tomorrow.

---

<a id="BC-6955-rework-task-3"></a>
## task-3 — 4th surface of BC-6958 task-3 Auto Mode P3 fix-application

**Decision:** Auto Mode + `/workflows:review` → apply ALL validator-confirmed P2/P3s in same PR when behavior-preserving + trivial. This session: 3 P2 + 4 P3 validated and CONFIRMED, 5 downgraded, 1 dismissed; 7 confirmed fixes applied (all behavior-preserving line-citation corrections, no contract semantics changed). Counter at **4/6** — same-day cluster (BC-6958 1st → BC-6957 2nd → BC-7050 3rd → this rework 4th).

**Category:** pattern-application

**Confidence:** 8/10

**Inputs:**
- BC-6958 task-3 precedent text (Auto Mode P3 fix-application; 3-gate override of strict P1-only spec).
- BC-6957 task-3 (2nd surface, same-day 2026-05-11).
- `/workflows:review` thorough verdict on the rework PR: 0 P1 confirmed (perf P1 downgraded), 3 P2 CONFIRMED (validator subagent independently verified each), 4 P3 CONFIRMED (Q46 range, Q46 sub-decision 1, Q31 range, checkpoint 12-field self-contradiction), 5 downgraded (perf and CDR-URL stylistic), 1 dismissed (security hallucination — validator caught the reviewer claiming content that didn't exist in the file).
- All 7 applied fixes were trivial line-number edits in citation strings; none changed the content of cited canonical memory; none changed any of the 22 AC-required grep strings.

**Alternatives Considered:**
1. (Chosen) Apply all 7 validator-confirmed fixes in this PR. Reason: BC-6958 task-3 prescribed it; user is in Auto Mode and explicitly chose `/workflows:review`; the cost of folding behavior-preserving citation fixes into the same PR is zero (no extra PR overhead, single review cycle, single ship cycle).
2. Apply only the P2s; defer the P3s. Rejected — the same-PR fold-in is the BC-6958 task-3 pattern, and the P3s here are objectively wrong line numbers (same failure mode as the P2s, just less severe; no reason to split).
3. Defer all fixes to a follow-up PR. Rejected — strict `/workflows:review` spec compliance would also skip Step 3 simplify-auto-fix anyway since no test suite for markdown; the P1-only fix-loop in Step 7 wouldn't fire (no P1s). Strict-spec would ship the wrong cites; Auto Mode + BC-6958 task-3 saves them.
4. Re-validate each fix independently after applying. Rejected — already validated pre-fix by per-finding Sonnet/Opus subagents; re-validating is redundant; ran `scripts/validate.sh` + 22 AC greps post-fix as the integration gate instead.

**Precedent Referenced:**
- BC-6958 task-3 — 1st surface (2026-05-11)
- BC-6957 task-3 — 2nd surface (2026-05-11)
- BC-7050 task-3 — 3rd surface (2026-05-11)
- This session — 4th surface (2026-05-11; same-day cluster mirrors task-2's pattern — both task-2 and task-3 of BC-6958 are reapplying in lockstep, 4 surfaces in one day)

**Tags:** auto-mode-fold-in, 4th-surface, p2-p3-validator-confirmed, BC-6958-cluster, behavior-preserving

**Outcome:**
- Files changed: 6 markdown files + 1 deletion of 12-field schema enumeration in checkpoint-pattern.md.
- Tests: post-fix `scripts/validate.sh` 0 errors; 22 AC greps PASS; no `:281` / `:318`-as-anchor / `:323`-as-anchor citations remain (sanity grep returns 0); `:292` × 6 / `:329` × 1 / `:334` × 3 all present.
- Approved by: auto-verified.

**Generalization:** At 4 of 6 surfaces. Same-day same-cluster co-evolution of task-2 (rebase) + task-3 (fold-in) is now the dominant pattern — 4 surfaces in 1 day for both. Joint promotion is the natural shape: bake rebase into `/workflows:ship` Step 1 default + bake P2/P3 fold-in into `/workflows:review` Step 7 default behavior (predicate: Auto Mode + validator-CONFIRMED + behavior-preserving + trivial). Worth pre-drafting the promotion follow-up issue now in anticipation of 5th/6th surface this week.
