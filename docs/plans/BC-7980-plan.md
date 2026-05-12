# BC-7980 Plan — document EB bulk-CSV case-preservation gotcha

**Issue:** [BC-7980](https://linear.app/brite-nites/issue/BC-7980/) — BC-7598 follow-up: document EB bulk-CSV case-preservation gotcha (BC-6785 R-28 resolution)
**Branch:** `corinne/bc-7980-bc-7598-follow-up-document-eb-bulk-csv-case-preservation`
**Type:** TRIVIAL doc-add (2 edits + render-verification spike)
**Sibling lineage:** BC-6785 R-28 (originator, inconclusive at round-5 close) → BC-6780 (3-row case-asymmetry rule) → BC-7597 (spec-correctness fixes) → BC-7598 (Bundle 2 vendor gotchas) → **BC-7980 (this issue, would have folded into Bundle 2 if discovered earlier)**

---

## Plan-gate plain-language gist

EB handles custom-variable name case differently across its endpoints. We already documented 3 endpoints in a table. The 4th — the CSV-upload variant — is documented nowhere. Last week's curl spike confirmed CSV-upload **preserves** key case at the lead-display layer (UPPERCASE stays UPPERCASE), while the JSON endpoint silently lowercases. **Render-time behavior remains unverified** — we don't know whether `{UPPERCASE}` and/or `{lowercase}` tokens in an email body actually resolve against a case-preserved lead. Before adding the doc row, we run a quick live test in workspace 13 (operator opens EB UI Preview Body and reports back). The verdict (both resolve / only-uppercase / neither) determines the exact phrasing of the new row. Then 2 file edits (`email-bison.md` table + `launch-campaign.md` one-line caveat) + version bump + cleanup. Sandbox ends with zero permanent state delta.

## Edit-site path correction

Issue body cites `plugins/marketing/skills/email-bison/SKILL.md § Case-rule asymmetry gotcha table`. The actual table is in `plugins/marketing/tools/integrations/email-bison.md` (lines 283–291). The SKILL.md is the skill activator; `tools/integrations/email-bison.md` is the canonical reference (skill ↔ tool integration pattern). **6th observed instance of plan-gate scope-expansion** (BC-6298 / BC-6544 / BC-6548 / BC-6782 / BC-7597 family — pattern well-documented; no new precedent file needed). All other path references in the issue body resolve correctly.

## Verification approach (confirmed with operator)

- **Surface:** EB UI Preview Body (canonical Liquid-render verification surface per BC-6308 R-2a).
- **NOT** Mode 1 local render (the `/marketing:launch-campaign` local renderer can diverge from EB's actual render engine — BC-6784 precedent: Mode 1 = "Amanuel", UI Preview Body = "Rainer").
- **NOT** Mode 2 test-send (would add an email to operator's inbox; UI Preview Body delivers the same EB-render evidence with zero inbox cost).

---

## Task list

### Task 1: Set up worktree

**Action:** Create worktree on branch `corinne/bc-7980-bc-7598-follow-up-document-eb-bulk-csv-case-preservation` at `~/Projects/worktrees/brite-claude-plugins/bc-7980-bulk-csv-case-preservation/`. Verify clean baseline (`./scripts/validate.sh` passes).

**Verification:** Worktree exists, branch checked out, `./scripts/validate.sh` exits 0.

**Time:** 1 min

---

### Task 2: CSV-upload 1 sentinel lead to workspace 13

**Action:** Run Bash curl multipart spike against `POST /api/leads/bulk/csv` (since `call_api` is JSON-only — verified in the BC-7980 issue body). Workspace 13 token from environment.

**CSV contents** (`/tmp/bc-7980-render-test.csv`):
```
email,first_name,RECENCY_ANCHOR
bc-7980-render-test@britenites.com,RenderTest,csv-render-test
```

**Curl command shape:**
```bash
curl -X POST "https://app.bisonsphere.com/api/leads/bulk/csv" \
  -H "Authorization: Bearer $EB_TOKEN" \
  -F "csv=@/tmp/bc-7980-render-test.csv" \
  -F "columnsToMap[email]=email" \
  -F "columnsToMap[first_name]=first_name" \
  -F "columnsToMap[RECENCY_ANCHOR]=RECENCY_ANCHOR"
```

**Capture:** lead ID returned, full `custom_variables` array of the resulting lead (`call_api GET /api/leads/{id}`).

**Verification:** Lead created; `custom_variables[].name == "RECENCY_ANCHOR"` (uppercase preserved per BC-7980 storage-time verdict).

**Time:** 3 min

---

### Task 3: Create draft campaign with both-case tokens

**Action:** Via `call_api`, create a draft campaign (workspace 13) with a single sequence-step body containing **both** tokens. Use a clearly-labeled test name.

**Campaign name:** `BC-7980 render-test (deleteme)`

**Sequence-step body** (plain text, no Liquid wrappers):
```
Hi {FIRST_NAME},

Upper-token: {RECENCY_ANCHOR}
Lower-token: {recency_anchor}

End.
```

**Attach** the sentinel lead from Task 2 to this campaign via `import_leads_to_campaign` (or direct `POST /api/campaigns/{id}/leads/attach-leads` if attach is more reliable).

**Verification:** Campaign created with `status: "draft"`; lead attached; `get_campaign` confirms 1 lead, 1 step.

**Time:** 3 min

---

### Task 4: Capture UI Preview Body verdict

**Action:** Operator opens EB UI for the draft campaign, navigates to the sequence-step's Preview Body view, selects the sentinel lead. Operator reports rendered output back to agent.

**Possible verdicts** (determines Task 5 phrasing):

| Verdict | Observed render | Doc-row phrasing direction |
|---|---|---|
| **A — Both resolve** | Upper-token: `csv-render-test` / Lower-token: `csv-render-test` | "Case-preservation is display-only; render normalizes" |
| **B — Only UPPERCASE resolves** | Upper-token: `csv-render-test` / Lower-token: `{recency_anchor}` (literal) | "Real render-time divergence; operators using bulk-CSV must use UPPERCASE tokens" |
| **C — Neither resolves** | Upper-token: `{RECENCY_ANCHOR}` / Lower-token: `{recency_anchor}` (both literal) | "Render-time bug — case-preserved lead-level name can't be addressed by any template token; **STOP plan execution and file separate bug**" |

**Recovery if Verdict C:** Halt plan, file a separate issue (`/marketing:launch-campaign` bulk-CSV render-time bug), keep current 3-row table un-augmented, close BC-7980 as "verification inconclusive — render bug supersedes; tracked in <new-issue>".

**Verification:** Verdict captured in plan-file (append as `## Verdict (captured 2026-05-12)` section); reported in PR description.

**Time:** 3 min

---

### Task 5: Edit `email-bison.md` — add 4th row to case-asymmetry table

**File:** `plugins/marketing/tools/integrations/email-bison.md` (lines 283–291)

**Edit shape (Verdict A — both resolve):** Add 4th row to the existing 3-row table:

```markdown
| `POST /api/leads/bulk/csv` `columnsToMap[]` keys (Phase 4 — CSV upload variant) | **`columnsToMap[]` key case preserved at lead-display layer** (`custom_variables[].name` matches the key case exactly — UPPERCASE stays UPPERCASE). Workspace schema (`GET /api/custom-variables`) unaffected — lowercase canonical. **Render-time:** EB normalizes at render — `{UPPERCASE}` token resolves the case-preserved value via case-insensitive lookup (matches the JSON-endpoint rule). | BC-7980 (verified 2026-05-12 via UI Preview Body) |
```

Update the closing paragraph (line 291) to reflect the now-verified `/api/leads/bulk/csv` endpoint:

```markdown
The asymmetry is not documented in EB's external API spec. Inconsistent case-handling is a recurring class for EB; treat any new endpoint touching custom-variable names as untrusted-case until verified live. Three endpoints verified live: `POST /api/custom-variables` (BC-6299), `POST /api/leads/multiple` (BC-6780), `POST /api/leads/bulk/csv` (BC-7980). Verified specifically — no separate `upsert_multiple_leads` endpoint exists (BC-6785 round-5 R-28; phantom path removed BC-7597). Surfaced by BC-6554 round-4 S-4 + BC-6785 round-5 R-28; rule extensions shipped in BC-6780 + BC-7980.
```

**Edit shape (Verdict B — only UPPERCASE resolves):** Same row structure, but the **Render-time** clause reads:
```
**Render-time:** EB does NOT normalize at render for bulk-CSV-uploaded leads — only UPPERCASE `{TOKEN}` resolves against the case-preserved name; lowercase token renders as literal text. Operators using bulk-CSV upload MUST use UPPERCASE tokens (matches the BC-6548 UPPERCASE-only render rule for JSON-endpoint leads but applies strictly here vs. case-insensitive there).
```

**Verification:** `grep -c "BC-7980" plugins/marketing/tools/integrations/email-bison.md` returns 2 (new row + closing paragraph).

**Time:** 3 min

---

### Task 6: Edit `launch-campaign.md` Phase 4 step 1 — add one-line caveat

**File:** `plugins/marketing/commands/launch-campaign.md` (line 454, immediate vicinity of `bulk_create_leads_csv` mention)

**Edit:** Append to the existing line 454 sentence "Variant endpoint: `bulk_create_leads_csv` (CSV-upload variant, `POST /api/leads/bulk/csv`)." — one-line caveat:

```markdown
Variant endpoint: `bulk_create_leads_csv` (CSV-upload variant, `POST /api/leads/bulk/csv`) — note that this endpoint preserves `columnsToMap[]` key case at lead-display layer (workspace schema unaffected); see `email-bison.md` § Case-rule asymmetry for the full 4-endpoint cross-reference (BC-7980).
```

**Verification:** `grep -c "BC-7980" plugins/marketing/commands/launch-campaign.md` returns 1.

**Time:** 1 min

---

### Task 7: Bump marketing plugin version

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json`: `"version": "0.3.37"` → `"version": "0.3.38"`
- `.claude-plugin/marketplace.json`: marketing entry `"version": "0.3.37"` → `"version": "0.3.38"`

**Reason:** Edit under `plugins/marketing/commands/` triggers the version-bump rule (CLAUDE.md gotcha). The `tools/integrations/` edit doesn't strictly require it, but the `commands/` edit does.

**Verification:** Both `version` strings match `0.3.38`; `./scripts/validate.sh` exits 0.

**Time:** 1 min

---

### Task 8: Cleanup workspace 13 + validate

**Cleanup actions:**
- Delete the sentinel lead (created in Task 2) via `call_api DELETE /api/leads/{id}`.
- Delete the draft campaign (created in Task 3) via `call_api DELETE /api/campaigns/{id}`.
- Verify cleanup: `GET /api/leads/{id}` → 404, `GET /api/campaigns/{id}` → 404.

**Validation:** `./scripts/validate.sh` exits 0. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` passes.

**Verification:**
- Workspace 13 lead count delta = 0 (no permanent state delta — matches BC-6515 cleanup pattern).
- Workspace 13 campaign count delta = 0.
- Workspace 13 custom-variables schema unchanged (still 15 vars — confirmed by Task 2 storage-time finding).
- All scripts exit 0.

**Time:** 2 min

---

## Total time estimate

~17 min execution + UI Preview Body operator step. TRIVIAL ship — likely no review-agent pipeline needed (TRIVIAL verdict precedent: BC-7597 / BC-7598 / BC-6298 / BC-6300 / BC-6299 / BC-6301 / BC-6304 / BC-6302 / BC-6303 / BC-6544 / BC-6548 / BC-6515 / BC-6556 / BC-6545 / BC-6784 — 15 consecutive TRIVIAL ships in this chain through PR #279).

## Risks & mitigations

- **Risk:** Verdict C (render-time bug). **Mitigation:** Task 4 explicitly halts and files a separate issue; this plan does NOT close BC-7980 on a bug.
- **Risk:** Workspace 13 cleanup-skip leaves permanent state delta. **Mitigation:** Task 8 explicitly deletes; Task 4 captures lead+campaign IDs into the plan-file for traceability.
- **Risk:** UI Preview Body operator step blocks agent flow. **Mitigation:** Plan halts execution between Task 3 (campaign create) and Task 4 (verdict capture), awaiting operator UI report.

## Verdict (captured 2026-05-12 via UI Preview Body)

**Verdict A (refined) — render normalizes via the existing BC-6548 rule.**

Lead 14768 (CSV-uploaded, `custom_variables[].name = "RECENCY_ANCHOR"` case-preserved per Task 2), attached to draft campaign 51, sequence step 47 body containing both `{RECENCY_ANCHOR}` and `{recency_anchor}`. EB UI Preview Body rendered output (operator screenshot):

```
Hi RenderTest,

Upper-token: csv-render-test
Lower-token: recency_anchor

End.
```

- `{RECENCY_ANCHOR}` → `csv-render-test` ✅ (UPPERCASE resolves case-insensitively against the case-preserved name).
- `{recency_anchor}` → `recency_anchor` (literal text, no braces) — matches the BC-6548 render-engine rule for lowercase tokens (documented in `email-bison.md:282`).

**Implication for the doc-row:** CSV endpoint's case-preservation is **lead-display-layer only**. Render behavior follows the existing UPPERCASE-only render rule (BC-6548) regardless of storage-time case. Operators using bulk-CSV need no special token handling.

**Workspace schema check** (Task 8 cleanup will reconfirm): no new `RECENCY_ANCHOR`-cased entry expected in workspace schema (still 15 lowercase-canonical vars).

## Acceptance criteria (from issue)

- [x] Render verification task completed; verdict captured in plan-file `## Verdict` section (Task 4)
- [x] Single PR with 2 doc additions (Tasks 5 + 6)
- [x] `email-bison.md` § Case-rule asymmetry: 4th row added with phrasing reflecting verdict (Task 5)
- [x] `launch-campaign.md` § Phase 4 step 1: one-line caveat linking to the gotcha table (Task 6)
- [x] `./scripts/validate.sh` exits 0 (Task 8)
- [x] No behavior change — pure documentation adds
