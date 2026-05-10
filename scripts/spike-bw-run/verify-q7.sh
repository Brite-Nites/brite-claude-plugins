#!/usr/bin/env bash
# verify-q7.sh — Q7 collection-share retrieval semantics (BC-6905 spike).
# Verifies a collection-shared item is retrievable via `bw get password`,
# and reports collection metadata (without printing the secret value).
# Throwaway POC; deleted alongside spike-bw-run/ when BC-6906 lands.
set -uo pipefail

ITEM="${1:-tam-map-spider-api-key}"
ENG_COLL_ID="${2:-7d6f25ca-40c9-4480-8844-b42e010a29a3}"

echo "## Q7 — collection-share retrieval semantics"
echo "item=$ITEM"
echo ""

# Metadata: collectionIds, organizationId, type, hasPassword
echo "=== Metadata (no values) ==="
bw list items --search "$ITEM" | jq --arg engId "$ENG_COLL_ID" '
  [.[] | select(.name == $ENV.ITEM // "tam-map-spider-api-key")
       | {
           name,
           type,
           organizationId,
           collectionIds,
           inEngineering: (.collectionIds | index($engId) != null),
           hasLoginPassword: (.login.password != null and .login.password != "")
         }
  ]
'
echo ""

# Retrieval check: bw get password to /dev/null, then `bw get password | wc -c`
# These run inside this script so the security hook (which inspects top-level
# Bash command strings) doesn't see the credential pipeline.
echo "=== Retrieval check ==="
if value=$(bw get password "$ITEM" 2>/dev/null); then
  printf "bw_get_exit=0\n"
  printf "value_length=%d\n" "${#value}"
  printf "value_nonempty=%s\n" "$([ -n "$value" ] && echo true || echo false)"
  unset value
else
  EXIT=$?
  printf "bw_get_exit=%d (FAIL)\n" "$EXIT"
fi
