# BC-11924 — ADR-031 Anti-Spam Guardrails Consolidation

**Linear:** [BC-11924](https://linear.app/brite-nites/issue/BC-11924)
**Milestone:** Marketing Plugin v0.1 — GTM Workflows (Revgrowth)
**Type:** Documentation
**Estimate:** ~1.5h

## Goal

Author `docs/decisions/031-anti-spam-guardrails.md` consolidating the five TAM-protection rules currently scattered across `prospect-temporal-gate` skill body, `handbook/marketing/go-to-market/campaign-rules.md`, and operator memory.

## Tasks

1. **Read source material**
   - `plugins/marketing/skills/prospect-temporal-gate/SKILL.md` (published version at `~/.claude/plugins/marketplaces/brite-claude-plugins/plugins/marketing/skills/prospect-temporal-gate/SKILL.md`) — confirm exact rule statements + exceptions
   - Existing ADRs 008, 009 for format/voice consistency
   - BC-10198 description (already pulled) for CampaignMember history rationale
   - Optional: `gh api repos/Brite-Nites/handbook/contents/marketing/go-to-market/campaign-rules.md` if accessible — confirm handbook rule wording

2. **Draft ADR-031**
   - Status: Proposed
   - Context: scattered rules + 2026-05-28 user intent
   - Decision: 5 rules with statement / scope / exceptions / enforcement layer for each
   - Consequences: enforcement layer becomes prospect-temporal-gate (links BC-11930)
   - Alternatives: doing nothing / handbook-only / per-skill — analysis
   - Cross-links: BC-10190, BC-10198, BC-10191, BC-10192, campaign-rules.md

3. **Update CLAUDE.md ADR list**
   - Add `ADR-031: Anti-spam guardrails consolidation` entry under `## Architecture Decisions`

4. **Validate**
   - `./scripts/check-guardrails.sh --claude-md CLAUDE.md` (size + anti-slop)
   - `./scripts/validate.sh` (CI parity)
   - Manual: ensure all 5 rules + 4 cross-links present

5. **Commit + PR**
   - Commit: `BC-11924: ADR-031 — anti-spam guardrails consolidation`
   - PR title same
   - Use HEREDOC for commit message; Co-Authored-By footer

## Out of Scope

- Rewriting `prospect-temporal-gate` skill (separate issue BC-11930)
- Handbook PR to `campaign-rules.md` (cross-repo, separate)
- ADR-030 (Snowflake access) — next issue in this session
- Audience-view catalog or Source 4 design — later in this session

## Acceptance Criteria

Mirrors [BC-11924](https://linear.app/brite-nites/issue/BC-11924) AC. The 5 mandatory items.

## Notes

- Reference voice: ADR-008 is the closest peer (Brite-original, Marketing plugin-scoped).
- The calendar-year vertical rotation rule (rule 5) is **new policy** introduced by this ADR — call this out explicitly in the Decision section so reviewers spot it.
