<!-- eval-waiver: Shared PROCEDURE include, not a command — it has no frontmatter and is never invoked as /revops:concurrency-probe. Its body is the two DeployRequest queries plus a hand-off to scripts/promotion_topology.py --concurrency-verdict, which owns every decision here and IS behaviorally eval'd (scripts/test_promotion_topology.sh asserts the fail-closed property across nine broken-input shapes). There is nothing left in this file to fixture: it decides nothing itself. It lands in the diff-gate's changed set only because classify_changes globs with fnmatch, whose `*` crosses `/`, while command_surface uses Path.glob, which does not — so this path is invisible to --check's surface and cannot take a debt row. -->

# Shared procedure — blocking deploy-concurrency probe (BC-19521)

Not a command. Included by reference from `/revops:preview-changes`,
`/revops:push-to-production`, and `/revops:emergency-deploy-to-production` so all
three run the identical probe.

## What changed and why

The old Phase 0.5 was an **advisory 24-hour lookback that failed open**. Its own
instructions said *"do not halt the deploy over an advisory check"*, so a Tooling
API error read as "nobody else is deploying." It also could not see a deploy that
was running right now — it only looked at `CreatedDate`, and a `Status` of
`InProgress` was reported, not acted on.

Three changes, per ADR-026 and BC-19521:

1. It **blocks**. A hit halts the command instead of asking whether you feel fine about it.
2. It **sees in-flight deploys** — `DeployRequest` with `Status = 'InProgress'`.
3. It **fails closed**. A query error is a block, not a pass. An unanswered
   question is not a `no`.

The override is explicit and narrow: `--override-concurrency` clears a *recent*
deploy, and never clears an *in-flight* one. Two concurrent deploys to one org
interleave unpredictably; there is no operator judgement that makes that safe.

## Procedure

Substitute `{target-org}` with the alias this command resolved. It always matches
`^[a-zA-Z0-9._@-]+$` (Phase 0.25 rejects anything else), so it is safe to
interpolate.

### Step 1 — run both queries and decide

```bash
set -u   # NOT set -e: a failing sf query is an input to the verdict, not an abort.

ORG="{target-org}"
LOOKBACK=24
OVERRIDE=false   # set to true ONLY if --override-concurrency was passed

TMPD="$(mktemp -d)"

# Query A — is a deploy running right now? Pending/Canceling count too: both
# mean the org is mid-deploy and a second deploy would interleave with it.
sf data query --use-tooling-api --target-org "$ORG" --json \
  --query "SELECT Id, CreatedBy.Name, CreatedDate, Status, NumberComponentsTotal
           FROM DeployRequest
           WHERE Status IN ('InProgress','Pending','Canceling')
           ORDER BY CreatedDate DESC
           LIMIT 5" > "$TMPD/in_flight.json" 2>&1

# Query B — did one land inside the lookback window?
sf data query --use-tooling-api --target-org "$ORG" --json \
  --query "SELECT Id, CreatedBy.Name, CreatedDate, Status, NumberComponentsTotal
           FROM DeployRequest
           WHERE CreatedDate = LAST_N_HOURS:${LOOKBACK}
             AND Status NOT IN ('InProgress','Pending','Canceling')
           ORDER BY CreatedDate DESC
           LIMIT 5" > "$TMPD/recent.json" 2>&1

echo "--- raw in-flight envelope ---"; cat "$TMPD/in_flight.json"
echo "--- raw recent envelope ---";    cat "$TMPD/recent.json"

# Hand both raw envelopes to the decision core. It owns the fail-closed rule:
# a non-zero status, an unexpected shape, or unparseable output all produce
# `blocked_error`, never `clear`. Do NOT re-implement this in prose.
#
# The heredoc is QUOTED ('PYEOF'), so the shell substitutes nothing into the
# Python source — the envelopes travel as files, not as interpolated strings.
# Interpolating raw JSON into a Python literal would mangle every backslash
# escape the moment a component name contained one.
python3 - "$ORG" "$LOOKBACK" "$OVERRIDE" "$TMPD" <<'PYEOF'
import json, os, subprocess, sys

org, lookback, override, tmpd = sys.argv[1:5]

def envelope(name):
    path = os.path.join(tmpd, name)
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except OSError as exc:
        return {"status": 1, "unreadable": str(exc)}
    try:
        return json.loads(raw)
    except ValueError:
        # Not JSON at all — usually an `sf` stack trace or an auth error on
        # stderr. Hand it on as a failed envelope; the core will block.
        return {"status": 1, "unparseable": raw[:400]}

payload = {
    "target_org": org,
    "lookback_hours": int(lookback),
    "override": override == "true",
    "in_flight": envelope("in_flight.json"),
    "recent": envelope("recent.json"),
}

root = os.environ.get("CLAUDE_PLUGIN_ROOT")
if not root:
    print(json.dumps({
        "decision": "blocked_error",
        "blocking": True,
        "reason": "CLAUDE_PLUGIN_ROOT is unset, so the decision core could not be "
                  "located. The probe fails closed.",
    }, indent=2))
    sys.exit(0)

mod = os.path.join(root, "scripts", "promotion_topology.py")
proc = subprocess.run([sys.executable, mod, "--concurrency-verdict", "-"],
                      input=json.dumps(payload), capture_output=True, text=True)
sys.stdout.write(proc.stdout or json.dumps({
    "decision": "blocked_error",
    "blocking": True,
    "reason": f"the decision core did not run: {proc.stderr.strip()[:400]}",
}, indent=2))
PYEOF

rm -rf "$TMPD"
```

### Step 2 — act on the verdict

Read the emitted JSON's `decision` field. Do not interpret the raw query output
yourself; the module already did.

| `decision` | What it means | What you do |
|---|---|---|
| `clear` | Nothing running, nothing recent. | Continue to the next phase. Narrate the result. |
| `blocked_inflight` | A deploy is running against this org now. | **Halt.** Print `records` verbatim. `--override-concurrency` does **not** apply — say so. |
| `blocked_recent` | A deploy landed inside the lookback. | **Halt.** Print `records` verbatim. Name `--override-concurrency` as the deliberate way past. |
| `override` | A recent deploy was overridden by explicit flag. | Continue, and print the overridden records so the choice is on the record. |
| `blocked_error` | The probe could not answer. | **Halt.** Print the raw envelopes and the `reason`. Never treat this as `clear`. |

Halt messages, verbatim:

- `blocked_inflight` —
  > **Blocked: a deploy is already in flight against `{target-org}`.** Two
  > concurrent deploys to one org interleave unpredictably, so this is not
  > overridable. Watch it finish in Setup → Deployment Status, then re-run.

- `blocked_recent` —
  > **Blocked: {N} deploy(s) landed against `{target-org}` in the last 24h.**
  > Coordinate with the prior deployer. If you have already done that, re-run
  > with `--override-concurrency`.

- `blocked_error` —
  > **Blocked: the concurrency probe could not answer.** This check fails closed
  > — an unanswered question is not a `no`. Fix the query error above (usually an
  > expired session: re-run `/revops:check-environment-health`), then re-run.
  > If you must proceed without the probe, do it manually with `sf` and own the risk.

### Rules

- **Never downgrade a block to a question.** The probe's output is the decision. There is no `AskUserQuestion` that turns `blocked_recent` into a proceed — the flag is the only path.
- **Never re-run the queries after a block** hoping for a different answer. Surface and halt.
- **Never implement the verdict logic in prose.** It lives in `scripts/promotion_topology.py` and is covered by `scripts/test_promotion_topology.sh`. Prose that says "fail open" is exactly the bug this replaced.
