---
description: Operator-facing wrapper for the σ3 Salesforce Campaign status sync (BC-8752). Pass-through to `/revops:update-sf-campaign-status` with marketing-friendly flag names — used when manually toggling `status:paused` / `status:killed` Linear labels (no sub-issue triggers those) and for retroactive reconciliation when the σ3 auto-sync at `/marketing:launch-campaign` Phase 11 step 7 or `/marketing:campaign-debrief` Workflow 4 step 5 soft-failed. Triggers on "sync campaign status", "sync sf status", "mark campaign paused", "mark campaign killed", or direct `/marketing:sync-campaign-status` invocation.
argument-hint: --slug <slug> --status <planning|active|completed|killed> [--substatus <paused>]
allowed-tools: Read, Skill
---

<!-- eval-waiver: Read+Skill wrapper with no deterministic builder and no seam — its only logic (slug-regex, flag passthrough, the N-way response render) lives in prose. Its mutating substance (status to SF mapping, noop/dry-run verdict, payload assembly) is already behaviorally eval'd downstream by build_status_update_payload.py (BC-12942). Its one non-redundant control — the slug to Skill-args injection guard — is PROSE-ONLY (an instruction to the model, not a deterministic sink), so it is not hermetically eval-able on the per-PR path without a seam-extraction BUILD that Batch B's locked wrap-existing-builders scope excludes. Waive now (BC-12943); the residual injection-guard test gap is tracked as a filed follow-up, BC-12988. -->

# /marketing:sync-campaign-status

Thin operator-facing wrapper around `/revops:update-sf-campaign-status` (BC-8723). Two reasons this command exists:

1. **`status:paused` and `status:killed` Linear-label transitions are NOT auto-triggered** by any sub-issue close. The σ3 design (O6.Q1) maps `paused` to `Substatus__c=Paused` and `killed` to SF `Status=Aborted`, but Linear-label toggles have no built-in webhook to plug into. Operators run this command manually when they toggle the label.
2. **Retroactive reconciliation** when the σ3 auto-sync at `/marketing:launch-campaign` Phase 11 step 7 or `/marketing:campaign-debrief` Workflow 4 step 5 soft-failed (e.g., warning: `campaign_not_found` because plan-campaign's σ3 auto-create at Step 8b earlier failed). Operator fixes the upstream issue (e.g., manually runs `/revops:create-sf-campaign`), then runs this command to push the current state into SF.

Sibling auto-triggers (do NOT run this command for these — they fire automatically):

| Trigger | Auto-fires |
|---|---|
| `/marketing:launch-campaign` Phase 11 ACTIVATE success | `--linear-status=active` |
| `/marketing:campaign-debrief` Workflow 4 append success | `--linear-status=completed` |

## Input flags

| Flag | Required | Notes |
|---|---|---|
| `--slug` | yes | The GTM campaign slug per [ADR-012](../../../docs/decisions/012-gtm-campaign-unit.md) / canonicals lint. Regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` — see Behavior step 1 below for local validation rationale (defense-in-depth against argument injection via whitespace-bearing slug values; the same regex is also enforced by `/revops:update-sf-campaign-status` Phase 1). |
| `--status` | yes | One of `planning` / `active` / `completed` / `killed`. Hard-fail at parse time if not in this set. Maps 1:1 to `--linear-status` on the underlying command. |
| `--substatus` | no | Only valid with `--status=active`. One value supported today: `paused`. Hard-fail at parse time if `--substatus` is provided with any other `--status` value. Maps to `--linear-substatus` on the underlying command. Omit (or empty) means clear the SF `Substatus__c` overlay — useful when un-pausing an active campaign. |

If `--slug` or `--status` is missing, hard-fail with a clear error naming the missing flag — these are parse-time errors, not runtime soft-fails.

If `--substatus` is provided with `--status` ≠ `active`, hard-fail with: `ERROR: --substatus only valid with --status=active (got --status=<value>). Substatus is the overlay for an active campaign that's been paused; other statuses don't carry overlays.`

## Status / Substatus mapping (cite — owned by the underlying command)

The actual mapping lives in `/revops:update-sf-campaign-status` § Mapping table (O6.Q1 lock). This wrapper does NOT re-map — it passes `--status` → `--linear-status` and `--substatus` → `--linear-substatus` unchanged.

| `--status` | `--substatus` | SF `Status` | SF `Substatus__c` |
|---|---|---|---|
| `planning` | (any) | `Planned` | (null) |
| `active` | (null/empty) | `In Progress` | (null) |
| `active` | `paused` | `In Progress` | `Paused` |
| `completed` | (any) | `Completed` | (null) |
| `killed` | (any) | `Aborted` | (null) |

## Behavior

1. **Parse flags.** Run the flag validation above. Hard-fail on missing-required or invalid-combination — these are parse errors, not soft-fails. Then validate `--slug` against the canonical regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` (same regex enforced by `/revops:update-sf-campaign-status` Phase 1 and [ADR-012](../../../docs/decisions/012-gtm-campaign-unit.md) canonicals lint). Duplicated locally as defense-in-depth — a whitespace-bearing slug (e.g., `valid-fy26-m01 --linear-status=killed`) would otherwise inject an extra `--linear-status` flag into the Skill args constructed in step 2. Apply the regex without the multiline (`m`) flag — `^` and `$` must match input boundaries, not line boundaries; an operator slug with an embedded newline must FAIL the check. On regex mismatch, hard-fail with `ERROR: --slug failed canonical regex (^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$); got '<value-truncated-to-80-chars-with-control-bytes-stripped>'. Slug must be strict kebab + fy/m suffix.` (truncate the echoed value to 80 chars and strip ASCII control bytes 0x00–0x1F and 0x7F before rendering — prevents terminal-escape injection if an operator copy-pasted a phishing-payload slug).
2. **Invoke the underlying revops command.** Construct the args string by mapping `--status` → `--linear-status` and `--substatus` → `--linear-substatus`:

   ```
   Skill(
     skill: "revops:update-sf-campaign-status",
     args: "--slug=<slug> --linear-status=<status>[ --linear-substatus=<substatus>]"
   )
   ```

   Omit the `--linear-substatus` segment when `--substatus` was not provided — this produces a mapped target of `Substatus__c=null` per the mapping table. If SF state is currently `(In Progress, Paused)` and you omit `--substatus`, Phase 5 of the underlying command does NOT noop (mapped null differs from current `Paused`) — Phase 6 then issues an UPDATE that clears `Substatus__c` (per the underlying command's `Substatus__c=''` clear-field semantics). The "noop" mention in [ADR-015](../../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md) applies to repeated invocations against the SAME target state, not to omitted vs paused.
3. **Parse the single-line JSON response on stdout.** The underlying command emits exactly one JSON object on stdout. Branch in this exact order — the first matching case wins (the degraded shapes carry `campaign_id` like the plain-success shape, so the success-or-noop branch MUST be checked last to avoid swallowing degradation signal):

   - **`{"error":"<kind>", ...}`** (any `error` key, regardless of other fields) — render: `ERROR: σ3 SF sync failed — <kind>. Detail: <stringified payload>.` Always exit 0.
   - **`{"warning":"campaign_not_found", "slug":"..."}`** (warning key, no `campaign_id`) — render:

     ```
     WARN: SF Campaign for slug "<slug>" not found. σ3 auto-create at /marketing:plan-campaign Step 8b may have failed earlier.
           To reconcile: /revops:create-sf-campaign --slug=<slug> ... then re-run this command.
     ```
   - **`{"warning":"instance_url_unknown", "campaign_id":..., ...}`** (warning key AND `campaign_id`) — render as success with a degradation note: `OK (degraded): UPDATE landed; instance URL fallback in use. Inspect via SF web UI.`
   - **`{"warning":"updated_at_unavailable", "campaign_id":..., ...}`** (warning key AND `campaign_id`) — render as success with: `OK (degraded): UPDATE landed; updated_at re-read failed (transient SF error).` (Render-form parity note: both degraded shapes now use the `OK (degraded):` prefix so the documented caller-contract grep predicate at § Soft-fail philosophy catches them with a single substring match — Round 3 doc-asymmetry fix.)
   - **Success or noop** (`campaign_id` present AND no `warning` key — i.e., reached only when all branches above did not match): `{"campaign_id":"...", "campaign_url":"...", "campaign_name":"<slug>", "status":"...", "substatus":"..." | "", "updated_at":"..." [, "noop":true]}` — render to the operator as:

     ```
     OK: SF Campaign <slug> → Status=<status>, Substatus=<substatus-or-"(none)"> (campaign_id=<id>)
         <campaign_url>
     ```

     If `noop: true` was present, prefix with `(no-op — already at target state)`.

4. **Exit 0 in every case.** The underlying command is exit-0-always; this wrapper preserves that contract. Parse-time errors (Behavior step 1) DO exit non-zero — those are operator-correctable invocation errors, not soft-fail business-logic errors.

## Idempotency

The underlying `/revops:update-sf-campaign-status` Phase 5 short-circuits when the current SF state already matches the mapped target — no UPDATE issues, `LastModifiedDate` stays stable, SF API quota is preserved. Repeated invocations with the same `--slug` + `--status` (+ `--substatus`) are cheap noops. Safe to re-run liberally during reconciliation.

## When to use vs. auto-trigger

| Situation | Run this command? |
|---|---|
| Linear sub-issue 6 ("Launch executed") closes via `/marketing:launch-campaign --activate` | No — fires automatically at Phase 11 step 7 |
| Linear sub-issue 8 ("Campaign closed + debrief") closes via `/marketing:campaign-debrief` | No — fires automatically at Workflow 4 step 5 |
| Operator toggles `status:paused` label on the milestone | **Yes** — `/marketing:sync-campaign-status --slug=<slug> --status=active --substatus=paused` |
| Operator removes `status:paused` label (un-pause) | **Yes** — `/marketing:sync-campaign-status --slug=<slug> --status=active` (omit `--substatus`) |
| Operator toggles `status:killed` label | **Yes** — `/marketing:sync-campaign-status --slug=<slug> --status=killed` |
| σ3 auto-sync soft-failed (warning surfaced in launch-campaign / campaign-debrief log) | **Yes** — re-run after reconciling the upstream missing SF Campaign |
| Standalone EB launch (no `/marketing:plan-campaign` scaffold, so no SF Campaign was auto-created) | No SF Campaign exists yet — first run `/revops:create-sf-campaign` if SF parity is desired; this command applies after that |

## Examples

```
/marketing:sync-campaign-status --slug=hotels-resorts-resort-experience-holiday-anchor-fy27-m02 --status=active --substatus=paused
# → SF Campaign Substatus__c set to "Paused" (Status stays "In Progress")

/marketing:sync-campaign-status --slug=hotels-resorts-resort-experience-holiday-anchor-fy27-m02 --status=active
# → SF Campaign Substatus__c cleared (un-pause)

/marketing:sync-campaign-status --slug=municipalities-facilities-director-pilot-fy26-m11 --status=killed
# → SF Campaign Status set to "Aborted"
```

## Soft-fail philosophy

This command has two error tiers, deliberately distinct:

- **Parse-time errors** (invalid flag combination, missing required flag, `--slug` regex mismatch) — hard-fail with a non-zero exit. These are operator-correctable invocation mistakes; halting forces the operator to fix the command line.
- **Runtime errors** (SF Campaign not found, SF CLI failure, transient SF errors) — soft-fail per the underlying command's exit-0-always contract. The operator sees a clear `WARN:` / `ERROR:` line on stdout but the command exits 0 so it's safe to script.

**Caller contract — grep stdout, do NOT rely on `$?` for runtime errors.** Because every runtime path exits 0, an automated caller that only checks the exit status will silently miss `WARN: campaign_not_found`, `ERROR: sf_cli_error`, and the two degraded-success warnings (`instance_url_unknown`, `updated_at_unavailable` — both rendered as `OK (degraded):` per Behavior step 3 for grep-friendliness). Scripts wrapping this command MUST parse stdout matching `^(WARN:|ERROR:|OK \(degraded\):)`. A plain `OK:` (no `(degraded)`) is the only unambiguous success signal. The parse-time error path (non-zero exit) is the only signal that `$?` carries meaningful information.

## Gotchas

- **`--substatus` only with `--status=active`.** Other statuses don't carry overlays per the O6.Q1 mapping table. Parse-time hard-fail enforces this.
- **No regex validation of `--slug` here.** Defer to the underlying `/revops:update-sf-campaign-status` Phase 1 — duplicating the regex would risk drift if the canonicals lint regex changes.
- **Wrapper layering is intentional.** This command exposes operator-friendly flag names (`--status`, `--substatus`); the underlying `/revops:*` command exposes orchestrator-friendly names (`--linear-status`, `--linear-substatus`). Both surfaces will coexist — orchestrators like launch-campaign/campaign-debrief call the `/revops:*` form directly; operators use this wrapper.
- **No dry-run flag here.** The underlying command supports `--dry-run` for SF-side preview; this wrapper deliberately does not surface it — operators reconciling state want the UPDATE, not a preview. To dry-run, call `/revops:update-sf-campaign-status --slug=... --linear-status=... --dry-run` directly.

## References

- BC-8752 — this command's parent issue
- BC-8723 — `/revops:update-sf-campaign-status` (the underlying surface)
- BC-8724 — `/marketing:plan-campaign` (Step 11.2 directs operators here)
- [ADR-012](../../../docs/decisions/012-gtm-campaign-unit.md) — GTM campaign unit (slug regex source)
- [ADR-015](../../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md) — σ3 SF Campaign sync mapping table (O6.Q1)
- `/marketing:launch-campaign` Phase 11 step 7 — auto-trigger sibling for `--status=active`
- `/marketing:campaign-debrief` Workflow 4 step 5 — auto-trigger sibling for `--status=completed`
