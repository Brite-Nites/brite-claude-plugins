# brite-core ↔ team gbrain wiring (plugins-repo view)

Companion to `brite-team-gbrain/docs/wiring/team-gbrain-wiring.md`. That doc covers the
serve/sync/Minions side; this one covers what lives **in this plugins repo**.

## What brite-core wires

| Concern | File | Replaces |
|---|---|---|
| Brain-first guidance (session) | `plugins/core/hooks/hooks.json` → SessionStart | the inline `Brain-first` pointer lines (the bold-prefixed one-liners in agent/skill bodies; removal = BC-11750, later in v0.1) |
| Brain-first guidance (subagent) | `plugins/core/hooks/hooks.json` → SubagentStart (JSON envelope) | the broken plain-stdout SubagentStart hooks (PR #385) |
| Shared security/quality hooks | `plugins/core/hooks/hooks.json` → PreToolUse/PostToolUse | per-plugin duplicates (de-dup = BC-11753, later in v0.1) |
| Team-gbrain MCP | `plugins/core/.mcp.json` + `scripts/gbrain-team-broker.sh` | the 5 domain-plugin registrations (de-dup = BC-11753, later in v0.1) |
| Guidance content | `plugins/core/team-gbrain-usage.md` (≤2KB) | `plugins/_shared/team-gbrain-usage.md` |

## Migration sequencing (additive first, subtractive next — both in v0.1)

BC-11750 and BC-11753 are **in-scope for v0.1** (design Weeks 2–3). They are **not dropped** —
they are sequenced to run *after* this additive pass, because the design (Q16b) prescribes
**overlap-then-cleanup**: add the new home first, validate it fires in real sessions, *then*
remove the duplicates. BC-11750 (pointer removal) is explicitly `blockedBy` BC-11749 (these
hooks) because deleting the pointer lines before the hooks are proven would strip brain-first
guidance entirely. So this pass ships brite-core **additively** — during the overlap window
the guidance is double-delivered (pointer lines + hooks), which is harmless. The subtractive
steps land next, once the hooks are validated firing in real sessions:

- **BC-11750** — remove the pointer lines (43 occurrences: 36 in `.md` bodies + 7 in `.tmpl`
  sources; acceptance gate `grep -rE '\*\*Brain-first\*\*' plugins/ --include='*.md' | grep -v plugins/core/`
  → 0 after also regenerating the 7 templated `SKILL.md`. The `plugins/core/` exclusion skips
  this doc + the README, which reference the token descriptively) + add core-enablement
  warnings to the 5 domain plugins.
- **BC-11753** — remove the now-duplicate `gbrain-team` MCP from the 5 domain `.mcp.json` and
  the shared security/quality hooks from their `hooks/hooks.json`.

> This pass is the additive keystone only (BC-11748 + BC-11749 + the additive half of
> BC-11752). BC-11750 and BC-11753 remain open and will be completed in a follow-up pass
> within the same sprint, gated on real-session hook validation.

## The SubagentStart fix in one line

```bash
jq -Rs '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: .}}' "$GUIDANCE"
```

SessionStart treats raw stdout as `additionalContext`; **SubagentStart does not** — raw
stdout there goes to the debug log and never reaches the subagent. That asymmetry is exactly
why PR #385 failed silently. brite-core's SubagentStart hook emits the envelope and degrades
loudly (logs `jq missing` vs `file unreadable` to stderr) instead of `2>/dev/null || true`.
`tests/test_size_cap.sh` locks both the ≤2KB cap and the envelope shape.
