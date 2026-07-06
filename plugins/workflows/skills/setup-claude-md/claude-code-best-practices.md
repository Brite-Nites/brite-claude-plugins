# Claude Code Best Practices — Reference

## 1. CLAUDE.md Best Practices

- Include all bash commands first (build, test, lint, typecheck, single-test)
- Document code style conventions specific to the project
- Keep it concise — ruthlessly prune; if Claude already does it correctly without the instruction, delete it
- Bullet points are ~60% better followed than prose paragraphs
- Every line should earn its place — pruning heuristic: "Would removing this cause Claude to make mistakes?"
- Code style enforcement belongs in linters/formatters, not CLAUDE.md (60% more efficient)
- Never include generic advice — every line must be project-specific
- Use short, imperative sentences
- Put the most important commands first (build/test/lint)
- Include common pitfalls and gotchas
- Add verification checklists
- Use `/init` to generate a starter CLAUDE.md for a new project

## 2. Memory Hierarchy

Claude Code reads instructions from six levels (highest precedence first):

1. **Managed policy** — `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) or `/etc/claude-code/CLAUDE.md` (Linux). Set by IT/admins; always loaded, highest priority.
2. **Project memory** — `./CLAUDE.md` or `./.claude/CLAUDE.md` at the repo root. Checked into source control. The primary file for project-specific instructions.
3. **Project rules** — `./.claude/rules/*.md` — modular, auto-loaded rule files with optional path-scoping (see Section 3). Checked into source control.
4. **User memory** — `~/.claude/CLAUDE.md` — personal preferences that apply across all projects (e.g., "always use bun", "prefer concise output").
5. **Project local** — `./CLAUDE.local.md` — per-project overrides that are auto-gitignored. Use for personal preferences within a specific project.
6. **Auto memory** — `~/.claude/projects/<project>/memory/` — Claude's own notes persisted across sessions. `MEMORY.md` is always loaded; additional topic files are loaded on demand.

Child-directory `CLAUDE.md` files are loaded on demand when Claude reads files in those directories.

## 3. Modular Rules

The `.claude/rules/` directory provides modular, auto-loaded instruction files:

- All `.md` files in `.claude/rules/` are automatically loaded
- Subdirectory organization is supported (e.g., `.claude/rules/testing/unit.md`)
- Symlinks work for sharing rules across projects: `ln -s ~/shared-rules .claude/rules/shared`
- Path-scoped rules use YAML frontmatter with a `paths:` field:

```yaml
---
paths:
  - "**/*.tsx"
  - "src/components/**/*"
  - "{src,lib}/**/*.ts"
---
These rules only apply to files matching the glob patterns above.
```

**When to use what:**
- **CLAUDE.md** — project-wide instructions, build commands, architecture
- **Rules** — file-type or directory-specific conventions (e.g., "all .tsx files must use named exports")
- **Hooks** — zero-exception enforcement (security blocks, auto-formatting)

## 4. @import Syntax

Reference external files from CLAUDE.md using `@path/to/file`:

```markdown
# CLAUDE.md
@docs/api-conventions.md
@docs/architecture.md
@README.md
```

Use `@import` for detailed documentation that would bloat the main CLAUDE.md. The referenced file's content is loaded into context when CLAUDE.md is read. This keeps the core file concise while making detailed docs available.

- Relative paths resolve relative to the file containing the import
- Imported files can recursively import additional files (max depth of 5)
- Imports inside markdown code spans/blocks are not evaluated

## 5. What NOT to Include in CLAUDE.md

Remove or avoid adding:

- **Standard language conventions** — Claude already knows TypeScript, Python, Go, etc.
- **Code style rules** — use linters/formatters instead (ESLint, Prettier, Ruff)
- **Things Claude can infer from reading code** — patterns visible in existing files
- **Detailed API documentation** — link to docs or use context7 MCP instead
- **File-by-file codebase descriptions** — Claude can read the code itself
- **Long tutorials or explanations** — extract to `docs/` with `@import`
- **Information that changes frequently** — it will go stale quickly
- **Self-evident practices** — "write clean code", "follow best practices"

## 6. Context Window Management

- Context fills fast; performance degrades as it fills
- Scope conversations to one feature/task at a time
- Use `/clear` between unrelated tasks
- Use `/compact <instructions>` for controlled compaction with custom focus
- Use `Esc + Esc` or `/rewind` to open the rewind menu — restore previous state or summarize from a checkpoint
- Break large projects into plans saved to files, not held in context
- Use subagents (`context: fork`) for multi-phase work
- Prefer file-based communication between phases over context passing
- MCP tools consume tokens — don't enable all servers at once; only what you need

## 7. Plan Before Coding

Use Plan Mode to separate exploration from execution:

- **Explore** — read code, understand the problem, gather context
- **Plan** — design the approach, identify files to change, set validation criteria
- **Implement** — execute the plan, write code
- **Commit** — verify and commit

Skip planning for trivial tasks — if you could describe the diff in one sentence, just do it.

- Save plans to files so they survive context resets
- Use `Ctrl+G` to edit plans in your text editor for faster iteration
- Include validation criteria in every plan step
- Never let the agent jump straight to coding on complex tasks

**Writer/Reviewer pattern**: Use separate sessions — one to implement, another to review. The reviewer session gets a fresh context window without implementation bias.

## 8. Verification

Verification is the single highest-leverage thing you can do for agent effectiveness.

| Before | After |
|--------|-------|
| "Write tests" | "Run `npm test -- --grep 'auth'` and verify 0 failures" |
| "Check it works" | "Run `curl localhost:3000/api/health` and verify `{"status":"ok"}`" |
| "Make sure types are correct" | "Run `npx tsc --noEmit` with 0 errors" |
| "Update the docs" | "Verify `/docs` renders without 404s" |

- Run build, lint, and typecheck after every meaningful change
- Invest in making verification rock-solid — agents can only self-correct if they can detect their own mistakes
- Address root causes, not symptoms — a failing test is a signal, not the problem
- Prefer automated checks over manual review
- Test commands should be runnable with a single command

## 9. Configuration Best Practices

- `/permissions` — allowlist commands you trust (e.g., `npm test`, `npx tsc`)
- CLI tools (`gh`, `aws`, `vercel`) are the most context-efficient way to interact with external services
- MCP servers via `claude mcp add` — extend capabilities but keep the set focused
- **Hooks are deterministic; CLAUDE.md is advisory** — use hooks for zero-exception rules (security blocks, formatting) and CLAUDE.md for guidance that may need judgment

## 10. Common Failure Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Kitchen sink session | Mixing unrelated tasks fills context with irrelevant state | One task per session, `/clear` between tasks |
| Correcting over and over | Repeated corrections pollute context; Claude gets confused | `/clear` after 2 failed attempts, restate clearly |
| Over-specified CLAUDE.md | Important rules get lost in noise (>150 lines) | Prune to essentials, extract detail to `docs/` |
| Trust-then-verify gap | Plausible code accepted without running tests | Always run verification commands before marking done |
| Infinite exploration | Unscoped investigation fills context window | Set explicit scope and file count limits upfront |
| Excessive MCP tools | >20k tokens of MCP definitions degrades performance | Only enable what you need for the current task |
| Skipping the planning phase | Jumping to code on complex tasks causes rework | Use Plan Mode for anything non-trivial |
| Circular dependencies | Task graphs with cycles prevent agent progress | Explicit dependency ordering, break cycles |
| Holding plans in context | Large plans consume window, degrade over time | Save plans to files, reference by path |
| Over-prescriptive steps | Rigid instructions prevent agent problem-solving | Describe *what* and *why*, let agent decide *how* |
| Missing validation criteria | Completion is ambiguous without concrete checks | Every task needs a verification command |

## 11. Task Decomposition for Agents

- Each task needs full context (an agent should never need to ask questions)
- Include: what to do, why, relevant files, constraints, how to verify
- Complexity estimate (S/M/L) helps agents plan their approach
- Explicit dependencies prevent ordering mistakes
- Self-contained tasks can be parallelized across agents
- An agent reading the issue cold should be able to start immediately

## 12. CLAUDE.md Section Checklist

Use this when generating a new CLAUDE.md:

**Required:**
- [ ] Build & Test Commands (build, test, lint, typecheck, dev, single-test)
- [ ] Code Conventions (only non-obvious, project-specific rules)
- [ ] Architecture (key patterns, data flow, important directories)
- [ ] Gotchas & Workarounds (things that will bite you)

**Optional but valuable:**
- [ ] Environment Setup (env vars, secrets, dependencies)
- [ ] Workflow Rules (branches, commits, PRs, CI)
- [ ] Testing Conventions (framework, naming, coverage)
- [ ] Verification Checklist (pre-completion checks)
