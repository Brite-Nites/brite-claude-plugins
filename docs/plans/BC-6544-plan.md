# BC-6544 plan — fix misleading "PATCH is idempotent" framing in launch-campaign + email-bison

**Issue:** [BC-6544](https://linear.app/brite-nites/issue/BC-6544) — EB `PATCH /api/campaigns/{id}/update` treats omitted boolean fields as `false`; current spec wording calls it "idempotent" without qualification, which creates a silent foot-gun for any future spec that adds a second PATCH on the same campaign.

**Shape:** docs-only TRIVIAL spec fix — 1st BC-6308 round-3 follow-up to ship (the BC-5906 round-2 chain closed at 9/9 with BC-6303). Same TRIVIAL-ship shape as the round-2 chain.

**Target shape:** ~3 small Edits across 2 files. No code, no validators, no new metadata. Verified-against-API replacement text is supplied by the issue body (BC-6544 § Recommended fix).

---

## What's wrong

EB's `PATCH /api/campaigns/{id}/update` is **not** a true partial update. Per the API spec wording (verified `search_api_spec` 2026-05-01), each boolean field's description reads `"If nothing sent, false is assumed."` Live reproduction in BC-6308 round-3 walk T6 confirmed: PATCHing with `{can_unsubscribe: false}` (omitting `plain_text`) silently reset `plain_text` from `true` back to `false`.

The current spec calls this "idempotent" without the qualifier "only if you re-send the EXACT same body." The framing is correct for BC-6306's single-PATCH `{plain_text: true}` flow today (because campaigns start with all-false defaults, and the spec only ever does one PATCH per campaign), but it makes the foot-gun invisible to any future author reviewing the spec.

If anyone ever adds a second PATCH later (e.g., `max_emails_per_day: 100`) without re-sending `plain_text: true`, the BC-6306 plain_text production-blocker class is silently reintroduced.

## Sites to fix (4 total)

Verified via `grep -n "idempotent"` 2026-05-01:

1. **`plugins/marketing/commands/launch-campaign.md` line 545** — Phase 5 step 8, the canonical "Apply plain_text deliverability default" paragraph. Currently says: *"PATCH is idempotent (re-asserting plain_text: true against an already-plain-text campaign is a no-op), so reused campaigns and resume runs are both safe."* — load-bearing site, this is what BC-6544 explicitly calls out.

2. **`plugins/marketing/commands/launch-campaign.md` line 548** — Phase 5 fail-mid-loop paragraph. Currently says: *"After partial-PATCH, the spec re-runs the step 8 PATCH loop on every campaign in campaign_ids regardless of prior state — PATCH is idempotent, so already-plain-text campaigns are no-ops."* — same misleading framing, smaller blast-radius (resume path), but should match step 8's tightened wording.

3. **`plugins/marketing/tools/integrations/email-bison.md` line 212** — § Common workflows row 2a (`update_campaign` Tool inventory entry). Currently ends with: *"Single PATCH per campaign — not on the two-call confirmation gate list. Idempotent."* — needs to extend with the omitted-field gotcha so the canonical reference card carries the warning, not just the launch-campaign command.

4. **`plugins/marketing/tools/integrations/email-bison.md` line 271** — § Known gotchas `plain_text` bullet. Currently says: *"single PATCH, idempotent — update_campaign is NOT on the two-call confirmation gate list"* — same framing issue; tighten in line with the row 2a update.

The 6 other "idempotent" matches in `launch-campaign.md` (lines 280, 863, 867, 938, 962, 963) are about different idempotency concerns (re-running the whole command, Phase 11 not being idempotent, custom-variables POST) and remain accurate — leave them alone.

---

## Tasks

### Task 1 — Tighten launch-campaign.md Phase 5 step 8 (line 545)

**File:** `plugins/marketing/commands/launch-campaign.md`

**What to change:** Replace the trailing "PATCH is idempotent (re-asserting plain_text: true against an already-plain-text campaign is a no-op), so reused campaigns and resume runs are both safe." sentence with the BC-6544 § Recommended fix replacement text, adapted to fit the surrounding paragraph:

> **EB's PATCH treats omitted boolean fields as `false`** (per the API spec — *"If nothing sent, false is assumed."*). The single `plain_text: true` PATCH is safe BECAUSE campaigns start with all-false defaults — but ANY future PATCH on this campaign that intends to preserve `plain_text: true` MUST re-send it explicitly in the body. The same rule applies to any other boolean setting (`open_tracking`, `can_unsubscribe`, `reputation_building`, etc.). Re-asserting `plain_text: true` against an already-plain-text campaign is the safe no-op; OMITTING it from a subsequent PATCH silently resets it. Reused campaigns and resume runs are safe under the current single-PATCH flow; do NOT add a second PATCH to this campaign without re-sending `plain_text: true`.

**Why this wording:** the issue's recommended replacement is verbatim except the trailing "Reused campaigns and resume runs are safe under the current single-PATCH flow; do NOT add a second PATCH to this campaign without re-sending `plain_text: true`." sentence — added to preserve the reused/resume safety claim that the original sentence carried (and that the next paragraph at line 548 echoes).

**Verification:** `grep -c "If nothing sent, false is assumed" plugins/marketing/commands/launch-campaign.md` returns ≥ 1.

---

### Task 2 — Tighten launch-campaign.md Phase 5 fail-mid-loop paragraph (line 548)

**File:** `plugins/marketing/commands/launch-campaign.md`

**What to change:** In the existing line-548 paragraph, replace *"After partial-PATCH, the spec re-runs the step 8 PATCH loop on every campaign in campaign_ids regardless of prior state — PATCH is idempotent, so already-plain-text campaigns are no-ops."* with:

> After partial-PATCH, the spec re-runs the step 8 PATCH loop on every campaign in `campaign_ids` regardless of prior state. Each PATCH re-sends `plain_text: true` explicitly; already-plain-text campaigns are safe no-ops on re-send (the omitted-field reset risk only fires if a different PATCH body is sent without re-asserting `plain_text: true` — see step 8).

**Why:** the partial-PATCH resume path is the most likely future-author trap (someone might think "PATCH idempotent → I can just send `{can_unsubscribe: false}` here and skip the plain_text"). The wording change keeps the resume-safe claim but anchors it to the always-include rule.

**Verification:** `grep -n "the omitted-field reset risk" plugins/marketing/commands/launch-campaign.md` returns line 548 (or whichever line the paragraph lands on after the line-545 edit).

---

### Task 3 — Extend email-bison.md row 2a Tool inventory (line 212) and § Known gotchas plain_text bullet (line 271)

**File:** `plugins/marketing/tools/integrations/email-bison.md`

**What to change (line 212):** Replace the trailing "Idempotent." with:

> Idempotent on re-send (each PATCH must include every boolean to preserve — EB resets omitted booleans to `false` per API spec wording *"If nothing sent, false is assumed."*; verified BC-6544).

**What to change (line 271):** Replace *"single PATCH, idempotent —"* with *"single PATCH; idempotent on re-send only when the same body is repeated, see BC-6544 —"* and append at the end of the bullet (after "Surfaced by BC-5906 round-2 dogfood (Sx-15); spec fix shipped in BC-6306."):

> The "PATCH treats omitted booleans as false" gotcha was added 2026-05-01 (BC-6544); details under § Tool inventory row 2a.

**Why:** keeps the two surfaces consistent. Row 2a is the canonical reference card; the gotchas bullet cross-references it. Both updates carry the BC-6544 verification anchor.

**Verification:**
- `grep -c "If nothing sent, false is assumed" plugins/marketing/tools/integrations/email-bison.md` returns ≥ 1.
- `grep -c "BC-6544" plugins/marketing/tools/integrations/email-bison.md` returns ≥ 2.

---

## Out of scope

Per BC-6544 § Out of scope:

- Adding `reputation_building` or `can_unsubscribe` to the spec PATCH (BC-6306 deliberately deferred those — operator preference is OFF; this issue does NOT recommend touching them).
- Any change to BC-6306's existing single-PATCH behavior (works correctly as-is).
- Systematic survey of other EB PATCH endpoints with the same omitted-fields semantics (would require its own investigation issue).

## Acceptance criteria

- [ ] launch-campaign.md line 545 paragraph replaces the unqualified "idempotent" framing with the omitted-field rule + the always-include guidance.
- [ ] launch-campaign.md line 548 fail-mid-loop paragraph aligns with the new wording (resume path remains safe-claimed but anchored to the always-include rule).
- [ ] email-bison.md row 2a Tool inventory entry carries the omitted-field gotcha with the API-spec quote and BC-6544 anchor.
- [ ] email-bison.md § Known gotchas plain_text bullet cross-references the row 2a gotcha and carries the BC-6544 anchor.
- [ ] No other "idempotent" occurrence in either file is changed (the 6 unrelated hits remain).
- [ ] `validate.sh` + `check-guardrails.sh CLAUDE.md` both pass.

## Out-of-band

No plugin version bump needed (per CLAUDE.md gotcha: bump only on `plugins/<plugin>/{hooks,skills,commands,agents}/**` changes — `commands/launch-campaign.md` triggers the rule; `tools/integrations/email-bison.md` does not, but the launch-campaign edit alone forces the bump).

**Plugin bump scope:**

- `plugins/marketing/.claude-plugin/plugin.json` — version bump
- `.claude-plugin/marketplace.json` — matching marketing entry version bump

## Estimated effort

3 tasks × ~3 minutes each = ~10 minutes coding, ~5 minutes review. TRIVIAL ship expected (no validator changes, no new flows, exact wording supplied by the issue body).

## Precedent applied

- **BC-6301 task-2 (5x pattern-match brainstorm-skip rule)** — 9 prior TRIVIAL docs-only spec-fix ships in the BC-5906 round-2 chain (BC-6306/6298/6300/6299/6301/6304/6302/6307/6303); brainstorm skipped per established pattern. This is the 1st BC-6308 round-3 follow-up of the same shape.
- **BC-6306 dogfood-bundle pattern (procedural + canonical reference co-update)** — applies here: launch-campaign.md is the procedural surface, email-bison.md is the canonical reference; both must move together to prevent drift.
- **BC-6298 task-2 precedent (track-instance threshold for promotion to CLAUDE.md)** — this is a 1st-instance signal for "spec wording with embedded foot-gun against unstated invariant." If a similar bug surfaces again, increment the counter; promote at 3rd instance.
