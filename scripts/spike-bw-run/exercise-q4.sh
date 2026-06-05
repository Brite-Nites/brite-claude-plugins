#!/usr/bin/env bash
# exercise-q4.sh — Q4 MCP stdio handshake passthrough test (BC-6905 spike).
# Pipes an `initialize` JSON-RPC into bw-run-wrapped spider-cloud-mcp;
# captures stdout/stderr separately so we can verify clean passthrough.
#
# Output: writes /tmp/q4-stdout.txt + /tmp/q4-stderr.txt; prints summary.
# Throwaway POC; deleted alongside spike-bw-run/ when BC-6906 lands.
set -uo pipefail  # no -e: we capture exit code below for diagnostics

WRAPPER="$(dirname "$0")/bw-run.sh"
ITEM="${1:-tam-map-spider-api-key}"
MCP_PKG="${2:-spider-cloud-mcp@2.1.1}"
TIMEOUT_S="${3:-45}"

INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"bc-6905-spike","version":"0"}}}'

rm -f /tmp/q4-stdout.txt /tmp/q4-stderr.txt
# Use perl alarm wrapper because macOS lacks GNU `timeout`/`gtimeout`.
echo "$INIT" \
  | perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_S" bash "$WRAPPER" "SPIDER_API_KEY=$ITEM" -- npx -y "$MCP_PKG" \
    > /tmp/q4-stdout.txt 2> /tmp/q4-stderr.txt
EXIT=$?

echo "exit=$EXIT (124=timeout)"
echo ""
echo "=== STDOUT (first 3 lines) ==="
head -3 /tmp/q4-stdout.txt
echo ""
echo "=== STDOUT byte count ==="
wc -c /tmp/q4-stdout.txt
echo ""
echo "=== STDERR (first 40 lines) ==="
head -40 /tmp/q4-stderr.txt
echo ""
echo "=== STDERR byte count ==="
wc -c /tmp/q4-stderr.txt
echo ""
echo "=== STDOUT first-line shape (jq probe) ==="
head -1 /tmp/q4-stdout.txt | jq '{jsonrpc, id, hasResult: (.result != null), protocolVersion: .result.protocolVersion, hasCapabilities: (.result.capabilities != null), serverInfo: .result.serverInfo}' 2>&1 || echo "(stdout not parseable as JSON)"
echo ""
echo "=== STDOUT bw-run.sh noise check (should be 0) ==="
printf "bw-run.sh substring count on stdout: "
grep -c "bw-run.sh:" /tmp/q4-stdout.txt || true
