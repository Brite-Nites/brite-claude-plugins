# 040. FDA `flow_id` is an opaque identifier; `domain` is explicit, never derived by splitting `flow_id`

**Status:** Accepted
**Date:** 2026-06-28
**Linear:** [BC-13294](https://linear.app/brite-nites/issue/BC-13294) (builders assume DOMAIN-NN flow_id values) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [029](029-fda-canonical-flow-doc-key.md) — **supersedes** its `DOMAIN-NN` *value-format* sub-claim (the `flow_id`-not-`sub_flow_id` *key* decision + the 20-key story canon stand) · [033](033-fda-journey-frontmatter-canon.md) (journey frontmatter, the `domain` kebab field) · [034](034-structural-ratchet-full-surface-gate.md)

## Context

[ADR-029](029-fda-canonical-flow-doc-key.md) settled the FDA flow-doc identity **key**: the canonical key is `flow_id` (+ `parent_issue`), and the tooling is *not* made bilingual with the kebab `sub_flow_id` deviation — the two deviation repos converge instead (BC-13152). That decision is correct and stands.

Riding along in ADR-029's title and prose was a second, narrower claim: that the `flow_id` **value** has the shape `DOMAIN-NN` (e.g. `PROD-08`). That shape was never *reasoned about* as a deliberate constraint — it was simply the style the two canonical repos (brite-base, brite-roster) happened to use. BC-13294 surfaced that the value format is, in fact, **not** uniform across FDA consumers:

| Repo | `flow_id` value style | `domain` field |
|---|---|---|
| brite-base (427), brite-roster (41) | `DOMAIN-NN` — `PROD-08` | `PROD` (UPPERCASE code) |
| **brite-sites** (28 stories + 9 journeys) | **slash-form** — `admin-panel/layout-and-auth` | `admin-panel` (kebab) |

brite-sites carries the **correct key** (`flow_id`) — this is a *value-format* divergence, a different axis from ADR-029's key convergence (BC-13152) and from the `sub_flow_id` key drift.

**The enforcement stack already treats `flow_id` as opaque.** Verified empirically on the brite-sites checkout (2026-06-28):

- `run_fda_ci_audit.py <brite-sites>` → **✓ all gates pass** (28 stories + 9 journeys, every `flow_id` slash-form). The CI runner + `/flow:audit` Phase-B derive domains from `docs/product/flows/<domain>/` **directory names** (`build_audit_report._domains` → `flows.iterdir()`), and scope by `doc.stem` — never by parsing `flow_id`.
- `flow_frontmatter_lint.py` checks key **presence**, not value **format** (its own comment: *"values are BC-12692's territory"*).
- `regenerate-flow-index.mts` reads `flow_id` as an opaque string and `domain` from the **explicit** `domain` field; its `numericSuffix` already **gracefully degrades** (`MAX_SAFE_INTEGER` → `localeCompare`) for a non-numeric suffix — a working opaque-id precedent already shipping to consumers.
- `build_journey_frontmatter.py` reads `domain` from the scaffold-log frontmatter, not from `flow_id`.

The `DOMAIN-NN` *value-format* assumption survived in exactly **one** place: the two deterministic frontmatter **builders**. `build_story_frontmatter.py` validates `--flow-id` against `_FLOW_ID_RE = ^[A-Za-z]+-\d+\Z` (exit 2 on slash-form) and — the load-bearing coupling — derives `domain = flow_id.split("-", 1)[0]`, which on `admin-panel/layout-and-auth` yields the garbage `"admin"` while the true domain `admin-panel` sits right there as the directory name *and* the explicit `domain:` field. `build_journey_frontmatter.py` shares the `_FLOW_ID_RE` shape and `int()`s the suffix in its natural-sort. (The dormant `normalize-fda-frontmatter.mjs` skeleton also splits `-`, but it is a documented no-op — ADR-029 — and does not run.)

The builders are **latent**, not broken-in-production: they only run on fresh scaffolding (`/flow:add-domain`, re-scaffold, frontmatter re-stamp). brite-sites is already built, so they don't run there today. The trap springs the day someone runs `/flow:add-domain` **on brite-sites** → the journey builder exits 2 (confirmed in BC-13291, which sidestepped the builder with a standalone migrator *because* it couldn't run). The frontmatter lint accepted brite-sites all along precisely because it is key-level, not value-level — which is why this slid through silently.

So the builders are not enforcing a canon. They are the **anomaly**: the one place that re-derives a fact (`domain`) that is already explicit everywhere else in the system. The real question BC-13294 poses is not "should we bless a second value format" but "should `flow_id` ever have been treated as a parseable structure at all."

## Decision

**`flow_id` is an opaque identifier. `domain` is an explicit fact — the `docs/product/flows/<domain>/` directory name, mirrored in the doc's `domain` front-matter field and the scaffold-log's `domain` / `domain_code` fields. No FDA tooling derives `domain` (or any other fact) by parsing the internal structure of `flow_id`.**

Consequences of the invariant:

- **Both `DOMAIN-NN` and slash-form are valid `flow_id` values**, because nothing parses `flow_id`'s shape. `DOMAIN-NN` remains the default style a fresh scaffold emits; slash-form (`<domain>/<flow-slug>`) is equally canonical. There is no enumerated list of "allowed formats" to keep in sync — an opaque id has no format to violate. The only constraint on a `flow_id` value is a **safe character set** (so it can never malform emitted YAML), not a shape.
- **The deterministic builders are brought into line with the rest of the system** (this PR):
  - `build_story_frontmatter.py` — `_FLOW_ID_RE` relaxes from `^[A-Za-z]+-\d+\Z` to a safe-charset slug accepting both styles; `domain` comes from the scaffold-log's explicit `domain_code` front-matter field (per [`SCHEMA.md`](../../plugins/flow-architecture/templates/.flow/scaffold-log/SCHEMA.md), the required field that "matches `master-flow-inventory`"), with an optional `--domain` override and a legacy `flow_id`-split fallback only when `domain_code` is absent from an old scaffold-log; scaffold-log table-row matching becomes shape-agnostic (exact `flow_id` token, not a `DOMAIN-NN` regex extraction).
  - `build_journey_frontmatter.py` — `_FLOW_ID_RE` relaxes to the same safe charset; its natural-sort `_natural_key` degrades gracefully for a non-numeric suffix (mirroring the shipping `regenerate-flow-index.mts` `numericSuffix`) instead of crashing on `int("auth")`.
  - The change is **backward-compatible by construction**: for a `DOMAIN-NN` input the builders emit byte-identical output (`domain_code: PROD` == `split("PROD-08")` == `PROD`), so the existing golden fixtures do not churn. New slash-form fixtures + goldens lock the opaque path.
- **This is the spec for BC-12692's value check.** A future value-format gate validates `flow_id` to a **safe character set**, not a `DOMAIN-NN` shape, and reads `domain` from the explicit field. The frontmatter lint already defers value-format to BC-12692 — this ADR is what "value-format" means.
- **No consumer-repo churn.** brite-sites keeps its readable slash-form; brite-base / brite-roster keep `DOMAIN-NN`. Neither is forced to converge on the other.

## Consequences

- ADR-029's **key** decision (`flow_id` not `sub_flow_id`; the plugin is single-key, not bilingual) and its **20-key story canon** are untouched and still cited by `flow_frontmatter_lint.py`, `run_fda_ci_audit.py`, the builders, `audit.md`, and `artifact-gate-pattern.md`. Only ADR-029's `DOMAIN-NN` *value-format* sub-claim is superseded; its `Status` line + the relevant clause are amended to point here.
- A `/flow:add-domain` (or re-scaffold / re-stamp) run on **brite-sites** now succeeds end-to-end instead of exiting 2 — the latent trap BC-13294 documented is closed at its root, not merely documented.
- The plugin conforms to the invariant it declares: the ADR and the builder fix ship in **one PR**, so there is no window where the doc says "opaque" while the code splits `flow_id`.
- `scripts/` is cache-relevant, so this PR bumps `plugins/flow-architecture/.claude-plugin/plugin.json` + the matching `.claude-plugin/marketplace.json` entry (BC-6000 same-commit rule), and appends a uniquely-named `validate.sh` section rather than extending the prime-tick chain.

## Out of scope (flagged, not actioned)

- **The dormant `normalize-fda-frontmatter.mjs`** still contains a `flowId.split('-')[0]`. It is a no-op skeleton (ADR-029) that never runs; fixing dead code is left to whoever ever activates it. Recorded here so a future activator doesn't reintroduce the derivation.
- **The Linear-issue-title axis** (`verify-linear-references.mts`, `lib/fda-title.mts`, `lib/flow_linear_lint.py`) parses Linear **issue titles** as `DOMAIN-NN:` / `[Discipline] DOMAIN-NN`. That is a **separate** identity surface (the Linear title convention, not the flow-doc `flow_id` value), it is not gated by the CI audit, and it reads `flow_id` itself opaquely. A title-convention decision for slash-form repos is a distinct follow-up, not part of this value-format ADR.

## Rejected alternatives

- **Converge brite-sites → `DOMAIN-NN`** (the BC-13152 move for the *key* drift). Dominated by the data: brite-sites is already green under full FDA enforcement, slash-form is readable and internally self-consistent (docs + journeys + Linear milestone descriptions all use it), and the value-format axis — unlike the key axis — has no tooling that actually requires `DOMAIN-NN`. Rewriting every `flow_id` across 28 stories + 9 journeys + INDEX + Linear refs to destroy a working convention buys nothing. Rejected.
- **Bless slash-form as a sanctioned *second* enumerated format** (widen the builders to recognize two shapes). Keeps the "`flow_id` has a recognized shape" framing and so commits the tooling to enumerate and keep two formats in sync forever — the maintenance surface ADR-029 explicitly rejected for the *key* ("not bilingual"). Treating `flow_id` as opaque subsumes "accept slash-form" without sanctioning format pluralism: there is one rule (safe charset), not two formats. Rejected in favour of the opaque invariant.
- **Accept + leave documented** (status quo — the disposition BC-13294 itself parked). Records the trap but leaves the builders latent-broken; a future `/flow:add-domain` on brite-sites still exits 2. The coupling (`domain = split(flow_id)`) is a one-line root cause with a byte-identical fix, so documenting-without-fixing trades a trivial change now for a cold rediscovery later. Rejected.
- **Amend ADR-029 in place** rather than supersede. The opaque-id + explicit-domain stance is a substantive architectural decision with its own context (the slash-form repo), its own consequences (the builder refactor, the BC-12692 spec), and a citable home Lane A / future gate authors need — not a typo-fix. A standalone superseding ADR (the 038→039 house pattern) preserves ADR-029's audit trail and keeps every existing ADR-029 citation (all about the *key*) valid. Rejected in favour of supersession.
