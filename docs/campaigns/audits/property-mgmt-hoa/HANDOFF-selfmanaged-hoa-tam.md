# HANDOFF — Self-Managed HOA TAM-Map (Phoenix pilot)

**For a fresh session. Goal: build a TAM of self-managed (board-run) HOAs in the Phoenix metro for a Brite Nites holiday-lighting campaign, using `/marketing:tam-map`.**

---

## 1. Objective
Build a prospect database of **independent / self-managed HOAs** in **Maricopa County (Phoenix metro)** — communities run by a volunteer board with **no management company** — and get a reachable board contact for each. Pilot first; scale to other metros if it passes.

## 2. Why this vertical + how it differs from what's already loaded
A separate 3,811-lead HOA campaign is already loaded in Email Bison (drafts 162/163/164). Those are **professionals at management firms** (FirstService, Associa, etc.) who manage others' HOAs — firmographically findable.

**This TAM is the opposite population:** self-run associations with no management company. They are **not** in any firmographic data source (no company, volunteer boards). **Zero overlap by definition** — and the sourcing method (below) explicitly excludes any HOA that has a management company, i.e. the firms already in the loaded campaign.

## 3. ICP (what qualifies)
- Entity: **Brite Nites** (residential holiday lighting). `docs/marketing-context.md` does NOT exist yet, so the command will AskUserQuestion for entity — pick Nites, or provide inline ICP.
- **Self-managed** = the association's Arizona Corporation Commission filing lists the **board/officers as the agent**, NOT a management company. If a management company is the agent → DISQUALIFY (already covered by the loaded campaign).
- Geography: Maricopa County / Phoenix metro (pilot). In Brite's service footprint + high HOA density + strong desert holiday-lighting culture.
- Buyer = board president / treasurer (direct; no manager gatekeeper).

## 4. Validated sources (from the 2026-07-27 de-risk test)
1. **Arizona Corporation Commission** (azcc.gov / ecorptestonline.azcc.gov/EntitySearch) — HOAs are nonprofit corps; annual reports list **directors/officers + designated agent (mgmt co or board)**. The agent field IS the self-managed flag. PRIMARY spine.
2. **azhoawatch.org** — aggregates ACC data per-HOA, cleanly flags **management-company vs self-managed + board names** (one page fetched fine via WebFetch; bulk-scrapability UNTESTED — verify early).
3. **arizona-hoa.com** — 11k AZ HOAs + 30k board members + emails, but **paywalled / 403-blocked** to scraping. Consider a paid subscription only if free sources yield too few emails.

## 5. Build steps (maps onto tam-map phases)
1. **Source Discovery / Collection** — pull Maricopa County nonprofit entities matching "homeowners association / community association / property owners association" from ACC (or scrape azhoawatch).
2. **Exclusion** — drop any whose designated agent is a management company → keeps self-managed only.
3. **Extract** board officer names + mailing address per HOA.
4. **Split** — (a) HOA has a website → scrape `board@` / `info@` / `president@`; (b) names + address only → direct-mail bucket.
5. **Verify** emails via BounceBan / MillionVerifier.
6. **Phase 4.5 MANDATORY** — cross-workspace EB exclusion (both b2b + personal) so we don't re-hit anyone already in EB, incl. the loaded HOA campaign.

## 6. Expected yield + the known bottleneck
**Findability is proven. Contactability is the bottleneck** — the ACC gives board NAMES + mailing address, but email/website is often absent. Estimate **~30–50% email-reachable**, the rest **direct-mail-only**. Realistic pilot: **~50–100 email-contactable self-managed HOAs from Phoenix**, plus a larger direct-mail bucket.
**Pass/fail:** ≥150 candidate self-managed HOAs found AND ≥30% yield a *deliverable* board email → scale to other metros. Mostly-dead inboxes → stop cheaply.

## 7. Tooling prerequisites + caveats (READ before starting)
- **Run `/marketing:setup-tam-map` first** — tam-map needs Spider.cloud / AI Ark / Discolike MCPs + IcyPeas/BlitzAPI/Prospeo/MillionVerifier scripts via `bw-run.sh` (Bitwarden). Per prior sessions the pipeline has needed setup; relaunch Claude Code after setup so MCP processes spawn.
- **Source-method deviation:** the standard tam-map **Nites path is "Google Maps ZIP"**, which will NOT surface self-managed HOAs well (they have no storefront listing). Steer Phase 1 Source Discovery to the **ACC / azhoawatch** sources instead. If the command fights this, a **custom build** (ACC/azhoawatch scrape → filter self-managed → scrape→extract board email → verify) is a valid fallback — mirrors the historic-sites / senior-living custom builds.
- **marketing-context.md missing** → entity AskUserQuestion will fire; pick Nites.
- EB b2b MCP was disconnected last session; if it's down again, direct-API works via `$EMAILBISON_B2B_TOKEN`.

## 8. Copy angle (for later)
**Direct-to-board, no gatekeeper.** Smaller communities → lower ACV, higher-touch, faster personal decision, less competition (big lighting vendors chase managed portfolios). Pitch the president/treasurer directly.

## 9. Related context
- Loaded management-firm campaign + full audit: `docs/campaigns/audits/property-mgmt-hoa/SESSION-STATUS.md`
- Memory: `project_hoa_campaign_build`, `reference_serper_maps_tam`, `reference_tam_map_pipeline_broken`, `reference_people_finding_method`

---

## KICKOFF PROMPT (paste into the new session)

> I want to build a TAM of **self-managed HOAs in the Phoenix metro (Maricopa County)** — board-run associations with **no management company** — for a Brite Nites holiday-lighting campaign. This is a NEW vertical, distinct from the management-firm HOA campaign already loaded in EB.
>
> First read `docs/campaigns/audits/property-mgmt-hoa/HANDOFF-selfmanaged-hoa-tam.md` for full context, validated sources, and caveats.
>
> Then run `/marketing:tam-map` for this ICP. Note: the standard Nites "Google Maps ZIP" source won't find self-managed HOAs — steer Source Discovery to the **Arizona Corporation Commission filings + azhoawatch.org** (an HOA is self-managed when its ACC designated agent is the board, not a management company). If tam-map tooling isn't ready, run `/marketing:setup-tam-map` first (and relaunch). Exclude anyone already in EB (Phase 4.5). Pilot target: ~50–100 verified email-contactable self-managed HOAs; flag the direct-mail-only bucket separately.
