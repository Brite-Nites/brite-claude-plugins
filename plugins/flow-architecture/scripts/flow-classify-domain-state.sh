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

# Validate DOMAIN against the Q20.4 schema as amended by Q20 amendment 2
# (BC-10352, 2026-05-22): lowercase kebab-case slug. Original Q20.4 spec used
# UPPERCASE (implied via Q15/Q20 examples like TEAM-08 / AUTH-11 /
# ASSET-DISCOVERY), but Brand Hub iter-2's shipped inventory (the canonical
# dogfood reality) uses lowercase + backtick-wrapped + em-dash separator;
# Path A locks iter-2's shape as canonical going forward. Defends against
# injection via interview values passing through here unsanitized.
case "$DOMAIN" in
  '' )
    echo "flow-classify-domain-state: DOMAIN is empty" >&2
    exit 2
    ;;
esac
if ! printf '%s' "$DOMAIN" | grep -Eq '^[a-z][a-z0-9-]*$'; then
  echo "flow-classify-domain-state: DOMAIN '$DOMAIN' fails [a-z][a-z0-9-]* (Q20 amendment 2 schema; BC-10352)" >&2
  exit 2
fi

if [ ! -f "$INVENTORY_PATH" ]; then
  echo "flow-classify-domain-state: inventory-path '$INVENTORY_PATH' not a file" >&2
  exit 2
fi

# H3 match — case-sensitive (DOMAIN is lowercase per Q20 amendment 2 schema).
# The canonical H3 form per `flow-inventory-add` Section 3 (BC-10352 align)
# is `^### [BACKTICK]?<DOMAIN>[BACKTICK]? — <display> (N flows)$` with em-dash
# as the canonical separator (Q20.3 memory + iter-2 reality). Both
# backtick-wrapped and bare H3s are matched — Brand Hub's iter-2 inventory
# mixes the two and both are considered valid. Pattern built via printf so
# the backtick metacharacter doesn't trip bash command-substitution inside a
# double-quoted regex. The grep only requires a whitespace boundary after
# the optionally-backtick-wrapped slug, so it stays separator-agnostic and
# prevents prefix false-positives (`### asset-foundation` does not match
# `### asset-foundation-extended`).
BACKTICK='`'
H3_REGEX="$(printf '^### [%s]?%s[%s]?[[:space:]]' "$BACKTICK" "$DOMAIN" "$BACKTICK")"
if grep -Eq "$H3_REGEX" "$INVENTORY_PATH"; then
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
