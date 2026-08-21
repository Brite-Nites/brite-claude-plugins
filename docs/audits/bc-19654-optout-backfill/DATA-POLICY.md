# Where the person-level data lives

This directory tracks **reasoning and queries only**. The working data files — triage
decisions, blocked-address lists, sweep output, lead states — are **git-ignored and stay on
disk**, per the PR #511 / #585 policy.

**This repo is public.** The people in those files asked to stop being contacted; publishing
their addresses would compound the very thing this audit exists to fix.

Ignored here (present on disk, never committed):

| File | Holds |
| --- | --- |
| `triage-decisions.csv` | per-address keep/reject + reason for the first case |
| `org-scope-candidates-73.tsv` | the 73 org-scope candidates with reply text |
| `wave1-lead-final-state.tsv` · `wave2-lead-final-state.tsv` | post-run lead states |
| `wave4-address-blocks.tsv` | the 206 addresses blocked in wave 4 |
| `wave4-reread-23.tsv` · `wave4-reread-genuine-8.txt` | the re-read set and its verdicts |
| `wave5-widened-sweep-106.tsv` · `wave5-subject-only-optouts.tsv` | widened-sweep output |
| `wave1-domains-blocked.txt` · `wave2-domains-blocked.txt` | blocked domain lists |
| `exclude_notoptout.txt` · `exclude_addressonly.txt` | wave-1 exclusion lists |

**Domains are kept in the tracked markdown; individuals are not.** A domain is a business
identifier and the audit is unreadable without it. Personal names and addresses are replaced
with `<person>@domain` or a role description.

The source of truth is not this directory in any case: suppression state lives in Email Bison,
and the full reply history is in Snowflake `ANALYTICS.STAGING.STG_EMAILBISON__*`. Every number
in the markdown is reproducible from `queries/` — run them to regenerate any list.
