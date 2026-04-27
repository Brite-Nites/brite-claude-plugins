#!/usr/bin/env bash
# RevOps SessionStart probe — emits a "RevOps Active" banner when an SFDX
# project (sfdx-project.json) is reachable by walking up from the current
# working directory. Silent in non-SFDX contexts.
#
# Probe walks $PWD up to filesystem root using parameter expansion (no
# subshells, no fork-per-iteration). Loop terminates when ${dir%/*} can no
# longer shrink. Steady-state cost: pure builtins + a few stat calls
# (<10ms warm), well under the 50ms session-start budget.
#
# Issue: BC-5806

dir="$PWD"
while :; do
  if [ -f "$dir/sfdx-project.json" ]; then
    printf '%s\n' \
      "🔧 RevOps Active" \
      "" \
      "You're in an SFDX project. SF intelligence loaded." \
      "" \
      "Commands:" \
      "  /revops:deploy-sandbox — dry-run + sandbox deploy + tests" \
      "  /revops:deploy-prod — prod deploy with double-confirm + Tooling API verify" \
      "  /revops:post-deploy-runbook — walk manual post-merge steps" \
      "" \
      "Skills auto-activate by intent: sf-deploy, sf-permissions, sf-apex, sf-metadata, sf-soql, etc."
    exit 0
  fi
  parent="${dir%/*}"
  [ -z "$parent" ] && parent="/"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
