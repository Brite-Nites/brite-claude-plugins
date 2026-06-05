# GTM Campaign Orchestration — Friction Log

**Owner**: Holden Halford (BC-8727 first dogfood operator)
**Started**: 2026-05-19
**Source dogfood**: BC-8727 (T6-O) — Brite Labs × Hotels & Resorts × Director of Resort Experience × Holiday Anchor Audit × FY26 M02
**Feeds**: BC-8729 (V3 ratification, T6-P) + hot-patches landing inline with this PR
**Pair-reads with**: `plugins/marketing/commands/plan-campaign.md`, `docs/gtm-campaign-orchestration-README.md` § 3.6, `BC-8727-plan.md`

## Entry schema

```
### F<N> — <Title> [<severity>]

**When**: <ISO timestamp>
**Step**: <plan-campaign step / phase reference>
**Friction observed**: <one paragraph>
**Root-cause hypothesis**: <one paragraph>
**Proposed fix**: <hot-patch | V3-defer | docs-only | upstream-BC>
**Disposition**: <applied in this PR | deferred to BC-N | logged for V3 BC-8729>
```

**Severity**:
- `blocker` — halts dogfood progression; requires immediate workaround or hot-patch
- `annoyance` — workable but rough; degrades operator experience
- `minor` — cosmetic / docs / wording

**Adversarial mindset**: target ≥7 entries (BC-8727 AC is ≥5). If the dogfood produces <5, the operator wasn't pushing hard enough — re-run with adversarial input.

## Roll-up summary

| # | Title | Step | Severity | Disposition |
|---|---|---|---|---|
| F1 | BC-8725 sibling commands unshipped — Path A blocked at canonicality | 2.2 | blocker (workaround applied) | hot-patch (manual canonicals edit); upstream-BC = BC-8725 priority bump |
| F2 | Skill-tool dispatch loads spec markdown but does not execute | n/a (invocation) | minor | docs-only (add operator-facing note to plan-campaign.md) |
| F3 | Step 2.2 error template lists empty personas as ambiguous string | 2.2 | minor | hot-patch (render `[]` explicitly) |
| F4 | Canonicality validation is short-circuit, not batch — operator only learns about persona-miss; offer-miss + target-personas-miss only surface on re-run | 2 | annoyance | V3-defer (BC-8729 candidate: batch-validate 2.1-2.4 + report all misses) |
| F5 | Spec's `list_milestones(projectId=..., query=...)` doesn't match the MCP tool shape (`project`, no `query`) | 3.3 | minor | hot-patch (spec call signature) |
| F6 | `list_milestones` returns 69K-char dump with no filter param — collision check requires offline grep | 3.3 | annoyance | V3-defer (Linear MCP feature request; orchestrator workaround = file-grep) |
| F7 | Handbook brief template is gitbook-prose; spec's `{{slot}}` substitution table no-ops against it | 8a.2 / 8a.3 | annoyance | hot-patch (clarify spec; recommend inline fallback when template lacks slots) |
| F8 | `save_milestone` response has no `url` field — spec assumes one | 8a.5 | minor | hot-patch (construct URL from project; document in spec) |
| F9 | Linear prosemirror auto-links bare `BC-NNNN` in milestone + issue descriptions | 8a + 9 | informational | no-op (different from GitHub Magic Issue ID; Linear-internal only) |
| F10 | `list_issue_labels` exposes `name:` filter — spec at 8a.6 says "if MCP exposes prefix filter, prefer that" but doesn't use it | 8a.6 | annoyance | hot-patch (use name: filter in spec) |
| F11 | SF MCP default target-org is `marketing-claude-prod` (alias), but `/revops:create-sf-campaign` defaults `--target-org=brite-prod` — mismatch surfaces only at SOQL call site | 8b (sibling) | annoyance | docs-only (clarify spec for caller) |
| F12 | SF JWT auth refresh failing in env — every σ3 call soft-fails | 8b (operational) | annoyance | upstream-BC (re-auth SF; not BC-8727 scope) |
| F13 | `/revops:create-sf-campaign` Phases 2 + 3 have no explicit error branch for SOQL call failure (only Phase 5's `sf_cli_error`) | 8b (sibling) | annoyance | hot-patch (extend sibling spec to map Phase 2/3 SOQL errors to `sf_cli_error`) |
| F14 | `/revops:create-sf-campaign --dry-run` still requires live SF auth for Phases 2 + 3 | 8b (sibling) | minor | V3-defer (offline dry-run; not blocker) |
| F15 | Linear MCP `save_issue` partial update with just `blockedBy` is SAFE — labels + descriptions + parent preserved (spec worry confirmed unfounded) | 9 | informational | hot-patch (update spec to reflect verified behavior) |
| F16 | Manifest schema has no `linear.sub_issues[]` field — can't walk manifest → sub-issues for downstream consumers | 7 | annoyance | V3-defer (schema_version 2 candidate) |
| F17 | `blockedBy` field on save_issue is plural array (not `blockedById` singular per spec wording) | 9 | minor | hot-patch (spec typo: `blockedById` → `blockedBy`) |
| F18 | 10 sub-issue creates + 9 blockedBy updates = 19 MCP round-trips per scaffold — heaviest surface of the orchestrator | 9 | annoyance | V3-defer (single-pass with `blockedBy` on create would cut to 10; needs API check that linear-MCP accepts forward-ref to not-yet-created IDs in same batch — unlikely) |

## Entries

### F1 — BC-8725 sibling commands unshipped — Path A blocked at canonicality [blocker]

**When**: 2026-05-19T(pending — fills on first plan-campaign invocation)

**Step**: 2.2 (persona canonicality assertion) — HARD-FAIL pointer reads "add it via /marketing:new-persona (BC-8725)" but the command does not exist on disk.

**Friction observed**: The Path A worked example in `docs/gtm-campaign-orchestration-README.md` § 3.6 assumes `/marketing:new-persona` and `/marketing:new-offer` exist to bootstrap canonical entries when plan-campaign hard-fails at Step 2. As of 2026-05-19, BC-8725 (the issue authoring these three sibling commands) is still in Backlog with no shipped artifact. Inspection of `plugins/marketing/commands/` confirms only `launch-campaign.md` and `plan-campaign.md` exist — `new-persona.md`, `new-offer.md`, and `new-vertical.md` are absent. An operator running plan-campaign on a vertical with empty canonicals (e.g., hotels-resorts) hits the HARD-FAIL, follows the error message's pointer to `/marketing:new-persona`, and discovers the command does not exist.

**Root-cause hypothesis**: BC-8725 was placed at Tier 9 ("optional / deferrable") in the implementation plan, with priority Low. The dogfood path A specifically requires it. The "deferrable" judgment in T9-W priority was correct for the bulk of campaigns (the 7 Active verticals already have populated canonicals), but the cohort-1 lock chose hotels-resorts SPECIFICALLY to exercise Path A. Result: BC-8725 is functionally a hard pre-req for the cohort-1 dogfood, even though it isn't declared as a blockedBy.

**Proposed fix**:
1. **This PR (hot-patch workaround)**: Hand-edit `plugins/marketing/data/canonicals/hotels-resorts.yaml` to add `director-of-resort-experience` persona + `holiday-anchor-audit` offer, then re-run plan-campaign. Capture this workaround in the friction log so future operators don't get stuck.
2. **Upstream-BC**: Bump BC-8725 priority Low → High and add `blocks: BC-8727` relation. Without BC-8725, every future Path A dogfood reproduces this friction.
3. **plan-campaign.md doc fix** (hot-patch candidate): Update the Step 2.2 HARD-FAIL message to say "add it via /marketing:new-persona (BC-8725) — if BC-8725 is not yet shipped, hand-edit `plugins/marketing/data/canonicals/{vertical}.yaml` per the schema and run `python3 plugins/marketing/scripts/lint_canonicals.py` to verify." This is a 2-line text-only change.

**Disposition**: F1 hot-patch (workaround applied in this PR) + upstream-BC (BC-8725 priority bump comment to be added when filing) + docs-only (plan-campaign.md error-message update applied in this PR).

**Reproduction**: `Skill(skill: "marketing:plan-campaign", args: "--entity=labs --vertical=hotels-resorts --persona=director-of-resort-experience --offer=holiday-anchor-audit --month=2 --year=2026 --launch-date=2026-02-03 --owner-email=marketingadmin@britenites.com --eb-workspace=emailbison-b2b --situation-mining --creative-angles --dry-run")` → `Read plugins/marketing/data/canonicals/hotels-resorts.yaml` returns `personas: []`. Step 2.2 HARD-FAIL message would read: `ERROR: Persona 'director-of-resort-experience' is not defined for vertical 'hotels-resorts' in hotels-resorts.yaml. Either correct the slug, OR add it via /marketing:new-persona (BC-8725). Current canonical personas: <empty>`.

---

### F2 — Skill-tool dispatch loads markdown spec but does not execute [minor]

**When**: 2026-05-19T17:30Z (BC-8727 Phase 1)

**Step**: n/a — Skill invocation envelope.

**Friction observed**: Invoking `Skill(skill: "marketing:plan-campaign", args: "...")` returns the full markdown spec body verbatim with the argument string appended. There is no "runner" — Claude (the operator) must read the markdown and tool-call each Step (1, 1b, 2, 3, ...) manually. A new operator who expects `/marketing:plan-campaign --foo=bar` to "just run" will be surprised when the response is a 900-line procedural specification.

**Root-cause hypothesis**: This is how all slash-command skills work in Claude Code — they ARE procedural specs that the model executes. The orchestrator-style framing of plan-campaign (11 numbered Steps, dry-run preview, two-call confirm gate, etc.) reinforces the "runner" mental model that doesn't match the actual dispatch reality.

**Proposed fix**: Add a 1-paragraph note at the top of plan-campaign.md ("How this command runs") that says: "When invoked, the model reads this spec and executes each Step in order using its tool palette. There is no separate runtime; the spec IS the program. To debug a partial run, re-invoke from the failure point or apply hot-patches inline." This sets operator expectations without changing behavior.

**Disposition**: docs-only — hot-patch in this PR.

---

### F3 — Step 2.2 error message renders empty personas list ambiguously [minor]

**When**: 2026-05-19T17:35Z

**Step**: 2.2 — persona-not-found HARD-FAIL.

**Friction observed**: The error template at plan-campaign.md Step 2.2 reads `Current canonical personas: <comma-separated personas[].slug>`. When `personas: []`, the comma-separated render is the empty string, producing `Current canonical personas: ` (trailing nothing). An operator pasting the error to a teammate may interpret this as a missing field rather than an empty list.

**Root-cause hypothesis**: Spec author assumed at least one persona would always be present. Path A's intentional bait case (empty personas/offers) breaks the rendering assumption.

**Proposed fix**: Update the error template to render empty arrays as `<empty — vertical has no personas defined yet; this vertical is in Path A "Exploring/Future" status>`. Same fix applies to Step 2.3 (offers).

**Disposition**: hot-patch — apply to plan-campaign.md in this PR.

---

### F4 — Canonicality validation is short-circuit, not batch [annoyance]

**When**: 2026-05-19T17:36Z

**Step**: 2 (overall)

**Friction observed**: When 2.2 fails, the operator only learns about the missing persona. They will run `/marketing:new-persona` (or hand-patch), re-invoke, and ONLY THEN discover 2.3 ALSO fails because the offer is missing. The cohort-1 dogfood specifically exercises BOTH a missing persona AND a missing offer — two HARD-FAIL round-trips required, when a single batch validation could surface both at once.

**Root-cause hypothesis**: The "first-miss HARD-FAIL" pattern is the safer / simpler design for the orchestrator. Batch reporting requires deferring the failure mode + accumulating findings. Per the cohort-1 walk in README § 3.6, both Phase 2 (new-persona) and Phase 3 (new-offer) are expected — but they're sequential in the spec, which baked the short-circuit in.

**Proposed fix**: V3 (BC-8729) candidate. Batch-validate Steps 2.1 → 2.2 → 2.3 → 2.4. If ANY fail, surface all misses in one error block before halting. Operator runs `/marketing:new-persona` AND `/marketing:new-offer` once, then re-invokes once. Cuts dogfood-Path-A round-trips from 3 to 2 (and arbitrary N → 2 generally).

**Disposition**: deferred to V3 (BC-8729 ratification). Not a blocker for BC-8727 because the cohort-1 walk explicitly anticipates the multi-trip pattern in Phase 2 + Phase 3.

---

### F5 — `list_milestones` MCP-tool signature drift from spec [minor]

**When**: 2026-05-19T21:00Z, Step 3.3

**Friction**: Spec calls `list_milestones(projectId=<id>, query=<slug>)`. The actual MCP-tool schema is `project: <id-or-name-or-slug>` (no `projectId`) and there is NO `query` param. Spec drift between authored time + current MCP shape.

**Root-cause**: Linear MCP tool shapes evolve independently of plan-campaign spec. No cross-reference test catches drift.

**Proposed fix**: hot-patch — update spec to current call shape: `list_milestones(project=<project-id>)`. Also note F6 absence of filter at the same call site.

---

### F6 — `list_milestones` returns unfiltered project dump (69K chars) [annoyance]

**When**: 2026-05-19T21:00Z, Step 3.3

**Friction**: With no `query` filter, `list_milestones(project=<gtm-project-id>)` returned 69,671 characters in one call. Linear's Brite GTM has ~70 milestones already. Result triggered the "exceeds max tokens" handler, forcing fallback to file-grep for collision check. Workable, but every plan-campaign run pays the dump cost.

**Root-cause**: Linear MCP omits the `name`-filter param available elsewhere (e.g. `list_issue_labels` HAS `name:` filter — see F10).

**Proposed fix**: V3-defer. File upstream linear-MCP feature request for `name:` / `query:` on `list_milestones`. Workaround in spec: document the grep-on-saved-output collision fallback. The hot-patch is the spec note + workaround; the real fix is upstream.

---

### F7 — Handbook brief template doesn't use `{{slot}}` placeholders [annoyance]

**When**: 2026-05-19T21:01Z, Step 8a.2-8a.3

**Friction**: `gh api repos/brite-nites/handbook/contents/marketing/go-to-market/templates/campaign-brief-template.md` returned a gitbook-style template (`{% hint %}` blocks, prose-style empty bullets `-`). The spec's slot-substitution table (Step 8a.3) assumes Jinja-style `{{slug}}` / `{{vertical_display}}` etc. — none of those exist in the handbook template. Slot-replace would silently no-op, producing a milestone description with no campaign metadata.

**Root-cause**: Spec authored before the handbook template was finalized; templates evolved without cross-referencing the orchestrator's slot expectations.

**Proposed fix**: hot-patch. Two options:
1. **Recommended**: Update plan-campaign.md to use the inline fallback (Step 8a.4) BY DEFAULT (with the gitbook-style handbook template available as reference for the human brief-author to consult), since the inline fallback IS the slot-substitution surface.
2. **Alternative**: Update the handbook template to include `{{slot}}` placeholders for orchestrator-substitution. Larger change touching the handbook repo.

Going with option 1 in this PR; option 2 is a follow-up handbook PR.

---

### F8 — `save_milestone` response has no `url` field [minor]

**When**: 2026-05-19T21:03Z, Step 8a.5

**Friction**: Linear MCP `save_milestone` returns `{id, name, description, progress, sortOrder, targetDate}` — no `url`. Spec at 8a.5 says "Capture the returned `id` + `url`" and later uses `<milestone-url>` as a slot. Without a returned URL, the orchestrator has to construct one.

**Root-cause**: Linear's milestone URL isn't a clean `/milestone/{id}` shape — it's typically reached via `/project/{slug}` with a fragment or query param to focus a milestone. The MCP doesn't expose either.

**Proposed fix**: hot-patch. Update spec to either:
1. Use the project URL as the milestone "URL" (operator clicks through to the milestone from there) — applied in this PR's manifest write.
2. Construct a Linear deep-link if a stable format can be confirmed (e.g. `https://linear.app/<org>/project/<slug>?selectedMilestone=<id>` — needs verification).

Going with option 1 in this PR; document option 2 verification as a follow-up.

---

### F9 — Linear prosemirror auto-links bare `BC-NNNN` in descriptions [informational]

**When**: 2026-05-19T21:03Z, Step 8a + Step 9

**Friction**: Milestone + issue descriptions written with bare `BC-8727`, `BC-5825`, `BC-8752`, `BC-2719` got auto-converted by Linear's prosemirror to `<issue id="UUID">BC-NNNN</issue>` magic-tags. Different mechanism than `[BC-8727](url)` markdown links.

**Root-cause**: Linear's own issue-reference auto-linker. Distinct from GitHub's Magic Issue ID auto-close (which fires on PR title / branch name / squash commit body). Linear's auto-link is internal-only.

**Proposed fix**: no-op — this is correct + useful Linear behavior. Document in `gotcha_linear_pr_title_magic_id_auto_close.md` memory that Linear's internal prosemirror auto-linker is SAFE (does not propagate to GitHub auto-close); only bare `BC-NNNN` in GitHub-side artifacts (PR title / branch / body / squash commit) triggers the auto-close.

**Disposition**: docs-only — note added to gotcha memory in this PR.

---

### F10 — `list_issue_labels` exposes `name:` filter but spec doesn't use it [annoyance]

**When**: 2026-05-19T21:04Z, Step 8a.6

**Friction**: Per the MCP-tool schema, `list_issue_labels` accepts `name: "<filter>"`. The plan-campaign.md spec at 8a.6 acknowledges this possibility ("If the Linear MCP exposes a prefix filter, prefer that") but the actual logic uses unfiltered enumeration. At 200 campaigns × 8 labels per = 1,600 labels, the dump cost is real.

**Root-cause**: Spec authored as a best-guess fallback; never updated to use the filter that exists.

**Proposed fix**: hot-patch. Update Step 8a.6 to use `list_issue_labels(team=..., name="<each-label>")` per label — 8 lookups instead of 1 dump. Each call returns either `[]` (label missing → create) or one match (label exists → skip).

---

### F11 — `--target-org` default mismatch between SF MCP config + `/revops:create-sf-campaign` spec [annoyance]

**When**: 2026-05-19T21:05Z, Step 8b (sibling)

**Friction**: SF MCP `get_username(defaultTargetOrg=true)` returns the alias from `~/.sf/config.json`: in this env, `marketing-claude-prod`. The `/revops:create-sf-campaign` spec defaults `--target-org` to `brite-prod`. Two different SF orgs are implied; the operator has no clear signal which to use unless they pass `--target-org` explicitly.

**Root-cause**: Spec authored against a clean assumption (`brite-prod` is the prod org); actual dev env uses a different alias.

**Proposed fix**: docs-only. Update `/revops:create-sf-campaign` spec to clarify:
- Default is `brite-prod` (the SF prod-org canonical alias).
- If the caller wants the SF MCP's `~/.sf/config.json` default, pass `--target-org` from `mcp__plugin_revops_salesforce__get_username(defaultTargetOrg=true).value`.
- Document the gotcha that aliases ≠ usernames; literal username required for `run_soql_query`.

---

### F12 — SF JWT auth refresh failing across env [annoyance]

**When**: 2026-05-19T21:06Z, Step 8b (operational)

**Friction**: `sf org display --target-org marketing-claude-prod --json` returned `connectedStatus: "Unable to refresh session due to: Error authenticating with JWT. Errors encountered: invalid assertion (×3)"`. Every σ3 call would soft-fail. The σ3 soft-fail contract handled it correctly (campaign_id stays null, WARN line), but operationally someone needs to re-auth SF.

**Root-cause**: JWT cert / key issue. Outside BC-8727 scope; surfaced by the dogfood.

**Proposed fix**: upstream-BC. File a new BC for "SF JWT refresh failure across plugin MCP" — block: at-least-one Brite operator must successfully re-auth SF before σ3 lands real data. Not a BC-8727 blocker (soft-fail works).

---

### F13 — `/revops:create-sf-campaign` Phases 2 + 3 lack explicit SOQL-error branches [annoyance]

**When**: 2026-05-19T21:06Z, Step 8b (sibling)

**Friction**: The sibling spec describes success paths for Phase 2 (idempotency precheck SOQL) + Phase 3 (owner lookup SOQL) but doesn't enumerate what happens if the SOQL call itself fails (auth, network, permset). The error catalog only documents Phase 5 `sf_cli_error`. In BC-8727 dogfood, Phase 2's auth-fail effectively was an `sf_cli_error` but the spec doesn't say that explicitly.

**Root-cause**: Spec authored assuming SOQL calls succeed; only Phase 5 has explicit error handling.

**Proposed fix**: hot-patch sibling. Update `/revops:create-sf-campaign` spec:
- Phase 2 SOQL error → emit `{"error":"sf_cli_error","phase":"idempotency_precheck","detail":"<message>"}` and exit 0.
- Phase 3 SOQL error → emit `{"error":"sf_cli_error","phase":"owner_lookup","detail":"<message>"}` and exit 0.
- Update error catalog to list `sf_cli_error` with optional `phase` field.

---

### F14 — `/revops:create-sf-campaign --dry-run` still requires live SF auth [minor]

**When**: 2026-05-19T21:06Z

**Friction**: --dry-run skips Phase 5 (the actual sf data create record), but Phases 2 + 3 still hit live SF for idempotency precheck + owner lookup. Cannot validate the orchestrator flow offline.

**Root-cause**: --dry-run was added to skip the only mutating step (Phase 5), but the prerequisite reads weren't gated.

**Proposed fix**: V3-defer. Add an offline-dry-run mode (`--offline-dry-run`?) that synthesizes the preview JSON with placeholder values for `<owner-id>` and assumes no existing campaign. Useful for orchestrator-side integration tests.

---

### F15 — `save_issue` partial update with just `blockedBy` is SAFE [informational]

**When**: 2026-05-19T21:08Z, Step 9 second pass

**Friction observed**: Spec at Step 9 worries "If the MCP rejects the minimal partial update, file a follow-up". Dogfood validation: 9× `save_issue(id=BC-NNNNN, blockedBy=[...])` calls each succeeded with full response shape (labels, descriptions, parentId, projectMilestone all preserved). The spec's worry was unfounded.

**Root-cause**: Linear MCP `save_issue` uses partial-update semantics on `id`-supplied calls.

**Proposed fix**: hot-patch. Update spec to confirm "DOGFOOD-VERIFIED: minimal partial update is safe at this MCP version (2026-05-19, BC-8727)". Keep the two-pass approach for robustness, OR collapse to single-pass IF `blockedBy` accepts forward-references to not-yet-created IDs (untested; likely not).

---

### F16 — Manifest schema has no `linear.sub_issues[]` field [annoyance]

**When**: 2026-05-19T21:08Z, Step 7 schema

**Friction**: Manifest captures `linear.milestone_id` but not the 11 issue IDs produced at scaffold (1 container BC-10636 + 8 standard sub-issues BC-10637..BC-10644 + 2 optional Labs/Creative-Angles BC-10645..BC-10646). Downstream consumers (campaign-debrief, portfolio-snapshot, σ3 status-sync trigger) cannot walk manifest → issues programmatically; they have to re-query Linear with the milestone-id.

**Root-cause**: Schema v1 prioritized cross-layer identity (Linear milestone ↔ SF Campaign ↔ EB workspace) but not sub-issue traversal.

**Proposed fix**: V3-defer. schema_version 2 — add `linear.container_id` + `linear.sub_issues: [{title, id, role}]` array. Each entry maps a sub-issue back to its role (#1 brief / #2 list / ...). Decide at v2 design time whether the container row lives inside sub_issues[] with a `role: "container"` marker OR sits at its own top-level key. Backward-compatible reader = "use sub_issues[] if present, fall back to milestone re-query otherwise". Migration: no rewrites needed; new campaigns get v2 manifests.

---

### F17 — Spec wording `blockedById` is typo for `blockedBy` [minor]

**When**: 2026-05-19T21:08Z, Step 9

**Friction**: Spec at Step 9 says "Linear MCP `save_issue` shape for the second pass is **MINIMAL** — `save_issue(id=<sub-issue-id>, blockedById=<id>)` ONLY." The actual MCP field is `blockedBy: <array of issue IDs>`, plural. Typo creates confusion when the operator tries to look up the field in the schema.

**Root-cause**: Spec drift from the underlying MCP shape.

**Proposed fix**: hot-patch. Spec edit: `blockedById` → `blockedBy` (singular → plural array). Touches multiple paragraphs in Step 9.

---

### F18 — 21+ MCP round-trips per scaffold is the heaviest surface [annoyance]

**When**: 2026-05-19T21:08Z, Step 9 total

**Friction**: Plan-campaign produces (Step 9.0) 1 container issue + (Step 9.1) 8 standard sub-issues + (Step 10) up to 2 optional = 11 issue creates (Pass 1) + 9 blockedBy updates (Pass 2) = 20 issue-related round-trips when both `--situation-mining` + `--creative-angles` are enabled. Add Step 8a.6 label pre-check (8 filtered list + up to 8 creates = 16 worst-case, post-F10 hot-patch) + Step 3.3 project + milestone-collision (2) + Step 8a.5 milestone create (1) + Step 8b SF reads (3 — get_username, idempotency, owner) + Step 7 manifest write (1) ≈ ~43 total MCP/Bash calls per scaffold. Slow + latency-prone.

**Root-cause**: Linear's MCP shape is per-issue; no batch-create endpoint.

**Proposed fix**: V3-defer. Track total scaffold-time observed. If > 30s consistently, file upstream Linear MCP feature request for `save_issues_batch` (array of issue payloads, single round-trip).

---

## Summary

**Total entries**: 18 (target ≥7, AC ≥5 — comfortably over).

**Disposition tallies**:
- hot-patch in this PR: F1 (canonicals + spec error-msg), F2 (docs note), F3 (empty-array render), F5 (spec call signature), F7 (spec recommend inline fallback), F8 (spec URL construction), F10 (spec name: filter), F15 (spec confirm safe), F17 (spec typo fix) — 9 hot-patches
- docs-only / informational: F9 (memory note), F11 (sibling spec clarify), F13 (sibling spec extend)
- V3-defer (BC-8729 review): F4 (batch validation), F6 (linear-MCP feature req), F14 (offline dry-run), F16 (schema v2), F18 (batch-create MCP)
- upstream-BC: F12 (SF re-auth)

**Hot-patches applied in this PR**: 9 — see commits per the PR description.
