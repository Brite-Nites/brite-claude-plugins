# BC-6780 — Fix case-asymmetry at lead-create binding (Phase 4 step 2 + email-bison.md gotcha)

**Linear:** [BC-6780](https://linear.app/brite-nites/issue/BC-6780/bc-6554-follow-up-fix-case-asymmetry-at-lead-create-binding-phase-4)
**Branch:** `corinne/bc-6780-bc-6554-follow-up-fix-case-asymmetry-at-lead-create-binding`
**Blocks:** BC-6785 (round-5 launch-campaign dogfood)
**Approach (per sequential-thinking, this session):** Option A — agent translates at body-build time, spec names the rule explicitly, hard-fail guard mirrors the sibling BC-6548 rule shape. Authors keep UPPERCASE-everywhere mental model in artifacts; vendor-API quirk lives at the API boundary where it applies.

## Plain-language gist

When our automation uploads leads to Email Bison, each lead carries custom-variable names. EB requires those names lowercase at this one endpoint, or it 422s the whole batch. We've been authoring UPPERCASE everywhere (and it's the right convention for body tokens — that's a load-bearing rule). The fix: agent flips CAPS → lowercase right before it sends, with a named step and a guard so the rule stays visible. We also correct an existing reference-doc bullet that contradicts this finding.

## Reconciliation table (issue body vs ground truth)

| # | Issue claim | Ground truth (this session) | Action |
|---|---|---|---|
| 1 | "spec defect at Phase 4 step 2 example body shape" | Verified: `launch-campaign.md:462-466` shows UPPERCASE in lead-create body | Fix per task 1 |
| 2 | Three rules at three endpoints (issue context table) | Verified — confirmed in `email-bison.md:281` (wrongly claims uppercase round-trips) and BC-6299/BC-6548 precedents | Consolidate into one new gotcha (task 5) AND correct line 281 |
| 3 | "Consider whether agent should auto-lowercase…tradeoff: silent translation could mask future EB behavior changes" | Resolved this session via sequential-thinking → **Option A** (agent translates, named step, hard-fail guard, not silent) | Implement per tasks 1-3 |
| 4 | Spec defect scope = Phase 4 step 2 only | Phase 4 step 4 sample render (line 489) also shows UPPERCASE — operator-facing, but visual mismatch with body | Fix in scope (task 4) for internal consistency, per BC-6544 plan-gate scope-expansion pattern (12+ instances) |
| 5 | Sibling endpoints (upsert_multiple_leads, /api/leads/bulk CSV variant) | Unverified this session; rule confirmed only on `/api/leads/multiple` | Defer-with-guardrail (BC-6299 task-2): lock spot-check into BC-6785 verification matrix via Linear comment (task 7) |

## Precedents applied

- **BC-6548** — UPPERCASE-only token render rule enforced via Phase 1 step 5 HARD FAIL with clear error message. Same shape applied at Phase 4 step 2 for the lead-bind rule (inverse case, same enforcement structure).
- **BC-6544 (12+ instances)** — plan-gate scope-expansion when issue-enumerated sites are a strict subset of grep-discoverable matches. Phase 4 step 4 sample (line 489) added in scope.
- **BC-6299 task-2 / BC-6515** — defer-with-guardrail when API behavior is unverified at sibling surfaces; lock spot-check into next downstream issue's verification matrix (BC-6785 round-5).
- **BC-6300 task-2** — plan file co-locates with worktree (rides PR), not main repo. Write to main for approval, copy to worktree at creation, delete main copy.
- **BC-6000 task-1** — change touches `plugins/marketing/{commands,tools}/...` ⇒ plugin.json + marketplace.json version bump in same commit.

---

## Tasks

### Task 1 — Update Phase 4 step 2 example body to lowercase + inline comment

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** 462-466 (the JSON example body)
**Time:** 3 min

**Current:**
```json
"custom_variables": [
  {"name": "RECENCY_ANCHOR", "value": "<row-specific value>"},
  {"name": "PROOF_POINT_COMPANY", "value": "<row-specific value>"},
  {"name": "COMPANY_DOMAIN", "value": "<csv company_domain>"}
]
```

**Target:**
```json
"custom_variables": [
  // Names lowercased here — EB's POST /api/leads/multiple rejects (422) UPPERCASE names (BC-6780).
  // Artifact uses UPPERCASE everywhere; agent translates at this boundary only.
  {"name": "recency_anchor", "value": "<row-specific value>"},
  {"name": "proof_point_company", "value": "<row-specific value>"},
  {"name": "company_domain", "value": "<csv company_domain>"}
]
```

**Verification:** `grep -nE '"name":\s*"[A-Z_]+"' plugins/marketing/commands/launch-campaign.md` returns no matches in the Phase 4 step 2 region (lines 450-510).

---

### Task 2 — Add labeled translation sub-step to Phase 4 step 2

**File:** `plugins/marketing/commands/launch-campaign.md`
**Insert after:** line 483 ("The per-row custom_variables values come from CSV columns…")
**Time:** 4 min

**New sub-step text (insert as continuation of step 2, before step 3 chunking):**

> **Lowercase names before send.** EB's `POST /api/leads/multiple` requires `custom_variables[].name` to be exact-lowercase — UPPERCASE names return HTTP 422 and reject the whole chunk (verified BC-6554 round-4 S-4; precedent BC-6780). Convert each name to lowercase as the final step of body construction. Authors keep UPPERCASE everywhere in the copy artifact (BC-6548 token-render rule); the translation happens here only, at the API boundary. Do not lowercase the artifact itself — only the per-call body.
>
> Note (BC-6299): EB silently lowercases names at variable creation (Phase 3), so the lowercased per-lead `name` matches the EB-side stored form. Render-engine token lookup is case-insensitive against that lowercased store (BC-6308 round-3 R-2a). The ONLY endpoint with a strict lowercase requirement is `POST /api/leads/multiple` lead-create binding.

**Verification:** `grep -nE 'BC-6780|Lowercase names before send' plugins/marketing/commands/launch-campaign.md` returns at least one match in the Phase 4 region.

---

### Task 3 — Add HARD-FAIL guard before per-chunk POST

**File:** `plugins/marketing/commands/launch-campaign.md`
**Insert in:** step 6a (per-chunk loop), before "First vendor call"
**Time:** 4 min

**New guard text (immediately above step 6a's "First vendor call"):**

> **Pre-send guard (BC-6780).** Before issuing the chunk's POST, assert that every `custom_variables[].name` in the constructed body matches `^[a-z][a-z0-9_]*$` — no uppercase characters anywhere. **HARD FAIL** if the assertion fails. Error message: "Chunk {i} body contains UPPERCASE custom_variables[].name `{name}` — EB's POST /api/leads/multiple requires lowercase or returns HTTP 422 (BC-6780). Agent translation step (Phase 4 step 2 'Lowercase names before send') was skipped or incomplete." Halt the entire run; chunks already committed stay; operator inspects the body construction and re-runs.
>
> This guard mirrors the BC-6548 Phase 1 step 5 token-UPPERCASE check (inverse case, same enforcement shape). Its role is to catch translation-step regressions before they hit EB and 422 the chunk.

**Verification:** `grep -nE 'Pre-send guard \(BC-6780\)' plugins/marketing/commands/launch-campaign.md` returns one match in the Phase 4 region.

---

### Task 4 — Lowercase Phase 4 step 4 sample render for visual consistency

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** ~489 (the sample render shown to operator at gate 4)
**Time:** 2 min

**Current:**
> 1. email: `alex@denvergov.org`, first_name: `Alex`, custom_variables: [RECENCY_ANCHOR: "the Denver downtown master plan announcement last month"]

**Target:**
> 1. email: `alex@denvergov.org`, first_name: `Alex`, custom_variables: [recency_anchor: "the Denver downtown master plan announcement last month"]

**Rationale:** The operator inspects this sample at gate 4 and expects it to reflect what gets sent on the wire. Showing UPPERCASE here when the actual body is lowercase creates a visual mismatch that could mask body-construction bugs. Per the BC-6544 plan-gate scope-expansion pattern (now 12+ instances), include this site even though the issue body enumerates only the step 2 example.

**Verification:** `grep -nE '\[RECENCY_ANCHOR:|\[PROOF_POINT_COMPANY:' plugins/marketing/commands/launch-campaign.md` returns no matches.

---

### Task 5 — Correct email-bison.md line 281 + add consolidated case-asymmetry gotcha

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Time:** 5 min

**5a — Correct line 281.** Current line ends with: "verified Phase 4 round-2 — uppercase per-lead names round-trip but match against EB's lowercase store". This claim is **wrong** per BC-6554 round-4 S-4 (UPPERCASE → 422). Rewrite the inaccurate clause to:

> verified BC-6554 round-4 S-4 — UPPERCASE per-lead `custom_variables[].name` returns HTTP 422 at `POST /api/leads/multiple` (the lead-create-bind endpoint). The `/marketing:launch-campaign` Phase 4 step 2 lowercases automatically; manual API users must do the same.

The rest of the bullet (about lowercase store) is correct and stays.

**5b — Add new consolidated gotcha after line 282** (which covers BC-6548 token-render UPPERCASE-only):

> - **Case-rule asymmetry: three endpoints, three rules.** The same `custom_variables[].name` field follows three different case rules at three different points in the EB workflow. Cross-reference table:
>
>   | Endpoint / surface | Rule | Source |
>   |---|---|---|
>   | `POST /api/custom-variables` (Phase 3 — variable creation) | EB silently lowercases on store. Sending UPPERCASE → stored lowercase. No error. | BC-6299 (Sx-3) |
>   | Render-engine token lookup (`{TOKEN}` in subject/body) | Case-insensitive against the lowercased store, BUT the `{TOKEN}` MUST be UPPERCASE in the body — lowercase tokens render as literal text (no resolution). | BC-6548 / BC-6308 round-3 R-2a |
>   | `POST /api/leads/multiple` `custom_variables[].name` (Phase 4 — lead-bind) | **Strict exact lowercase required.** UPPERCASE → HTTP 422; whole chunk rejects. | BC-6780 (this entry) |
>
>   The asymmetry is not documented anywhere in EB's external API spec. Inconsistent case-handling is a recurring class for EB; treat any new endpoint touching custom-variable names as untrusted-case until verified live. Verified specifically on `POST /api/leads/multiple`; sibling endpoints (`upsert_multiple_leads`, `/api/leads/bulk` CSV variant) unverified — see BC-6785 round-5 verification matrix.

**Verification:** `grep -nE 'Case-rule asymmetry|BC-6780' plugins/marketing/tools/integrations/email-bison.md` returns ≥2 matches.

---

### Task 6 — Bump plugin + marketplace versions

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json` — bump `version` (current minor → +0.0.1 patch; spec-correctness fix, not new capability)
- `.claude-plugin/marketplace.json` — bump matching `marketing` entry's `version`

**Time:** 2 min

**Verification:** `grep -E '"version":' plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json` shows the same new version on both sides.

---

### Task 7 — Linear update: lock sibling-endpoint spot-check into BC-6785 round-5

**Tool:** `mcp__linear__save_comment` on BC-6785
**Time:** 2 min

**Comment body:**

> BC-6780 ships with the case-asymmetry rule verified specifically on `POST /api/leads/multiple` (lead-create binding). Sibling endpoints unverified this session:
> - `upsert_multiple_leads` (variant of `/api/leads/multiple`)
> - `bulk_create_leads_csv` → `POST /api/leads/bulk` (CSV-upload variant)
>
> Round-5 verification matrix should add an S-row probing each sibling endpoint with one UPPERCASE custom_variables[].name to confirm whether (a) same 422 rule applies, (b) silent lowercasing applies, or (c) different behavior. Defer-with-guardrail per BC-6299 task-2 — the rule shipped fail-closed for the verified endpoint; siblings stay unhardened until round-5 verifies.

**Verification:** Comment visible on BC-6785 in Linear after save.

---

## Out of scope

- **Live verification of the lowercase rule via fresh API call.** Already verified live during BC-6554 round-4 S-4 (UPPERCASE → 422; lowercase → 200). No fresh probe needed.
- **Sibling-endpoint verification** (`upsert_multiple_leads`, `/api/leads/bulk`). Deferred to BC-6785 round-5 per task 7.
- **Removing line 281's "match against EB's lowercase store" clause.** That part is still correct (BC-6299) and load-bearing for the render-engine lookup story. Only the inaccurate "uppercase round-trip" clause changes.
- **Changes to email-copywriting skill.** Author convention stays UPPERCASE-everywhere per BC-6548. No artifact-side changes.
- **Wrapper-path implementation** (a Brite-side `bulk_create_leads` MCP wrapper that auto-translates). BC-6439 confirmed no wrapper exists for these endpoints, and adding one is a much larger investment for marginal benefit.

## Verification (full plan)

1. `grep -nE '"name":\s*"[A-Z_]+"' plugins/marketing/commands/launch-campaign.md` — zero matches in Phase 4 step 2 region.
2. `grep -nE 'BC-6780' plugins/marketing/commands/launch-campaign.md` — at least 3 matches (translation sub-step, pre-send guard, optional inline example comment).
3. `grep -nE 'Case-rule asymmetry|BC-6780' plugins/marketing/tools/integrations/email-bison.md` — ≥2 matches.
4. `grep -nE 'uppercase per-lead names round-trip' plugins/marketing/tools/integrations/email-bison.md` — zero matches (the inaccurate clause is gone).
5. plugin.json + marketplace.json `marketing` entry show same new version.
6. BC-6785 has a new comment from this session locking sibling-endpoint spot-check into the round-5 matrix.

## Risk + decision log

- **Risk: agent skips translation step.** Mitigation: hard-fail guard at task 3 catches body-construction regressions before send.
- **Risk: future EB behavior change at lead-bind endpoint.** Mitigation: rule is named at the boundary with a precedent cite — single edit-target if behavior shifts. Silent translation would have hidden the divergence.
- **Decision: keep UPPERCASE in copy artifact.** Per session brainstorm, splitting the case convention by field would leak vendor-API quirks into authoring with no benefit. Authors stay clean; quirk lives at the API boundary.
- **Decision: hard-fail guard NOT optional.** Without it, the named translation step is just prose; the guard makes the rule executable.
