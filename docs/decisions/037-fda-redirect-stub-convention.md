# 037. FDA redirect-stub convention (`doc_type: redirect`)

**Status:** Accepted
**Date:** 2026-06-23
**Linear:** [BC-12907](https://linear.app/brite-nites/issue/BC-12907) (redirect-stub gate — fan-out foundation β) · [BC-12905](https://linear.app/brite-nites/issue/BC-12905) (brite-roster compound-loop PRD, parent) · [BC-12303](https://linear.app/brite-nites/issue/BC-12303) (wire FDA audit into consumer CI) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [029](029-fda-canonical-flow-doc-key.md) (the `flow_id`/`DOMAIN-NN` identity that `redirect_to` names) · [036](036-fda-story-frame-bold-span-match.md) (sibling fan-out unit α — story-frame predicate) · [033](033-fda-journey-frontmatter-canon.md) (frontmatter-schema family)

## Context

Some sub-flows are **intentional aliases**: an inventory row exists for a sub-flow whose canonical home is *another* sub-flow, often in a different domain of the same repo. The motivating case is brite-roster `secure-file-ingestion/SFI-05`, whose real story lives at `audit-acl/ACL-06` — SFI-05 is a signpost, not a story.

Before this convention, such a doc had no legal shape under the FDA audit:

- A **full story doc with no real job story** fails `story-front-matter-populated` / `story-job-story-regex` / `story-ac-gherkin-count` — it has no When/I-want/AC because the story lives elsewhere.
- **Deleting** the alias doc breaks `story-docs-complete` (the per-domain gate that asserts `inventory rows == story-doc files`): the inventory row would have no file. It also erases a discoverable signpost for anyone navigating from the alias's name.
- A **filesystem symlink** is not git-portable, breaks on case-insensitive APFS (the BC-6969 class), and is not a readable doc.

The fan-out (BC-12303) cannot reach green on brite-roster without a first-class way to say "this sub-flow is an alias — validate it as a pointer, not a story." (ADR-036 / unit α clears ACL-06's marker brittleness; this convention / unit β clears SFI-05.)

## Decision

A story doc may declare itself a **redirect stub** with two front-matter keys:

- `doc_type: redirect` — selects the redirect-validation profile (absent / any other value ⇒ a normal story doc; today the field is effectively a two-state enum `{"" → story, "redirect"}`).
- `redirect_to: <flow_id>` — a **bare canonical `DOMAIN-NN` flow_id** (per ADR-029), NOT a path. It is resolved by **global stem lookup across all domains of the same repo** — a redirect commonly targets another domain (SFI-05 → ACL-06), so a same-directory check would wrongly fail. Empty or no-such-flow ⇒ a dangling pointer that hard-fails.

A redirect stub is the **6-key minimal** front-matter set `REDIRECT_CANON = (flow_id, domain, doc_type, redirect_to, intent, last_reviewed)` and **has no body** (no job story, AC, personas, or children — those describe the canonical doc).

**Validation profile.** When `doc_type == redirect` the audit:

- runs `redirect-target-resolvable` (always) — the pointer must resolve;
- runs `redirect-front-matter-valid` **only under `frontmatter_schema: strict`** (config-gated per `.flow/config.json`, mirroring the story path's strict-gating) — the 6-key canon, drift- and missing-checked;
- **skips** the story gates (`story-front-matter-populated`, `story-job-story-regex`, `story-ac-gherkin-count`, children/qa) — a signpost has no story by design;
- **still runs body link-resolution** — an alias that links a doc must link a real one.

**Three enforcement surfaces, single source of truth.** The predicates (`_doc_type`, `_redirect_to_resolvable`) and the `REDIRECT_CANON` lint live once in `build_audit_report.py` / `lib/flow_frontmatter_lint.py`; the audit-time `evaluate()`, the bash twin (`run-audit-smoke.sh`), and the CI runner (`run_fda_ci_audit.py`) all route through them.

**Gate-name vocabularies differ by surface, intentionally.** `evaluate()` (the granular 36-gate report) emits `redirect-target-resolvable` + `redirect-front-matter-valid`; the CI runner (the consumer-facing failure grouping) emits `redirect-target` + the generic `frontmatter-schema`. This is the *same* split already in place between `evaluate()`'s `story-front-matter-populated` and the runner's `frontmatter-schema` — the runner groups by the broad category a repo owner acts on (doc_type-agnostic "your frontmatter is off-canon"); the report names the exact predicate.

**Authoring.** `build_story_frontmatter.py --flow-id <ID> --doc-type redirect --redirect-to <ID> --as-of <date>` deterministically emits a stub (no `--scaffold-log`). The `flow-doc-author` skill documents this for operator/orchestrator-identified aliases; auto-detecting *which* flows are aliases (from inventory/Linear metadata) is separate upstream design, out of scope.

## Consequences

- brite-roster's full story-frame debt is mechanically solvable end-to-end: α clears ACL-06, β clears SFI-05.
- The convention is a **frontmatter contract enforced across every consumer repo on three surfaces** — hard to reverse, hence this ADR.
- A redirect stub passes the audit with `status`-free, story-free front-matter — it cannot silently masquerade as a built story (no `status: BUILT` to mislead).
- **No plugin version bump for the gate** (scripts + tests only — consistent with α / #485 / the ADR-034 ratchets). The same PR's `flow-doc-author/SKILL.md` authoring note *does* bump (`1.2.18`), because SKILL.md is cache-keyed.
- Regression-locked: predicate unit tests, ci-runner vslice, frontmatter-lint, the bash↔Python oracle, and a round-trip of the generator's own output. The shared eval/smoke fixtures stay redirect-free (the 515 behavioral-eval golden + the oracle are unchanged); redirect cases use dedicated fixtures.

## Rejected alternatives

- **Delete the alias doc.** Breaks `story-docs-complete` (inventory row with no file) and erases the signpost. Rejected.
- **Filesystem symlink.** Not git-portable, breaks on case-insensitive APFS (BC-6969 class), not a readable doc. Rejected.
- **Leave it a full story doc (empty body).** Fails `story-front-matter-populated` / `story-job-story-regex` — exactly the breakage this convention removes. Rejected.
- **Path-form `redirect_to` (`../audit-acl/ACL-06.md`).** Couples to filesystem layout, breaks on moves/renames (the cross-reference-link 404 class, BC-13710/BC-13152), and contradicts the ADR-029 flow-id identity. The pointer is a flow_id, resolved by lookup. Rejected.
- **Unconditional `redirect-front-matter-valid` (not strict-gated).** Would force the 6-key canon on repos still running lenient frontmatter, off-message with the story path's strict-gating. Rejected — config-gated to match.
