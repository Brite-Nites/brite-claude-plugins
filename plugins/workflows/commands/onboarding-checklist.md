---
description: Guide for setting up a new Brite dev environment
---

# Brite Developer Onboarding

Walk the user through setting up their development environment for Brite projects. Verify each step succeeds before moving to the next. If a step fails, help troubleshoot before continuing.

## Step 1: System Prerequisites

Check for and help install required system tools:

| Tool | Check Command | Install (macOS) |
|------|--------------|-----------------|
| **Git** | `git --version` | `xcode-select --install` |
| **Node.js 18+** | `node --version` | `brew install node` or nvm |
| **pnpm** | `pnpm --version` | `npm install -g pnpm` |
| **Python 3.11+** | `python3 --version` | `brew install python@3.11` |
| **Poetry** | `poetry --version` | `pipx install poetry` |
| **Docker** | `docker --version` | Docker Desktop |

Run the check commands and report which tools are already installed and which need setup.

## Step 2: Repository Access

Help the user clone the project repository:

1. Verify GitHub access: `gh auth status`
2. If not authenticated: `gh auth login`
3. Clone the repository the user specifies
4. Verify the clone succeeded

If the user doesn't specify a repo, ask which Brite project they're joining.

## Step 3: Environment Configuration

Guide environment variable setup:

1. Check if `.env.example` or `.env.template` exists in the repo
2. If it does, copy it to `.env`: `cp .env.example .env`
3. Walk through each variable, explaining what it's for
4. Help the user fill in values (API keys, database URLs, etc.)
5. Warn about any secrets that should come from a team lead or password manager

## Step 4: Project Dependencies

Install project dependencies based on what's in the repo:

**If `package.json` exists:**
```bash
pnpm install
```

**If `pyproject.toml` exists:**
```bash
poetry install
```

**If `docker-compose.yml` exists:**
```bash
docker compose up -d
```

Verify each installation completes without errors.

## Step 5: Database Setup

If the project uses a database:

1. Check if PostgreSQL is running locally or via Docker
2. Run migrations if applicable:
   - Python: `alembic upgrade head`
   - Node.js: check for migration scripts in `package.json`
3. Seed data if a seed script exists
4. Verify database connectivity

## Step 6: IDE Configuration

Recommend VS Code extensions based on the project's tech stack:

**Always recommend:**
- ESLint
- Prettier
- GitLens

**For TypeScript/React projects:**
- Tailwind CSS IntelliSense
- Pretty TypeScript Errors

**For Python projects:**
- Python (Microsoft)
- Ruff
- Black Formatter

Check if `.vscode/settings.json` or `.vscode/extensions.json` exists in the repo and point the user to it.

## Step 7: Claude Code Plugin Setup

Install the Brite Claude Code plugins:

```bash
claude plugins add https://github.com/Brite-Nites/brite-claude-plugins
```

Verify the plugin is loaded by checking that `/workflows:tech-stack` is available.

## Step 8: Verification

Run a final check to confirm everything works:

1. **Build check**: Run the project's build command (if any)
2. **Test check**: Run the test suite to confirm a passing baseline
3. **Dev server check**: Start the development server and confirm it responds
4. **Lint check**: Run linters to confirm the codebase is clean

Report results as a checklist:

```
[x] System tools installed
[x] Repository cloned
[x] Environment configured
[x] Dependencies installed
[x] Database running
[x] IDE configured
[x] Claude Code plugins loaded
[x] Build passes
[x] Tests pass
[x] Dev server starts
```

If any step failed, summarize what still needs attention.

## Step 9: Next Steps

Once everything passes, suggest:

1. Read the project's README and CLAUDE.md
2. Check the current sprint in Linear for assigned issues
3. Run `/workflows:tech-stack` to review the technology stack
4. Make a small test change to verify the full workflow (edit, commit, push)
