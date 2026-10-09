"""One bounded ads-agent run: results snapshot in, change plan out (BC-28215), and in act
mode the plan applied inside the hard limits of ADR-0033 in brite-gtm (BC-28216).

Results come from the warehouse snapshots only, never from the ad APIs (spec story 45).
The platform adapter is read for current settings. Only act mode writes to it, through
`adapter.apply(change)`, and every hard limit is checked again just before each write.

Change-log rows. A plan row is one planned edit to one setting: proposed, held (failed a
limit check) or no_change. A budget move is two plan rows, a cut and a raise, and is one
change: only the planner writes the raise, keyed `<cut key>:pair`. Approvals and apply
results never edit a plan row. Each is a new row whose key starts with the plan row's key:
    <cut or change key>:approved     the Head of GTM approved it (a move: both halves);
                                     logged_by is the approver
    <plan key>:applied               act mode wrote it, or found it already in effect
    <plan key>:apply_failed:<hash>   act mode refused it or the write failed; reason says why
Only `applied` is final. A refused or failed change is tried again on the next act run.
A frozen run (below) logs one `frozen` row per platform per day and no plan rows.

Act applies cuts first. A raise is written only after its own paired cut is applied, and
only if the pair's net is zero or less; a raise with no paired cut is always refused.

Weeks 1-2 (rule `weeks_1_2` on): act applies approved changes only, at most one change per
platform per day. A move counts as one change, so one approval moves the money.

The run date (BC-28522). Plan, approve and act all work on one day's plan: the calendar
date of `now` in the rules' `timezone`, not in UTC. By the UTC date, an approval at 7 pm US
Central would look for the next day's plan and fail. `now` itself is never converted, and a
`now` with no time zone is refused.

The data freeze (BC-28219). If the lead feed breaks, the snapshot shows no leads and the
kill rule turns off good ads. So before planning, a run reads yesterday's row (the day
before the run date) of the lead reconciliation mart for its platform. The run is frozen
when the row is missing, when the platform's and BriteBase's lead counts differ by more
than `max_lead_count_gap`, or when both counts are zero but the platform spent money. A
frozen run plans, approves and applies nothing; it logs one `frozen` row and posts one
Slack alert a day. The watchdog is a separate run and still pauses.

Where later tickets plug in:
- Meta (BC-28218): pass a Meta adapter with the same `platform` / `read_settings` /
  `read_ads` / `apply` shape, budgets normalised to micros.
- season rules and the step-up gate (BC-28220): append to CHECKS; add keys to the check
  context (e.g. the install-date feed) in `_plan`.
"""

from __future__ import annotations

import hashlib
import json
from datetime import date, timedelta
from zoneinfo import ZoneInfo, available_timezones

# The rule settings a run needs. Values are config, never code, and never in this public
# repo: a file passed with --rules until BC-28220's warehouse settings table exists. The
# agent only reads them; nothing here can write one, so it cannot clear the stop.
RULES = {
    "weekly_ceiling": "dollars a week across Brite's own campaigns on this platform",
    "max_move_pct": "largest change to one setting in one run, as a fraction (0.25 = 25%)",
    "min_conversions": "conversions a campaign needs in the snapshot before it is judged",
    "weeks_1_2": "true: act applies only approved changes, at most one per platform per day",
    "emergency_stop": "true while the Head of GTM's emergency stop is on: act writes nothing",
    "target_cpl": "target cost per lead in dollars (a conversion in the snapshot is a lead)",
    "kill_multiple": "an ad with zero leads turns off once it spends this many target_cpl (3)",
    "compare_multiple": "ads compare on cost per lead only once each spends this many target_cpl (5)",
    "timezone": "IANA time zone name (Area/City); the run date is the calendar date there",
    "max_lead_count_gap": "writes freeze above this gap in yesterday's platform vs BriteBase lead counts (0.20 = 20%)",
}
FLAGS = ("weeks_1_2", "emergency_stop")  # must be JSON true or false, so a typo fails loudly

MODES = ("propose", "act")
PLAN = ("proposed", "held", "no_change")
BUDGET, STATUS = "daily_budget_micros", "status"
PAIR = ":pair"  # a move's raise is keyed <cut key>:pair; only the planner writes one

# What act mode may write, as (target type, field). Anything else is refused, rule
# settings included (ADR-0033 §2: the agent never changes its own rules).
WRITABLE = {("campaign", BUDGET), ("campaign", STATUS), ("ad", STATUS)}

# The edit columns a result row copies from its plan row, so it reads on its own.
EDIT = ("run_date", "platform", "account_id", "target_type", "target_id", "target_name",
        "field", "old", "new", "checks")


def run(*, warehouse, adapter, slack, rules, now, mode="propose", emit=False):
    """Plan, log and post one day's changes. In act mode, then apply what the hard limits
    allow and log each result. `emit` returns the plan and writes nothing anywhere
    (ADR-028's side-effect-free mode)."""
    if mode not in MODES:
        raise ValueError(f"mode must be propose or act, not {mode!r}")
    _check_rules(rules)
    run_date = _run_date(rules, now)
    log = [r for r in warehouse.read_change_log(run_date) if r["platform"] == adapter.platform]
    frozen = _freeze(warehouse, adapter.platform, run_date, rules)
    if frozen:
        return _frozen_run(frozen, log, warehouse=warehouse, slack=slack, rules=rules,
                           run_date=run_date, mode=mode, platform=adapter.platform, emit=emit)
    snapshot = [r for r in warehouse.read_snapshot() if r["platform"] == adapter.platform]
    ad_results = [r for r in warehouse.read_ad_snapshot() if r["platform"] == adapter.platform]
    accounts = sorted({r["account_id"] for r in snapshot + ad_results + log if r["account_id"]})
    settings = adapter.read_settings(accounts)
    campaigns = {(s["account_id"], s["campaign_id"]): s for s in settings}
    ads = {(a["account_id"], _ad_target(a)): a for a in adapter.read_ads(accounts)}

    if mode == "act" and any(r["status"] in PLAN for r in log):
        changes = []  # act plans once a day: a re-run only finishes today's plan
    else:
        changes = _plan(snapshot, ad_results, settings, campaigns, ads, rules, now)
        for c in changes:
            c.update(run_date=run_date, mode=mode, platform=adapter.platform)
            c["key"] = _key(c)
        move = [c for c in changes if c["field"] == BUDGET]
        if len(move) == 2:  # the day's one budget move, [cut, raise]: link the raise to its cut
            move[1]["key"] = f"{move[0]['key']}{PAIR}"
    logged = {r["key"] for r in log}
    new = [c for c in changes if c["key"] not in logged]
    out = {"run_date": run_date, "mode": mode, "changes": new, "already_logged": len(changes) - len(new),
           "frozen": None}
    if new and not emit:
        warehouse.write_change_log(new)  # the record first: a failed post or write loses no plan
    if mode == "propose":
        if new and not emit:
            slack.post(summary(new, mode=mode))
        return out

    stopped = rules["emergency_stop"]
    results, waiting = [], []
    if not stopped:
        results, waiting = _apply(log + new, adapter=adapter, warehouse=warehouse, rules=rules,
                                  campaigns=campaigns, ads=ads, emit=emit)
    out.update(results=results, waiting=[c["key"] for c in waiting], emergency_stop=stopped)
    if (new or results) and not emit:
        slack.post(summary(new, results, mode=mode, stopped=stopped, waiting=len(waiting)))
    return out


def approve(*, warehouse, rules, key, by, now):
    """Log the Head of GTM's approval of one proposed change in today's plan, as a new row
    keyed `<change key>:approved` with logged_by = the approver. Either half of a budget
    move approves the move: the row is keyed from the cut and covers both halves. `key` may
    be a unique prefix of 8 or more characters. Approving the same change twice logs one row.
    `rules` is the run's rules file: its `timezone` says which day's plan is today's. While
    the change's platform is frozen (BC-28219), nothing is approved."""
    by = (by or "").strip()
    if not by:
        raise ValueError("name the approver with --by")
    if len(key) < 8:
        raise ValueError("give at least 8 characters of the change key")
    _check_rules(rules)
    run_date = _run_date(rules, now)
    plan = {r["key"]: r for r in warehouse.read_change_log(run_date) if r["status"] in PLAN}
    found = {k.removesuffix(PAIR) for k in plan if k.startswith(key)}
    if len(found) != 1:
        raise ValueError(f"{len(found)} planned changes in the {run_date} plan match key {key}; need exactly one")
    change = found.pop()
    halves = [plan[k] for k in (change, change + PAIR) if k in plan]
    if not halves or halves[0]["key"] != change:
        raise ValueError(f"change {change[:12]} has no cut in the {run_date} plan, so it cannot be approved")
    for c in halves:
        if c["status"] != "proposed":
            raise ValueError(f"change {c['key'][:12]} is {c['status']}: only a proposed change can be approved")
    platform = halves[0]["platform"]
    frozen = _freeze(warehouse, platform, run_date, rules)
    if frozen:
        raise ValueError(f"{platform} is frozen today, so nothing can be approved. Why: {frozen['detail']}")
    reason = f"approved by {by}" + (" (both halves of the move)" if len(halves) == 2 else "")
    row = dict(_result(halves[0], "approved", reason, mode="approve"), logged_by=by)
    warehouse.write_change_log([row])
    return row


def summary(changes, results=(), *, mode="propose", stopped=False, waiting=0):
    """The Slack message for one run: every new plan row and every new apply result, and
    why. A re-run with nothing new posts nothing."""
    c0 = (list(changes) + list(results))[0]
    head = f"Ads agent, {c0['platform']}, {c0['run_date']} ({mode} mode)"
    if changes and changes[0]["status"] == "no_change":
        lines = [f"{head}: No changes. Why: {changes[0]['reason']}."]
    elif changes:
        counts = {s: sum(c["status"] == s for c in changes) for s in ("proposed", "held")}
        tail = " Nothing is changed until approved." if mode == "propose" else ""
        lines = [f"{head}: {counts['proposed']} proposed, {counts['held']} held.{tail}"]
        for c in changes:
            failed = [f"{k['name']} ({k['detail']})" for k in c["checks"] if not k["passed"]]
            lines.append(
                f"• {'HELD ' if failed else ''}{c['target_name']}: {_edit(c)}. Why: {c['reason']}. "
                + (f"Failed: {'; '.join(failed)}." if failed
                   else f"Checks passed: {', '.join(k['name'] for k in c['checks'])}. Key {c['key'].removesuffix(PAIR)[:12]}.")
            )
    else:
        lines = [f"{head}:"]
    if stopped:
        lines.append("Emergency stop is on: nothing was written to the ad account.")
    for r in results:
        done = r["status"] == "applied"
        lines.append(f"• {'APPLIED' if done else 'NOT APPLIED'} {r['target_name']}: {_edit(r)}. Why: {r['reason']}.")
    if waiting:
        lines.append(f"{waiting} change(s) wait for the Head of GTM's approval.")
    return "\n".join(lines)


def _check_rules(rules):
    missing = [k for k in RULES if k not in rules]
    if missing:
        raise ValueError(f"rule settings missing: {', '.join(missing)}")
    bad = [k for k in FLAGS if not isinstance(rules[k], bool)]
    if bad:
        raise ValueError(f"rule settings must be true or false: {', '.join(bad)}")
    zone = rules["timezone"]
    # The exact name only. ZoneInfo alone would load "america/denver" from macOS's
    # case-blind disk and refuse it on Linux.
    if not isinstance(zone, str) or zone not in available_timezones():
        raise ValueError(f"rule setting timezone {zone!r} is not in this machine's IANA time zone list")


def _run_date(rules, now):
    """The calendar date of `now` in the rules' time zone, as YYYY-MM-DD."""
    if now.utcoffset() is None:
        raise ValueError("now has no time zone, so its date is unknown")
    return now.astimezone(ZoneInfo(rules["timezone"])).date().isoformat()


def _key(c):
    """Idempotency key: the same edit planned twice on one day is one row."""
    parts = [c["run_date"], c["platform"], c["account_id"], c["target_type"], c["target_id"],
             c["field"], c["old"], c["new"], c["reason"] if c["status"] == "no_change" else None]
    return hashlib.sha256(json.dumps(parts).encode()).hexdigest()


def _result(c, status, reason, mode="act"):
    """A row logged next to plan row `c`, keyed from its key. Repeating the same failure
    gives the same key, so re-runs do not pile up identical rows."""
    key = f"{c['key']}:{status}"
    if status == "apply_failed":
        key += ":" + hashlib.sha256(reason.encode()).hexdigest()[:12]
    return {**{k: c[k] for k in EDIT}, "key": key, "mode": mode, "status": status, "reason": reason}


def _edit(c):
    if c["field"] == BUDGET:
        return f"daily budget ${c['old'] / 1_000_000:,.2f} → ${c['new'] / 1_000_000:,.2f}"
    return f"{c['field']} {c['old'] or 'none'} → {c['new']}"


def _ad_target(a):
    """An ad's target id: Google's ad-group-ad id, `<ad group id>~<ad id>`."""
    return f"{a['ad_group_id']}~{a['ad_id']}"


def _campaign_of(c, campaigns, ads):
    """The settings row of the campaign a change touches, or None if it is not there."""
    if c["target_type"] == "ad":
        ad = ads.get((c["account_id"], c["target_id"]))
        return ad and campaigns.get((c["account_id"], ad["campaign_id"]))
    if c["target_type"] == "campaign":
        return campaigns.get((c["account_id"], c["target_id"]))
    return None


# --- the data freeze (BC-28219) ------------------------------------------------------------


def _freeze(warehouse, platform, run_date, rules):
    """Why the platform is frozen today, as a failed `lead_count_gap` check, or None. Reads
    yesterday's lead reconciliation row: the day before the run date, in the rules' time zone.
    gap_pct is |platform - BriteBase| / the larger count, null only when both are zero."""
    day = (date.fromisoformat(run_date) - timedelta(days=1)).isoformat()
    rows = [r for r in warehouse.read_lead_reconciliation(day) if r["platform"] == platform]
    row = rows[0] if len(rows) == 1 else {}
    leads, britebase, gap, spend = (row.get(k) for k in
                                    ("platform_leads", "britebase_leads", "gap_pct", "platform_spend"))
    limit = rules["max_lead_count_gap"]
    if len(rows) != 1:
        why = f"{len(rows)} lead count rows for {day}, not one: the lead feed may be broken"
    elif leads == 0 and britebase == 0:
        if spend == 0:
            return None  # nothing spent, no leads either side: nothing disagrees
        spent = "an unknown amount" if spend is None else f"${spend:,.2f}"
        why = f"spend with no leads: {platform} spent {spent} on {day} and neither it nor BriteBase counted a lead"
    elif gap is not None and gap <= limit:
        return None
    else:  # over the limit, or a null gap with a count above zero: not an agreed count
        size = "the gap is unknown" if gap is None else f"a {gap:.1%} gap, over the {limit:.1%} limit"
        why = f"{platform} counted {leads} leads on {day} and BriteBase {britebase}: {size}"
    return {"name": "lead_count_gap", "passed": False, "detail": why, "lead_date": day,
            "platform_leads": leads, "britebase_leads": britebase, "gap_pct": gap, "platform_spend": spend}


def _frozen_run(check, log, *, warehouse, slack, rules, run_date, mode, platform, emit):
    """A frozen run plans, approves and applies nothing. It logs one `frozen` row and posts
    one alert per platform per day; a re-run finds the row and posts nothing new."""
    row = {**dict.fromkeys(EDIT), "run_date": run_date, "platform": platform, "mode": mode,
           "status": "frozen", "reason": check["detail"], "checks": [check],
           "key": hashlib.sha256(json.dumps([run_date, platform, "frozen"]).encode()).hexdigest()}
    if row["key"] not in {r["key"] for r in log} and not emit:
        warehouse.write_change_log([row])  # the record first, as in an unfrozen run
        slack.post(f"Ads agent, {platform}, {run_date} ({mode} mode): FROZEN. Why: {row['reason']}. "
                   "The agent plans, approves and writes nothing until the lead count check passes. "
                   "The watchdog still runs.")
    out = {"run_date": run_date, "mode": mode, "changes": [], "already_logged": 0, "frozen": row}
    if mode == "act":
        out.update(results=[], waiting=[], emergency_stop=rules["emergency_stop"])
    return out


# --- act: apply today's plan -------------------------------------------------------------


def _apply(rows, *, adapter, warehouse, rules, campaigns, ads, emit):
    """Write each of today's proposed changes that the hard limits allow, cuts first, and
    log each result as soon as it is known. Returns (new result rows, changes waiting for
    approval)."""
    logged = {r["key"] for r in rows}
    plan = {r["key"]: r for r in rows if r["status"] in PLAN}
    approved = {r["key"].removesuffix(":approved") for r in rows if r["status"] == "approved"}
    applied = [r for r in rows if r["status"] == "applied"]
    done = {r["key"].removesuffix(":applied") for r in applied}  # plan keys already in effect
    results, waiting = [], []
    for c in sorted((r for r in plan.values() if r["status"] == "proposed" and r["key"] not in done),
                    key=_apply_order):
        verdict, why = _decide(c, plan=plan, approved=approved, applied=applied, done=done,
                               rules=rules, campaigns=campaigns, ads=ads)
        if verdict == "wait":
            waiting.append(c)
            continue
        if verdict == "apply" and emit:  # a preview counts its would-be writes, like a real run
            applied.append(_result(c, "would_apply", why))
            done.add(c["key"])
            results.append(applied[-1])
            continue
        if verdict == "apply":
            try:
                adapter.apply(c)
            except Exception as e:  # any write failure is logged and retried next run, never fatal
                verdict, why = "refuse", f"the write failed: {type(e).__name__}: {e}"
        row = _result(c, "apply_failed" if verdict == "refuse" else "applied", why)
        if row["status"] == "applied":
            applied.append(row)
            done.add(c["key"])
        if row["key"] not in logged:
            if not emit:
                warehouse.write_change_log([row])
            results.append(row)
    return results, waiting


def _apply_order(c):
    """Cuts first: a move's raise is only written once its cut is in effect."""
    return (c["new"] - c["old"] if c["field"] == BUDGET else 0, c["key"])


def _decide(c, *, plan, approved, applied, done, rules, campaigns, ads):
    """May act write this proposed change now? Returns (verdict, why). The verdict is apply;
    done (already in effect, so log it with no write); wait (needs approval); or refuse.
    ADR-0033's hard limits are checked again here, at write time, whatever the plan said.
    A budget move is one change: its approval and its daily-limit slot belong to the cut."""
    change = c["key"].removesuffix(PAIR)  # a move's raise belongs to its cut's change
    if (c["target_type"], c["field"]) not in WRITABLE:
        return "refuse", f"{c['target_type']} {c['field']} is not an ad setting the agent may write"
    camp = _campaign_of(c, campaigns, ads)
    if camp and camp["brand"]:
        return "refuse", "brand campaign: the agent never touches brand keywords"
    if c["field"] == BUDGET:
        if camp and camp["budget_shared"]:
            return "refuse", "shared budget: moving it would move other campaigns too"
        pct = abs(c["new"] - c["old"]) / c["old"] if c["old"] else float("inf")
        if pct > rules["max_move_pct"]:
            return "refuse", f"moves {pct:.0%} (limit {rules['max_move_pct']:.0%})"
    creates_or_deletes = c["target_type"] == "campaign" and c["field"] == STATUS and (
        c["old"] is None or c["new"] == "REMOVED")
    if (rules["weeks_1_2"] or creates_or_deletes) and change not in approved:
        return "wait", "needs the Head of GTM's approval"
    if rules["weeks_1_2"] and {k.removesuffix(PAIR) for k in done} - {change}:
        return "refuse", "one change per platform per day while weeks_1_2 is on"
    if any((a["account_id"], a["target_type"], a["target_id"], a["field"])
           == (c["account_id"], c["target_type"], c["target_id"], c["field"]) for a in applied):
        return "refuse", "this setting was already changed today"
    current = _current(c, campaigns, ads)
    if current != c["old"]:
        if current == c["new"]:
            return "done", "already at the planned value, so no write was made"
        return "refuse", f"the setting is now {current}, not the planned {c['old']}"
    if c["field"] == BUDGET and c["new"] > c["old"]:
        cut = plan.get(change) if c["key"].endswith(PAIR) else None
        if not cut or cut["field"] != BUDGET or cut["new"] >= cut["old"]:
            return "refuse", "a raise is only written as half of a planned move, after its cut"
        pair_net = c["new"] - c["old"] + cut["new"] - cut["old"]
        if pair_net > 0:
            return "refuse", f"the move would raise total daily budget by ${pair_net / 1_000_000:,.2f}"
        if cut["key"] not in done:
            return "refuse", "its paired cut has not been applied, so the raise waits for it"
    return "apply", "every hard limit passed"


def _current(c, campaigns, ads):
    """The setting's value now, as the adapter read it at the start of this run."""
    if c["target_type"] == "ad":
        ad = ads.get((c["account_id"], c["target_id"]))
        return ad and ad["status"]
    camp = campaigns.get((c["account_id"], c["target_id"]))
    if c["field"] == BUDGET:
        return camp and camp["daily_budget_micros"]
    return "ENABLED" if camp else None  # settings list enabled campaigns only


# --- plan ---------------------------------------------------------------------------------


def _plan(snapshot, ad_results, settings, campaigns, ads, rules, now):
    changes, why_none = _propose_budget_move(snapshot, settings, rules)
    kills, why_no_kill = _propose_ad_kills(ad_results, campaigns, ads, rules)
    changes += kills
    ctx = {"changes": changes, "settings": settings, "campaigns": campaigns, "ads": ads,
           "rules": rules, "now": now}
    for c in changes:
        c["checks"] = []
        for check in CHECKS:
            got = check(c, ctx)
            if got is not None:
                c["checks"].append({"name": check.__name__.lstrip("_"), "passed": got[0], "detail": got[1]})
        if not all(k["passed"] for k in c["checks"]):
            c["status"] = "held"
    if not changes:
        changes = [{"status": "no_change", "account_id": None, "target_type": None, "target_id": None,
                    "target_name": None, "field": None, "old": None, "new": None,
                    "reason": f"{why_none}; {why_no_kill}", "checks": []}]
    return changes


# Limit checks: (change, ctx) -> (passed, detail), or None when the check does not apply
# to that kind of change. ctx holds the day's planned changes, current settings, rules
# and the clock. A change that fails any check is held, not proposed. Rule values come
# from ctx["rules"], never from code.


def _max_move(c, ctx):
    if c["field"] != BUDGET:
        return None
    limit = ctx["rules"]["max_move_pct"]
    pct = abs(c["new"] - c["old"]) / c["old"]
    return pct <= limit, f"moves {pct:.0%} (limit {limit:.0%})"


def _no_total_raise(c, ctx):
    if c["field"] != BUDGET:
        return None
    net = sum(x["new"] - x["old"] for x in ctx["changes"] if x["field"] == BUDGET)
    return net <= 0, f"net daily budget change {'-' if net < 0 else '+'}${abs(net) / 1_000_000:,.2f}"


def _weekly_ceiling(c, ctx):
    if c["field"] != BUDGET:
        return None
    ceiling = ctx["rules"]["weekly_ceiling"]
    daily = sum(s["daily_budget_micros"] for s in ctx["settings"]) + sum(
        x["new"] - x["old"] for x in ctx["changes"] if x["field"] == BUDGET)
    weekly = daily * 7 / 1_000_000
    return weekly <= ceiling, f"${weekly:,.2f} a week at planned budgets (ceiling ${ceiling:,.2f})"


def _brand_untouched(c, ctx):
    camp = _campaign_of(c, ctx["campaigns"], ctx["ads"])
    brand = bool(camp and camp["brand"])
    return not brand, "brand campaign" if brand else "not a brand campaign"


CHECKS = [_max_move, _no_total_raise, _weekly_ceiling, _brand_untouched]


def _propose_budget_move(snapshot, settings, rules):
    """Move budget from the campaign with the worst cost per conversion to the best one
    that is limited by budget. Total daily budget stays the same. Shared budgets and brand
    campaigns are never moved. Returns (changes, reason there are none)."""
    results = {(r["account_id"], r["campaign_id"]): r for r in snapshot}
    judged = []
    for s in settings:
        r = results.get((s["account_id"], s["campaign_id"]))
        if r and not s["budget_shared"] and not s["brand"] and r["conversions"] >= rules["min_conversions"]:
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
        "field": BUDGET,
        "old": old,
        "new": old + delta,
        "reason": reason,
    }


def _propose_ad_kills(ad_results, campaigns, ads, rules):
    """Turn off ads that spend without results. An ad with zero leads turns off once it has
    spent kill_multiple x target_cpl, never before. Ads in one ad group are compared on cost
    per lead only once each has spent compare_multiple x target_cpl; the worst of those turns
    off. Ads in brand campaigns are never touched. Returns (changes, reason there are none)."""
    target = rules["target_cpl"]
    kill_at, compare_at = rules["kill_multiple"] * target, rules["compare_multiple"] * target
    changes, groups = [], {}
    for r in ad_results:
        ad = ads.get((r["account_id"], _ad_target(r)))
        camp = ad and campaigns.get((r["account_id"], ad["campaign_id"]))
        if not (ad and ad["status"] == "ENABLED" and camp and not camp["brand"]):
            continue
        if r["conversions"] == 0:
            if r["spend"] >= kill_at:
                changes.append(_ad_off(ad, f"zero leads after ${r['spend']:,.2f} spend, at least "
                                           f"{rules['kill_multiple']}x the ${target:,.2f} target cost per lead"))
        elif r["spend"] >= compare_at:
            groups.setdefault((r["account_id"], ad["ad_group_id"]), []).append((r["spend"] / r["conversions"], ad))
    for group in groups.values():
        group.sort(key=lambda g: g[0])
        (best_cpl, best), (worst_cpl, worst) = group[0], group[-1]
        if len(group) >= 2 and worst_cpl > best_cpl:
            changes.append(_ad_off(worst, f"cost per lead ${worst_cpl:,.2f} against ${best_cpl:,.2f} for "
                                          f"{best['ad_name']} in the same ad group; both spent at least "
                                          f"{rules['compare_multiple']}x the target cost per lead"))
    return changes, None if changes else "no ad met the kill rule"


def _ad_off(ad, reason):
    return {
        "status": "proposed",
        "account_id": ad["account_id"],
        "target_type": "ad",
        "target_id": _ad_target(ad),
        "target_name": ad["ad_name"],
        "field": STATUS,
        "old": ad["status"],
        "new": "PAUSED",
        "reason": reason,
    }
