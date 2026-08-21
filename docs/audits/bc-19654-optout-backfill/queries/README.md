# Reproducing the audit

Every figure in the wave docs comes from these queries. They read only from Snowflake and
write nothing.

## Setup

```bash
python3 -m pip install 'snowflake-connector-python[secure-local-storage]' pyyaml
```

`sfq.py` resolves its connection in this order:

1. **Environment variables** — `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`,
   `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_SCHEMA`, and either
   `SNOWFLAKE_PRIVATE_KEY_PATH` (+ `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`) or `SNOWFLAKE_PASSWORD`.
2. **`~/.dbt/profiles.yml`** — the `brite_enterprise_data_platform` profile, which is the
   standard team setup. Override which profile/target with `DBT_PROFILE` / `DBT_TARGET`.

With a working dbt profile, no environment variables are needed. If neither source resolves,
the script exits with a message naming what to set — it does not fail mid-query.

You need read access to `ANALYTICS.STAGING.STG_EMAILBISON__*`. Every query fully qualifies its
tables, so whichever database your profile points at does not matter.

## Running

Paths below are from the **repository root** — the runner takes SQL on stdin, so it does not
care about your working directory as long as both paths resolve:

```bash
Q=docs/audits/bc-19654-optout-backfill/queries
python3 "$Q/sfq.py" < "$Q/q_base.sql"
```

Or from inside this directory:

```bash
cd docs/audits/bc-19654-optout-backfill
python3 queries/sfq.py < queries/q_base.sql
```

Output is TSV with a `-- N rows` trailer per statement. Files may hold several statements
separated by a line containing exactly `--SPLIT--`.

## What each query answers

| File | Answers |
| --- | --- |
| `q_base.sql` | reproduces the issue's headline **598** opt-out senders, and the quote-stripped **569** |
| `q_cov.sql` | how many are uncovered by the email **or** domain blocklist, per workspace |
| `q_phrase.sql` | splits the uncovered set by phrase strength (the A / C1 / C2 buckets) |
| `q_final.sql` · `q_band.sql` · `q_blast.sql` | domain-size bands and the blast radius of a domain block |
| `q_scope.sql` · `q_scope2.sql` | individual vs organisation-scoped request language |
| `q_dump73.sql` | the org-scope candidates with reply text, for reading |
| `q_remain.sql` | the remaining queue, to diff against a live blocklist |
| `q_sweep.sql` · `q_subj.sql` | the widened sweep, and subject-line-only opt-outs |
| `q_juris.sql` · `q_ca3.sql` | the non-US / CASL jurisdiction check |
| `q_unread3.sql` · `q_samp325.sql` | the unread-inbox count and its sample |
| `q_samp.sql` | bucket sampling used to estimate precision |

## Two traps these queries encode

- **`REGEXP_LIKE` needs the `s` flag.** Snowflake anchors the pattern to the whole string, and
  without `s` the `.` does not match newlines — so `.*x.*` silently fails on any multi-line email
  signature. This produced a false zero during the audit (see `JURISDICTION.md`).
- **Coverage is instance-relative.** Blocklists are per workspace; always join on `_EB_WORKSPACE`,
  and filter `IS_DELETED_IN_SOURCE` on the blocklist tables.
