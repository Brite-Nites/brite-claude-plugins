#!/usr/bin/env bash
set -euo pipefail

# flow-classify-domain-state.sh — filesystem-only classifier for a domain's
# FDA scaffold state, supporting Q20 amendment 1 (BC-9971) inventory-only
# re-scaffold detection in /flow:add-domain Phase 2.
#
# Returns exactly one classification token on stdout:
#   absent              — no `### <DOMAIN>` H3 in inventory.
#   inventory-only      — H3 present, journey doc absent.
#   journey-exists      — H3 present, journey doc present, flows dir empty.
#   fully-scaffolded-fs — H3 present, journey doc present, flows dir non-empty.
#
# The Linear-milestone overlay (`FDA: <domain>` present?) is the orchestrator's
# responsibility — bash cannot call MCP per Q32. See
# `plugins/flow-architecture/commands/add-domain.md` Phase 2 prose for the
# combined classification rule.
#
# Usage:
#   flow-classify-domain-state.sh <inventory-path> <flows-dir> <journeys-dir> <DOMAIN>
#
# Exits:
#   0 on success (token on stdout)
#   2 on missing/malformed inputs (message on stderr)
#
# bash 3.2+ compatible (Q32). No PyYAML; stdlib only.

if [ "$#" -ne 4 ]; then
  echo "usage: flow-classify-domain-state.sh <inventory-path> <flows-dir> <journeys-dir> <DOMAIN>" >&2
  exit 2
fi

INVENTORY_PATH="$1"
FLOWS_DIR="$2"
JOURNEYS_DIR="$3"
DOMAIN="$4"

# Validate DOMAIN against the Q20.4 schema (uppercase slug). Defends against
# injection via interview values passing through here unsanitized.
case "$DOMAIN" in
  '' )
    echo "flow-classify-domain-state: DOMAIN is empty" >&2
    exit 2
    ;;
esac
if ! printf '%s' "$DOMAIN" | grep -Eq '^[A-Z][A-Z0-9_-]*$'; then
  echo "flow-classify-domain-state: DOMAIN '$DOMAIN' fails [A-Z][A-Z0-9_-]* (Q20.4 schema)" >&2
  exit 2
fi

if [ ! -f "$INVENTORY_PATH" ]; then
  echo "flow-classify-domain-state: inventory-path '$INVENTORY_PATH' not a file" >&2
  exit 2
fi

# H3 match — case-sensitive (FDA H3s are uppercase per Q20.4 schema). The
# canonical H3 form per `flow-inventory-add` Section 3 is
# `^### <DOMAIN> --- <display> \(\d+ flows\)$` (triple-hyphen separator) and
# per Q20.3 (memory:230) is `^### <DOMAIN> — .* \(\d+ flows\)$` (em-dash) —
# the two surfaces disagree. Rather than gate on the separator + flow count,
# require only a whitespace boundary after `<DOMAIN>`: that's sufficient for
# presence detection, robust against minor schema drift, and prevents prefix
# false-positives (`### FOO` does not match `### FOO-EXTENDED`).
if grep -Eq "^### ${DOMAIN}[[:space:]]" "$INVENTORY_PATH"; then
  HAS_H3="yes"
else
  HAS_H3="no"
fi

# Journey doc path — `docs/product/journeys/<domain-lowercase>.md` per the
# Q16 schema. Lowercase translation matches `commands/add-domain.md` Phase 5
# terminator artifact (`docs/product/journeys/<target_domain>.md`). Manual
# tr to avoid bash-4-only `${var,,}`.
DOMAIN_LC="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]')"
JOURNEY_DOC="$JOURNEYS_DIR/${DOMAIN_LC}.md"
if [ -f "$JOURNEY_DOC" ]; then
  HAS_JOURNEY="yes"
else
  HAS_JOURNEY="no"
fi

# Flows subdir — `docs/product/flows/<domain-lowercase>/` with at least one
# story-doc-shaped file. Story docs follow Q15 / Q20.4 naming `<DOMAIN>-NN.md`
# (case-insensitive at the filename level since the dir is lowercase). The
# regex-pattern check defends the classification from incidental README.md,
# INDEX.md, or other non-story sidecars dropping a domain into
# `fully-scaffolded-fs` when it should stay at `journey-exists`. The first
# match short-circuits via `-print -quit`.
FLOWS_SUBDIR="$FLOWS_DIR/$DOMAIN_LC"
if [ -d "$FLOWS_SUBDIR" ]; then
  FIRST_STORY="$(find "$FLOWS_SUBDIR" -type f -iname "${DOMAIN}-[0-9]*.md" -print -quit 2>/dev/null || true)"
  if [ -n "$FIRST_STORY" ]; then
    HAS_STORIES="yes"
  else
    HAS_STORIES="no"
  fi
else
  HAS_STORIES="no"
fi

# Classification table (Q20 amendment 1 BC-9971):
#
#   H3   journey  stories  ->  outcome
#   no   *        *        ->  absent
#   yes  no       *        ->  inventory-only
#   yes  yes      no       ->  journey-exists
#   yes  yes      yes      ->  fully-scaffolded-fs
if [ "$HAS_H3" = "no" ]; then
  echo "absent"
elif [ "$HAS_JOURNEY" = "no" ]; then
  echo "inventory-only"
elif [ "$HAS_STORIES" = "no" ]; then
  echo "journey-exists"
else
  echo "fully-scaffolded-fs"
fi
