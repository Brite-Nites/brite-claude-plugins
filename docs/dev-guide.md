# Developer Iteration Guide

Fast feedback loop for plugin development. Edit → validate → test → repeat.

## Setup

### Enable dev mode

Replace the installed marketplace clone with a symlink to your working copy:

```bash
scripts/dev-setup.sh
```

This backs up the installed plugin and creates a symlink so edits in your repo are immediately visible to Claude Code. Restart Claude Code to pick up changes.

### Disable dev mode

Restore the original installation:

```bash
scripts/dev-teardown.sh
```

## Validate

### Full plugin validation

Run all checks (JSON validity, frontmatter, cross-references, step sequences, hooks):

```bash
scripts/validate.sh
```

### Single skill/command/agent validation

Fast check on one file (~1s):

```bash
# Skill — by directory name
scripts/validate-single.sh brainstorming

# Command — by filename (with or without .md)
scripts/validate-single.sh session-start
scripts/validate-single.sh session-start.md

# Agent — with agents/ prefix
scripts/validate-single.sh agents/code-reviewer
```

Checks frontmatter fields, name matching, format rules, and step sequence.

## Test Triggers

### Full trigger suite

Run all test cases from the trigger registry:

```bash
scripts/test-skill-triggers.sh
```

### Single skill trigger test

Test whether a phrase matches a specific skill:

```bash
# Ad-hoc phrase + registry test cases
scripts/test-single-trigger.sh brainstorming "let's explore design alternatives"

# Registry test cases only
scripts/test-single-trigger.sh brainstorming
```

Shows match/no-match with details (which keyword matched, negative keyword blocks, precedence).

## Typical Workflow

1. **Start dev mode** — `scripts/dev-setup.sh` (once)
2. **Edit** a skill, command, or agent
3. **Validate** — `scripts/validate-single.sh <name>`
4. **Test triggers** — `scripts/test-single-trigger.sh <skill> "test phrase"` (if skill has trigger keywords)
5. **Full validation** — `scripts/validate.sh` (before commit)
6. **Test interactively** — restart Claude Code and test the skill manually
7. **End dev mode** — `scripts/dev-teardown.sh` (when done)

## Pre-push Hook

To run full validation automatically before every push:

```bash
scripts/setup-hooks.sh
```

## Further Testing

See [`testing-guide.md`](testing-guide.md) for the full interactive testing checklist (51 tests across 7 layers).
