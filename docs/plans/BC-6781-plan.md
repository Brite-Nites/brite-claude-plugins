# BC-6781 Plan — Rewrite test-copy-liquid.json with canonical `{% assign %}` form

**Status**: Awaiting approval
**Issue**: [BC-6781](https://linear.app/brite-nites/issue/BC-6781) (round-5 chain blocker)
**Blocks**: [BC-6785](https://linear.app/brite-nites/issue/BC-6785) (round-5 dogfood walk)
**Related**: BC-6554 (round-4 dogfood) · BC-6613 (Liquid syntax adoption) · BC-6782 (validator regex tightening — shipped PR #254)

---

## Plain-language summary

The launch-campaign dogfood walks use a fake JSON copy file as test input. Round-4 found that the Liquid templating syntax inside that file was written in the wrong shape — every lead rendered identically because per-lead values never reached Liquid evaluation.

This task rewrites the file using the **canonical** Liquid pattern documented in `email-copywriting/SKILL.md` (Pattern A + Pattern B), and saves the corrected version to `docs/dogfood/bc-6554/test-copy-liquid.json` as durable dogfood evidence (replacing the round-4 worktree-local broken version that got cleaned up).

**Live verification is intentionally deferred to round-5 (BC-6785).** Reasoning:
- Round-5 S-23 re-walk would do the exact same Preview Body inspection across the same 3-lead pattern. Doing it here would duplicate work.
- Round-5 is the convergent dogfood — its job is to verify all round-4 fixes (BC-6780 + BC-6781 + BC-6782) landing together. S-23 belongs in that walk structurally.
- The canonical Pattern A + B form is documented from EB vendor article 184; risk that it doesn't render per-lead correctly is low.

This issue ships the file rewrite. BC-6785 carries the live verification. The BC-6781 closing comment will note this scope split so the rationale is durable.

This is a test fixture only — no customer-facing copy, no plugin change, no marketplace version bump.

---

## Scope

**In scope**:
- Author canonical `test-copy-liquid.json` at `docs/dogfood/bc-6554/test-copy-liquid.json`
- Update round-4 transcript follow-up table to point at the new artifact path
- Commit + ship via `/workflows:ship`

**Out of scope** (explicitly):
- Live EB Preview Body verification across 3 leads → **handled by BC-6785 round-5 walk S-23**
- Round-5 dogfood walk itself → BC-6785
- BC-6780 case-asymmetry fix → independent round-5 blocker
- BC-6783 / BC-6784 cleanup follow-ups
- Pattern C (contains-keyword branching) — not exercised by S-23
- Plugin version bump — not editing under `plugins/<plugin>/{hooks,skills,commands,agents}/**`

---

## Tasks

### Task 1 — Author canonical test-copy-liquid.json (~10 min)

**File**: `docs/dogfood/bc-6554/test-copy-liquid.json` (NEW)

**Schema**: matches `plugins/marketing/skills/email-copywriting/SKILL.md` § JSON artifact schema (`schema_version: "1.0"`, `entity`, `offer_tier`, `custom_variables[]`, `step_1`, `step_2`).

**Liquid patterns required** (from SKILL.md § Liquid + spintax for graceful per-lead fallback):

- **Pattern A** — assign + filter chain fallback for `RECENCY_ANCHOR`:
  ```liquid
  {%- assign anchor = '{RECENCY_ANCHOR}' | strip | default: 'recent activity' -%}
  ... {{ anchor }} ...
  ```
- **Pattern B** — conditional + spintax fallback for `PROOF_POINT_COMPANY`:
  ```liquid
  {%- assign company = '{PROOF_POINT_COMPANY}' | strip -%}
  {% if company %}{{ company }}{% else %}NO_PROOF_POINT_company{% endif %}
  ```

**Whitespace control**: every Liquid line uses `{%- ... -%}` per SKILL.md § Whitespace control rule (non-negotiable — without hyphens every line emits a blank line).

**custom_variables**: declare `recency_anchor` and `proof_point_company` with non-empty defaults so Phase 1 step 5 Path 5b passes (defaults are the safety-net fallback when CSV columns + Liquid both miss).

**step_1.subject**: spintax-only, no merge variables (per SKILL.md rule: subjects MUST NOT contain Liquid output).

**step_1.body**: ~80 words, contains both Pattern A and Pattern B sites, `<br><br>` paragraph breaks, no `<p>` tags, no em-dashes, no `{{TOKEN}}` double-brace EB-token typos.

**step_2.subject**: spintax-only, does NOT start with `Re:` (EB auto-prepends).

**step_2.body**: shorter follow-up, can omit Liquid (round-5 S-23 only tests step_1 patterns).

**Verification within task** (local grep — no EB calls):
1. `grep -E "\{%-?\s*assign\s+\w+\s*=\s*'\{[A-Z_]+\}'[^%]*default:\s*['\"][^'\"]+['\"][^%]*-?%\}" docs/dogfood/bc-6554/test-copy-liquid.json` → at least one match (Pattern A regex from launch-campaign.md:232 — the BC-6782 validator).
2. `grep -E "\{%-?\s*if\s+\w+\s*%\}" docs/dogfood/bc-6554/test-copy-liquid.json` → at least one match (Pattern B truthy-check shape).
3. `grep -E "\{\{\s*[A-Z_]+\s*\}\}" docs/dogfood/bc-6554/test-copy-liquid.json` → zero matches (no double-brace UPPERCASE typos).

**Acceptance**: file exists, all three grep checks pass, schema valid against SKILL.md § JSON artifact schema.

---

### Task 2 — Update round-4 transcript follow-up table (~3 min)

**File**: `docs/dogfood/bc-6554/round-4-transcript.md`

**Change**: in the round-5 follow-up table (the row that lists BC-6781), update the row's description to cross-reference the new artifact location at `docs/dogfood/bc-6554/test-copy-liquid.json`. This gives the round-5 walker an unambiguous file pointer when they re-walk S-23.

The row currently reads (per the round-4 grep):
> | [BC-6781](https://linear.app/brite-nites/issue/BC-6781) | 🔴 Spinoff (blocker) | rewrite test-copy-liquid.json using canonical `{% assign %}` pattern + verify Liquid renders per-lead values | High |

Update to append "→ corrected artifact at `docs/dogfood/bc-6554/test-copy-liquid.json` (verification deferred to BC-6785 S-23 walk per scope split)" so the round-5 walker (you, ~next session) sees both the file pointer and the scope-split rationale at a glance.

**Acceptance**: round-4 transcript follow-up table row for BC-6781 cites the new path.

---

### Task 3 — Commit + ship (~5 min)

**Branch**: `corinne/bc-6781-bc-6554-follow-up-rewrite-test-copy-liquidjson-using` (from issue gitBranchName).

**Files in commit**:
- `docs/dogfood/bc-6554/test-copy-liquid.json` (NEW)
- `docs/dogfood/bc-6554/round-4-transcript.md` (one-row update)
- `docs/plans/BC-6781-plan.md` (this file)

**No plugin version bump** — no edits under `plugins/<plugin>/{hooks,skills,commands,agents}/**`.

**Commit message**:
> BC-6781: rewrite test-copy-liquid.json with canonical `{% assign %}` (verification deferred to BC-6785)

**Ship**: `/workflows:ship` produces the PR + Linear update + compound-learnings. Closing comment on BC-6781 must call out the scope split: "Live verification deferred to BC-6785 round-5 S-23 walk to avoid duplicate work — same artifact, same 3-lead Preview Body inspection, structurally fits in the convergent dogfood."

---

## Verification checklist (final)

- [ ] `docs/dogfood/bc-6554/test-copy-liquid.json` exists, schema-valid, all three grep checks pass
- [ ] Round-4 transcript follow-up table row for BC-6781 cites the new artifact path
- [ ] Closing comment on BC-6781 explains scope split (verification → BC-6785)
- [ ] Linear BC-6781 status: → In Review (post-PR)

---

## Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Canonical Pattern A + B form is somehow still broken at EB engine level | Low | Documented from EB article 184; if BC-6785 S-23 finds 🔴, file round-6 chain extension. Cost is one round-5 S-row, not blocked work. |
| Round-5 walker overlooks the corrected artifact path | Low | Task 2 updates the transcript follow-up table directly; round-5 issue (BC-6785) already cites BC-6781 as a blocker. |
| Schema drift between SKILL.md § JSON artifact schema and the artifact | Low | Task 1 verification step 1 grep'es against the BC-6782 validator regex — same regex the launch-campaign Phase 1 gate uses. |

---

## Estimated total: ~18 min hands-on
