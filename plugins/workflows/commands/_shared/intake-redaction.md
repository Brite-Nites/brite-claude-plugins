# Intake — canonical secret-redaction pattern list

> **Canonical source.** This is the single home for the secret-redaction patterns used by the
> intake front door. Both `/workflows:raise-a-ticket` (product branch) and
> `/workflows:report-issue` (agent-tooling branch / direct alias) reference this file — neither
> inlines its own copy. Add a new pattern **here once**; do not paste pattern lists back into the
> command bodies. Enforced by `plugins/workflows/tests/test-intake-redaction-canon.sh`.

## How to apply (LLM-applied, by design)

Redaction is performed by the model reading the report, **not** by a bundled script — the intake
commands run from arbitrary repos / directories (operator mode, product repos) where a
plugin-relative script isn't on the path. The win here is **one source of truth for the patterns**,
not a new execution model.

1. Scan **all reporter-supplied free text** — the narrative and any pasted log/error blocks. A
   credential can appear anywhere, not just inside a fenced code block.
2. Replace every match with `[REDACTED]`.
3. Put any sanitized log/error text in a fenced code block in the issue body.
4. Always warn the reporter: *"I scanned for common secret patterns and redacted matches — review
   the output below for any secrets I may have missed before confirming."* Redaction is a
   best-effort net over known patterns, not a guarantee; the preview + confirm gate is the backstop.

## Canonical patterns

Redact any occurrence of:

| Pattern | Catches |
|---------|---------|
| `Bearer ` | HTTP bearer auth headers |
| `password=` | URL/query/form password params |
| `password:` | YAML / config / log password fields |
| `token=` | URL/query/form token params |
| `token:` | YAML / config / log token fields |
| `sk-` | OpenAI-style secret keys |
| `AKIA` | AWS access key IDs |
| `postgres://` | Postgres connection strings (embedded creds) |
| `mongodb+srv://` | MongoDB Atlas connection strings |
| `redis://` | Redis connection strings |
| `ghp_` | GitHub personal access tokens |
| `gho_` | GitHub OAuth tokens |
| `glpat-` | GitLab personal access tokens |
| `xoxb-` | Slack bot tokens |
| `xoxp-` | Slack user tokens |
| `hooks.slack.com` | Slack incoming-webhook URLs |
| `PRIVATE KEY` | PEM private-key bodies |
| `-----BEGIN` | PEM block headers (keys / certs) |
| `eyJ` | JWTs (base64url-encoded `{"` header prefix) |
| `api_key=` | Generic API-key params |
| `AIza` | Google API keys |

Screenshots: note they exist but aren't attached (attachments are out of scope for intake).
