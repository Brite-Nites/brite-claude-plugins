# 024. Defer the `launch-campaign` Phase 2 → `verify_emails` swap to the bulk-verify door

**Status:** Accepted
**Date:** 2026-06-05
**Linear:** [BC-8173](https://linear.app/brite-nites/issue/BC-8173) (activate launch-campaign Phase 2 brite-enrichment swap)
**Related issues:** [BC-5538](https://linear.app/brite-nites/issue/BC-5538) (shipped `verify_emails`, the tool BC-8173 was waiting on), [BC-5296](https://linear.app/brite-nites/issue/BC-5296) (REST batch door — the swap's real home), [BC-12048](https://linear.app/brite-nites/issue/BC-12048) (audience views — where deliverability filtering lives)
**Affected files:** [`plugins/marketing/commands/launch-campaign.md`](../../plugins/marketing/commands/launch-campaign.md) § Phase 2 step 1; [`plugins/marketing/tools/integrations/brite-enrichment.md`](../../plugins/marketing/tools/integrations/brite-enrichment.md) § Consumed by + § Related skills

## Context

`/marketing:launch-campaign` Phase 2 sorts a campaign's lead list on two axes — email-type (`professional` / `role` / `personal`, via `is_role` / `is_free`) and ESP host (Google / Microsoft / Other) — and combines them into a 9-cell segmentation grid. Today both axes are resolved **for free**: email-type by static list match (no network, instant), ESP by a parallel `dig MX` sweep (public DNS, ~minutes for thousands of domains).

BC-8173 (filed 2026-05-12) anticipated swapping Phase 2's static email-type classification for the Brite enrichment MCP once a verification tool existed. Its concrete plan was **one batched call** — `verify_emails(records=leads, recipe="classification+deliverability")` — to classify ~1k leads at once for ~$4, ~20s wall-clock, trading "small $$ for accuracy + ~50× speed." The `launch-campaign.md:290` comment recorded the intent as a future "internals-only change."

The verification tool shipped as **`verify_emails(email: str) -> dict`** (BC-5538, 2026-06-05): **one email per call**, interactive, no `records=` / `recipe=` parameters, ~$0.003/call. The batched API BC-8173 assumed never existed. Re-examining the swap against the tool we actually built surfaced that the ticket's premise no longer holds.

## Decision Drivers

- **Inverted cost/speed.** Looping a single-email tool over a 1k-lead list is ~1k sequential tool calls — **slower** than the free static pass + parallel `dig`, not 50× faster, and it costs ~$3/run of provider spend where today's path is $0.
- **Wrong door (MCP-vs-batch boundary).** The enrichment MCP is the *interactive, small-N* door; list-scale work belongs to the *bulk* door (the REST batch surface, BC-5296), which is not yet built. Per-lead looping over 1k leads is the documented interactive anti-pattern (1k budget-gate reads, ~1k receipt writes).
- **Credentials.** `verify_emails` needs Snowflake (daily budget gate read + `ENRICHMENT_ATTEMPTS` receipt write). The plugin-distributed enrichment MCP carries **no** Snowflake credentials — `verify_emails` only works in the single-operator local-creds run (ADR-012 Addendum 2 in `brite-data-platform`). A shared command cannot rely on it for all operators.
- **Thin marginal value.** Of the three things `verify_emails` returns: `esp` duplicates what free `dig` already gives; `is_deliverable` is genuinely new but Phase 2 has no deliverability axis and that filtering's home is the audience-view layer (BC-12048), not `launch-campaign`; only `is_role` / `is_free` are modestly better (catching variant role inboxes the static list deliberately skips). The one real upside does not justify the cost/door/creds problems at list scale.

## Decision

**Defer the swap. Make no functional change to Phase 2; keep the free static-list + `dig` classification as the primary path. Correct the stale "internals-only swap" notes to record why the swap waits, and point the real swap at the bulk-verify door (BC-5296).**

Concretely:

1. `launch-campaign.md` § Phase 2 step 1 — the `:290` "future swap is an internals-only change" comment and the `:292` "that's the BC-5538 swap's job" note are rewritten to state that the shipped tool is single-email-only, so list-scale classification is **not** a drop-in here and waits on BC-5296.
2. `brite-enrichment.md` § Consumed by — `launch-campaign`'s row flips from "satisfied — `verify_emails` shipped" to "deferred — list-scale verify waits on BC-5296"; § Related skills updated to match.
3. **No** `allowed-tools` wildcard is added (the command makes no MCP call) and **no** eval is added (there is no new code path to test). The static free-mail list and its `tam-mapping` Operational rule 1 cross-reference are unchanged and remain in sync.

## Alternatives Considered

### A. Docs-only deferral — **chosen**

Correct the notes; defer the functional swap to BC-5296. No behavior change. Closes BC-8173 truthfully ("the swap can't happen with the single-email tool; here's where it really lives") rather than shipping a wasteful approximation.

### B. Docs deferral + an optional small-N interactive spot-check

Keep the static path as primary, but let the operator hand a *few* ambiguous addresses to `verify_emails` at gate 2 to double-check the static buckets, local-creds-only, with static fallback.

**Why rejected:** Builds a feature nobody asked for; bakes a step into a *shared* command that silently no-ops for every operator except the one with local creds; the value (slightly better role detection on a hand-picked handful) does not earn the added surface, eval, and provider spend. Offered as a possible future follow-up, not baked in.

### C. Force the literal per-lead loop

Loop `verify_emails` over the full lead set as written.

**Why rejected:** The interactive anti-pattern — inverted cost/speed, 1k budget-gate reads + receipt writes, and creds-blocked on the distributed plugin. Strictly worse than today's free path.

## Consequences

### Positive

- Phase 2 keeps its free, fast, creds-independent classification — works identically for every operator and in the distributed plugin.
- The stale "internals-only swap" promise is corrected in all three places it appeared, so a future contributor doesn't try to build a swap the shipped tool can't support.
- The real swap is unambiguously located at the bulk-verify door (BC-5296), with the cost/value caveats (`esp` already free via `dig`; deliverability belongs in BC-12048) recorded for when that ticket is built.

### Negative

- BC-8173's headline upside (smarter role detection) is not delivered now. Mitigation: the static list's misses are bounded by operator review at gate 2, and the upside returns with BC-5296.

### Out of scope

- Whether bulk-verify is worth the provider spend at all, given `dig` covers `esp` for free and deliverability lives in audience views (BC-12048) — that trade is BC-5296's call, not this one.
- Phone validation, provider tuning, `enriched_leads.csv` schema (BC-8173 non-goals).

## Verification

`./scripts/validate.sh` exits 0 after the doc edits. No runtime behavior changes, so no functional eval applies; Phase 2 continues to classify via the static lists + `dig`.
