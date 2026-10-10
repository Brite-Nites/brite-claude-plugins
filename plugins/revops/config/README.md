# revops config

Data files the revops commands read. No procedural logic lives here.

## `org-aliases.json` — the protected-org alias list

One file. Two repos read it.

1. `plugins/revops` commands read it through
   [`../scripts/promotion_topology.py`](../scripts/promotion_topology.py).
2. The brite-salesforce PreToolUse deploy-policy hook (BC-19519) reads the JSON
   directly, so it needs no Python and no plugin import.

Path from an installed plugin: `${CLAUDE_PLUGIN_ROOT}/config/org-aliases.json`.

### What a policy hook needs

Two fields carry the policy. Everything else is explanation.

| Field | Use |
|---|---|
| `protected_aliases` | Flat list of every alias (including each `aka`) a laptop must not deploy to freely. |
| `dev_org.alias_pattern` | Regex for the per-developer orgs a laptop *may* deploy to. |

Each `orgs[]` entry also carries `enforcement`, one of:

- `block` — refuse a local `sf` deploy. The org is CI-deployed only.
- `warn` — legacy path, not yet refused. Warn and name the replacement.
- `allow` — the intended inner-loop path.

An alias that matches nothing is **unknown**. Treat unknown as blocked. Failing
closed is the point.

### Adding an org

1. Add the `orgs[]` entry, including `enforcement`.
2. If `enforcement` is not `allow`, add the alias and every `aka` to `protected_aliases`.
3. Run `bash ../scripts/test_promotion_topology.sh` — it asserts the two stay in sync.

### Authority

`brite-salesforce/CLAUDE.md` and brite-salesforce ADR-016 define Brite deploy
discipline. This file mirrors it outward. When the two disagree,
brite-salesforce wins and this file is what is stale.

## `pipeline-config.example.json` — the repo-local guidance config

ADR-026 section 5: the plugin **guides** and never claims to enforce. Every
guidance mechanism reads a repo-local pipeline config and no-ops where absent,
so revops stays portable.

Copy the example to `.revops-pipeline.json` at the root of an SFDX repo (that
is, in brite-salesforce, not here). When the file is missing, the guidance layer
prints nothing and the commands still run. Read it with:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/promotion_topology.py" --pipeline-guidance .
```
