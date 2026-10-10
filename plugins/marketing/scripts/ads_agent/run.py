"""One bounded ads-agent run (BC-28215): results snapshot in, change plan out.

Results come from the warehouse snapshot only, never from the ad APIs (spec story 45).
The platform adapter is read for current settings only; propose mode never writes to it.

Where later tickets plug in:
- act mode (BC-28216): after the log write, apply the new `proposed` rows through
  `adapter.apply(change)` and log the result. Today any mode but propose raises.
- Meta (BC-28218): pass a Meta adapter with the same `platform` / `read_settings` shape,
  budgets normalised to micros.
- season rules and the step-up gate (BC-28220): append to CHECKS; add keys to the check
  context (e.g. the install-date feed) in `run`.
"""

from __future__ import annotations

import hashlib
import json

# The rule settings a run needs. Values are config, never code, and never in this public
# repo: a file passed with --rules until BC-28216's warehouse settings table exists.
RULES = {
    "weekly_ceiling": "dollars a week across Brite's own campaigns on this platform",
    "max_move_pct": "largest change to one setting in one run, as a fraction (0.25 = 25%)",
    "min_conversions": "conversions a campaign needs in the snapshot before it is judged",
}


def run(*, warehouse, adapter, slack, rules, now, mode="propose", emit=False):
    """Plan, log and post one day's changes. `emit` returns the plan and writes nothing
    (ADR-028's side-effect-free mode)."""
    if mode != "propose":
        raise NotImplementedError(f"{mode} mode is BC-28216; only propose mode is built")
    missing = [k for k in RULES if k not in rules]
    if missing:
        raise ValueError(f"rule settings missing: {', '.join(missing)}")
    snapshot = [r for r in warehouse.read_snapshot() if r["platform"] == adapter.platform]
    settings = adapter.read_settings(sorted({r["account_id"] for r in snapshot}))
    run_date = now.date().isoformat()

    changes, why_none = _propose_budget_move(snapshot, settings, rules)
    ctx = {"changes": changes, "settings": settings, "rules": rules, "now": now}
    for c in changes:
        c["checks"] = []
        for check in CHECKS:
            ok, detail = check(c, ctx)
            c["checks"].append({"name": check.__name__.lstrip("_"), "passed": ok, "detail": detail})
        if not all(k["passed"] for k in c["checks"]):
            c["status"] = "held"
    if not changes:
        changes = [{"status": "no_change", "account_id": None, "target_type": None, "target_id": None,
                    "target_name": None, "field": None, "old": None, "new": None,
                    "reason": why_none, "checks": []}]
    for c in changes:
        c.update(run_date=run_date, mode=mode, platform=adapter.platform)
        c["key"] = _key(c)

    logged = warehouse.read_logged_keys(run_date)
    new = [c for c in changes if c["key"] not in logged]
    if new and not emit:
        warehouse.write_change_log(new)  # the record first: a failed Slack post loses no plan
        slack.post(summary(new))
    return {"run_date": run_date, "mode": mode, "changes": new, "already_logged": len(changes) - len(new)}


def summary(changes):
    """The daily Slack message: every new change and why. A re-run has none, so it is silent."""
    c0 = changes[0]
    head = f"Ads agent, {c0['platform']}, {c0['run_date']} ({c0['mode']} mode)"
    if c0["status"] == "no_change":
        return f"{head}: No changes. Why: {c0['reason']}."
    counts = {s: sum(c["status"] == s for c in changes) for s in ("proposed", "held")}
    lines = [f"{head}: {counts['proposed']} proposed, {counts['held']} held. Nothing is changed until approved."]
    for c in changes:
        failed = [f"{k['name']} ({k['detail']})" for k in c["checks"] if not k["passed"]]
        lines.append(
            f"• {'HELD ' if failed else ''}{c['target_name']}: daily budget "
            f"${c['old'] / 1_000_000:,.2f} → ${c['new'] / 1_000_000:,.2f}. Why: {c['reason']}. "
            + (f"Failed: {'; '.join(failed)}." if failed else f"Checks passed: {', '.join(k['name'] for k in c['checks'])}.")
        )
    return "\n".join(lines)


def _key(c):
    """Idempotency key: the same edit planned twice on one day is one row."""
    parts = [c["run_date"], c["platform"], c["account_id"], c["target_type"], c["target_id"],
             c["field"], c["old"], c["new"], c["reason"] if c["status"] == "no_change" else None]
    return hashlib.sha256(json.dumps(parts).encode()).hexdigest()


# Limit checks: (change, ctx) -> (passed, detail). ctx holds the day's planned changes,
# current settings, rules and the clock. A change that fails any check is held, not
# proposed. Rule values come from ctx["rules"], never from code.


def _max_move(c, ctx):
    limit = ctx["rules"]["max_move_pct"]
    pct = abs(c["new"] - c["old"]) / c["old"]
    return pct <= limit, f"moves {pct:.0%} (limit {limit:.0%})"


def _no_total_raise(c, ctx):
    net = sum(x["new"] - x["old"] for x in ctx["changes"])
    return net <= 0, f"net daily budget change {'-' if net < 0 else '+'}${abs(net) / 1_000_000:,.2f}"


def _weekly_ceiling(c, ctx):
    ceiling = ctx["rules"]["weekly_ceiling"]
    daily = sum(s["daily_budget_micros"] for s in ctx["settings"]) + sum(x["new"] - x["old"] for x in ctx["changes"])
    weekly = daily * 7 / 1_000_000
    return weekly <= ceiling, f"${weekly:,.2f} a week at planned budgets (ceiling ${ceiling:,.2f})"


CHECKS = [_max_move, _no_total_raise, _weekly_ceiling]


def _propose_budget_move(snapshot, settings, rules):
    """Move budget from the campaign with the worst cost per conversion to the best one
    that is limited by budget. Total daily budget stays the same. Returns (changes, reason
    there are none)."""
    results = {(r["account_id"], r["campaign_id"]): r for r in snapshot}
    judged = []
    for s in settings:
        r = results.get((s["account_id"], s["campaign_id"]))
        if r and not s["budget_shared"] and r["conversions"] >= rules["min_conversions"]:
            judged.append((r["spend"] / r["conversions"], s))
    if len(judged) < 2:
        return [], f"fewer than two campaigns have {rules['min_conversions']} conversions to judge"
    judged.sort(key=lambda x: x[0])
    recipients = [(cpc, s) for cpc, s in judged if s["budget_limited"]]
    if not recipients:
        return [], "no judged campaign is limited by budget, so extra budget would buy nothing"
    (to_cpc, to), (from_cpc, frm) = recipients[0], judged[-1]
    if from_cpc <= to_cpc:
        return [], "the best budget-limited campaign already has the worst cost per conversion"
    step = min(frm["daily_budget_micros"], to["daily_budget_micros"]) * rules["max_move_pct"]
    amount = int(step) // 10_000 * 10_000  # whole cents
    if amount <= 0:
        return [], "the move would be under one cent"
    return [
        _change(frm, -amount, f"cost per conversion ${from_cpc:,.2f}, the worst of the judged campaigns"),
        _change(to, amount, f"cost per conversion ${to_cpc:,.2f} and limited by budget"),
    ], None


def _change(setting, delta, reason):
    old = setting["daily_budget_micros"]
    return {
        "status": "proposed",
        "account_id": setting["account_id"],
        "target_type": "campaign",
        "target_id": setting["campaign_id"],
        "target_name": setting["campaign_name"],
        "field": "daily_budget_micros",
        "old": old,
        "new": old + delta,
        "reason": reason,
    }
