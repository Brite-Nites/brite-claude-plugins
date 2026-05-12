#!/usr/bin/env bash
# Stub verify-docs.sh for the audit-broken-shape fixture. Returns 0 (Phase A pass).
# Real consuming projects (BriteBase / Brand Hub) own a richer implementation; the
# stub here lets /flow:audit's Phase A invocation succeed in the smoke-test fixture.
# Mirrors clean-shape but with TEAM-03 omitted (the deliberately missing story doc).
set -euo pipefail
echo "PASS docs/product/flows/TEAM/TEAM-01.md"
echo "PASS docs/product/flows/TEAM/TEAM-02.md"
echo "PASS docs/product/flows/SHIP/SHIP-01.md"
echo "PASS docs/product/flows/SHIP/SHIP-02.md"
echo "PASS docs/product/flows/SHIP/SHIP-03.md"
exit 0
