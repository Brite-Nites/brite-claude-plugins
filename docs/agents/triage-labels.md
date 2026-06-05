# Triage Labels

The skills speak in terms of canonical triage roles across **two axes** — a **category**
(`bug` / `enhancement`) and a **state** (the five below). This file maps those roles to the actual
label strings used in this repo's tracker (Linear). Defaults below are unchanged from canonical.

## State roles

| Role in mattpocock/skills | Label in our tracker | Meaning                                  |
| ------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`            | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`              | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`         | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`         | `ready-for-human`    | Requires human implementation            |
| `wontfix`                 | `wontfix`            | Will not be actioned                     |

## Category roles

The `/triage` skill works in terms of `bug` / `enhancement`; Brite types issues with the
CDR-016 type axis. Map them:

| Role in mattpocock/skills | Label in our tracker | Meaning                                            |
| ------------------------- | -------------------- | -------------------------------------------------- |
| `bug`                     | `type:bug`           | Something is broken (repro section required)        |
| `enhancement`             | `type:task`          | New feature / improvement / idea (CDR-016 default)  |

`/workflows:raise-a-ticket` applies the category (`type:bug` / `type:task`) at intake; the triage
stage reads it via this mapping. (CDR-016 also has `type:spike` / `type:chore` / `type:doc`; those
have no mattpocock category role — the triage stage may re-type as needed.)

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label
string from these tables.

Edit the right-hand column to match whatever vocabulary you actually use. Note: in Linear, `needs-triage`
and `wontfix` also have natural homes as the built-in **Triage** and **Canceled** workflow states — switch
to those if you'd rather drive triage by state than by label.
