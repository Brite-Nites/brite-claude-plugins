# BC-5826 X17 Dogfood — Transcript

**Date:** 2026-04-20 · **Workspace:** `emailbison-personal` (id 13, BriteNites Team) · **Leads:** 6 · **Entity:** brite-labs · **Preset:** list-building / municipalities · **Offer tier:** T2 · **Activate:** OFF (draft-only)

## Outcome

**Partial pass** — Phases 1 + 2 walked live against the EB MCP. Phases 3–11 paper-walked after a critical spec gap surfaced at Phase 10 (see F13 below). Phase 10's mandatory render criterion was satisfied via the local-render fallback path.

**X17 verification criteria status:**

- Test campaign on emailbison-personal — pending (intentionally deferred; Phases 3–9 would have created workspace state we opted not to clean up)
- 5–10 leads — **6 test leads authored** in `.claude/worktrees/bc-5826/dogfood/test-leads.csv`
- Phase 10 preview must render — **PASS** (via local-render fallback; spec'd "pull from EB endpoint" path is unimplementable per F13)
- Transcript attached to BC-5826 — **this comment**

The dogfood produced far more signal as a spec-gap audit than as a full-flow execution. 32 frictions identified, several critical. Recommending a round-2 dogfood AFTER the follow-up issues land.

## Inputs used

**CSV** — 6 leads mixed across 3 domains: gmail.com (×2), outlook.com (×2), brite.co (×2). All with fake local-parts (`dogfood-test-NN@…`) so no real mail could be sent even if `--activate` were fat-fingered.

**Copy artifact** — hand-authored to match BC-5825 email-copywriting schema v1.0. T2 free-asset, list-building preset, municipalities vertical. 10 variables in step_1 body, 2 in step_2 body, 0 in either subject (all spintax).

Both files preserved in `.claude/worktrees/bc-5826/dogfood/` on branch `holden/bc-5826-launch-campaign` (gitignored at commit time).

## Live-walk summary

**Phase 1 PRE-FLIGHT** — 10 validation steps walked. All 13 body sanity checks passed. 10 variables resolved (8 via `custom_variables[].default`, 2 EB-standard via lead fields at UPLOAD time). Workspace/entity cross-mapping flagged (brite-labs → expected b2b; dogfood override to personal).

**Phase 2 HOST LOOKUP** — MCP-native path unimplementable (no lead-side ESP tool; `check-mx-records` is sender-only). Fell back to Bash `dig`. Real MX resolution surfaced a non-obvious ESP distribution: `brite.co` resolved to Google Workspace (via `aspmx.l.google.com`), so the actual segmentation is **Google 4 / Microsoft 2 / Other 0** — not the 2/2/2 we'd have assumed. Value of real ESP detection confirmed.

## Phase 10 — local render (F13 fallback path)

Rendered step_1 + step_2 for lead 1 (Alex / Test Denver City), deterministic first-option spintax. All 5 output-sanity checks passed (no unresolved variables, no unresolved spintax, no em-dashes, no `<p>`, no `{{`).

```
STEP 1
Subject: Quick question

Saw the downtown master-plan announcement at Test Denver City Alex, and it lined up with a pattern we've been watching across municipalities.

Most municipalities teams we work with run into downtown lighting specs getting stuck at design review, and one that solved it was Boulder Pearl Street, who ran 38% higher evening foot traffic in 2024.

Happy to pull a short architectural lighting preview for Test Denver City if useful, no commitment.

Best,
Amanuel

STEP 2 (wait 4 days)
Subject: Re: Quick question

Circling back in case it got buried. Still happy to send the architectural lighting preview whenever it's useful.

Best,
Amanuel
```

## Friction log — 32 total

Live-surfaced during Phases 1–2 walk: **F1, F2, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13** (12 frictions). Paper-walk through Phases 3–11 surfaced **F14–F32** (19 additional).

### Critical

**F13 — Phase 10 preview endpoint does not exist.** `search_api_spec` on "preview email", "sequence preview", "render" returned nothing matching. The only test-related endpoint is `POST /api/campaigns/sequence-steps/{sequence_step_id}/test-email` which requires Phases 4–9 to have run AND sends a real email to a specified recipient — this is NOT a preview, it's a test-send. The command's Phase 10 needs a semantic rewrite: default to local render from copy artifact + lead data (client-side, no EB call), with optional `--test-send <email>` flag for real EB test-sends after Phase 9.

### Moderate

**F1 — Extended-tier tool surface.** Command file names tools like `bulk_create_leads`, `create_custom_variable`, `attach_sender_emails_to_campaign`, `create_sequence_steps`, `resume_campaign` as if directly callable. Reality: every one of these is **extended tier**, accessible only via `call_api` + `search_api_spec` to ground-truth the endpoint path and request body. Only `create_campaign`, `create_lead`, `list_leads`, `get_campaign`, `get_lead`, `list_campaigns`, `bulk_count`, `bulk_export`, `discover_tools`, `search_api_spec`, and a handful of read/workspace tools are core-tier.

**F7 — Variable-presence check doesn't encode EB convention.** Phase 1 step 5 does case-insensitive CSV-column match, but EB has standard variables (`{COMPANY}`, `{FIRST_NAME}`, `{LAST_NAME}`) that correspond to lead fields (`company`, `first_name`, `last_name`) via EB's render engine — not via string match against CSV column names. `{COMPANY}` vs `company_name` won't match on prefix; would false-flag. Spec needs an explicit EB-standard-variable allowlist OR a "resolved-via-bulk_create_leads-lead-fields" catch.

**F10 — Phase 2 MCP-native ESP lookup doesn't exist.** No lead-side ESP detection tool in EB. Bash `dig` is the only path today. Spec positions `dig` as "if not available" — should lead with it as the primary path.

**F11 — Phase 2 ordering blocks future MCP-native approach.** Phase 2 runs before Phase 4 UPLOAD. If EB ever adds server-side ESP inference accessible via `get_lead`, we can't use it because leads don't exist yet at Phase 2 timing. Moving Phase 2 after Phase 4 would unlock that path.

### Minor

**F2** — Entity→workspace mapping rigid (brite-labs → b2b always; no first-class dogfood/personal cross-mapping).

**F4** — `{SENDER_*}` resolution priority chain not explicit. Where does `custom_variables[].default` sit in the priority order relative to `docs/marketing-context.md`, Salesforce User lookup, operator ask?

**F5** — Lead spot-check "render" ambiguous on spintax. If unresolved, preview reads oddly; if resolved, which option? Suggest deterministic first-option.

**F6** — Metadata write path `docs/campaigns/{entity}/…` pollutes production directory during dogfood / testing. Consider `--dogfood` flag or alternate path.

**F8** — Phase 1 has a step-3 workspace-mismatch gate and a step-10 final gate. Fold into one UX gate.

**F9** — Base skeleton A grammar awkward: `at {COMPANY} {FIRST_NAME}, and …` renders as "at Test Denver City Alex, and …". FIRST_NAME wants vocative punctuation. **Out-of-scope for BC-5826 — belongs in BC-5825 follow-up.**

**F12** — Empty ESP bucket handling unspec'd (skip or include?).

### Paper-walked (hypothesized, not live-validated)

- **F14** — `list_custom_variables` pagination unspec'd
- **F15** — Conflicting-variable resolution (name match, default differs) — EB may not support default-overwrite on create
- **F16** — Variables are workspace-scoped; collisions with other campaigns in same workspace unspec'd
- **F17** — `create_lead` requires `last_name`; bulk variant likely same; CSV marks it optional (collision)
- **F18** — Mid-chunk UPLOAD failure recovery not spec'd
- **F19** — Vendor prompt wording assumed; "relay verbatim" works with whatever EB returns but test coverage unclear
- **F20** — Campaign-name collision handling unspec'd
- **F21** — **Important:** Phase 6 needs lead ID → bucket mapping in memory between phases; metadata only tracks count
- **F22** — `allow_parallel_sending` relay path untested in this dogfood
- **F23** — `list_sender_emails` pagination: cursor vs page mechanism unclear in spec
- **F24** — 772 senders in one attach payload — size-limit check needed
- **F25** — `list_sender_emails` filter `status: "connected"` not explicitly required; warmup senders could leak
- **F26** — Post-attach eventual-consistency retry window unquantified
- **F27** — Workspace with 0 schedule templates is a Phase 8 dead-end
- **F28** — Schedule-template presence is per-workspace — can't assume
- **F29** — Phase 9 silent override of `step_1.wait_in_days` (`max(1, …)`) — operator doesn't see authored value changed
- **F30** — `thread_reply: true` field assumed on step 2; needs `search_api_spec` ground-truth on v1.1 sequence-steps body
- **F31** — Partial-success tracking in Phase 11 (1-of-2 activated shows as `activated: false` in metadata)
- **F32** — (reserved; deleted; see F13)

## Proposed follow-up issues

Grouping for a tidy fix:

**Issue A (Critical, High priority)** — `BC-5826 follow-up: rewrite Phase 10 for EB reality`. Covers F13 + F5. Phase 10 default: local render from copy artifact + lead data, client-side, no EB call, deterministic spintax first-option. Optional `--test-send <email>` flag for real EB test-send after Phase 9. Update BC-5826 verification criterion #13 wording. Ship before round-2 dogfood.

**Issue B (Moderate, High priority)** — `BC-5826 follow-up: spec corrections from X17 dogfood`. Batch covering F1 (tool-tier documentation), F2 (entity-workspace flexibility), F4 (sender resolution priority), F7 (EB-standard variable convention), F10 (Phase 2 Bash `dig` as primary), F11 (Phase 2 ordering). Plus the minor/cosmetic batch: F6, F8, F12.

**Issue C (Minor, Medium priority)** — `BC-5826 follow-up: X17 round-2 dogfood, full flow execution`. Actually run Phases 3–9 in the workspace to validate F14–F31 (the paper-walked hypotheses). Blocked by A + B landing first. Deliverable: end-to-end workspace campaign in draft state with attached transcript.

**Issue D (Minor, Low priority)** — `BC-5825 follow-up: email-copywriting base skeleton A grammar (F9)`. Out-of-scope for BC-5826; belongs in BC-5825. The `at {COMPANY} {FIRST_NAME}, and …` pattern renders awkwardly; FIRST_NAME wants vocative punctuation.

## Recommendation

Land Issue A + B before shipping `/marketing:launch-campaign`. Issue C (round-2 dogfood) is a pre-ship nice-to-have but not a blocker. Issue D is cleanup on a separate skill.

---

*Dogfood artifacts preserved at `.claude/worktrees/bc-5826/dogfood/` on branch `holden/bc-5826-launch-campaign`.*
