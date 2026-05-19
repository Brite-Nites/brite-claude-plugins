# BC-9971 Plan — `/flow:add-domain` support for inventory-only-domain re-scaffold (Q20.4 amendment)

**Linear:** [BC-9971](https://linear.app/brite-nites/issue/BC-9971) — High · Backlog · milestone "Flow-Driven Architecture Plugin v1.1"
**Branch:** `holden/bc-9971-flow-architecture-flowadd-domain-support-inventory-only`
**Worktree:** `.claude/worktrees/bc-9971/`
**Approach:** Option A (auto-detect at Phase 2; surface a new `inventory-only` branch alongside the existing Q20.4 hard-reject) — confirmed in issue body; Options B (explicit `--inventory-only` flag) and C (new orchestrator) rejected at issue authorship.
**Plugin version target:** flow-architecture `1.0.7` → `1.0.8` (patch — behavior-broadening within Q20.4, no breaking schema change).

## Tasks

### 1. Amend Q20 in `project_fda_plugin_interview.md` (schema-discipline amendment pattern)

Add a `Q20 amendment 1 — inventory-only-domain re-scaffold branch (LOCKED <today> per BC-9971)` block after the existing Q20 lock (line 224 area, before Q29). Preserve the original sub-decision 4 (hard-reject) text verbatim; append the amendment's prose recording: the three-condition classifier, the new `inventory-only` outcome, the canonical-inventory consumption rule (Phase 2 does NOT regenerate), the unchanged Q20.6 surface (still fires for confirmation), and the new "fully-scaffolded" guarded no-op. Audit trail format mirrors Q47 amendment 1 / Q23 amendment 1 / Q29 amendment 1 (BC-9971 surfaced during BC-6998 iter-2 → BC-9559 follow-up children → asset-foundation manual orchestration validated the desired end-state). Cross-link to Q47 (orchestrator scope, since Phase 2 prose update is the orchestrator-side derivative) and Q31.1 (no breadcrumb schema change needed — the `inventory-only` path uses the same domain-add breadcrumb shape).

**Verify:** `grep -n "Q20 amendment 1" plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` returns one match; total amendment count line (currently at memory:48) bumps from 16 → 17.

### 2. Add Phase 2 classifier helper script: `scripts/flow-classify-domain-state.sh`

Filesystem-only domain-scaffold-state classifier (Linear milestone check stays orchestrator-side per Q32 — bash can't call MCP). Signature:

```
flow-classify-domain-state.sh <inventory-path> <flows-dir> <journeys-dir> <DOMAIN>
```

Outputs exactly one line to stdout: `absent` | `inventory-only` | `journey-exists` | `fully-scaffolded-fs`. Exit codes: `0` on success, `2` on missing inputs.

- `absent` — no `^### <DOMAIN> ` H3 in inventory.
- `inventory-only` — H3 exists, `<journeys-dir>/<domain>.md` absent.
- `journey-exists` — H3 exists, journey doc exists, `<flows-dir>/<domain>/` absent or empty.
- `fully-scaffolded-fs` — H3 exists, journey doc exists, `<flows-dir>/<domain>/` non-empty (story docs landed).

Implementation notes: bash 3.2 + macOS guards (`set -u` + empty-array guard); no PyYAML; case-insensitive H3 match disabled (FDA H3s are uppercase per Q20.4 schema). Domain code is `[A-Z][A-Z0-9_-]*` regex-validated before grep to defend against injection through interview values. The Linear milestone overlay (`FDA: <domain>` present?) is the orchestrator's responsibility — documented inline in `commands/add-domain.md` Phase 2 prose, NOT here. This keeps the helper purely filesystem and testable in isolation against the v-slice fixture pattern.

**Verify:** Helper runs cleanly against the new fixture (task 5); exits `2` on malformed inputs without leaving partial state.

### 3. Update `commands/add-domain.md` Phase 2 prose

Pre-dispatch step inserted at top of the existing "Phase 2: inventory append (domain-add mode) — gate Q20.6" section:

1. **Inventory-only detection** — invoke `flow-classify-domain-state.sh` for `state.target_domain` (the user has not yet supplied this at Phase 2 entry; the new flow is: prompt for the target-domain code BEFORE dispatching `flow-inventory-add`; reuse the same Q19-mini interview Phase 1 surface form for domain-code capture; on `absent`, fall through to today's `flow-inventory-add` domain-add behavior unchanged; on `inventory-only`, take the new branch; on `journey-exists` OR `fully-scaffolded-fs`, take the no-op-with-warning branch per AC bullet 6).
2. **Linear milestone overlay** — query `mcp__plugin_workflows_linear-server__list_milestones` for the project; check whether `FDA: <target_domain>` is present. Combined classification: `inventory-only` (helper) AND milestone-absent (MCP) → take the new branch. If helper says `inventory-only` but milestone IS present → log "inventory says inventory-only but Linear milestone exists — possible drift; proceeding with idempotent re-scaffold per Q13 milestone-create idempotency-against-stored-`milestone_id`" and continue (the milestone-create step in Phase 3 is already idempotent per the Resume contract table).
3. **`inventory-only` branch behavior** — log: `Detected inventory-only domain '<target_domain>' — proceeding to Phase 3 scaffold using existing inventory section as canonical.` Skip the Q19-mini interview (the H3 section, sub-flow rows, status tags, and personas are the canonical record per the issue's "existing inventory section as canonical" requirement). Parse the existing H3 section to populate `state.target_domain_display`, `state.new_sub_flow_ids[]` (from the table rows), and an in-memory equivalent of what Q19-mini would have produced. **Do NOT re-fire L2 review** in this branch — there is no inventory write; L2 reviews the inventoried-but-not-yet-scaffolded design. Instead: re-fire L2 as part of Phase 5 read-stash population (the L2 stash is the journey doc's source per Q26 mod 2, so we still need it). Q20.6 confirmation gate **still fires** but with a different preview surface: "Detected inventory-only domain `<DOMAIN>`. Proceed to Phase 3 scaffold using the inventory section dated `<H3 line>` (preserves status tags + sub-flow rows verbatim)? Approve / Reject."
4. **`fully-scaffolded-fs` OR `journey-exists` branch** — log: `Domain '<target_domain>' already has journey doc and/or story docs on filesystem. No-op.` Surface `AskUserQuestion`: `Re-scaffold anyway via --force? (Re-runs Phases 3-6; clobbers existing journey doc + story docs unless --force flag preserved skip-if-exists per Q15.3 + Q16.3.)` Default: Cancel (clean exit; breadcrumb `status: abandoned` with `reason: 'already-scaffolded (Q20 amendment 1)'`).
5. **`absent` branch** — unchanged. Q20.4 hard-reject path becomes unreachable in normal flow because the `absent` precondition is the only entry to the existing `flow-inventory-add` domain-add code path; Q20.4's hard-reject text remains as the safety net for any caller that bypasses the classifier.

Cite `Q20 amendment 1` at the top of the updated Phase 2 section + add a new "Inventory-only re-scaffold mode" subsection at the section bottom summarizing the four outcomes for resume + auditing reference.

**Resume contract table update:** Add a sentence under the Phase-2 row: "On `mode: inventory-only-rescaffold` (recorded in breadcrumb's `domains[0].inventory_only_rescaffold: true` extension field), Q20.4 idempotency hard-reject is bypassed; resume re-runs the classifier — if it still reads `inventory-only`, the breadcrumb advances to `current_phase: 3` without re-prompting Q20.6." Q31.1 forward-tolerance covers the new `inventory_only_rescaffold` flag; no Q31 amendment required (precedent: Q47 sub-decision 7 calls out same forward-tolerance argument for `milestone_id` + `new_sub_flow_count`).

**Verify:** `grep -n "Q20 amendment 1\|inventory-only" plugins/flow-architecture/commands/add-domain.md` returns ≥ 4 matches; Phase 2 prose unambiguously distinguishes the 4 branches; no surviving text claims Q20.4 hard-reject is the only outcome.

### 4. Amend Q20.4 in `skills/flow-inventory-add/SKILL.md`

Light-touch update — the sub-skill's domain-add Q20.4 hard-reject behavior is unchanged when the orchestrator dispatches it (because the orchestrator only dispatches `flow-inventory-add` on the `absent` classifier outcome). The amendment adds a single paragraph at the bottom of Section 4 ("Idempotency — hard-reject on duplicate (Q20.4)") noting:

> **Caller-side guard (Q20 amendment 1, BC-9971).** `/flow:add-domain` Phase 2 invokes a pre-dispatch classifier (`flow-classify-domain-state.sh` + Linear milestone overlay) before calling this skill in domain-add mode. The hard-reject below fires only on the `absent` outcome; the orchestrator handles `inventory-only` / `journey-exists` / `fully-scaffolded-fs` outcomes itself without dispatching this skill. The reject text below remains the safety net for any caller that bypasses the classifier (e.g., third-party orchestrators in v1.1+).

Cross-link to the `Q20 amendment 1` block in `project_fda_plugin_interview.md` and the updated Phase 2 section in `commands/add-domain.md`.

**Verify:** `grep -n "Q20 amendment 1" plugins/flow-architecture/skills/flow-inventory-add/SKILL.md` returns one match; existing Q20.4 reject text preserved verbatim per schema-discipline amendment pattern.

### 5. Add v-slice fixture + scenarios

Two new fixtures under `plugins/flow-architecture/tests/fixtures/`:

- **`synthetic-inventory-only-domain/`** — single inventory H3 section for `ASSET-DISCOVERY` (3 sub-flows in the table), no journey doc, no flows directory contents. Mirrors the Brand Hub asset-discovery state circa 2026-05-15.
- **`synthetic-fully-scaffolded-domain/`** — same H3 section PLUS `docs/product/journeys/asset-discovery.md` (1-line stub) PLUS `docs/product/flows/asset-discovery/ASSET-DISCOVERY-01.md` story-doc stub.

Add a new test harness file: `tests/run-inventory-only-rescaffold-vslice.sh`. Bash 3.2 compatible; reuses the pass/fail/skip pattern from `run-greenfield-vslice.sh`. Scenarios:

1. **absent**: against `synthetic-greenfield/` (no `ASSET-DISCOVERY` section), helper returns `absent`. PASS.
2. **inventory-only**: against `synthetic-inventory-only-domain/`, helper returns `inventory-only`. PASS.
3. **journey-exists**: against fixture where journey doc exists but flows dir is empty, helper returns `journey-exists`. PASS.
4. **fully-scaffolded-fs**: against `synthetic-fully-scaffolded-domain/`, helper returns `fully-scaffolded-fs`. PASS.
5. **malformed inputs**: missing positional arg → exit 2 with stderr message. PASS.
6. **regex-validated domain code**: rejects domain code containing `..`, `/`, ` `, etc.; exit 2. PASS.

`tests/run-greenfield-vslice.sh` is NOT modified — keeps the existing 69-pass baseline intact. The new harness runs alongside it (CI invokes both via `scripts/validate.sh`).

**Verify:** `bash plugins/flow-architecture/tests/run-inventory-only-rescaffold-vslice.sh` exits 0 with all 6 scenarios PASS; existing vslice still passes.

### 6. Validate scripts/validate.sh picks up the new harness

`scripts/validate.sh` discovers test harnesses by convention. Confirm via:

```bash
bash scripts/validate.sh 2>&1 | grep -A2 "inventory-only-rescaffold"
```

If discovery is filename-pattern-based and the new harness name doesn't match, EITHER rename the harness to match OR add an explicit entry. (Prior precedent: BC-6957 added `run-greenfield-vslice.sh`; check that commit's scripts/validate.sh delta for the discovery convention.)

### 7. Bump plugin version + marketplace

- `plugins/flow-architecture/.claude-plugin/plugin.json` — `version: "1.0.7"` → `"1.0.8"`.
- `.claude-plugin/marketplace.json` — flow-architecture entry `version: "1.0.7"` → `"1.0.8"`.

Both in the same commit as the Phase 2 prose changes (BC-6000 cache-propagation rule).

**Verify:** `grep -n '"1.0.8"' plugins/flow-architecture/.claude-plugin/plugin.json .claude-plugin/marketplace.json` returns two matches.

### 8. Ship

Open PR; body cites `Closes BC-9971` (auto-flips Linear to Done on merge per gotcha_github_auto_close_linear_state). Body lists touched files + amendment audit-trail count bump (16 → 17). Run `/workflows:review` per BC-318 / BC-9027 norms; fix any P1s; loop until clean. Rebase before push to avoid INDEX revert (parallel PR velocity gotcha).

## Out of scope (filed as follow-ups if needed)

- The sibling concern ("L-review agents hallucinating file existence" — PR #248 L1 Eng falsely claimed extract-zip/route.ts didn't exist) is explicitly v1.1 triage territory per the issue body. Do NOT attempt as part of this issue. If we have time post-merge, file a separate BC-issue under "Flow-Driven Architecture Plugin v1.1" milestone with the BC-9971 reference + recommended fixes (reviewer-prompt hardening OR dispatcher post-validation).
- BC-9559 children (BC-9560..BC-9568) re-run via the fixed orchestrator is the dogfood validation — tracked under BC-9559, not blocking this PR. Once BC-9971 ships and is installed, those children can be picked up in subsequent sessions per the [[feedback-retroactive-fda-scaffold-per-domain-validation]] memory (validate per-domain via dogfood + team retro before batch authorizing).

## Verification chain (Levels 1-4)

- L1 (build): `bash scripts/validate.sh` exits 0.
- L2 (tests): both `run-greenfield-vslice.sh` (69 pass) and `run-inventory-only-rescaffold-vslice.sh` (6 pass) green.
- L3 (acceptance): all 7 AC bullets from the issue body covered: orchestrator proceeds (task 3), inventory consumed canonical (task 3), Phases 3-6 produce expected artifacts (orchestrator prose unchanged for Phases 3-6, so behavior is by-construction), 9 BC-9559 children unblocked (downstream — out of scope for this PR), unit tests (task 5), commands/add-domain.md Phase 2 amended (task 3), Q20.4 amended (task 4), interview-doc amendment recorded (task 1).
- L4 (integration): `/workflows:review` clean; PR description cites `Closes BC-9971`.
