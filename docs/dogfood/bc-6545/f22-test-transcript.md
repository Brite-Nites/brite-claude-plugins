# BC-6545 — F22 (allow_parallel_sending) live verification transcript

**Date:** 2026-05-04
**Workspace:** `emailbison-personal` workspace 13 (`BriteNites Team`, primary)
**Operator:** Corinne Brewer
**Branch:** `corinne/bc-6545-f22-verification`
**Plan:** [`docs/plans/BC-6545-plan.md`](../../plans/BC-6545-plan.md)

---

## Plain-language summary

Tested whether Email Bison's safety check actually refuses to attach a lead that's already in another campaign. Result: **the safety check fires** (HTTP 422 without the override flag, HTTP 200 with it). But the test surfaced two nuances the current spec doesn't capture: (1) the safety check fires even on **draft** campaigns, not just active ones — so the spec's "active sequence" wording is too narrow, (2) the `call_api` wrapper hides the response body, so the spec's "relay the prompt verbatim" guidance is unactionable through that code path.

---

## Setup

Workspace confirmed via `get_active_workspace_info`:

```json
{
  "instance_url": "https://personal.outbase.so",
  "active_workspace": {"id": "13", "name": "BriteNites Team", "is_primary": true}
}
```

Created artifacts:
- Campaign A: `id=31`, `name="BC-6545 F22-test-A"`, `status=draft`, `type=outbound`
- Campaign B: `id=32`, `name="BC-6545 F22-test-B"`, `status=draft`, `type=outbound`
- Test lead: `id=14724`, `email="bc-6545-f22-test@brite.co"`, `name="F22 Test"`, `company="BC-6545"`, `title="Test Lead"`

Attach lead 14724 to campaign 31:

```
POST /api/campaigns/31/leads/attach-leads
body: {"lead_ids": [14724]}
```

Response (HTTP 200):

```json
{
  "success": true,
  "data": {
    "success": true,
    "message": "Leads successfully added to BC-6545 F22-test-A. Existing leads were not added.",
    "note": null
  }
}
```

**Activation step (plan Task 1 step 6) — skipped.** Searched API spec for activation endpoints (`activate campaign`, `launch`, `start campaign`) — all returned `not found`. Per BC-6298 (`search_api_spec` doesn't match natural-language phrases), additional search terms could be tried, but the plan's explicit fallback path was to "attach the lead to a non-activated campaign A (just creates the lead↔campaign join), then attach to B and observe." Pivoted to that fallback. Pre-test state at the moment of conflict-attach: lead 14724 attached to draft campaign 31; both campaigns A and B in `status=draft`; no senders, sequence steps, or schedule on either.

---

## Test 2a — without override

Request:

```
POST /api/campaigns/32/leads/attach-leads
body: {"lead_ids": [14724]}
```

Response:

```json
{
  "error": "HTTP 422 Error",
  "hint": "Use search_api_spec to verify the correct endpoint and request body format."
}
```

**HTTP status: 422.** Response body hidden by the `call_api` MCP wrapper (same Sx-8 limitation seen on `bulk_create_leads` — see `email-bison.md` line 276). The wrapper returns only the generic `{"error": "HTTP 422 Error"}` envelope; no diagnostic body, no parallel-sending prompt text, no per-lead skip list.

---

## Test 2b — with override

Request:

```
POST /api/campaigns/32/leads/attach-leads
body: {"lead_ids": [14724], "allow_parallel_sending": true}
```

Response (HTTP 200):

```json
{
  "success": true,
  "data": {
    "success": true,
    "message": "Leads successfully added to BC-6545 F22-test-B. Existing leads were not added.",
    "note": null
  }
}
```

The override flag enabled the attach. Confirms the Test 2a 422 was caused by the F22 safety check, not by an unrelated validation (same endpoint + same body shape + only differing parameter is `allow_parallel_sending: true`).

---

## Verdict

**Classification: fires-as-spec, with two nuance corrections.**

| Aspect | Spec assumption | Verified behavior |
|----|----|----|
| Does the safety check fire? | Yes | **Yes (verified)** |
| When does it fire? | "lead is already in another campaign's active sequence" (`launch-campaign.md:560`, `email-bison.md:270`) | **Lead is in another campaign — regardless of campaign status.** Both A and B were in `status=draft`; no senders; no sequence; the lead was attached but not actively being emailed. F22 still fired. The check is on attached-to-any-campaign, not active-sequence-only. |
| Does override work? | `allow_parallel_sending: true` enables the attach | **Yes (verified)** |
| Does EB return a verbatim prompt body for the operator to relay? | `launch-campaign.md:589` says "if the vendor returns this prompt instead of the normal confirmation, treat it as a real semantic gate. Relay verbatim..." | **Cannot be verified through `call_api`.** The MCP wrapper exposes only `{"error": "HTTP 422 Error"}` — no prompt body, no diagnostic. The "relay verbatim" guidance is unactionable through this code path. The body may exist in the raw HTTP response but is stripped by the wrapper. Vendor-tool path (e.g., direct `import_leads_to_campaign` MCP call) may or may not surface the body — not verified this round. |

---

## Implications for spec edits

Four lines need update with verified behavior + BC-6545 cite-anchor:

### `plugins/marketing/commands/launch-campaign.md` line 556

Current: "The `allow_parallel_sending` branch below IS a real semantic vendor gate (the API does return a parallel-sending prompt body), so it stays as-written."

Issue: Asserts "the API does return a parallel-sending prompt body" — verified, but the body is hidden through `call_api`. The semantic-gate characterization is correct; the prompt-body claim needs caveating.

Edit shape: Keep the "real semantic vendor gate" framing. Replace "the API does return a parallel-sending prompt body" with "verified BC-6545 — attach returns HTTP 422 when conflict detected; via `call_api` the response body is stripped to `{error: HTTP 422 Error}` (Sx-8 wrapper limitation), but the override flag (`allow_parallel_sending: true`) succeeds when added".

### `plugins/marketing/commands/launch-campaign.md` line 560

Current: "if any lead being attached is already in another campaign's **active** sequence, the tool refuses and returns a prompt asking whether to enable parallel sending."

Issue: "active sequence" is too narrow — F22 fires on any attached lead, regardless of campaign status (verified BC-6545 with both campaigns in `status=draft`).

Edit shape: Change "in another campaign's active sequence" → "in another campaign (regardless of campaign status — verified BC-6545)". Drop the "returns a prompt" claim or caveat with the wrapper limitation; replace with "the tool refuses with HTTP 422".

### `plugins/marketing/commands/launch-campaign.md` line 589

Current: "if the vendor returns this prompt instead of the normal confirmation, treat it as a real semantic gate. Relay verbatim..."

Issue: "Relay verbatim" is unactionable through `call_api` — there's no prompt body in the wrapper's response.

Edit shape: Change the relay guidance to operator-side action: "if the call_api response returns `{error: HTTP 422 Error}` on attach (and the endpoint + body are correct per Test 2a/2b precedent), treat it as the F22 safety check firing. Surface to the operator: which lead(s) appear to be in conflict (look up via `list_leads` against attached campaigns), present the (a) decline / (b) approve-parallel branches per below". Note the verbatim-relay path applies to vendor-tool calls (where the MCP wrapper may surface the body), not `call_api`.

### `plugins/marketing/tools/integrations/email-bison.md` line 270

Current: "**`import_leads_to_campaign` may fail with `allow_parallel_sending` prompt.** If a lead being attached is already in another campaign's active sequence, the tool refuses the attach and returns a prompt asking whether to enable parallel sending."

Issue: Same two nuances — "active sequence" is too narrow; "returns a prompt" doesn't reflect the wrapper-stripped reality through `call_api`. Also: the bullet refers to the `import_leads_to_campaign` vendor tool, not `call_api`. Need to disambiguate which path was tested.

Edit shape: Tighten "may fail" → "fires" (verified BC-6545). Change "active sequence" → "any campaign". Add: "Verified via `call_api` against `/api/campaigns/{id}/leads/attach-leads` (BC-6545, 2026-05-04) — HTTP 422; response body stripped to `{error: HTTP 422 Error}` (Sx-8 wrapper limitation). The vendor-tool path (`import_leads_to_campaign` direct invocation) may surface the prompt body — not verified this round. Override (`allow_parallel_sending: true`) succeeds in both cases."

---

## Cleanup

Lead 14724 deletion (queued):

```
DELETE /api/leads/14724
→ {"success": true, "message": "Lead deletion process started..."}
```

Campaigns 31 + 32 bulk deletion (queued):

```
DELETE /api/campaigns/bulk
body: {"campaign_ids": [31, 32]}
→ {"success": true, "message": "The selected campaigns have been queued for deletion."}
```

Verified clean state via `list_campaigns(search="BC-6545")` → 0 results, `list_leads(search="bc-6545-f22-test")` → 0 results. **No permanent state delta in workspace 13.** (Workspace 13's 8 prior permanent custom variables are unaffected — F22 test does not touch custom variables.)

---

## Sources

- Issue body: [BC-6545](https://linear.app/brite-nites/issue/BC-6545) — explicit test recipe in § "Test setup required (pre-poisoning)"
- Plan: [`docs/plans/BC-6545-plan.md`](../../plans/BC-6545-plan.md)
- Spec lines under review: `plugins/marketing/commands/launch-campaign.md` 556 / 560 / 589, `plugins/marketing/tools/integrations/email-bison.md` 270
- Wrapper limitation reference: BC-5906 round-2 Sx-8 → BC-6298 (`call_api` strips response body on 422)
- Live-verify precedent: BC-6515 (live-verify before enshrining doc claims)
- Search-term precedent: BC-6298 (`search_api_spec` doesn't match natural-language phrases)
