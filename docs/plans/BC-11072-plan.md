# BC-11072 plan — re-POST atomic-422 framing correction across 8 sites

**Issue:** [BC-11072](https://linear.app/brite-nites/issue/BC-11072) — Backlog → in progress
**Branch:** `corinne/bc-11072-launch-campaign-md-454-prose-contradicts-atomic-422`
**Worktree:** `../brite-claude-plugins-bc-11072` (already set up)
**Shape:** TRIVIAL doc-only — 6 files, 8 site edits. 6th application of the BC-6298 plan-gate scope-expansion pattern (BC-6298/6544/6548/6782/7597 → BC-11072).

## Plain-language gist

Our docs in 8 different places currently teach that Email Bison's bulk-create-leads endpoint "upserts" existing leads when you re-POST them (i.e., quietly updates them in place). That's wrong — verified live, twice in the dogfood chain and once more in this plan's verification spike. EB actually rejects any batch containing an already-existing-lead email with HTTP 422 and creates nothing. This issue replaces the wrong prose with the correct behavior at all 8 sites. Behavior-only, no recovery prescription (no clean recovery path exists in EB's API; that's the caller's problem to solve).

## Live verification (BC-11072 spike, 2026-05-22)

| Test | Setup | Result |
|------|-------|--------|
| Mixed batch (1 existing + 1 brand-new email) | Lead id 15154 (`bc11072-anchor-test@dogfoodtest.com`) created via `create_lead`; then `POST /api/leads/multiple` with that email + `bc11072-newbie-mixed@dogfoodtest.com` | HTTP 422 atomic; new email confirmed absent from workspace via `search: "bc11072-newbie"` returning 0 leads |
| Cleanup | `DELETE /api/leads/15154` | Queued; "Lead deletion process started" |

Adds two prior verifications (BC-6785 round-5 R-6 — 1-row case; BC-7667 round-6 R-6 scenario B — 1-row case) to a triplet of live evidence for the atomic-422 claim. Variant-endpoint absence already triple-checked at BC-6785 R-28.

Side-finding (NOT in BC-11072 scope): EB's `list_leads ?search=` filter degrades to "no filter, return all leads" when the search term contains `@` and matches nothing — observed when searching for `bc11072-newbie-mixed@dogfoodtest.com` returned 8,491 leads (full workspace). The non-`@` variant `bc11072-newbie` returned 0 cleanly. Tracking note for a separate ticket; outside this issue.

## Canonical AFTER snippets

**For fuller-prose sites (Site 1, Site 2):**
> "There is no separate `upsert_multiple_leads` endpoint, AND `/api/leads/multiple` does NOT upsert existing leads — re-POSTing a batch with any already-existing-lead email returns HTTP 422 and rejects the whole batch (Sx-8 atomic rule). Verified BC-6785 round-5 R-6 + BC-7667 round-6 R-6 + BC-11072 spike (mixed batch, 2026-05-22). No `upsert_multiple_leads` variant endpoint exists (BC-6785 R-28)."

**For terse table/bullet sites (Sites 4–8):**
> "Re-POSTing a batch with any already-existing-lead email returns HTTP 422 atomic rejection (Sx-8); no upsert behavior. No `upsert_multiple_leads` endpoint exists (BC-6785 R-28)."

**For the Sx-8 disambiguation (Site 3 — `email-bison.md:276`):**
- Replace `"duplicate email"` in the parenthetical examples with `"email matching an already-existing lead in the workspace"`
- Add a closing parenthetical pointer to the BC-11071 within-chunk bullet that sits at line 277 immediately below.

## Tasks

### T1 — Fix Site 1: `plugins/marketing/commands/launch-campaign.md:454`

Replace the `"server upserts in place by email match; verified BC-6785 round-5 R-28 — POST /api/leads/upsert-multiple → 405, PUT → 422..."` clause with the fuller-prose AFTER snippet above. Preserve surrounding sentences.

**Verification before edit:** `grep -n "upserts in place" plugins/marketing/commands/launch-campaign.md` returns one line — confirm line number is still ~454.

### T2 — Fix Site 2: `plugins/marketing/tools/integrations/email-bison.md:212`

Replace the `"server upserts in place by email match — no separate upsert_multiple_leads endpoint; verified BC-6785 round-5 R-28"` clause in the row-1 "What it does" cell with the **terse** AFTER snippet (table cell, not prose paragraph).

This is the site I deferred from BC-11071 last session per operator approval.

### T3 — Tighten Site 3: `email-bison.md:276` Sx-8 bullet

Disambiguate the existing "duplicate email" wording — it's ambiguous now that the BC-11071 within-chunk bullet at line 277 covers the within-chunk-dup case. Replace:
- `"A single bad row (duplicate email, invalid format)"` → `"A single bad row (email matching an already-existing lead in the workspace, invalid format)"`
- Add closing parenthetical: `"(Distinct from the within-chunk-duplicate case in the next bullet: same email twice in one chunk → silent dedup, not 422.)"`

### T4 — Fix Site 4: `plugins/marketing/skills/email-bison/SKILL.md:73`

Replace `"re-POSTs that act as upserts share the cap (no separate `upsert_multiple_leads` endpoint — verified BC-6785 round-5 R-28)"` with: `"re-POSTs with any already-existing-lead email return HTTP 422 atomic rejection (Sx-8) — no upsert behavior; no separate `upsert_multiple_leads` endpoint exists (BC-6785 round-5 R-28)"`.

### T5 — Fix Site 5: `plugins/marketing/skills/campaign-orchestration/SKILL.md:64`

Table cell in the "Create lead records before the campaign exists" row. Replace `"re-POST `bulk_create_leads` to upsert — no separate `upsert_multiple_leads` endpoint, BC-6785 R-28"` with the terse AFTER snippet.

### T6 — Fix Site 6: `plugins/marketing/skills/campaign-orchestration/SKILL.md:83`

Replace `"re-POSTs that act as upserts share the cap (no separate `upsert_multiple_leads` endpoint — BC-6785 R-28)"` — parallel rewording to T4.

### T7 — Fix Site 7: `plugins/marketing/skills/campaign-orchestration/SKILL.md:144`

Replace `"To merge against existing leads, re-POST `bulk_create_leads` — there is no separate `upsert_multiple_leads` endpoint (BC-6785 R-28)"` with terse AFTER snippet.

### T8 — Fix Site 8: `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md:183`

Replace `"To merge against existing leads, re-POST `bulk_create_leads` (no separate `upsert_multiple_leads` endpoint)"` with terse AFTER snippet.

### T9 — Validate

- `./scripts/validate.sh` exit 0 from worktree root
- `git diff --stat` confirms exactly 5 files changed (launch-campaign.md, email-bison.md, email-bison/SKILL.md, campaign-orchestration/SKILL.md, OUTBOUND-SKILL-TEMPLATE.md) — note: 8 site edits land in 5 distinct files (campaign-orchestration/SKILL.md has 3 sites)
- `grep -rE 'upserts? in place|merge against existing|act as upserts|to upsert' plugins/marketing/` returns 0 hits in non-precedent/non-plan/non-dogfood paths

### T10 — Acceptance criteria check

From issue body:
- [ ] Rewrite the prose at line 454 to reflect: "There is no separate `upsert_multiple_leads` endpoint AND `/api/leads/multiple` does NOT upsert existing leads — re-POST returns HTTP 422 (Sx-8 all-or-nothing). Verified BC-6785 round-5 R-6 + BC-7667 round-6 R-6." → T1 (+BC-11072 spike attribution added)
- [ ] Cross-ref Sx-8 + the existing atomic-422 gotcha at `email-bison.md:276` → T1, T2, T4, T5, T6, T7, T8 all cross-ref Sx-8 in their AFTER text; T3 tightens Sx-8 itself
- [ ] `./scripts/validate.sh` exits 0 → T9
- [ ] No behavior change — pure prose correction → by construction (markdown-only)

## Non-tasks (explicitly out of scope)

- **EB `list_leads ?search=` degradation gotcha** (search with `@` returns all leads on no-match) → file separately if it matters; tracking note only here.
- **Recovery-path prescription** in any of the 8 sites — operator-confirmed: document the behavior, don't prescribe a workaround (no clean one exists).
- **`email-bison.md:293` Case-rule asymmetry table prose** — confirmed accurate during grep; the variant-endpoint absence claim there is correctly scoped (R-28 evidence about variant endpoints, no "upsert in place" claim).
- **BC-11073** (test-copy-liquid.json strip-hyphens) — separate sibling follow-up.

## Plugin version bump

**Not required.** Paths touched:
- `plugins/marketing/commands/launch-campaign.md` — inside `commands/` → **WOULD** trigger version bump per CLAUDE.md
- `plugins/marketing/tools/integrations/email-bison.md` — under `tools/` → no bump
- `plugins/marketing/skills/email-bison/SKILL.md` — inside `skills/` → **WOULD** trigger version bump per CLAUDE.md
- `plugins/marketing/skills/campaign-orchestration/SKILL.md` — inside `skills/` → **WOULD** trigger version bump
- `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — `_template/` is a doc template, not an active skill — needs to be re-checked at execution time whether the gotcha rule treats `_template/` paths as skill edits

**Conclusion:** This DOES touch `commands/` and `skills/` (not just `tools/`), so per CLAUDE.md "Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`" — **marketing plugin version bump IS required this PR**. Bump `plugins/marketing/.claude-plugin/plugin.json` patch version + the matching `.claude-plugin/marketplace.json` entry.

Add as T11 (version bump) before committing.

### T11 — Bump marketing plugin version

- `plugins/marketing/.claude-plugin/plugin.json` patch bump (current is `0.3.43` per recent merges; bump to `0.3.44`)
- `.claude-plugin/marketplace.json` matching entry update
- Commit alongside the prose changes in the same commit (per CLAUDE.md "SAME commit" rule)

## Risks

- **Line drift between plan-time and exec-time:** the file may have grown between sessions. Per-task grep anchors before each edit.
- **Sx-8 disambiguation wording in T3 IS load-bearing prose** — must not break the adjacent BC-11071 within-chunk bullet at line 277. Read both bullets together post-edit to confirm the contrast lands cleanly.

## Estimated effort

30–45 minutes. 8 site edits + version bump + validate + grep-check + commit + PR.
