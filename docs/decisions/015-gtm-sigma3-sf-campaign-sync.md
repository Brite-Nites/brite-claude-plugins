# 015. GTM σ3 — Salesforce Campaign auto-create + status sync via revops plugin commands

**Status:** Accepted (2026-05-13); **amended 2026-05-19** — implementation surface respec'd from MCP write tools to slash commands; design intent unchanged. **Amended 2026-05-22** — σ3 sibling-parity backport pattern locked across both SF-write commands (BC-10510 + BC-10511).
**Date:** 2026-05-13 / amended 2026-05-19 / amended 2026-05-22
**Linear:** [BC-8717](https://linear.app/brite-nites/issue/BC-8717) (`/revops:create-sf-campaign`), [BC-8723](https://linear.app/brite-nites/issue/BC-8723) (`/revops:update-sf-campaign-status`), [BC-8752](https://linear.app/brite-nites/issue/BC-8752) (trigger automation), [BC-10510](https://linear.app/brite-nites/issue/BC-10510) (Phase 0 cache backport), [BC-10511](https://linear.app/brite-nites/issue/BC-10511) (`--target-org` regex backport)
**Related ADRs:** [ADR-007](007-revops-plugin-design.md), [ADR-013](013-gtm-three-layer-split.md), [ADR-014](014-gtm-salesforce-portfolio-rollup.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3 (SF box) + §3.6 (worked example Step 7), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.5 + §7.8

## Context

The D4 sub-issue template (per ADR-012 + design doc Section 2) has sub-issue #4 "Salesforce setup" — historically a manual step where Corinne logged into SF and created the Campaign record by hand. Manual-step-often-forgotten was a known failure mode.

After ADR-014 (SF = portfolio rollup home), accurate SF state became load-bearing: missing SF Campaign records mean missing rollup rows. The original O11 question (Salesforce vs Linear orchestration) resolved to **σ3** — keep ADR-013's 3-layer split, but automate the SF Campaign create + status sync.

## Decision Drivers

- **Manual sub-issue #4 was high-defect** — every forgotten SF Campaign created portfolio rollup gaps.
- **revops:salesforce MCP** (per ADR-007) already exists with run_soql_query + metadata-deploy + run_apex_test (read-only / metadata surfaces). Per-record writes are NOT served by upstream `@salesforce/mcp@0.30.5` (Salesforce-published npm package) — adding write tools to that namespace would require a new Brite-owned MCP server. With only two write surfaces in scope (T2-E + T2-F), slash commands sit below the threshold where a fresh MCP server earns its boilerplate.
- **Soft-fail required** — SF write failure cannot halt `/marketing:plan-campaign` (BC-8724); operator must be able to scaffold even when SF is down (manifest gets `campaign_id: null`).
- **Status transitions must auto-fire** — sub-issue 6 close → SF "In Progress"; sub-issue 8 close → SF "Completed". Operators forget manual status flips; portfolio rollup needs accurate state.
- **`paused` overlay** doesn't fit in SF's single-valued Status field — requires a custom `Substatus__c` field.

## Decision

**σ3 = auto-create SF Campaign at scaffold time + auto-sync status on Linear transitions**, via two new slash commands in the revops plugin (each calling upstream `mcp__plugin_revops_salesforce__run_soql_query` for prechecks + `sf` CLI via Bash for the write):

### 1. `/revops:create-sf-campaign --slug --entity --vertical --persona --offer --year --month --owner-email --launch-date [--target-org] [--dry-run]`

Creates SF Campaign with `Name=slug`, `Vertical__c`, `Persona__c`, `Offer__c`, `Entity__c`, `Status="Planned"`, `StartDate=launch_date`, `OwnerId` from owner_email lookup. Called by `/marketing:plan-campaign` Step 7b (BC-8724) via the Skill tool. Returns single-line `{ campaign_id, campaign_url, campaign_name }` JSON on stdout for manifest.json. Soft-fails (exit 0 with structured `{ error: "..." }` JSON) on duplicate slug, missing owner, invalid slug format, missing required flag, or `sf` CLI error.

### 2. `/revops:update-sf-campaign-status --slug --linear-status --linear-substatus`

Looks up SF Campaign by `Name=slug`. Maps Linear status → SF Campaign Status per the locked table:

| Linear label | SF Campaign Status | SF Substatus__c |
|---|---|---|
| `planning` | Planned | — |
| `active` | In Progress | — |
| `active` + `paused` | In Progress | Paused |
| `completed` | Completed | — |
| `killed` | Aborted | — |

Soft-fails (returns `warning: campaign_not_found`) when SF Campaign doesn't exist.

### 3. Trigger automation (BC-8752 / T2-FA, audit-fix)

Without trigger wiring, the slash command from #2 only fires on manual operator invocation — defeating σ3's intent. BC-8752 wires:

- `launch-campaign` final phase → `/revops:update-sf-campaign-status --slug=<slug> --linear-status=active` after EB launch
- `campaign-debrief` Workflow 4 (post-append) → `/revops:update-sf-campaign-status --slug=<slug> --linear-status=completed`
- `/marketing:sync-campaign-status` new command for manual `paused` / `killed` triggers (which don't auto-fire from sub-issue closes)

### 4. New SF custom field

`Substatus__c` (picklist `{null, Paused}`) — required because SF Status is single-valued and the O1 `paused` label is a stackable overlay on `active`.

## Consequences

- Sub-issue #4 ("Salesforce setup") redefined: post-σ3 it's SF Campaign reconciliation (verify auto-create succeeded) + audience members (CampaignMember records linked from EB lead suppress export) + Opportunity links. Not the creation step anymore.
- Plugin command surface gains `/marketing:sync-campaign-status` as the manual-trigger fallback for paused/killed transitions.
- `learnings.md` regen path (in `campaign-debrief`) gains a status-sync call after the append.
- Plugin filesystem (`manifest.json`) carries `salesforce.campaign_id` as the cross-system identity anchor.
- ADR-014's portfolio rollup depends on accurate SF state; σ3 is the upstream mechanism that delivers it.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Keep sub-issue #4 manual (no σ3) | Manual step is high-defect; missing SF Campaigns break ADR-014 rollup |
| Linear webhook → SF status sync (no plugin call sites) | Webhook infrastructure doesn't exist; adds runtime dep that's harder to reason about than skill-call-site triggers |
| Single mega-command `/revops:sync-sf-campaign` instead of create + update separately | Creates ambiguity about idempotency (insert vs update); two commands have crisper semantics |
| Skip Substatus__c, use prose in Description field | Not filterable in SF list views; ADR-014's "include paused, exclude killed" filter would have no field to query |
| **Add `create_sf_campaign` + `update_sf_campaign_status` as MCP write tools** (original ADR-015 framing, 2026-05-13) | `mcp__plugin_revops_salesforce__*` is upstream `@salesforce/mcp@0.30.5` (Salesforce-published npm package) — Brite cannot extend it without forking. Two write surfaces is below the ~5-tool threshold where a Brite-owned MCP server earns its boilerplate. Slash commands compose naturally with `/marketing:plan-campaign` via the Skill tool. Respec'd 2026-05-19. |
| Stand up a new Brite-owned `revops:campaign` MCP server | L-sized + rename cascade for two write tools; below the threshold. Path 1 above. |

## Amendment 2026-05-22 — σ3 sibling-parity backport pattern (BC-10510 + BC-10511)

Two patterns introduced by `/revops:update-sf-campaign-status` (BC-8723, shipped 2026-05-19 via PR #331) are backported to `/revops:create-sf-campaign` so both σ3 SF-write commands behave identically on metadata resolution and input validation. The amendment locks the patterns as canonical: both commands MUST share them, and any future σ3 SF-write sibling MUST adopt them.

### Pattern 1 — Phase 0 metadata cache (BC-10510)

Both commands call `sf org display --target-org <target-org> --json` EXACTLY ONCE at command start (skipping only on `--dry-run`). The response's `.result.username` and `.result.instanceUrl` are cached for the lifetime of the invocation. Downstream phases consume the cache:

- `<sf-username>` → Phase 2 + Phase 3 MCP `run_soql_query` calls (the upstream MCP rejects aliases — see `memory/gotcha_sf_mcp_username_not_alias.md`)
- `<instance-url>` → success-URL construction (avoids a second metadata round-trip)

The single-call contract collapses 2+ metadata fetches into 1 (saves ~200ms per σ3 fire). It is auditable: a contract test asserts `body.count("sf org display") == 1` (count-based per BC-8729 round-2 review pattern, NOT substring-absence — per `memory/gotcha_soql_substring_absence_assertions_fragile.md`).

If Phase 0's `sf org display` itself fails, no separate error is emitted — Phase 2/3 calls surface as the existing `sf_cli_error` path, and Phase 6 falls back to the deterministic instanceless URL placeholder with `warning: instance_url_unknown`. The cache is a soft optimization, not a precondition.

### Pattern 2 — `--target-org` regex shell-injection guard (BC-10511)

Both commands validate `--target-org` (when explicitly supplied) against regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set) in **Phase 0, before any shell-out**. Mismatch emits `{"error":"invalid_target_org","value":"<value>"}` exit 0 — soft-fail per the σ3 contract.

> **BC-12623 ordering correction.** The guard originally landed in Phase 1 — *after* Phase 0's `sf org display --target-org "<target-org>"` metadata fetch, which is `--target-org`'s **earliest** sink. The `"<value>"` double-quoting blocks bare metacharacters but not `$(...)` / backtick command substitution, so the value reached a shell before its guard. BC-12623 hoists the (unchanged) regex guard ahead of the Phase 0 shell-out in **both** commands — purely an ordering fix, no regex change — making the "before any shell-out" claim above true. The guard sits *above* Phase 0's `skip on --dry-run` gate so validation still runs on the dry-run path.

The character class is deliberately tight: blocks shell metacharacters (`$`, backticks, `;`, `&`, `|`, `>`, `<`, quotes, whitespace, parentheses) while accepting every character SF aliases and usernames legitimately use (alphanumerics, dot, underscore, at, hyphen). `--target-org` flows into `sf` CLI invocations in Phase 0 + Phase 5 + (pre-backport) Phase 6, so the guard is a defense-in-depth for shell-injection.

### Audit invariants (contract-tested in `plugins/revops/tests/test_create_sf_campaign_contracts.py`)

1. Phase 0 section header present + both cache variables (`<sf-username>`, `<instance-url>`) documented verbatim
2. EXACTLY one `sf org display` invocation in the command body (count-based)
3. `--target-org` regex appears verbatim in the command body
4. `--target-org` regex is **byte-identical** to the sibling `/revops:update-sf-campaign-status` regex — sibling drift surfaces immediately on either side's test run
5. `invalid_target_org` appears in the soft-fail error-key roster (7 keys total now: `missing_required_flag`, `invalid_slug_format`, `invalid_target_org`, `invalid_owner_email`, `duplicate_slug`, `missing_owner`, `sf_cli_error` — `invalid_owner_email` added by BC-12594)
6. **(BC-12623 → BC-12638)** the `--target-org` guard precedes its earliest sink. Originally locked per-file by `test_target_org_guard_precedes_phase_0_sink` (emit-JSON anchored). **Superseded** by the repo-wide consolidating lint `scripts/_lib/lint_target_org_guard.py` (BC-12638), which subsumes those per-file tests: it requires a standalone `<!-- guard:target-org -->` marker before the earliest sink **with the canonical regex documented in the window between the marker and the sink** (binding the marker to the real guard prose — a flag-table mention before the marker or a cross-reference after the sink does not satisfy it). The per-file tests are now deleted; the lint catches the same relocate/delete regressions idiom-agnostically across both σ3 commands *and* the marketing siblings. See the 2026-06-07 amendment.

The byte-identity test (#4) is the canonical lock: a unilateral edit to one sibling's regex fails the OTHER sibling's test — neither command can drift in isolation. Identical contract tests live in `test_update_sf_campaign_status_contracts.py`.

### Future σ3 sibling #3

If a third σ3 SF-write command is added, it MUST:

- Adopt Pattern 1 (Phase 0 metadata cache, single `sf org display` invocation).
- Adopt Pattern 2 (`--target-org` regex with the same character class).
- Adopt Pattern 3 (guard-precedes-sink ordering — `<!-- guard:target-org -->` marker before the earliest sink; see the 2026-06-07 amendment).
- Add a byte-identity contract test against this canonical pair.
- Be listed in this amendment's Linear refs.

The ~5-tool threshold (per the 2026-05-19 amendment for when a Brite-owned MCP server earns its boilerplate) still bounds the slash-commands-vs-MCP-server decision — but inside the slash-commands choice, σ3 siblings MUST be uniform.

## Amendment 2026-06-07 — guard-precedes-sink generalized repo-wide (BC-12637)

**Linear:** [BC-12637](https://linear.app/brite-nites/issue/BC-12637) (epic), [BC-12638](https://linear.app/brite-nites/issue/BC-12638) (coverage + consolidating lint), [BC-12639](https://linear.app/brite-nites/issue/BC-12639) (ADR-028 behavioral eval). Spawned by [BC-12623](https://linear.app/brite-nites/issue/BC-12623) (PR #446).

BC-12623 fixed the `--target-org` guard-after-sink window in the **two σ3 commands only**. A systematic repo-wide sweep (BC-12637) then found the premise of the "operator commands" worry was overstated **and** that the σ3 pair was not the whole surface:

- **Operator-facing revops commands are NOT in scope.** `deploy-prod` / `deploy-sandbox` / `doctor` / `setup-sandbox` / `post-deploy-runbook` **hardcode** `--target-org brite-prod` / `brite-sandbox` as literal aliases — they accept no `--target-org` input flag, so there is no value to inject (guarding a string constant is dead code). `post-deploy-runbook`'s `sf apex run --target-org <alias>` is an operator copy-paste runbook snippet, not a command-driven sink.
- **Two MARKETING commands were the real, previously-missed finding.** `/marketing:offer-performance` and `/marketing:portfolio-snapshot` interpolate a placeholder `--target-org "<target-org>"` from a `--target-org` flag **and both carried the identical guard-after-sink defect** (Phase 0 `sf org display` sink before the Phase 1 guard). Both are hoisted per Pattern 3. Their failure idiom is **hard-fail exit non-zero `ERROR:`** (truncate-80 + strip control bytes), *not* σ3's soft-fail JSON — idiom is per-command; only the guard *placement* and the regex are uniform.

### Pattern 3 — guard-precedes-sink ordering (generalized)

Any command (in **any** plugin) that interpolates a **non-literal** `--target-org` (a `<placeholder>` / `$var`, not a literal alias) into an executable `sf` shell-out MUST place its `^[a-zA-Z0-9._@-]+$` shape guard **before** the value's earliest sink — and above any skip-on-dry-run / cache-hit gate ("validate-then-resolve"). The guard is anchored by a standalone `<!-- guard:target-org -->` marker **bound to the guard prose**: the canonical regex must appear in the window *between the marker and the earliest sink* (idiom-agnostic — it generalizes across σ3's soft-fail-JSON and marketing's hard-fail-`ERROR:` contracts, where BC-12623's emit-JSON anchor could not, while staying positionally precise so a flag-table mention before the marker or a cross-reference after the sink cannot satisfy it). A command whose bash-fenced non-literal `--target-org` is *not* a real command-driven sink declares a non-silent, sink-scoped `<!-- guard:target-org:exempt <reason> -->`.

### Enforcement — consolidating lint subsumes the per-file ordering tests

`scripts/_lib/lint_target_org_guard.py` (wired into `validate.sh`) is the single repo-wide gate: for every `plugins/*/commands/*.md` with an executable non-literal `--target-org` sink (detected inside ` ```bash `/`sh`/`shell`/`~~~`/unlabeled fences, `=`- or whitespace-separated, quote-tolerant), it asserts a standalone `<!-- guard:target-org -->` marker precedes the earliest sink **and** the canonical regex is bound in the marker→sink window. Because the bind is positional, it catches the regressions the deleted per-file tests caught — relocating the guard prose below the sink, or deleting it while a regex mention survives elsewhere — **idiom-agnostically across both σ3 commands and the marketing siblings** (verified by re-running those exact mutations against the real σ3 file). It thus **subsumes** BC-12623's two bespoke per-file `test_target_org_guard_precedes_phase_0_sink` tests (now deleted) and fires on any *future* non-literal passthrough in either plugin — the systematic end to the BC-10511 → BC-12594 → BC-12623 whack-a-mole. The exemption is **sink-scoped** (an exempt marker governs only the earliest sink it precedes — it cannot mask a later real sink).

### ADR-028 behavioral eval (depth)

BC-12623's ordering test was a structural markdown-grep *proxy* — it proved placement, never that the guard *rejects* `$(...)`. `plugins/revops/scripts/validate_target_org.py` extracts the σ3 guard as a deterministic, side-effect-free validator; `test_validate_target_org.sh` (in `validate.sh`) executes it against real injection payloads asserting rejection **and** no side effect. First security worked example of [ADR-028](028-skill-engineering-discipline.md)'s behavioral-eval tier. (σ3-only — cross-plugin distribution blocks a marketing-shared validator file.)

### Audit-invariant roster drift-guard

Deferred to [BC-12640](https://linear.app/brite-nites/issue/BC-12640): a machine-check that the audit-invariant error-key roster above (7 keys) matches the actual command catalogs — would have auto-caught the "6 keys → 7" staleness BC-12623 fixed by hand.

## Cross-references

- README §3.6 — worked example Step 7 (SF auto-create at scaffold)
- README §7 — Tier 2 BCs in critical path
- Design doc §7.5 — σ3 lock
- Design doc §7.8 — σ3 scope expansion + status mapping table
- ADR-014 — the consumer of σ3's outputs
- `memory/gotcha_sf_mcp_username_not_alias.md` — the upstream constraint Pattern 1 routes around
- `memory/gotcha_soql_substring_absence_assertions_fragile.md` — why audit invariant #2 is count-based, not absence-based
- `memory/session_bc_8723.md` — full session log of the BC-8723 ship that established the patterns being backported here
