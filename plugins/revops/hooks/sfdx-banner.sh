#!/usr/bin/env bash
# RevOps SessionStart probe — emits a "RevOps Active" banner when an SFDX
# project (sfdx-project.json) is reachable by walking up from the current
# working directory. Silent in non-SFDX contexts.
#
# Probe is an unbounded stat-walk up from $PWD. dirname terminates the loop
# naturally at the filesystem root. Steady-state cost: ~5–8 stat calls
# (<10ms warm), well under the 50ms session-start budget.
#
# Issue: BC-5806

set -eu

dir="$PWD"
while :; do
  if [ -f "$dir/sfdx-project.json" ]; then
    printf '🔧 RevOps Active\n\n'
    printf "You're in an SFDX project. SF intelligence loaded.\n\n"
    printf 'Commands:\n'
    printf '  /revops:deploy-sandbox — dry-run + sandbox deploy + tests\n'
    printf '  /revops:deploy-prod — prod deploy with double-confirm + Tooling API verify\n'
    printf '  /revops:post-deploy-runbook — walk manual post-merge steps\n\n'
    printf 'Skills auto-activate by intent: sf-deploy, sf-permissions, sf-apex, sf-metadata, sf-soql, etc.\n'
    exit 0
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

exit 0
