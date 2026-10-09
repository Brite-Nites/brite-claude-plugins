"""One bounded ads-agent run: results snapshot in, change plan out (BC-28215), and in act
mode the plan applied inside the hard limits of ADR-0033 in brite-gtm (BC-28216). The
same run serves Google Ads and Meta (BC-28218): the platform is the adapter's.

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

Meta (BC-28218). Every rule above applies unchanged. A Meta budget sits on the ad set, so
a Meta move cuts one ad set and raises another; an ad's ad_group_id is its ad set. Meta's
own rules, each in its own function below:
- Housing: the agent never writes targeting, and holds a flag row for any ad set whose
  targeting breaks Meta's Housing rules (`_housing_breaks`).
- Two paths: each ad set is a market-site ad set or an instant-form ad set (`_path`).
- The 50/50 path test: two weeks after `meta_path_test_start`, the day's budget move goes
  toward the path with the lower cost per booked appointment (`_propose_path_move`).
- The switch to optimising for booked appointments always waits for approval.
- An ad turns on only from the approved shared library (`_approved_creative`).
- An ad with near-zero spend after `retire_after_days` is retired (`_propose_ad_retires`).
- "Limited by budget" is derived from yesterday's spend (`_derive_budget_limited`).

Where a later ticket plugs in:
- season rules and the step-up gate (BC-28220): append to CHECKS; add keys to the check
  context (e.g. the install-date feed) in `_plan`.
"""

from __future__ import annotations

import hashlib
import json
from datetime import date, datetime, timedelta
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
# The rule settings a Meta run needs as well (BC-28218).
META_RULES = {
    "meta_path_test_start": "YYYY-MM-DD the 50/50 site vs instant-form test began, or null for no test",
    "retire_after_days": "an ad this many days old with near-zero spend is retired (7)",
    "retire_spend_floor": "near-zero spend in dollars: an ad that spent this much or less in the snapshot",
    "meta_budget_limited_spend_pct": "limited by budget once yesterday's spend reached this fraction of its daily budget (0.95)",
}
FLAGS = ("weeks_1_2", "emergency_stop")  # must be JSON true or false, so a typo fails loudly

MODES = ("propose", "act")
PLAN = ("proposed", "held", "no_change")
BUDGET, STATUS = "daily_budget_micros", "status"
GOAL, TARGETING = "optimization_goal", "targeting"
PAIR = ":pair"  # a move's raise is keyed <cut key>:pair; only the planner writes one

# Per platform: the level that holds a daily budget, and what act mode may write, as
# (target type, field). Anything else is refused, targeting and rule settings included
# (ADR-0033 §2: the agent never changes its own rules).
PLATFORMS = {
    "google_ads": {"level": "campaign", "writable": {("campaign", BUDGET), ("campaign", STATUS), ("ad", STATUS)}},
    "meta_ads": {"level": "ad_set", "writable": {("ad_set", BUDGET), ("ad_set", GOAL), ("ad", STATUS)}},
}
# The keys that name a budget holder: its settings row's id and name, and the field of an
# ad (or ad result) that points to it.
LEVELS = {
    "campaign": {"id": "campaign_id", "name": "campaign_name", "of_ad": "campaign_id", "noun": "campaign"},
    "ad_set": {"id": "ad_set_id", "name": "ad_set_name", "of_ad": "ad_group_id", "noun": "ad set"},
}

PATHS = ("site", "instant_form")  # Meta's two paths, in the order a within-path move tries them
PATH_TEST_DAYS = 14  # the 50/50 path test runs two weeks (BC-28218 4c)
HOUSING_MIN_MILES = 15
KM_PER_MILE = 1.609344

# The edit columns a result row copies from its plan row, so it reads on its own.
EDIT = ("run_date", "platform", "account_id", "target_type", "target_id", "target_name",
        "field", "old", "new", "checks")


def run(*, warehouse, adapter, slack, rules, now, mode="propose", emit=False):
    """Plan, log and post one day's changes. In act mode, then apply what the hard limits
    allow and log each result. `emit` returns the plan and writes nothing anywhere
    (ADR-028's side-effect-free mode)."""
    if mode not in MODES:
        raise ValueError(f"mode must be propose or act, not {mode!r}")
    platform = adapter.platform
    if platform not in PLATFORMS:
        raise ValueError(f"platform must be one of {', '.join(PLATFORMS)}, not {platform!r}")
    _check_rules(rules, platform)
    run_date = _run_date(rules, now)
    log = [r for r in warehouse.read_change_log(run_date) if r["platform"] == platform]
    frozen = _freeze(warehouse, platform, run_date, rules)
    if frozen:
        return _frozen_run(frozen, log, warehouse=warehouse, slack=slack, rules=rules,
                           run_date=run_date, mode=mode, platform=platform, emit=emit)
    snapshot = [r for r in warehouse.read_snapshot() if r["platform"] == platform]
    ad_results = [r for r in warehouse.read_ad_snapshot() if r["platform"] == platform]
    accounts = sorted({r["account_id"] for r in snapshot + ad_results + log if r["account_id"]})
    settings = adapter.read_settings(accounts)
    level = PLATFORMS[platform]["level"]
    meta = platform == "meta_ads"
    acct = {  # the account state every planner, check and write decision reads
        "platform": platform, "level": level, "rules": rules, "run_date": run_date, "settings": settings,
        "units": {(s["account_id"], s[LEVELS[level]["id"]]): s for s in settings},
        "ads": {(a["account_id"], _ad_target(a)): a for a in adapter.read_ads(accounts)},
        # An ad turns on only from the approved shared library (BC-28218 4e).
        "creative": _creative(warehouse, platform) if meta else None,
    }

    if mode == "act" and any(r["status"] in PLAN for r in log):
        changes, notes = [], []  # act plans once a day: a re-run only finishes today's plan
    else:
        notes = _derive_budget_limited(adapter, accounts, acct) if meta else []
        changes, why_none = _plan(snapshot, ad_results, acct, now)
        notes += why_none
        for c in changes:
            c.update(run_date=run_date, mode=mode, platform=platform)
            c["key"] = _key(c)
        move = [c for c in changes if c["field"] == BUDGET]
        if len(move) == 2:  # the day's one budget move, [cut, raise]: link the raise to its cut
            move[1]["key"] = f"{move[0]['key']}{PAIR}"
    logged = {r["key"] for r in log}
    new = [c for c in changes if c["key"] not in logged]
    out = {"run_date": run_date, "mode": mode, "changes": new, "already_logged": len(changes) - len(new),
           "frozen": None, "notes": notes}
    if meta:
        out["paths"] = _paths(settings)
    if new and not emit:
        warehouse.write_change_log(new)  # the record first: a failed post or write loses no plan
    if mode == "propose":
        if new and not emit:
            slack.post(summary(new, mode=mode))
        return out

    stopped = rules["emergency_stop"]
    results, waiting = [], []
    if not stopped:
        results, waiting = _apply(log + new, adapter=adapter, warehouse=warehouse, acct=acct, emit=emit)
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


def _check_rules(rules, platform=None):
    """Every rule the run needs is set, and well-formed. `platform` adds that platform's own
    rules; approve passes none, since its plan rows were checked when they were planned."""
    need = list(RULES) + (list(META_RULES) if platform == "meta_ads" else [])
    missing = [k for k in need if k not in rules]
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
    if platform == "meta_ads" and rules["meta_path_test_start"] is not None:
        start = rules["meta_path_test_start"]
        try:
            date.fromisoformat(start)
        except (TypeError, ValueError):
            raise ValueError(f"rule setting meta_path_test_start {start!r} is not a YYYY-MM-DD date or null") from None


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
    if c["field"] == TARGETING:
        return "targeting is not Housing-safe; fix it by hand in Ads Manager"
    return f"{c['field']} {c['old'] or 'none'} → {c['new']}"


def _ad_target(a):
    """An ad's target id, `<ad group id>~<ad id>`: Google's ad-group-ad id. On Meta the ad
    group is the ad set."""
    return f"{a['ad_group_id']}~{a['ad_id']}"


def _unit_of_ad(ad, acct):
    """The settings row of the budget holder an ad sits in: its campaign on Google, its ad
    set on Meta."""
    return acct["units"].get((ad["account_id"], ad[LEVELS[acct["level"]]["of_ad"]]))


def _unit_of(c, acct):
    """The settings row of the budget holder a change touches, or None if it is not there."""
    if c["target_type"] == "ad":
        ad = acct["ads"].get((c["account_id"], c["target_id"]))
        return ad and _unit_of_ad(ad, acct)
    if c["target_type"] == acct["level"]:
        return acct["units"].get((c["account_id"], c["target_id"]))
    return None


def _reduces_spend(c):
    """A budget cut or an ad turned off: either only lowers spend."""
    if c["field"] == BUDGET:
        return c["old"] is not None and c["new"] is not None and c["new"] < c["old"]
    return c["target_type"] == "ad" and c["field"] == STATUS and c["new"] == "PAUSED"


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
    out = {"run_date": run_date, "mode": mode, "changes": [], "already_logged": 0, "frozen": row, "notes": []}
    if mode == "act":
        out.update(results=[], waiting=[], emergency_stop=rules["emergency_stop"])
    return out


# --- act: apply today's plan -------------------------------------------------------------


def _apply(rows, *, adapter, warehouse, acct, emit):
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
        verdict, why = _decide(c, plan=plan, approved=approved, applied=applied, done=done, acct=acct)
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


def _decide(c, *, plan, approved, applied, done, acct):
    """May act write this proposed change now? Returns (verdict, why). The verdict is apply;
    done (already in effect, so log it with no write); wait (needs approval); or refuse.
    ADR-0033's hard limits are checked again here, at write time, whatever the plan said.
    A budget move is one change: its approval and its daily-limit slot belong to the cut."""
    rules = acct["rules"]
    change = c["key"].removesuffix(PAIR)  # a move's raise belongs to its cut's change
    if (c["target_type"], c["field"]) not in PLATFORMS[acct["platform"]]["writable"]:
        return "refuse", f"{c['target_type']} {c['field']} is not an ad setting the agent may write"
    unit = _unit_of(c, acct)
    if unit and unit["brand"]:
        return "refuse", "brand campaign: the agent never touches brand keywords"
    if c["field"] == BUDGET:
        if unit and unit["budget_shared"]:
            return "refuse", "shared budget: moving it would move other campaigns too"
        pct = abs(c["new"] - c["old"]) / c["old"] if c["old"] else float("inf")
        if pct > rules["max_move_pct"]:
            return "refuse", f"moves {pct:.0%} (limit {rules['max_move_pct']:.0%})"
    for check in (_housing_safe, _approved_creative):  # Meta's own limits, again at write time
        got = check(c, acct)
        if got and not got[0]:
            return "refuse", got[1]
    creates_or_deletes = c["target_type"] == "campaign" and c["field"] == STATUS and (
        c["old"] is None or c["new"] == "REMOVED")
    # Switching what Meta optimises for is never automatic (BC-28218 4d).
    if (rules["weeks_1_2"] or creates_or_deletes or c["field"] == GOAL) and change not in approved:
        return "wait", "needs the Head of GTM's approval"
    if rules["weeks_1_2"] and {k.removesuffix(PAIR) for k in done} - {change}:
        return "refuse", "one change per platform per day while weeks_1_2 is on"
    if any((a["account_id"], a["target_type"], a["target_id"], a["field"])
           == (c["account_id"], c["target_type"], c["target_id"], c["field"]) for a in applied):
        return "refuse", "this setting was already changed today"
    current = _current(c, acct)
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


def _current(c, acct):
    """The setting's value now, as the adapter read it at the start of this run."""
    if c["target_type"] == "ad":
        ad = acct["ads"].get((c["account_id"], c["target_id"]))
        return ad and ad["status"]
    unit = _unit_of(c, acct)
    if c["field"] in (BUDGET, GOAL):
        return unit and unit[c["field"]]
    return "ENABLED" if unit else None  # settings list enabled budget holders only


# --- plan ---------------------------------------------------------------------------------


def _plan(snapshot, ad_results, acct, now):
    """The day's changes, each run through CHECKS, and why each rule that planned nothing
    planned nothing. Returns (changes, reasons)."""
    if acct["platform"] == "meta_ads":
        results = _ad_set_results(ad_results)
        changes, why_none = _propose_meta_budget_move(results, acct)
    else:
        results = {(r["account_id"], r["campaign_id"]): r for r in snapshot}
        changes, why_none = _propose_budget_move(results, acct)
    kills, why_no_kill = _propose_ad_kills(ad_results, acct)
    changes += kills
    whys = [why_none, why_no_kill]
    if acct["platform"] == "meta_ads":
        retires, why_no_retire = _propose_ad_retires(ad_results, acct, {(c["account_id"], c["target_id"]) for c in kills})
        goals, why_no_goal = _propose_goal_switches(results, acct)
        changes += retires + goals + _flag_housing_breaks(acct)
        whys += [why_no_retire, why_no_goal]
    whys = [w for w in whys if w]
    ctx = {**acct, "changes": changes, "now": now}
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
                    "reason": "; ".join(whys), "checks": []}]
    return changes, whys


# Limit checks: (change, ctx) -> (passed, detail), or None when the check does not apply
# to that kind of change. ctx holds the account state (`acct` in run), the day's planned
# changes and the clock. A change that fails any check is held, not proposed. Rule values
# come from ctx["rules"], never from code. Act also calls _housing_safe and
# _approved_creative again at write time, with the account state alone.


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
    budgets = [s["daily_budget_micros"] for s in ctx["settings"]]
    if None in budgets:  # a Meta lifetime budget has no daily amount: the total is unknown
        return False, "a budget has no daily amount, so the weekly total is unknown"
    daily = sum(budgets) + sum(x["new"] - x["old"] for x in ctx["changes"] if x["field"] == BUDGET)
    weekly = daily * 7 / 1_000_000
    return weekly <= ceiling, f"${weekly:,.2f} a week at planned budgets (ceiling ${ceiling:,.2f})"


def _brand_untouched(c, ctx):
    camp = _unit_of(c, ctx)
    brand = bool(camp and camp["brand"])
    return not brand, "brand campaign" if brand else "not a brand campaign"


def _housing_safe(c, ctx):
    """Meta only (BC-28218 4a). A change that does not only lower spend is held on an ad set
    whose targeting breaks Meta's Housing rules. A targeting flag row always fails here."""
    if ctx["platform"] != "meta_ads" or _reduces_spend(c):
        return None
    unit = _unit_of(c, ctx)
    if unit is None:
        return None
    breaks = _housing_breaks(unit.get("targeting"))
    if breaks:
        return False, f"targeting breaks Meta's Housing rules: {'; '.join(breaks)}"
    return True, "targeting is Housing-safe"


def _approved_creative(c, ctx):
    """Meta only (BC-28218 4e). An ad turns on only if its creative-inputs row exists and,
    when its photo was AI-edited, the row names the person who approved it."""
    if ctx["platform"] != "meta_ads" or (c["target_type"], c["field"], c["new"]) != ("ad", STATUS, "ENABLED"):
        return None
    row = ctx["creative"].get((c["account_id"], c["target_id"].split("~")[-1]))
    if row is None:
        return False, "no creative-inputs row: the ad is not from the approved shared library"
    if row["ai_edited"] and not row["approved_by"]:
        return False, "its AI-edited photo has no approved_by in the creative-inputs row"
    return True, "in the approved shared library"


CHECKS = [_max_move, _no_total_raise, _weekly_ceiling, _brand_untouched, _housing_safe, _approved_creative]


def _propose_budget_move(results, acct, among=None):
    """Move budget from the budget holder (a Google campaign, a Meta ad set) with the worst
    cost per conversion to the best one that is limited by budget. Total daily budget stays
    the same. Shared budgets and brand campaigns are never moved. `among(settings row)`
    limits the move to the rows it is true for. Returns (changes, reason there are none)."""
    rules, names = acct["rules"], LEVELS[acct["level"]]
    noun = names["noun"]
    judged = []
    for s in acct["settings"]:
        r = results.get((s["account_id"], s[names["id"]]))
        if (r and not s["budget_shared"] and not s["brand"] and r["conversions"] >= rules["min_conversions"]
                and (among is None or among(s))):
            judged.append((r["spend"] / r["conversions"], s))
    if len(judged) < 2:
        return [], f"fewer than two {noun}s have {rules['min_conversions']} conversions to judge"
    judged.sort(key=lambda x: x[0])
    recipients = [(cpc, s) for cpc, s in judged if s["budget_limited"]]
    if not recipients:
        return [], f"no judged {noun} is limited by budget, so extra budget would buy nothing"
    (to_cpc, to), (from_cpc, frm) = recipients[0], judged[-1]
    if from_cpc <= to_cpc:
        return [], f"the best budget-limited {noun} already has the worst cost per conversion"
    return _move(frm, to, f"cost per conversion ${from_cpc:,.2f}, the worst of the judged {noun}s",
                 f"cost per conversion ${to_cpc:,.2f} and limited by budget", acct)


def _move(frm, to, frm_reason, to_reason, acct):
    """One linked budget move, [cut, raise]: max_move_pct of the smaller budget, in whole
    cents. Returns (changes, reason there are none)."""
    step = min(frm["daily_budget_micros"], to["daily_budget_micros"]) * acct["rules"]["max_move_pct"]
    amount = int(step) // 10_000 * 10_000  # whole cents
    if amount <= 0:
        return [], "the move would be under one cent"
    return [_change(frm, -amount, frm_reason, acct["level"]), _change(to, amount, to_reason, acct["level"])], None


def _change(setting, delta, reason, level):
    old, names = setting["daily_budget_micros"], LEVELS[level]
    return {
        "status": "proposed",
        "account_id": setting["account_id"],
        "target_type": level,
        "target_id": setting[names["id"]],
        "target_name": setting[names["name"]],
        "field": BUDGET,
        "old": old,
        "new": old + delta,
        "reason": reason,
    }


def _propose_ad_kills(ad_results, acct):
    """Turn off ads that spend without results. An ad with zero leads turns off once it has
    spent kill_multiple x target_cpl, never before. Ads in one ad group (a Meta ad set) are
    compared on cost per lead only once each has spent compare_multiple x target_cpl; the
    worst of those turns off. Ads in brand campaigns are never touched. Returns (changes,
    reason there are none)."""
    rules = acct["rules"]
    target = rules["target_cpl"]
    kill_at, compare_at = rules["kill_multiple"] * target, rules["compare_multiple"] * target
    changes, groups = [], {}
    for r in ad_results:
        ad = acct["ads"].get((r["account_id"], _ad_target(r)))
        unit = ad and _unit_of_ad(ad, acct)
        if not (ad and ad["status"] == "ENABLED" and unit and not unit["brand"]):
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


# --- Meta's own rules (BC-28218) ------------------------------------------------------------


def _derive_budget_limited(adapter, accounts, acct):
    """Meta has no "limited by budget" status, so the run derives it before planning. A
    budget holder is limited only when yesterday's spend (the day before the run date, as in
    the data freeze) reached meta_budget_limited_spend_pct of its daily budget. The holder
    is the ad set, or its campaign when the budget sits on the campaign (`budget_level`).
    Missing spend or budget means not limited, and so does a failed spend read, which the
    run's notes then name: the error is always toward fewer raises. Spend is read from the
    adapter, like Google's own budget-limited status. Returns the notes."""
    day = (date.fromisoformat(acct["run_date"]) - timedelta(days=1)).isoformat()
    try:
        spend = {(r["account_id"], r["level"], r["id"]): r["spend"] for r in adapter.read_spend(accounts, day)}
        notes = []
    except Exception as e:  # spend only ever enables a raise: without it, no ad set is limited
        spend = {}
        notes = [f"yesterday's spend could not be read ({type(e).__name__}: {e}), "
                 "so no ad set counts as limited by budget"]
    pct = acct["rules"]["meta_budget_limited_spend_pct"]
    for s in acct["settings"]:
        holder, budget = s.get("budget_level"), s["daily_budget_micros"]
        spent = spend.get((s["account_id"], holder, s["ad_set_id"] if holder == "ad_set" else s["campaign_id"]))
        s["budget_limited"] = bool(holder and budget and spent is not None and spent * 1_000_000 >= pct * budget)
    return notes


def _creative(warehouse, platform):
    """The creative-inputs rows by (ad account, ad id): the approved shared library."""
    return {(r["ad_account_id"], r["ad_id"]): r for r in warehouse.read_creative_inputs(platform)}


def _ad_set_results(ad_results):
    """Meta results per ad set, summed from the ad snapshot (ad_group_id is the ad set).
    booked_appointments is None when any of the ad set's rows lacks it: the snapshot has no
    such column yet, or no value."""
    out = {}
    for r in ad_results:
        t = out.setdefault((r["account_id"], r["ad_group_id"]),
                           {"spend": 0.0, "conversions": 0.0, "booked_appointments": 0.0})
        t["spend"] += r["spend"]
        t["conversions"] += r["conversions"]
        booked = r.get("booked_appointments")
        t["booked_appointments"] = None if booked is None or t["booked_appointments"] is None \
            else t["booked_appointments"] + booked
    return out


def _path(s):
    """A Meta ad set's path, from its settings (BC-28218 4b): an instant-form ad set keeps
    the lead on the ad with a lead form (destination ON_AD); a site ad set sends people to
    the market site (destination WEBSITE). Anything else has no path."""
    return {"ON_AD": "instant_form", "WEBSITE": "site"}.get(s.get("destination_type"))


def _paths(settings):
    """Ad set ids by path, for the run's output."""
    out = {p: [] for p in (*PATHS, "untagged")}
    for s in settings:
        out[_path(s) or "untagged"].append(s["ad_set_id"])
    return out


def _propose_meta_budget_move(results, acct):
    """The day's Meta budget move. With no path test configured, the usual move. While the
    50/50 path test runs, the usual move stays inside one path, so the split holds. From
    two weeks after meta_path_test_start, the path test's move instead, every day until a
    person sets meta_path_test_start to null."""
    start = acct["rules"]["meta_path_test_start"]
    if start is None:
        return _propose_budget_move(results, acct)
    due = date.fromisoformat(start) + timedelta(days=PATH_TEST_DAYS)
    if date.fromisoformat(acct["run_date"]) >= due:
        return _propose_path_move(results, acct)
    whys = []
    for p in PATHS:
        changes, why = _propose_budget_move(results, acct, among=lambda s, p=p: _path(s) == p)
        if changes:
            return changes, None
        whys.append(f"{p}: {why}")
    return [], f"the path test runs until {due}, so a budget move stays inside one path ({'; '.join(whys)})"


def _per_booked(spend, booked):
    return spend / booked if booked else float("inf")


def _propose_path_move(results, acct):
    """The 50/50 path test's verdict (BC-28218 4c): one linked move from the path with the
    higher cost per booked appointment to the lower. The cut comes from the losing path's ad
    set with the highest cost per booked appointment; the raise goes to the winning path's
    ad set with the lowest. Booked appointments come from the snapshot's booked_appointments
    column; with no such column the test proposes nothing. Returns (changes, reason there
    are none)."""
    rules = acct["rules"]
    per = {p: {"spend": 0.0, "booked": 0.0, "sets": []} for p in PATHS}
    for s in acct["settings"]:
        p, r = _path(s), results.get((s["account_id"], s["ad_set_id"]))
        if p is None or r is None:
            continue
        if r["booked_appointments"] is None:
            return [], ("the ad results snapshot has no booked_appointments column, so the path test "
                        "cannot compare cost per booked appointment")
        per[p]["spend"] += r["spend"]
        per[p]["booked"] += r["booked_appointments"]
        if not s["budget_shared"] and not s["brand"]:
            per[p]["sets"].append((_per_booked(r["spend"], r["booked_appointments"]), s))
    missing = [p for p in PATHS if not per[p]["spend"]]
    if missing:
        return [], f"the path test needs spend on both paths; none on {', '.join(missing)}"
    cost = {p: _per_booked(per[p]["spend"], per[p]["booked"]) for p in PATHS}
    win, lose = sorted(PATHS, key=cost.get)
    if per[win]["booked"] < rules["min_conversions"]:
        return [], (f"the {win} path has {per[win]['booked']:g} booked appointments, "
                    f"fewer than the {rules['min_conversions']} needed to judge the path test")
    if cost[win] == cost[lose]:
        return [], f"both paths cost ${cost[win]:,.2f} per booked appointment"
    if not per[win]["sets"] or not per[lose]["sets"]:
        return [], "a path has no ad set whose own budget can move"
    lose_cost = "no booked appointments" if cost[lose] == float("inf") else f"${cost[lose]:,.2f}"
    why = f"path test: {win} ${cost[win]:,.2f} per booked appointment against {lose_cost} for {lose}"
    frm = max(per[lose]["sets"], key=lambda x: x[0])[1]
    to = min(per[win]["sets"], key=lambda x: x[0])[1]
    return _move(frm, to, f"{why}; the {lose} ad set with the highest cost per booked appointment",
                 f"{why}; the {win} ad set with the lowest cost per booked appointment", acct)


def _propose_goal_switches(results, acct):
    """Switch a leads-optimised ad set to optimise for booked appointments once it has
    min_conversions booked appointments in the snapshot (BC-28218 4d). Act never applies it
    without the Head of GTM's approval, even after weeks 1-2. Returns (changes, reason there
    are none)."""
    rules, changes, known = acct["rules"], [], False
    for s in acct["settings"]:
        r = results.get((s["account_id"], s["ad_set_id"]))
        booked = r and r["booked_appointments"]
        known = known or booked is not None
        if s[GOAL] == "leads" and not s["brand"] and booked is not None and booked >= rules["min_conversions"]:
            changes.append({
                "status": "proposed", "account_id": s["account_id"], "target_type": "ad_set",
                "target_id": s["ad_set_id"], "target_name": s["ad_set_name"], "field": GOAL,
                "old": "leads", "new": "booked_appointments",
                "reason": f"{booked:g} booked appointments in the snapshot, at least {rules['min_conversions']}",
            })
    if changes:
        return changes, None
    if not known:
        return [], "no ad set can switch to booked appointments: the snapshot has no booked_appointments column"
    return [], f"no leads-optimised ad set has {rules['min_conversions']} booked appointments"


def _propose_ad_retires(ad_results, acct, taken):
    """Retire (turn off) an ad that has been live retire_after_days or more and spent
    retire_spend_floor or less in the snapshot window: Meta has stopped showing it (BC-28218
    4f). An ad with no snapshot row spent nothing. Ads already turned off by the kill rule
    (`taken`) are skipped. Returns (changes, reason there are none)."""
    rules = acct["rules"]
    floor, after = rules["retire_spend_floor"], rules["retire_after_days"]
    spent = {(r["account_id"], _ad_target(r)): r["spend"] for r in ad_results}
    today, zone = date.fromisoformat(acct["run_date"]), ZoneInfo(rules["timezone"])
    changes = []
    for key, ad in sorted(acct["ads"].items()):
        unit = _unit_of_ad(ad, acct)
        if key in taken or ad["status"] != "ENABLED" or not unit or unit["brand"] or not ad.get("created_time"):
            continue
        age = (today - datetime.fromisoformat(ad["created_time"]).astimezone(zone).date()).days
        spend = spent.get(key, 0.0)
        if age >= after and spend <= floor:
            changes.append(_ad_off(ad, f"retired: ${spend:,.2f} spent in the snapshot after {age} days live, "
                                       f"at or under the ${floor:,.2f} floor"))
    return changes, None if changes else "no ad met the retire rule"


def _housing_breaks(t):
    """What in a Meta targeting spec breaks the Housing rules: every radius at least 15
    miles, no ZIP codes, no age or gender limits, no lookalike audiences. [] if nothing."""
    t, breaks = t or {}, []
    for side in ("geo_locations", "excluded_geo_locations"):
        if (t.get(side) or {}).get("zips"):
            breaks.append(f"ZIP codes in {side}")
    for kind in ("cities", "custom_locations", "places"):
        for loc in (t.get("geo_locations") or {}).get(kind) or []:
            radius, unit = loc.get("radius"), loc.get("distance_unit", "mile")
            miles = None if radius is None else radius / KM_PER_MILE if unit == "kilometer" else radius
            if miles is None or miles < HOUSING_MIN_MILES:
                size = "no radius" if miles is None else f"a {miles:.1f} mile radius"
                breaks.append(f"{loc.get('name') or loc.get('key') or kind} has {size}, under {HOUSING_MIN_MILES} miles")
    if (t.get("age_min") or 18) > 18 or (t.get("age_max") or 65) < 65:
        breaks.append(f"an age limit ({t.get('age_min') or 18}-{t.get('age_max') or 65})")
    if t.get("genders") and set(t["genders"]) != {1, 2}:
        breaks.append("a gender limit")
    for side in ("custom_audiences", "excluded_custom_audiences"):
        for a in t.get(side) or []:
            if a.get("subtype") in ("LOOKALIKE", None):  # an audience of unknown type may be one
                kind = "lookalike audience" if a.get("subtype") else "audience of unknown type"
                breaks.append(f"{kind} {a.get('name') or a.get('id')}")
    return breaks


def _flag_housing_breaks(acct):
    """One targeting row per ad set whose targeting breaks the Housing rules. _housing_safe
    always fails it, so the plan shows it as held, with the reason; act never writes
    targeting. A person fixes it by hand (BC-28218 4a)."""
    return [
        {"status": "proposed", "account_id": s["account_id"], "target_type": "ad_set",
         "target_id": s["ad_set_id"], "target_name": s["ad_set_name"], "field": TARGETING,
         "old": "; ".join(breaks), "new": None,
         "reason": "its current targeting breaks Meta's Housing rules"}
        for s in acct["settings"] if (breaks := _housing_breaks(s.get("targeting")))
    ]
