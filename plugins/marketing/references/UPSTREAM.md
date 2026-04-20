# Upstream provenance

`plugins/marketing/references/` was imported from [Revgrowth1/ai-gtm-workflows](https://github.com/Revgrowth1/ai-gtm-workflows) (MIT) as a content port on **2026-04-20**. No subtree, no automatic sync — these are static reference assets consumed by Brite marketing skills.

## Pinned commit

- **Source repo:** https://github.com/Revgrowth1/ai-gtm-workflows
- **Branch:** `main`
- **Commit SHA:** `03b30e166d3f8ed0eb9864cd2a78dda719558826`
- **Short SHA:** `03b30e1`

## License

MIT. See upstream [LICENSE](https://github.com/Revgrowth1/ai-gtm-workflows/blob/03b30e1/LICENSE). Original work © Revgrowth1 and contributors.

## Per-file manifest

| Target path (under `plugins/marketing/references/`) | Upstream path | Verbatim vs adapted |
|-----------------------------------------------------|---------------|---------------------|
| `research-processes/find-c-suite.md` | `references/research-processes/find-c-suite.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-competitors.md` | `references/research-processes/find-competitors.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-department-heads.md` | `references/research-processes/find-department-heads.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-directors.md` | `references/research-processes/find-directors.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-founders.md` | `references/research-processes/find-founders.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-growth-signals.md` | `references/research-processes/find-growth-signals.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-hiring.md` | `references/research-processes/find-hiring.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-job-role-insights.md` | `references/research-processes/find-job-role-insights.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-negativity.md` | `references/research-processes/find-negativity.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-news.md` | `references/research-processes/find-news.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-people-creative.md` | `references/research-processes/find-people-creative.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-pr-releases.md` | `references/research-processes/find-pr-releases.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-profiles.md` | `references/research-processes/find-profiles.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-reviews.md` | `references/research-processes/find-reviews.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-specialist-roles.md` | `references/research-processes/find-specialist-roles.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `research-processes/find-vp-leadership.md` | `references/research-processes/find-vp-leadership.md` | Verbatim (+ frontmatter; Serper→WebSearch prose rule) |
| `creative-thinking-models.md` | `references/creative-thinking-models.md` | Adapted — upstream verbatim + Brite worked examples appended |
| `hidden-signals-library.md` | `references/hidden-signals-library.md` | Adapted — upstream verbatim + 3 Brite-entity tables appended (Municipalities, HOAs, Universities) |
| `shelf-life-patterns.md` | `references/shelf-life-patterns.md` | Verbatim (+ frontmatter) |

## Serper → WebSearch prose translation

The upstream repo originated in a Serper-based agent stack. Brite standardizes on Claude Code's built-in `WebSearch` tool. Policy:

- Replace literal mentions of `Serper` (the search API name) with `WebSearch` in prose ONLY.
- Preserve query STRINGS verbatim — those are the validated IP that drives retrieval quality.
- Example: `"run this Serper query: site:linkedin.com/in intitle:\"VP Marketing\""` → `"run this WebSearch query: site:linkedin.com/in intitle:\"VP Marketing\""`. The query string is untouched.
- **Verification scope:** The issue-body rule `grep -rE "Serper" plugins/marketing/references/` returns no matches across the 19 **ported content files**. The term appears only in this `UPSTREAM.md` and the companion `README.md` — necessary meta-documentation of the policy itself. Excluding those two meta-files:

  ```bash
  grep -rlE "Serper" plugins/marketing/references/ --exclude=UPSTREAM.md --exclude=README.md
  # → empty (no matches)
  ```
  At pinned SHA `03b30e1`, upstream had **zero** Serper mentions across all 19 files — the translation rule was a no-op on first import. The rule is codified here for future upstream pulls where Serper references may re-appear.

## Brite-entity vertical swap

The originating Linear issue (BC-5823) body named Entertainment Venues / Landscape Contractors / HOAs as the three new Brite-entity hidden-signal tables. The user approved a swap on 2026-04-20 to **Municipalities / HOAs / Universities** because those are the three handbook-Active verticals with ship-ready ICP + persona documentation in `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md`. Brite Supply verticals are explicitly deferred from the handbook taxonomy, so vertical signal tables that would depend on Supply personas are out-of-scope until the handbook expands.

## Sync model

**Fork-by-default.** We treat `plugins/marketing/references/` as Brite content going forward. **No automatic upstream pulls.**

If we ever want to pull upstream improvements, the operation is manual:

1. Diff the target file against the pinned SHA (`git show 03b30e1:references/<path>`).
2. Re-apply Brite additions (worked examples, Brite-entity tables) to the new upstream body.
3. Bump the `source:` frontmatter and the `03b30e1` references in this manifest + adaptation banners.
4. Re-run the Serper→WebSearch grep as regression check.

The two adapted files (`creative-thinking-models.md`, `hidden-signals-library.md`) carry inline banners on line 1 that name the upstream commit — any future re-sync must preserve that convention.

## Attribution

Files adapted from upstream carry an inline HTML comment on line 1 above any frontmatter:

```
<!-- Adapted from Revgrowth1/ai-gtm-workflows@03b30e1 (MIT). <brief description of Brite additions>. -->
```

Verbatim-ported files carry only the YAML frontmatter block naming the upstream path and license.
