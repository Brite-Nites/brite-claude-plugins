# Source 4 — `list-building` reads Snowflake audience views

**Linear:** [BC-11928](https://linear.app/brite-nites/issue/BC-11928) (design) → [BC-11929](https://linear.app/brite-nites/issue/BC-11929) (implementation)
**Status:** Proposed
**Date:** 2026-05-28
**Depends on:** [ADR-021](../decisions/021-marketing-snowflake-access.md) (Snowflake-access mechanism), [`plugins/marketing/references/audience-views.md`](../../plugins/marketing/references/audience-views.md) (allowlist)
**Affects:** [`plugins/marketing/skills/list-building/SKILL.md`](../../plugins/marketing/skills/list-building/SKILL.md)

## Scope

This design specifies the invocation contract for a fourth input source on the `list-building` skill — direct Snowflake audience-view query — eliminating the manual CSV-export step that Source 2 (dbt audience CSV) requires today. Implementation is [BC-11929](https://linear.app/brite-nites/issue/BC-11929); this doc is the spec the implementation ships against.

Out of scope:

- New audience-view definitions (Corinne / GTM Intelligence owns view design)
- Snowflake credential rotation (handled by `bw-run.sh` per [ADR-010](../decisions/010-plugin-secret-config-canon.md))
- Changes to Sources 1–3 (tam-output / dbt-CSV / manual-CSV remain as-is)

## 1. Invocation contract

New flag added to `list-building` SKILL.md § Invocation flags:

| Flag | Default | Notes |
|---|---|---|
| `--snowflake-audience <view_name>` | (Source 4 mode) | Direct Snowflake query against a view from the catalog. Mutually exclusive with `--input-dir`, `--audience-csv`, `--input-csv`. View name MUST match `^[a-z][a-z0-9_]*$` (allowlist-validated). |
| `--snowflake-where <predicate>` | (optional) | SQL WHERE-clause fragment appended to the view query. Validated against an allowlist of column references (see § Predicate validation). |
| `--snowflake-limit N` | (optional, defaults to cost-gate behavior in § 5) | Caps the query's row return. When set and `N >= row count`, cost gate is skipped (caller pre-approved). When `N < row count`, skill stops with a count overflow — does NOT silently truncate. (Mirrors Source 2's `--max-records` semantics.) |

Mutual exclusion rules (Workflow 1 step 0 validation): at most one of `--input-dir`, `--audience-csv`, `--input-csv`, `--snowflake-audience` may be passed. Passing two or more HALTS with `EX-MUTUAL-EXCLUSION` and lists the conflicting flags.

### View-name validation

The view name is validated against the catalog at [`plugins/marketing/references/audience-views.md`](../../plugins/marketing/references/audience-views.md). Two layers, with the wrapper as the **authoritative** gate:

1. **Skill (advisory).** Before invoking the wrapper, the skill reads `audience-views.md`, parses the deterministic catalog block (first table immediately following the exact heading `## Catalog` — if no table or multiple matching tables, the parse FAILS and the skill HALTs), and rejects view names not in column 1. This is an early-fail UX check.
2. **Wrapper (authoritative).** The wrapper at `plugins/marketing/scripts/snowflake/query_audience.py` re-derives the allowlist independently and rejects out-of-allowlist names with its own structured-stderr error. The skill's advisory check is an optimization; the wrapper is the security boundary.

Both layers MUST reject view names that don't match `^[a-z][a-z0-9_]{0,62}$`. Per [ADR-021](../decisions/021-marketing-snowflake-access.md), this two-layer pattern is the SQL-injection guardrail for the operator-supplied identifier; arbitrary view names cannot reach Snowflake.

**Future work.** Markdown-table parsing is fragile under doc-reformatting tools. [BC-11929](https://linear.app/brite-nites/issue/BC-11929) follow-up: extract the catalog table into a typed data file (`plugins/marketing/references/audience-views.yaml` or `.json`), have `audience-views.md` render from / link to that source, and have both skill + wrapper read the typed file. Adds CI lint to detect catalog ↔ `brite-data-platform/main` drift.

### Predicate validation

`--snowflake-where` is allowlist-validated against a strict grammar — a deliberately narrow surface, since this string flows into SQL. The implementation MUST use `sqlglot` to parse the predicate to an AST and then walk the AST asserting the allowlist below; do NOT use `sqlparse` (which is a tokenizer, not a validator, and has known misparse issues on adversarial input).

**Grammar (AST-level allowlist).**

- The predicate parses as a single `WHERE` clause expression.
- Top-level structure: one or more `<comparison>` joined by `AND` or `OR`. When the predicate mixes `AND` and `OR`, every sub-expression MUST be parenthesized — `a = 1 AND b = 2 OR c = 3` is REJECTED; `(a = 1 AND b = 2) OR c = 3` is accepted. Forces explicit precedence; eliminates the boolean-precedence ambiguity class.
- A `<comparison>` is exactly one of:
  - `<column> <op> <literal>`
  - `<column> IS NULL`
  - `<column> IS NOT NULL`
  - `<column> IN ( <literal> [, <literal>]{0,99} )` — IN list MUST contain 1–100 literals (cap protects against COUNT-probe DoS); NOT IN follows the same shape
  - `<column> LIKE <quoted-string> ESCAPE '\'` — the `ESCAPE '\'` clause is REQUIRED (no implicit escape semantics); the literal value MUST NOT contain unescaped `_` or `%` — operators who want bare wildcards explicitly use `LIKE '...\_...' ESCAPE '\'` etc.
- `<column>` is a bare unquoted identifier matching `^[a-z][a-z0-9_]{0,62}$` (ASCII-only, no dotted refs, no quoted identifiers, no schema qualifications). After parsing, the identifier MUST match (case-sensitive) one of the columns documented for the target view in `audience-views.md`. Unicode confusables, smart quotes, and bidi marks all FAIL the regex.
- `<op>` ∈ `{=, !=, >, >=, <, <=}`. `=` and `!=` with a `NULL` literal are REJECTED (use `IS [NOT] NULL` — `col = NULL` always evaluates UNKNOWN in SQL and silently filters everything).
- `<literal>` is exactly one of:
  - **Quoted string** — single-quoted; embedded single quotes MUST be escaped as `''` (no backslash escapes); contents MUST match `^[\x20-\x7e\t]*$` (printable ASCII + tab — no newlines, no NUL, no high-bit, no control characters)
  - **Integer** — matches `^-?[0-9]{1,18}$`
  - **Float** — matches `^-?[0-9]{1,18}\.[0-9]{1,9}$`
  - **NULL** (only allowed in `IS [NOT] NULL`, see above)

**Rejected.** Any AST node not in the grammar above — subqueries, function calls (including `LOWER`, `UPPER`, `CAST`, `::`), arithmetic operators, CASE expressions, BETWEEN, EXISTS, multi-statement chains, comments (`--`, `/*`), semicolons (anywhere), backslash escapes in string literals.

**Implementation contract.** The wrapper at `plugins/marketing/scripts/snowflake/query_audience.py` exposes a `validate_predicate(view, predicate) -> Predicate | raises ExPredicateValidation` function. The validator MUST be the single chokepoint — the skill never passes a predicate string to the wrapper without it going through this function. If validation fails, HALT with `EX-PREDICATE-VALIDATION` and the rejected AST node (with its sqlglot type) quoted in the error.

**Eval coverage required for [BC-11929](https://linear.app/brite-nites/issue/BC-11929).** At minimum:

1. `1=1 OR business_category='commercial'` → REJECT (LHS-integer rule)
2. `business_category = NULL` → REJECT (`= NULL` rule)
3. `email LIKE '%admin%'` → REJECT (missing ESCAPE; bare `%`)
4. `email LIKE '\_admin' ESCAPE '\'` → ACCEPT
5. `id IN (1,2,...,150)` (151 elements) → REJECT (cap rule)
6. `a = 1 AND b = 2 OR c = 3` → REJECT (mixed AND/OR without parens)
7. `"work_email" = 'x'` → REJECT (quoted identifier rule)
8. `email = 'O''Brien'` → ACCEPT (escaped single quote)
9. `email = 'newline\ninjection'` → REJECT (literal content rule)
10. `LOWER(email) = 'x'` → REJECT (function call rule)
11. `email::text = 'x'` → REJECT (cast operator rule)
12. `EXISTS (SELECT 1)` → REJECT (subquery rule)

## 2. Per-source EB-exclusion routing

Source 4 runs EB-exclusion. The audience views (per audience-views.md) filter on quality + golden-record state but do **not** suppress against EB workspaces — that suppression is the consuming skill's job. The routing table in SKILL.md § Methodology > Per-source EB-exclusion routing gains a row:

| Source | Upstream EB-exclusion? | This skill runs EB-exclusion? |
|---|---|---|
| tam-mapping output (`--input-dir`), mtime ≤ 7 days | Yes | **No — skip** |
| tam-mapping output (`--input-dir`), mtime > 7 days | Yes (stale) | **No by default; user-explicit override path runs Workflow 2** |
| dbt audience CSV (`--audience-csv`) | No | **Yes** |
| Manual CSV (`--input-csv`) | No | **Yes** |
| **Snowflake audience (`--snowflake-audience`)** | **No** | **Yes** |

The Source 4 row matches the Source 2 (`--audience-csv`) and Source 3 (`--input-csv`) rows because the upstream state is symmetric: the view filters for quality but not for prior outbound contact.

When `audience_commercial_outreach` ships ([BC-2314](https://linear.app/brite-nites/issue/BC-2314)) and its definition includes EB suppression baked in (TBD per Corinne's design), this row should be revisited.

## 3. Resume detection

Existing resume logic reads `<output-dir>/source.json` first to determine the active source, then walks file existence in order: `source.json` → `suppression_set.json` → `enriched.jsonl` → `verified.jsonl` → `enriched_leads.csv`.

Source 4 extends `source.json` with a `source` field value of `snowflake-audience` plus four fields capturing query intent:

```jsonc
{
  "source": "snowflake-audience",
  "view": "audience_commercial_outreach",
  "where": "business_category = 'commercial' AND data_quality_score >= 80",
  "limit": 5000,
  "query_hash": "sha256:abc123...",
  "row_count": 4327,
  "exec_time_ms": 1840
}
```

`query_hash` is `sha256(json.dumps({"view": view, "where": where, "limit": limit}, sort_keys=True, separators=(",", ":")).encode("utf-8"))`. Use JSON serialization (not a delimiter-joined string) so a WHERE containing literal colons or other delimiter-like characters cannot collide hashes across different (view, where, limit) tuples. Resume logic for Source 4:

1. Read `source.json`. If `source != "snowflake-audience"`, skip Source 4 resume entirely.
2. Compute the current invocation's `query_hash`.
3. If `query_hash` matches the value in `source.json` AND `enriched.jsonl` exists, **skip the re-query** — resume from Workflow 3 onward against existing rows.
4. If `query_hash` differs, HALT with `EX-RESUME-HASH-MISMATCH` and instruct the operator to either pass `--resume` to acknowledge the deliberate parameter change (which re-queries) OR use a fresh `--output-dir`.

This prevents the silent-divergence failure mode where an operator tweaks `--snowflake-where`, expects a fresh result, but gets stale enriched rows because the skill never noticed the change.

## 4. Error modes

All errors HALT (non-zero exit) — Source 4 NEVER degrades silently to an empty list or a partial result. Per [ADR-021](../decisions/021-marketing-snowflake-access.md), the `query_audience.py` wrapper emits structured JSON to stderr; the skill surfaces the operator-actionable message.

| Code | Trigger | Skill HALT message |
|---|---|---|
| `EX-SNOWFLAKE-UNREACHABLE` | `snow` CLI cannot connect (network, credentials, account locked) | "Snowflake unreachable. Verify `bw-run.sh` credential injection and `snow` CLI connectivity. Exact error: <wrapper-stderr>." |
| `EX-VIEW-NOT-IN-SNOWFLAKE` | View name passed allowlist but doesn't exist in Snowflake (catalog out-of-date) | "View `<name>` is allowlisted but not found in Snowflake. The catalog at `audience-views.md` may be stale relative to `brite-data-platform/main`. Coordinate with Corinne (GTM Intelligence) to either ship the view or remove from catalog." |
| `EX-VIEW-NOT-IN-CATALOG` | View name not in audience-views.md catalog | "View `<name>` is not in the audience-view catalog. Valid views: <list>. To add a new view, follow the audience-views.md ownership process." |
| `EX-PREDICATE-VALIDATION` | `--snowflake-where` fails grammar check | "Predicate rejected at token `<token>`. Allowed: `<column> <op> <literal>` joined by AND/OR. Subqueries, function calls, and SQL comments are not allowed." |
| `EX-ZERO-ROWS` | Query returns 0 rows | "Query returned 0 rows. Either the audience view is empty for this WHERE, or the WHERE predicate excludes all rows. Sample 5 rows with `--snowflake-limit 5` and no WHERE to diagnose." |
| `EX-QUERY-TIMEOUT` | Wrapper exits with timeout signal (default: 60s) | "Snowflake query timed out after 60s. Consider narrowing WHERE or raising the wrapper timeout. Re-run with `--snowflake-limit <N>` to bound the result set." |
| `EX-COUNT-OVERFLOW` | Row count > `--snowflake-limit` when set | "Query would return <actual> rows but `--snowflake-limit` is <limit>. Either raise the limit or narrow WHERE. Skill does NOT truncate." |
| `EX-COST-GATE` | `--snowflake-limit` unset AND row count > default threshold (see § 5) | "Query would return <count> rows. Confirm by setting `--snowflake-limit <count>` or narrow WHERE." |
| `EX-MUTUAL-EXCLUSION` | More than one source flag passed | "Source flags are mutually exclusive. Got: <list of flags>. Pass exactly one." |
| `EX-RESUME-HASH-MISMATCH` | Resume detected but query params changed | "Resume detected at `<output-dir>` but query params differ from prior run. Pass `--resume` to acknowledge and re-query, or use a fresh `--output-dir`." |

The skill code maps `query_audience.py`'s stderr JSON `error_code` field to the table above; unrecognized codes HALT with `EX-WRAPPER-UNKNOWN` and quote the stderr verbatim.

## 5. Cost-gate behavior

Snowflake credit cost is a per-query function of row count + complexity. The skill protects against accidentally-expensive queries with a cost gate:

1. Before executing the full query, the wrapper issues a `SELECT COUNT(*) FROM <view> WHERE <predicate>` probe.
2. If `--snowflake-limit N` is set:
   - `count <= N`: proceed.
   - `count > N`: HALT with `EX-COUNT-OVERFLOW`.
3. If `--snowflake-limit` is unset:
   - `count <= 5000` (default threshold): proceed.
   - `count > 5000`: HALT with `EX-COST-GATE`. Operator must confirm by setting `--snowflake-limit <count>`.

The 5000 default is a deliberate friction. Outbound campaigns typically target hundreds, low thousands; queries returning tens of thousands are almost always a misconfigured WHERE. Operators with legitimate large queries pass `--snowflake-limit` explicitly.

The COUNT probe + query are not transactional — between probe and main query, the view may grow. The skill writes both `probe_count` and `actual_count` to `source.json`; if they differ by more than 10%, surface a warning at Workflow completion (the count grew under us; the operator may want to refresh).

## 6. Audit trail

`source.json` carries the full query-intent record (§ 3) plus execution metadata. Additionally, the skill writes a compact audit log entry for every Source 4 invocation to `<output-dir>/audit.log` as **JSON-lines** (one JSON object per line):

```jsonl
{"ts":"2026-05-28T14:23:00Z","source":"snowflake-audience","view":"audience_commercial_outreach","where":"business_category='commercial' AND data_quality_score>=80","limit":5000,"probe_count":4327,"actual_count":4327,"exec_ms":1840,"wrapper_exit":0}
```

JSON-lines is required (not space-delimited key=value) because the predicate may contain quoted strings whose contents are operator-supplied. JSON encoding eliminates the audit-log-injection class where a maliciously-crafted literal value (e.g., one containing embedded newlines) could spoof a second audit line. The predicate-validation grammar in § 1 already rejects newlines in literals as a defense-in-depth measure, but the JSONL format is the authoritative protection.

One line per attempt (including resume-skip cases — which log `"wrapper_exit":"resume-skip"`). Append-only; never overwritten. Used by `prospect-temporal-gate` debugging + by future drift-detection commands (e.g., [BC-11856](https://linear.app/brite-nites/issue/BC-11856) `/marketing:audit-campaigns`).

## 7. Cross-skill boundaries

What this design **owns**:

- The `--snowflake-audience` / `--snowflake-where` / `--snowflake-limit` invocation contract on `list-building`
- Wrapper invocation pattern (per [ADR-021](../decisions/021-marketing-snowflake-access.md))
- Cost-gate behavior + audit trail
- Resume detection extensions
- Error-code → HALT message mapping
- **The predicate-validation grammar** (§ 1) — both the skill's advisory check and the wrapper's authoritative gate consume the same grammar definition from this doc

What this design **does not own**:

- Audience-view definitions (TAM source contract) → owned by `brite-data-platform` (Corinne / GTM Intelligence)
- Audience-view catalog content → owned by [`plugins/marketing/references/audience-views.md`](../../plugins/marketing/references/audience-views.md), maintained by marketing plugin owners. The **catalog → Snowflake → skill consistency** is a three-way burden: the catalog can drift ahead of (or behind) `brite-data-platform/main`. Reconciliation is org coordination (with Corinne) until the future-work CI lint lands.
- Snowflake credential rotation → owned by [ADR-010](../decisions/010-plugin-secret-config-canon.md) + Bitwarden. The wrapper MUST NOT log `os.environ` on error paths; structured stderr is restricted to `view`, `where`, `limit`, `query_hash`, `error_code`, `error_detail` — credentials never appear in any output stream.
- Wrapper script implementation → BC-11929 ships `plugins/marketing/scripts/snowflake/query_audience.py`
- Enrichment / SMTP verify / free-email filter → existing list-building Workflows 3-5 (unchanged)
- Allowlist authoritative enforcement → the wrapper (the skill's check is advisory; see § 1 "View-name validation")

## Acceptance gates for [BC-11929](https://linear.app/brite-nites/issue/BC-11929)

The implementation issue verifies this design end-to-end. Each gate below maps to one or more error codes in § 4 and one or more eval-test scenarios:

1. **Happy path.** `--snowflake-audience audience_commercial_outreach --snowflake-limit 100` → returns 100 rows, EB-exclusion runs, enrichment runs, `enriched_leads.csv` lands. (Today: against `dim_people` since the audience view isn't built yet — switch to `audience_commercial_outreach` post-[BC-2314](https://linear.app/brite-nites/issue/BC-2314).)
2. **Allowlist rejection.** `--snowflake-audience does_not_exist` → `EX-VIEW-NOT-IN-CATALOG`, query never issued.
3. **Predicate injection rejection.** `--snowflake-where "1=1; DROP TABLE x"` → `EX-PREDICATE-VALIDATION` at the `;` token.
4. **Cost gate.** Default threshold violation: `--snowflake-audience dim_people` with no WHERE returns >5000 → `EX-COST-GATE` without executing the full query.
5. **Zero rows.** WHERE that matches nothing → `EX-ZERO-ROWS`.
6. **Resume hash mismatch.** Re-invoke with different `--snowflake-where` against same `--output-dir` → `EX-RESUME-HASH-MISMATCH`.
7. **Mutual exclusion.** `--snowflake-audience foo --input-csv bar.csv` → `EX-MUTUAL-EXCLUSION`.
8. **Wrapper error pass-through.** Force `snow` CLI failure (e.g., revoke credentials) → `EX-SNOWFLAKE-UNREACHABLE` with the wrapper's stderr quoted.

Eval tests at `plugins/marketing/tests/list-building/test_source_4_*.py` cover each gate.
