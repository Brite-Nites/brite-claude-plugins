---
description: Create a Salesforce Campaign record from canonical GTM slug + persona/offer/vertical/entity inputs. Idempotent (refuses duplicate slugs), soft-fail (all errors exit 0 with structured JSON), and orchestrator-friendly (single-line JSON on stdout). Called by `/marketing:plan-campaign` Step 8b (BC-8724) at scaffold time; can also be invoked manually for SF reconciliation when an earlier auto-create failed. Triggers on "create sf campaign", "scaffold sf campaign", "sigma3 auto-create", or direct `/revops:create-sf-campaign` invocation.
allowed-tools: Bash, mcp__plugin_revops_salesforce__run_soql_query
disable-model-invocation: true
---

# /revops:create-sf-campaign

Implements σ3 SF Campaign auto-create per [ADR-015](../../docs/decisions/015-gtm-sigma3-sf-campaign-sync.md). Replaces the originally-planned `mcp__plugin_revops_salesforce__create_sf_campaign` write tool (BC-8717 respec'd 2026-05-19) — the upstream `@salesforce/mcp` package is not Brite-owned, so the write surface lives here as a slash command instead.

**Soft-fail contract** (load-bearing, per BC-8724 design): every error path exits 0 with a structured `{"error":"<kind>", ...}` JSON object. Orchestrators detect failure by parsing the `error` key, NOT by exit code. NEVER throw, NEVER exit non-zero, NEVER halt with prose.

**Single-line JSON on stdout.** No narration, no banners, no markdown. The caller pipes the output to `jq`. If you need to log diagnostic context, write it to stderr — stdout is reserved for the one JSON line.

## Deterministic builder

`/revops:create-sf-campaign` is **command-as-orchestrator + a deterministic builder as composer** (the ADR-028 D2/D8 emit-mode seam, mirroring how `/marketing:plan-campaign` delegates to `build_manifest.py`). The SF Campaign **payload** assembly and the **dedup / owner verdict** *given the two SOQL reads* are owned by **[`plugins/revops/scripts/build_campaign_payload.py`](../scripts/build_campaign_payload.py)**, a pure, stdlib-only, hermetic helper the command **delegates to in BOTH its normal and emit runs** — that is the drift-prone logic the eval certifies in one place. The input-shape guards (slug / owner-email / target-org) are the SAME byte-identical regexes living in two roles: applied **in-context** at Phase 0/1 as the ordering-critical shell-/SOQL-injection guards — they MUST run *before* their `sf` / SOQL sinks (Phase 0/2/3) — **and** re-applied inside the builder as the canonical, eval-tested copy (parity-locked by the BC-12638 lint + the builder's parity test, so the two roles cannot drift). The command owns the IO boundary: the Phase-0/2/3 live SOQL reads, the Phase-5 `sf data create record` write, and emitting the builder's decision on stdout.

The builder's pure core is `decide(inputs, sf_state) -> {verdict, payload, output}`, where `sf_state` carries the results of the command's two live reads (Phase-2 idempotency precheck + Phase-3 owner lookup):

```json
{ "existing_campaigns": [ {"Id": "701…", "Name": "<slug>"} ], "owner": {"email": "<owner-email>", "id": "005…"} }
```

- `verdict` ∈ `would_create` | `would_skip_duplicate` | `error`.
- `payload` is the SF Campaign field-map (present on `would_create`, else `null`).
- `output` is the exact soft-fail JSON envelope to emit on stdout (present on every non-`would_create` branch, else `null` — the Phase-7 success envelope needs the post-write `Id`).

The 7th error-catalog key, **`sf_cli_error`**, has no branch in `decide()` — it is emitted by the command's IO layer on a live SOQL/CLI failure (Phase 2/3/5), which is not input-determined. The builder owns the six input-determined verdicts above; `sf_cli_error` stays with the IO boundary.

At **runtime** the order is load-bearing: Phase 0/1 validate the inputs **in-context first** (the shell-/SOQL-injection guards, *before* any `sf` or SOQL sink) → Phase 2/3 perform the SOQL reads → then pass the validated inputs + the SOQL rows to the builder for the dedup/owner verdict + payload:

```bash
echo '<scenario-json>' | python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_campaign_payload.py" --decide -
```

`would_create` → run the Phase-5 `sf data create record` with the returned `payload`, then emit Phase-7 success; any other verdict → emit the builder's `output` verbatim (still exit 0 — soft-fail). Because the payload + dedup/owner verdict are computed in ONE place, the behavioral eval that drives the builder (below) certifies the real decision logic, not a parallel copy. **The Phase prose below is the builder's contract: the command does NOT re-implement the payload assembly or the dedup/owner verdict in-context — those are builder-only. The Phase 0/1 input-shape regexes DO run in-context (the injection-ordering guards), applying the same byte-identical patterns the builder re-checks.**

## Emit mode (`--scenarios <fixture> --out-dir <sandbox>`)

`build_campaign_payload.py --scenarios <fixture> --out-dir <sandbox>` is the **side-effect-free** run the behavioral eval (BC-12701) exercises (ADR-028 § 5). Because the dedup + owner decisions depend on LIVE SOQL, the fixture **injects** those two reads as `sf_state` (the `/marketing:plan-campaign` idiom of injecting `created_at` to defeat `now()`) — so the builder is pure given its inputs. Emit runs `decide()` over a scenario matrix and writes `campaign-emit.json` (each row `{id, verdict, payload, campaign_id, output}`); it makes **NO** `run_soql_query` call, **NO** `sf` write, **NO** network call. `campaign_id` is always `null` — emit never writes. The eval golden-compares a structural projection of that matrix (`plugins/revops/tests/eval/create-sf-campaign.*`); the harness is `scripts/eval/test_eval_harness.sh` + the builder unit suite `plugins/revops/scripts/test_build_campaign_payload.sh`, both wired into `validate.sh`.

Emit mode does **not** make the command non-side-effecting: its DEFAULT run still creates a real Campaign, which is why **`disable-model-invocation: true`** is set (ADR-028 § 0 — the model must not fire the real, mutating run unprompted; the command stays invocable explicitly via `/revops:create-sf-campaign` and via `/marketing:plan-campaign` Step 8b's `Skill` delegation). Distinguish from the legacy `--dry-run` (Phase 4), which previews to stdout but still performs the live SOQL reads — `--dry-run` is the human/orchestrator preview; emit mode is the hermetic, testable seam.

## Input flags

Parse from the invocation (e.g. `/revops:create-sf-campaign --slug=... --entity=... ...`):

| Flag | Required | Notes |
|---|---|---|
| `--slug` | yes | Regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`. Becomes `Campaign.Name`. |
| `--entity` | yes | One of `nites` / `supply` / `labs` / `cross-entity`. Mirrors `Campaign.Entity__c` picklist from BC-8713. |
| `--vertical` | yes | Canonical vertical slug from `plugins/marketing/data/canonicals/`. |
| `--persona` | yes | Canonical persona slug. |
| `--offer` | yes | Canonical offer slug. |
| `--year` | yes | 4-digit, e.g. `2026`. |
| `--month` | yes | Integer 1-12. |
| `--owner-email` | yes | SF user email (literal username, NOT alias — per `gotcha_sf_mcp_username_not_alias.md`). |
| `--launch-date` | yes | ISO `YYYY-MM-DD`. Maps to `Campaign.StartDate`. |
| `--target-org` | no | Defaults to `brite-prod` (SF prod-org canonical alias). When supplied, validated against regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set). Used as a shell argument to `sf` CLI — the Phase 0 regex (validated before the metadata shell-out, `--target-org`'s earliest sink) blocks shell-injection metacharacters. NOTE: This default does NOT auto-read `~/.sf/config.json`'s `target-org`. If the caller wants the SF MCP's session default, they MUST resolve it via `mcp__plugin_revops_salesforce__get_username(defaultTargetOrg=true).value` and pass that as `--target-org` explicitly. BC-8727 friction-log F11. |
| `--dry-run` | no | Boolean. If present, print preview JSON and exit without inserting. |

If any required flag is missing, emit `{"error":"missing_required_flag","flag":"<name>"}` exit 0 and stop. Do NOT prompt the user — orchestrators expect non-interactive behavior.

## Phase 0 — Resolve target-org metadata (recommended optimization)

<!-- guard:target-org -->
**First, validate `--target-org` (always — even on `--dry-run`).** If `--target-org` was explicitly supplied, it MUST match regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set). Otherwise emit `{"error":"invalid_target_org","value":"<value>"}` exit 0 and stop **without running any shell-out**. This is the shell-injection guard, and it lives here because the metadata shell-out below is `--target-org`'s *earliest* sink: the value is interpolated into a double-quoted `sf` argument, which blocks bare metacharacters but NOT `$(...)` / backtick command substitution — so the regex (which excludes `$`, `(`, `)`, backticks, whitespace) MUST run before that interpolation. This validation runs on **every** path; it is NOT subject to the `--dry-run` skip below. Mirrors `/revops:update-sf-campaign-status` Phase 0 for sibling parity per ADR-015 amendment (BC-10511 + BC-12623).

Then resolve metadata — run via the `Bash` tool ONCE per invocation (skip on `--dry-run`):

```bash
sf org display --target-org "<target-org>" --json
```

> **Canonical reference (BC-12639, ADR-028 emit-mode seam):** the regex this guard applies mirrors, byte-identically, the deterministic side-effect-free validator [`plugins/revops/scripts/validate_target_org.py`](../scripts/validate_target_org.py) (`exit 0` accept / non-zero reject for the same `^[a-zA-Z0-9._@-]+$`). That validator is behaviorally eval'd (`test_validate_target_org.sh`, wired into `validate.sh`) against real injection payloads (`$(touch pwned)`, backtick, `x'; DROP`) asserting rejection **and** no side effect — so the regex is *proven to reject*, not assumed. The command applies the regex inline (in the guard above); keep it byte-identical to the validator. The consolidating lint (`scripts/_lib/lint_target_org_guard.py`) enforces the byte-identity and that the `<!-- guard:target-org -->` marker is bound to the guard prose before the Phase 0 sink.

Cache from the response:

- `<sf-username>` = `.result.username` — required for Phase 2 + Phase 3's MCP `run_soql_query` calls (per `gotcha_sf_mcp_username_not_alias.md`, the upstream MCP rejects aliases).
- `<instance-url>` = `.result.instanceUrl` — reused by Phase 6 (success URL construction); avoids a second metadata round-trip.

If the call fails, do NOT emit a separate error — fall through to Phase 2 and let any downstream failure surface as the existing `sf_cli_error` / `instance_url_unknown` paths. This is a soft optimization, not a precondition. Mirrors `/revops:update-sf-campaign-status` Phase 0 (BC-8723) for sibling parity per ADR-015 amendment (BC-10510).

## Phase 1 — Validate input

> **Shared with `build_campaign_payload.py`** (§ Deterministic builder): these are the SAME byte-identical regexes `decide()` applies (returning the `invalid_slug_format` / `invalid_owner_email` / Phase-0 `invalid_target_org` envelope as its `output`) — but they MUST also run **in-context, here, before Phase 2/3**, because the slug/email flow into SOQL string literals at Phase 2/3 and this is their injection guard. Validate in-context first (fail-fast, in order); the builder re-applies the identical patterns as the canonical, eval-tested copy (parity-locked), not as a substitute that would let the guard arrive *after* its SOQL sink.

`--target-org` is validated earlier, in **Phase 0** (its earliest sink) — see there; its `^[a-zA-Z0-9._@-]+$` shell-injection guard runs before the value is interpolated into any `sf` CLI shell-out (Phase 0/5/6). The remaining inputs are checked here (in order; fail-fast on first mismatch):

- `--slug` matches regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`. Otherwise emit `{"error":"invalid_slug_format","slug":"<value>"}` exit 0. This is also a SOQL-injection guard — the slug flows into a SOQL string literal in Phase 2, and the regex character class disallows quotes / backslashes / whitespace.
- `--owner-email` matches regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` (the canonical EMAIL_REGEX, byte-identical to the marketing-side callers `/marketing:plan-campaign` Step 4.2 / `/marketing:import-campaign` Step 5). Otherwise emit `{"error":"invalid_owner_email","value":"<value>"}` exit 0. This is also a SOQL-injection guard — the email flows into a SOQL string literal in Phase 3 (`WHERE Email = '<owner-email>'`), and the regex character class disallows quotes / backslashes / whitespace. An empty or whitespace-only value also fails this regex (rejected as `invalid_owner_email` for a precise diagnostic; security-neutral, since `WHERE Email = ''` is a harmless 0-row lookup that would otherwise fall through to Phase 3's `missing_owner`).

## Phase 2 — Idempotency precheck

> **The verdict is delegated to `build_campaign_payload.py`** (§ Deterministic builder): the command issues the SOQL read below, passes the returned rows in as `sf_state.existing_campaigns`, and the builder's exact `Name == <slug>` match yields the `would_skip_duplicate` verdict + the `duplicate_slug` `output`. The command performs the read; the builder owns the decision.

Call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the `<sf-username>` cached from Phase 0 (literal username). See § Gotchas — `gotcha_sf_mcp_username_not_alias.md`; do NOT pass `DEFAULT_TARGET_ORG`, do NOT pass the raw `--target-org` alias. If Phase 0's cache is empty (the upfront metadata fetch failed), the MCP will reject the alias and the call surfaces as the existing `sf_cli_error` path below — no separate fallback is issued, preserving the "exactly one metadata-fetch per invocation" contract.
- `query`: `SELECT Id FROM Campaign WHERE Name = '<slug>' LIMIT 1`

If the SOQL call ITSELF fails (auth refresh, network, permset, FLS), emit and exit (BC-8727 friction-log F13):

```json
{"error":"sf_cli_error","phase":"idempotency_precheck","detail":"<message from MCP>"}
```

Otherwise, if the result contains any record, emit and exit:

```json
{"error":"duplicate_slug","existing_id":"<Id from response>"}
```

The idempotency check is the load-bearing safety property: `/marketing:plan-campaign` re-runs MUST be no-ops when the slug already exists.

## Phase 3 — Owner lookup

> **Delegated to `build_campaign_payload.py`** (§ Deterministic builder): the command issues the SOQL read, passes the row in as `sf_state.owner` (`null` when 0 rows), and the builder yields `missing_owner` or carries the resolved `OwnerId` into the `would_create` payload.

Call `mcp__plugin_revops_salesforce__run_soql_query` with:

- `usernameOrAlias`: the `<sf-username>` cached from Phase 0 (same resolution as Phase 2).
- `query`: `SELECT Id FROM User WHERE Email = '<owner-email>' AND IsActive = TRUE LIMIT 1`

If the SOQL call ITSELF fails (auth, network, permset), emit and exit (BC-8727 friction-log F13):

```json
{"error":"sf_cli_error","phase":"owner_lookup","detail":"<message from MCP>"}
```

Otherwise, if the result is empty, emit and exit:

```json
{"error":"missing_owner","email":"<owner-email>"}
```

Capture the returned `Id` as `<owner-id>` for Phase 5.

## Phase 4 — Dry-run preview (conditional)

If `--dry-run` is present, emit the preview JSON and exit (NO insert attempted):

```json
{"dry_run":true,"command":"sf data create record --sobject Campaign --values \"Name='<slug>' Vertical__c='<vertical>' Persona__c='<persona>' Offer__c='<offer>' Entity__c='<entity>' StartDate=<launch-date> OwnerId='<owner-id>' Status='Planned'\" --target-org <target-org> --json","payload":{"Name":"<slug>","Vertical__c":"<vertical>","Persona__c":"<persona>","Offer__c":"<offer>","Entity__c":"<entity>","StartDate":"<launch-date>","OwnerId":"<owner-id>","Status":"Planned"},"target_org":"<target-org>"}
```

The preview proves the lookup + payload assembly without mutating SF. Useful for both human dry-run inspection and orchestrator-side integration tests.

## Phase 5 — Insert via SF CLI

> **The `--values` payload is the builder's `payload`** (§ Deterministic builder) — do NOT re-assemble the field-map in-context; use the `would_create` `payload` returned by `--decide` (Name / Vertical__c / Persona__c / Offer__c / Entity__c / StartDate / OwnerId / Status='Planned').

Run via the `Bash` tool:

```bash
sf data create record \
  --sobject Campaign \
  --values "Name='<slug>' Vertical__c='<vertical>' Persona__c='<persona>' Offer__c='<offer>' Entity__c='<entity>' StartDate=<launch-date> OwnerId='<owner-id>' Status='Planned'" \
  --target-org <target-org> \
  --json
```

Parse the `--json` response:

- `status === 0` and `result.id` present → capture `<campaign-id>`, proceed to Phase 6.
- Any other shape → emit and exit:

  ```json
  {"error":"sf_cli_error","detail":<raw upstream JSON>}
  ```

  Do NOT exit non-zero. The soft-fail contract requires exit 0 even on CLI failure.

## Phase 6 — Construct Campaign URL

REUSE the `<instance-url>` cached from Phase 0 — do NOT issue a second metadata-fetch call. The single-call contract is load-bearing per the BC-10510 sibling-parity backport (eliminates the ~200ms-per-invocation round-trip tax that the unscoped pre-cache version paid).

Construct:

```
<instanceUrl>/lightning/r/Campaign/<campaign-id>/view
```

If Phase 0's cache is empty (the upfront metadata fetch failed — auth expired, network), fall through to a deterministic instanceless URL placeholder and still emit success — the campaign WAS created, the URL is convenience metadata:

```json
{"campaign_id":"<id>","campaign_url":"https://lightning.force.com/lightning/r/Campaign/<id>/view","campaign_name":"<slug>","warning":"instance_url_unknown"}
```

## Phase 7 — Success output

Emit a single-line JSON object on stdout:

```json
{"campaign_id":"<id>","campaign_url":"<url>","campaign_name":"<slug>"}
```

This is the canonical success shape. Orchestrators capture `campaign_id` into `manifest.json.salesforce.campaign_id`.

## Error path catalog (all exit 0)

| `error` key | When | Recovery |
|---|---|---|
| `missing_required_flag` | A required flag was omitted | Caller re-invokes with full flag set |
| `invalid_slug_format` | `--slug` fails regex | Caller normalizes slug (per ADR-012 + canonicals lint) |
| `invalid_target_org` | Phase 0 `--target-org` regex `^[a-zA-Z0-9._@-]+$` rejected the input (validated before the Phase 0 shell-out, its earliest sink) | Caller normalizes alias / username to the SF org alias character set; defense against shell injection into Phase 0/5/6. Mirrors `/revops:update-sf-campaign-status` (BC-8723) for sibling parity per ADR-015 amendment (BC-10511 + BC-12623). |
| `invalid_owner_email` | Phase 1 `--owner-email` regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` rejected the input (incl. empty / whitespace-only) | Caller normalizes to a valid email address; defense against SOQL injection into Phase 3's `WHERE Email = '<owner-email>'` literal. Byte-identical to the marketing-side EMAIL_REGEX (`/marketing:plan-campaign` Step 4.2). |
| `duplicate_slug` | Phase 2 SOQL found existing Campaign | Caller treats as idempotent success; the existing `Id` is in `existing_id` |
| `missing_owner` | Phase 3 returned 0 rows | Caller verifies `--owner-email` is an active SF user, OR provisions the user |
| `sf_cli_error` | Phase 2 SOQL failure (auth/network/permset) OR Phase 3 SOQL failure OR Phase 5 returned non-zero status | Caller inspects `detail` field; common causes: SF JWT refresh failure (re-auth `sf`), missing `Substatus__c` field deploy, permset gap, FLS on custom field. Optional `phase` field (`idempotency_precheck` / `owner_lookup` / `insert`) signals which phase failed; absent for Phase 5 backward-compat. |

## Gotchas

- **`usernameOrAlias` must be a literal username.** Per [`memory/gotcha_sf_mcp_username_not_alias.md`](../../../../memory/gotcha_sf_mcp_username_not_alias.md), the upstream `@salesforce/mcp` rejects `DEFAULT_TARGET_ORG` sentinels and alias values for `run_soql_query`. Phase 0's metadata cache resolves `--target-org` to a literal username (via `.result.username`) on the single upfront call — Phase 2 + Phase 3 read from the cache instead of issuing per-call resolutions.
- **Soft-fail is non-negotiable.** A non-zero exit will halt `/marketing:plan-campaign` (BC-8724) mid-scaffold. Every branch in this command emits exit 0.
- **One JSON object, one line.** No pretty-printing, no trailing newlines, no banners. The caller's `jq` pipeline does not expect garbage.
- **No `AskUserQuestion`.** This is an orchestrator-callable command. Missing flags are errors, not prompts.
- **`Substatus__c` is set later, not here.** σ3 status sync (BC-8723 / `/revops:update-sf-campaign-status`) handles the `paused` overlay. This command always inserts `Status='Planned'` with no Substatus.
