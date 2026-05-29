# brite-core ↔ team gbrain wiring (plugins-repo view)

Companion to `brite-team-gbrain/docs/wiring/team-gbrain-wiring.md`. That doc covers the
serve/sync/Minions side; this one covers what lives **in this plugins repo**.

## What brite-core wires

| Concern | File | Replaces |
|---|---|---|
| Brain-first guidance (session) | `plugins/core/hooks/hooks.json` → SessionStart | the 36 inline `**Brain-first**:` pointer lines (removal = BC-11750, deferred) |
| Brain-first guidance (subagent) | `plugins/core/hooks/hooks.json` → SubagentStart (JSON envelope) | the broken plain-stdout SubagentStart hooks (PR #385) |
| Shared security/quality hooks | `plugins/core/hooks/hooks.json` → PreToolUse/PostToolUse | per-plugin duplicates (de-dup = BC-11753, deferred) |
| Team-gbrain MCP | `plugins/core/.mcp.json` + `scripts/gbrain-team-broker.sh` | the 5 domain-plugin registrations (de-dup = BC-11753, deferred) |
| Guidance content | `plugins/core/team-gbrain-usage.md` (≤2KB) | `plugins/_shared/team-gbrain-usage.md` |

## Migration sequencing (why this is additive-only right now)

The design (Q16b) prescribes **overlap-then-cleanup**: add the new home first, validate it
fires in real sessions, *then* remove the duplicates. BC-11750 (pointer removal) is
explicitly `blockedBy` BC-11749 (these hooks) because deleting the pointer lines before the
hooks are proven would strip brain-first guidance entirely. So this pass ships brite-core
**additively** — during the overlap window the guidance is double-delivered (pointer lines +
hooks), which is harmless. The subtractive PRs come after validation:

- **BC-11750** — remove the 36 pointer lines (`grep -rE '\*\*Brain-first\*\*' plugins/` → 0) + regenerate templates + add core-enablement warnings to the 5 domain plugins.
- **BC-11753** — remove the now-duplicate `gbrain-team` MCP from the 5 domain `.mcp.json` and the shared hooks from their `hooks/hooks.json`.

## The SubagentStart fix in one line

```bash
jq -Rs '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: .}}' "$GUIDANCE"
```

SessionStart treats raw stdout as `additionalContext`; **SubagentStart does not** — raw
stdout there goes to the debug log and never reaches the subagent. That asymmetry is exactly
why PR #385 failed silently. brite-core's SubagentStart hook emits the envelope and degrades
loudly (logs `jq missing` vs `file unreadable` to stderr) instead of `2>/dev/null || true`.
`tests/test_size_cap.sh` locks both the ≤2KB cap and the envelope shape.
