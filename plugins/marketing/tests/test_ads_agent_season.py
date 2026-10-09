"""The ads agent's season rules and step-up gate (BC-28220 with its 2026-10-06 amendment;
spec BC-28205, workstream 4).

The same seam as test_ads_agent_run.py: fixture snapshots, settings, capacity sheet rows,
booked appointments and rules in; the plan and the fakes' recorded calls out. Each rule
test names the brief item it covers in its docstring: 4a step-up gate, 4b capacity pause,
4c stale capacity row, 4d taper, 4e territory freeze, 4f 'multi' and capacity (BC-28579),
4g every territory 'multi' covers is full (BC-28580).
The real capacity sheet reader is checked against a fake Sheets API at the end; nothing
here calls Google or Snowflake.

Every id, name, number and date here is synthetic. This repo is public: no real account
ids, budgets, ceilings, results, sheet ids, location keys or step-up cost, ever.
"""

from __future__ import annotations

import copy
import json
import sys
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent.fakes import FakeCapacity, FakeGoogleAds, FakeMetaAds, FakeSlack, FakeWarehouse  # noqa: E402
from ads_agent.run import GATE_RULES, MULTI_RULES, SEASON_RULES, approve, run  # noqa: E402

ACCOUNT, META_ACCOUNT = "0000000001", "0000000002"
BUDGET = "daily_budget_micros"
M = 1_000_000  # micros per dollar


def _at(day, hours=0):
    """15:00 UTC on `day`, 08:00 or 09:00 in Denver: the same date there. Plus `hours`."""
    return datetime.fromisoformat(f"{day}T15:00:00+00:00") + timedelta(hours=hours)


TODAY = "2026-10-06"  # a Tuesday: the last two full weeks began Sep 21 and Sep 28
NOW = _at(TODAY)
LAST_TWO = ("2026-09-21", "2026-09-28")
TERRITORIES = ("territory-a", "territory-b", "territory-c")

SEASON = {"season_start": "2026-09-28", "step_up_cost_per_booked": 300, "step_up_weeks": 2,
          "capacity_pause_date": "2026-12-10", "taper_start": "2026-12-01", "taper_daily_pct": 0.10,
          "territory_freeze_date": "2026-11-09", "capacity_max_age_hours": 48}
# After weeks 1-2, so act applies what passes. The ceiling is high enough to stay out of the way.
RULES = {"weekly_ceiling": 5000, "max_move_pct": 0.25, "min_conversions": 3,
         "weeks_1_2": False, "emergency_stop": False,
         "target_cpl": 50, "kill_multiple": 3, "compare_multiple": 5,
         "timezone": "America/Denver", "max_lead_count_gap": 0.20, **SEASON}
META_RULES = dict(RULES, meta_path_test_start=None, retire_after_days=7, retire_spend_floor=5,
                  meta_budget_limited_spend_pct=0.95)

# (campaign id, territory, daily budget in dollars, snapshot spend, conversions, limited by budget)
CAMPAIGNS = [("1001", "territory-a", 100, 500.0, 10, True),   # $50 per conversion: the raise
             ("1002", "territory-b", 80, 800.0, 4, False),    # $200: the cut
             ("1003", "territory-c", 60, 300.0, 3, False)]    # $100
# The usual move is $20 from 1002 (territory-b) to 1001 (territory-a).
WITHIN = [(c, "territory-a" if c == "1002" else t, *rest) for c, t, *rest in CAMPAIGNS]  # 1002 moved to territory-a
QUIET = [(*rest, False) for *rest, _ in CAMPAIGNS]  # nothing limited by budget: no move
REFILL = [(c, t, 80 if c == "1001" else b, *rest) for c, t, b, *rest in CAMPAIGNS]  # 1001 at $80


def _snapshot(campaigns):
    return [{"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": c, "territory": t,
             "spend": spend, "conversions": n} for c, t, _, spend, n, _ in campaigns]


def _settings(campaigns):
    return [{"account_id": ACCOUNT, "campaign_id": c, "campaign_name": f"Fake campaign {c}",
             "daily_budget_micros": dollars * M, "budget_limited": limited, "budget_shared": False, "brand": False}
            for c, _, dollars, _, _, limited in campaigns]


COUNTS = ("booked_paid_new", "booked_paid_any_client", "booked_all_new", "booked_all_any_client")


def _booked(territory, week, per_booked, platform="google_ads", **counts):
    """One week of the territory weekly mart: 3 booked appointments in each of its four
    counts, at `per_booked` dollars each. `counts` replaces any of the four."""
    return {"platform": platform, "territory": territory, "week_start": week, "spend": per_booked * 3,
            **dict.fromkeys(COUNTS, 3), **counts}


MONDAYS = [(date(2026, 9, 7) + timedelta(weeks=k)).isoformat() for k in range(17)]  # Sep 7 to Dec 28
MET = [_booked(t, w, 280.0, p) for p in ("google_ads", "meta_ads") for t in TERRITORIES for w in MONDAYS]
AGREED = [{"platform": p, "lead_date": (date(2026, 9, 20) + timedelta(days=d)).isoformat(), "platform_leads": 20,
           "britebase_leads": 20, "gap_pct": 0.0, "platform_spend": 500.0}
          for d in range(110) for p in ("google_ads", "meta_ads")]  # the data freeze never fires here


def _sheet(now=NOW, **edits):
    """Operations' capacity sheet: a row per territory, open Nov 20, updated two hours
    before `now`. `edits` by territory letter (a, b, c): open_on and hours_old, or None for
    no row."""
    rows = []
    for t in TERRITORIES:
        edit = edits.get(t[-1], {})
        if edit is not None:
            rows.append({"territory": t, "next_open_install_date": edit.get("open_on", date(2026, 11, 20)),
                         "updated_at": now - timedelta(hours=edit.get("hours_old", 2))})
    return rows


def _fakes(campaigns=CAMPAIGNS, bookings=MET, sheet=None, extra_settings=()):
    return SimpleNamespace(warehouse=FakeWarehouse(_snapshot(campaigns), (), AGREED, bookings=bookings),
                           google=FakeGoogleAds(_settings(campaigns) + list(extra_settings)),
                           capacity=FakeCapacity(_sheet() if sheet is None else sheet), slack=FakeSlack())


def _run(f, rules=RULES, now=NOW, mode="propose", **kw):
    return run(warehouse=f.warehouse, adapter=f.google, capacity=f.capacity, slack=f.slack, rules=rules,
               now=now, mode=mode, **kw)


def _rows(out):
    return {(c["target_id"], c["field"]): c for c in out["changes"]}


def _move(out):
    """(cut, raise) of the usual move."""
    rows = _rows(out)
    return rows[("1002", BUDGET)], rows[("1001", BUDGET)]


def _failed(c):
    return [k["name"] for k in c["checks"] if not k["passed"]]


def _check(c, name):
    return next(k for k in c["checks"] if k["name"] == name)


def _reason(out, key):
    return next(r["reason"] for r in out["results"] if r["key"].startswith(key + ":"))


def _applied(warehouse, day, campaign_id, old, new):
    """A budget change act applied on `day`, as the change log holds it."""
    warehouse.write_change_log([{
        "run_date": day, "mode": "act", "platform": "google_ads", "status": "applied", "account_id": ACCOUNT,
        "target_type": "campaign", "target_id": campaign_id, "target_name": f"Fake campaign {campaign_id}",
        "field": BUDGET, "old": old, "new": new, "reason": "every hard limit passed", "checks": [],
        "key": f"seed-{day}-{campaign_id}:applied"}])


def _seed(warehouse, day, **edit):
    """A proposed plan row for `day` that the planner itself would never make."""
    warehouse.write_change_log([{
        "run_date": day, "mode": "propose", "platform": "google_ads", "status": "proposed", "account_id": ACCOUNT,
        "target_type": "campaign", "field": BUDGET, "target_name": "Fake seeded change",
        "reason": "seeded by the test", "checks": [], **edit}])


# --- 4a: the step-up gate --------------------------------------------------------------------


def test_step_up_gate_holds_a_move_past_launch_budget_without_booked_appointments():
    """4a. The territory weekly mart has no rows for the gate's weeks, so a move that lifts
    territory-a past its $100 launch budget is held, both halves, and act writes nothing.
    The notes say why."""
    f = _fakes(bookings=())

    plan = _run(f)
    out = _run(f, mode="act")

    cut, up = _move(plan)
    assert cut["status"] == up["status"] == "held"
    assert _failed(cut) == _failed(up) == ["step_up_gate"]
    assert _check(up, "step_up_gate")["detail"] == (
        "territory-a would go to $120.00 a day, over its $100.00 launch budget; the step-up gate is unmet: "
        "no booked-appointment data for territory-a the week of 2026-09-28")
    assert any("no territory meets the step-up gate" in n for n in plan["notes"])
    assert f.google.write_calls == [] and out["results"] == []


@pytest.mark.parametrize("bookings, status, detail", [
    ([_booked("territory-a", w, 280.0) for w in LAST_TWO], "proposed",
     "the step-up gate is met: cost per booked appointment (booked_paid_new) $280.00 the week of 2026-09-28, "
     "$280.00 the week of 2026-09-21, against $300.00"),
    ([_booked("territory-a", w, 300.0) for w in LAST_TWO], "proposed", "the step-up gate is met"),
    ([_booked("territory-a", "2026-09-28", 280.0), _booked("territory-a", "2026-09-21", 310.0)], "held",
     "$310.00 the week of 2026-09-21, against $300.00"),
    ([_booked("territory-a", "2026-09-28", 280.0)], "held",
     "no booked-appointment data for territory-a the week of 2026-09-21"),
    ([_booked("territory-a", "2026-09-28", 280.0), _booked("territory-a", "2026-10-05", 280.0)], "held",
     "no booked-appointment data for territory-a the week of 2026-09-21"),
    ([_booked("territory-a", w, 280.0, booked_paid_new=0) for w in LAST_TWO], "held",
     "none booked the week of 2026-09-28"),
    ([dict(_booked("territory-a", w, 280.0), spend=0.0, booked_paid_new=0) for w in LAST_TWO], "held",
     "none booked the week of 2026-09-28"),
    ([_booked("territory-a", w, 280.0, booked_paid_new=None) for w in LAST_TWO], "held",
     "no booked-appointment data for territory-a the week of 2026-09-28"),
    ([dict(_booked("territory-a", w, 280.0), spend=None) for w in LAST_TWO], "held",
     "no booked-appointment data for territory-a the week of 2026-09-28"),
    ([_booked("territory-a", w, 280.0, platform="meta_ads") for w in LAST_TWO], "held",
     "no booked-appointment data for territory-a"),
    ([_booked("territory-b", w, 280.0) for w in LAST_TWO], "held", "no booked-appointment data for territory-a"),
], ids=["met", "at-the-cost", "one-week-over", "one-week-missing", "this-week-is-not-full", "none-booked",
        "no-spend-none-booked", "null-count", "null-spend", "other-platform", "other-territory"])
def test_step_up_gate_needs_each_of_the_last_full_weeks_at_or_under_the_cost(bookings, status, detail):
    """4a. Past its launch budget, territory-a needs step_up_weeks (2) full weeks, Monday to
    Sunday before this week, each at or under step_up_cost_per_booked ($300 here). The
    week in progress, another platform's bookings and the cut's territory do not count. A
    null count or spend is no data, never zero (BC-28577)."""
    plan = _run(_fakes(bookings=bookings))

    cut, up = _move(plan)
    assert cut["status"] == up["status"] == status
    assert detail in _check(up, "step_up_gate")["detail"]


# (rules added, the column they choose). Left out, the gate counts booked_paid_new.
CHOICES = [({}, "booked_paid_new"), ({"gate_clients": "new", "gate_channels": "paid"}, "booked_paid_new"),
           ({"gate_clients": "any", "gate_channels": "paid"}, "booked_paid_any_client"),
           ({"gate_clients": "new", "gate_channels": "all"}, "booked_all_new"),
           ({"gate_clients": "any", "gate_channels": "all"}, "booked_all_any_client")]


@pytest.mark.parametrize("choice, column", CHOICES, ids=["default", "new-paid", "any-paid", "new-all", "any-all"])
@pytest.mark.parametrize("weeks, status, detail", [
    (((3, 0), (3, 0)), "proposed", "the step-up gate is met: cost per booked appointment ({column}) $280.00 the "
                                   "week of 2026-09-28, $280.00 the week of 2026-09-21, against $300.00"),
    (((2, 3), (3, 3)), "held", "the step-up gate is unmet: cost per booked appointment ({column}) $280.00 the "
                               "week of 2026-09-28, $420.00 the week of 2026-09-21, against $300.00"),
    (((0, 3), (0, 3)), "held", "the step-up gate is unmet: cost per booked appointment ({column}) none booked the "
                               "week of 2026-09-28, none booked the week of 2026-09-21, against $300.00"),
], ids=["two-weeks-under-opens", "one-week-over-shuts", "zero-bookings-shuts"])
def test_the_gate_counts_the_column_its_rules_choose(choice, column, weeks, status, detail):
    """4a with BC-28577. gate_clients ("new" or "any") and gate_channels ("paid" or "all")
    choose which of the territory weekly mart's four counts the gate divides spend by. Left
    out, the gate counts new clients' bookings credited to this platform's paid ads. Each
    week spent $840; `weeks` gives (the chosen count, the other three) for Sep 21 and Sep
    28. The other three always point the other way, so only the chosen column can give the
    result: two weeks at $280 open the gate, one week at $420 keeps it shut, and so does a
    territory with none of the chosen bookings."""
    bookings = [_booked("territory-a", week, 280.0, **{c: n if c == column else rest for c in COUNTS})
                for week, (n, rest) in zip(LAST_TWO, weeks)]
    f = _fakes(bookings=bookings)

    cut, up = _move(_run(f, rules=dict(RULES, **choice)))

    assert cut["status"] == up["status"] == status
    assert _failed(up) == ([] if status == "proposed" else ["step_up_gate"])
    assert _check(up, "step_up_gate")["detail"] == (
        "territory-a would go to $120.00 a day, over its $100.00 launch budget; " + detail.format(column=column))
    assert ("read_booked_appointments", "google_ads", "2026-09-21") in f.warehouse.calls


def test_money_moves_inside_a_territorys_launch_budget_without_the_gate():
    """4a. With no booked-appointment data at all, two moves still go ahead, so the weeks 1-2
    approved moves keep working. A move between two campaigns in territory-a leaves it at
    its $180 launch budget. And a raise that puts back the $20 the agent cut from
    territory-a on Oct 1 (after season_start) returns it to its $100 launch budget."""
    weeks_1_2 = dict(RULES, weeks_1_2=True)
    inside = _fakes(campaigns=WITHIN, bookings=())
    refill = _fakes(campaigns=REFILL, bookings=())
    _applied(refill.warehouse, "2026-10-01", "1001", 100 * M, 80 * M)

    plan = _run(inside, rules=weeks_1_2)
    approve(warehouse=inside.warehouse, rules=weeks_1_2, key=_move(plan)[0]["key"], by="Fake Head of GTM", now=NOW)
    _run(inside, rules=weeks_1_2, mode="act")
    back = _run(refill)

    assert [c["status"] for c in _move(plan)] == ["proposed", "proposed"]
    assert _check(_move(plan)[1], "step_up_gate")["detail"] == (
        "territory-a stays within its launch budget: $180.00 a day against $180.00")
    assert inside.google.applied == [c["key"] for c in _move(plan)]
    cut, up = _move(back)
    assert (up["old"], up["new"]) == (80 * M, 100 * M) and cut["status"] == up["status"] == "proposed"
    assert _check(up, "step_up_gate")["detail"] == (
        "territory-a stays within its launch budget: $100.00 a day against $100.00")


def test_act_checks_the_step_up_gate_again_before_each_write():
    """4a, at write time. Planned while territory-a met the gate; by the time act runs, its
    booked-appointment rows are gone. Act refuses both halves and writes nothing."""
    f = _fakes()
    plan = _run(f)
    f.warehouse.bookings = []

    out = _run(f, mode="act")

    assert [c["status"] for c in _move(plan)] == ["proposed", "proposed"]
    assert f.google.write_calls == []
    assert [r["status"] for r in out["results"]] == ["apply_failed", "apply_failed"]
    assert all("the step-up gate is unmet" in r["reason"] for r in out["results"])


# --- 4b: the capacity pause ------------------------------------------------------------------


@pytest.mark.parametrize("hours_old", [2, 100], ids=["fresh-row", "stale-row"])
def test_a_territory_past_the_capacity_pause_date_is_paused(hours_old):
    """4b. territory-c's next open install date is Dec 14, after the Dec 10 pause date, so
    its campaign is paused: proposed in propose mode, applied in act mode, and gone from the
    next day's read. A stale row still pauses, since a pause only lowers spend.
    territory-b's date is the pause date itself, so it stays on."""
    f = _fakes(campaigns=QUIET, sheet=_sheet(b={"open_on": date(2026, 12, 10)},
                                             c={"open_on": date(2026, 12, 14), "hours_old": hours_old}))

    plan = _run(f)
    _run(f, mode="act")
    tomorrow = _run(f, now=_at("2026-10-07"), mode="act")

    [pause] = [c for c in plan["changes"] if c["field"] == "status"]
    assert (pause["target_type"], pause["target_id"], pause["old"], pause["new"]) == ("campaign", "1003", "ENABLED",
                                                                                     "PAUSED")
    assert pause["status"] == "proposed" and _failed(pause) == []
    assert pause["reason"] == "territory-c's next open install date 2026-12-14 is after 2026-12-10"
    assert f.google.applied == [pause["key"]]
    assert not [c for c in tomorrow["changes"] if c["target_id"] == "1003"]


def test_the_capacity_pause_goes_ahead_during_the_freeze_and_the_taper():
    """4b. On Dec 2 the territory freeze and the taper are both on. territory-c is full: its
    campaign is paused and not tapered; the other two are tapered. Act applies all three."""
    day = "2026-12-02"
    f = _fakes(sheet=_sheet(_at(day), c={"open_on": date(2026, 12, 14)}))

    out = _run(f, now=_at(day), mode="act")

    rows = _rows(out)
    assert rows[("1003", "status")]["new"] == "PAUSED" and ("1003", BUDGET) not in rows
    assert {(t, r["new"]) for (t, field), r in rows.items() if field == BUDGET} == {("1001", 90 * M), ("1002", 72 * M)}
    assert sorted(f.google.applied) == sorted(c["key"] for c in out["changes"])


def test_no_raise_goes_into_a_full_territory():
    """4b. territory-a is full: its campaign is paused, and the move that would raise it is
    held, both halves, on the capacity check."""
    plan = _run(_fakes(sheet=_sheet(a={"open_on": date(2026, 12, 14)})))

    cut, up = _move(plan)
    assert _rows(plan)[("1001", "status")]["status"] == "proposed"
    assert cut["status"] == up["status"] == "held" and _failed(cut) == _failed(up) == ["capacity_open"]
    assert _check(up, "capacity_open")["detail"] == (
        "territory-a is full: its next open install date 2026-12-14 is after 2026-12-10")


def _meta_ad_set(ad_set_id):
    return {"account_id": META_ACCOUNT, "campaign_id": "5" + ad_set_id[1:], "campaign_name": "Fake Meta campaign",
            "ad_set_id": ad_set_id, "ad_set_name": f"Fake ad set {ad_set_id}", "daily_budget_micros": 50 * M,
            "budget_level": "ad_set", "budget_limited": False, "budget_shared": False, "brand": False,
            "status": "ENABLED", "optimization_goal": "leads", "destination_type": "WEBSITE", "targeting": {}}


def _meta_result(ad_set_id, territory):
    return {"platform": "meta_ads", "account_id": META_ACCOUNT, "campaign_id": "5" + ad_set_id[1:],
            "ad_group_id": ad_set_id, "ad_id": "7" + ad_set_id[1:], "territory": territory, "spend": 100.0,
            "conversions": 2}


META_RESULTS = [_meta_result("6001", "territory-a"), _meta_result("6002", "territory-b")]


def test_a_full_territory_pauses_its_meta_ad_sets():
    """4b on Meta. The budget sits on the ad set, so the ad set is what pauses."""
    meta = FakeMetaAds([_meta_ad_set("6001"), _meta_ad_set("6002")])
    f = SimpleNamespace(warehouse=FakeWarehouse([], META_RESULTS, AGREED, bookings=MET), google=meta,
                        capacity=FakeCapacity(_sheet(b={"open_on": date(2026, 12, 14)})), slack=FakeSlack())

    out = _run(f, rules=META_RULES, mode="act")

    [pause] = [c for c in out["changes"] if c["field"] == "status"]
    assert (pause["target_type"], pause["target_id"], pause["new"], pause["status"]) == (
        "ad_set", "6002", "PAUSED", "proposed")
    assert meta.applied == [pause["key"]]


# --- 4c: a stale capacity row ----------------------------------------------------------------


@pytest.mark.parametrize("sheet, fails, detail, alerted", [
    (_sheet(a={"hours_old": 49}), False,
     "territory-a's capacity row was last updated 49 hours ago, over the 48 hour limit", ["territory-a"]),
    (_sheet(a=None), False, "the capacity sheet has no next open install date for territory-a", ["territory-a"]),
    (_sheet(), True, "the capacity sheet could not be read", list(TERRITORIES)),
], ids=["stale", "missing", "unread"])
def test_a_stale_capacity_row_blocks_raises_into_its_territory_and_alerts_once(sheet, fails, detail, alerted):
    """4c. No raise goes into a territory whose row is older than capacity_max_age_hours
    (48 here), or has no row, or when the sheet cannot be read: the move is held, both
    halves. One Slack alert names each such territory. A preview posts nothing, and re-runs
    that day in either mode post no second alert."""
    f = _fakes(sheet=sheet)
    f.capacity.fails = fails

    _run(f, emit=True)
    assert f.slack.posts == [] and f.warehouse.change_log == []
    plan = _run(f)
    _run(f)
    _run(f, mode="act")

    cut, up = _move(plan)
    assert cut["status"] == up["status"] == "held" and _failed(cut) == _failed(up) == ["capacity_open"]
    assert _check(up, "capacity_open")["detail"] == detail
    alerts = [p for p in f.slack.posts if "CAPACITY SHEET NOT CURRENT" in p]
    assert len(alerts) == 1 and all(t in alerts[0] for t in alerted)
    assert sorted(r["target_id"] for r in f.warehouse.change_log if r["status"] == "capacity_alert") == alerted
    assert f.google.write_calls == []


def test_the_capacity_alert_goes_out_once_a_day_across_both_platforms():
    """4c. The Google run alerts on territory-a's stale row. The Meta run the same day, which
    also has an ad set in territory-a, finds the alert row and posts no second one."""
    warehouse = FakeWarehouse(_snapshot(CAMPAIGNS), META_RESULTS, AGREED, bookings=MET)
    capacity, slack = FakeCapacity(_sheet(a={"hours_old": 49})), FakeSlack()
    google = SimpleNamespace(warehouse=warehouse, google=FakeGoogleAds(_settings(CAMPAIGNS)), capacity=capacity,
                             slack=slack)
    meta = SimpleNamespace(warehouse=warehouse, google=FakeMetaAds([_meta_ad_set("6001"), _meta_ad_set("6002")]),
                           capacity=capacity, slack=slack)

    _run(google)
    _run(meta, rules=META_RULES)

    assert len([p for p in slack.posts if "CAPACITY SHEET NOT CURRENT" in p]) == 1
    assert [r["platform"] for r in warehouse.change_log if r["status"] == "capacity_alert"] == ["google_ads"]


def test_act_checks_capacity_again_before_each_write():
    """4c, at write time. Planned at 09:00 local while territory-a's row was 40 hours old.
    Act runs nine hours later, the same local day, when the row is 49 hours old: it refuses
    both halves and the alert goes out."""
    f = _fakes(sheet=_sheet(a={"hours_old": 40}))
    plan = _run(f)

    out = _run(f, now=NOW + timedelta(hours=9), mode="act")

    assert [c["status"] for c in _move(plan)] == ["proposed", "proposed"]
    assert f.google.write_calls == []
    assert all("49 hours ago, over the 48 hour limit" in r["reason"] for r in out["results"]) and len(out["results"]) == 2
    assert len([p for p in f.slack.posts if "CAPACITY SHEET NOT CURRENT" in p]) == 1


# --- 4d: the taper ---------------------------------------------------------------------------


def test_from_taper_start_every_budget_is_cut_by_the_daily_rate():
    """4d. From Dec 1 each campaign's budget is cut taper_daily_pct (10%) of that day's
    budget, in whole cents, every day, and no budget move is planned. A brand campaign and a
    shared budget are left alone. Each cut only lowers spend, so act applies it."""
    extra = [{"account_id": ACCOUNT, "campaign_id": "1004", "campaign_name": "Fake brand", "daily_budget_micros": 50 * M,
              "budget_limited": False, "budget_shared": False, "brand": True},
             {"account_id": ACCOUNT, "campaign_id": "1005", "campaign_name": "Fake shared", "daily_budget_micros": 50 * M,
              "budget_limited": False, "budget_shared": True, "brand": False}]
    f = _fakes(sheet=_sheet(_at("2026-12-01")), extra_settings=extra)

    first = _run(f, now=_at("2026-12-01"), mode="act")
    f.capacity.rows = _sheet(_at("2026-12-02"))
    second = _run(f, now=_at("2026-12-02"), mode="act")

    assert {(c["target_id"], c["old"], c["new"]) for c in first["changes"]} == {
        ("1001", 100 * M, 90 * M), ("1002", 80 * M, 72 * M), ("1003", 60 * M, 54 * M)}
    assert {(c["target_id"], c["old"], c["new"]) for c in second["changes"]} == {
        ("1001", 90 * M, 81 * M), ("1002", 72 * M, 64_800_000), ("1003", 54 * M, 48_600_000)}
    assert all(c["status"] == "proposed" and c["reason"] == "the taper: 10% a day from 2026-12-01"
               for c in first["changes"])
    assert any("no budget move: the taper began 2026-12-01" in n for n in first["notes"])
    assert len(f.google.applied) == 6


def test_taper_cuts_are_separate_changes_not_a_move():
    """4d. Two taper cuts are two changes, never a linked move: in weeks 1-2 each needs its
    own approval, and only one is applied a day."""
    rules, day = dict(RULES, weeks_1_2=True), "2026-12-01"
    f = _fakes(campaigns=CAMPAIGNS[:2], sheet=_sheet(_at(day)))

    a, b = _run(f, rules=rules, now=_at(day))["changes"]
    approve(warehouse=f.warehouse, rules=rules, key=a["key"], by="Fake Head of GTM", now=_at(day))
    out = _run(f, rules=rules, now=_at(day), mode="act")

    assert not b["key"].endswith(":pair")
    assert f.google.applied == [a["key"]] and out["waiting"] == [b["key"]]


@pytest.mark.parametrize("rules", [{k: v for k, v in RULES.items() if k != "taper_daily_pct"},
                                   dict(RULES, taper_daily_pct=None)], ids=["missing", "null"])
def test_a_missing_taper_rate_is_refused_only_from_taper_start(rules):
    """taper_daily_pct has no default. The day before taper_start the run goes ahead and
    plans the usual move. On taper_start and after, the run is refused before any read, and
    the error says why."""
    before = _fakes(sheet=_sheet(_at("2026-11-30")))

    plan = _run(before, rules=rules, now=_at("2026-11-30"))

    assert {c["target_id"] for c in plan["changes"]} == {"1001", "1002"}
    for day in ("2026-12-01", "2026-12-02"):
        f = _fakes()
        with pytest.raises(ValueError, match="taper_daily_pct is not set, and the taper began 2026-12-01"):
            _run(f, rules=rules, now=_at(day))
        assert f.warehouse.calls == f.google.calls == f.capacity.calls == []


# --- 4e: the territory freeze ----------------------------------------------------------------


def test_from_the_freeze_date_no_move_crosses_territories():
    """4e. The day before territory_freeze_date (Nov 9), the move from territory-b to
    territory-a is proposed. From Nov 9 it is held, both halves. A move inside one territory
    is still proposed."""
    def plan(day, campaigns=CAMPAIGNS):
        return _run(_fakes(campaigns=campaigns, sheet=_sheet(_at(day))), now=_at(day))

    before, on, inside = plan("2026-11-08"), plan("2026-11-09"), plan("2026-11-09", WITHIN)

    assert [c["status"] for c in _move(before)] == ["proposed", "proposed"]
    assert "territory_freeze" not in [k["name"] for k in _move(before)[1]["checks"]]
    cut, up = _move(on)
    assert cut["status"] == up["status"] == "held" and _failed(cut) == _failed(up) == ["territory_freeze"]
    assert _check(up, "territory_freeze")["detail"] == (
        "no money moves between territories from 2026-11-09; this move takes from territory-b and gives to territory-a")
    assert [c["status"] for c in _move(inside)] == ["proposed", "proposed"]
    assert _check(_move(inside)[1], "territory_freeze") == {
        "name": "territory_freeze", "passed": True, "detail": "the move stays inside territory-a"}


def test_act_refuses_both_halves_of_a_cross_territory_move_after_the_freeze():
    """4e, at write time. A move across territories is seeded into the Nov 9 plan, as if a
    planner elsewhere made it. Act refuses the cut as well as the raise and writes nothing."""
    day = "2026-11-09"
    f = _fakes(sheet=_sheet(_at(day)))
    _seed(f.warehouse, day, key="seed-x-0001", target_id="1002", old=80 * M, new=60 * M)
    _seed(f.warehouse, day, key="seed-x-0001:pair", target_id="1001", old=100 * M, new=120 * M)

    out = _run(f, now=_at(day), mode="act")

    assert f.google.write_calls == []
    for key in ("seed-x-0001", "seed-x-0001:pair"):
        assert "no money moves between territories from 2026-11-09" in _reason(out, key)


# --- 4f: 'multi' and capacity (BC-28579) -----------------------------------------------------


def _city(key):
    """One city in a Meta targeting spec, at the Housing minimum radius."""
    return {"key": key, "name": f"Fake city {key}", "region": "Fake State", "country": "US", "radius": 15,
            "distance_unit": "mile"}


# multi_territories: the territories the instant-form ad set covers, each with its cities' keys.
COVERS = {"territory-a": ["910001", "910002"], "territory-b": ["920001"], "territory-c": ["930001", "930002"]}
FORM_TARGETING = {"geo_locations": {"cities": [_city(k) for keys in COVERS.values() for k in keys],
                                    "location_types": ["home", "recent"]},
                  "publisher_platforms": ["facebook", "instagram"]}
FORM_RULES = dict(META_RULES, multi_territories=COVERS)
FORM_BUDGETS = {"6001": 100, "6002": 80, "6003": 60}  # dollars a day
FORM_TERRITORY = {"6001": "territory-a", "6002": "territory-b", "6003": "multi"}
MULTI_BOOKED = [_booked("multi", w, 280.0, "meta_ads") for w in MONDAYS]  # 'multi' meets its own gate
GEO = "geo_locations"


def _form_fakes(to="6003", sheet=None, targeting=FORM_TARGETING):
    """Meta mid-season: site ad sets 6001 (territory-a, $100) and 6002 (territory-b, $80),
    and the instant-form ad set 6003 ('multi', $60) with a city in each territory it
    covers. 6002 has the worst cost per lead and `to` the best, and `to` spent its whole
    budget yesterday, so the day's move is from 6002 to `to`. Every gate is met."""
    ad_sets = [dict(_meta_ad_set(a), daily_budget_micros=d * M) for a, d in FORM_BUDGETS.items()]
    ad_sets[2].update(ad_set_name="Fake instant-form ad set", destination_type="ON_AD",
                      targeting=copy.deepcopy(targeting))
    results = [dict(_meta_result(a, t), spend=120.0 if a == to else 800.0 if a == "6002" else 300.0,
                    conversions=4 if a == "6002" else 6) for a, t in FORM_TERRITORY.items()]
    spend = [{"account_id": META_ACCOUNT, "level": "ad_set", "id": to, "spend": float(FORM_BUDGETS[to])}]
    return SimpleNamespace(warehouse=FakeWarehouse([], results, AGREED, bookings=MET + MULTI_BOOKED),
                           google=FakeMetaAds(ad_sets, spend=spend),
                           capacity=FakeCapacity(_sheet() if sheet is None else sheet), slack=FakeSlack())


def _form_move(out, to="6003"):
    """(cut, raise) of the day's move from 6002 to `to`."""
    rows = _rows(out)
    return rows[("6002", BUDGET)], rows[(to, BUDGET)]


def _removal(out):
    [row] = [c for c in out["changes"] if c["field"] == GEO]
    return row


def _form_cities(f):
    """The keys of the cities the instant-form ad set targets now, as the fake serves it."""
    form = next(s for s in f.google.read_settings([META_ACCOUNT]) if s["ad_set_id"] == "6003")
    return [c["key"] for c in form["targeting"][GEO].get("cities", [])]


C_FULL = {"open_on": date(2026, 12, 14)}  # after the Dec 10 pause date


def test_a_raise_into_multi_goes_ahead_when_each_territory_it_covers_is_current_and_open():
    """4f rules 1 and 4. 'multi' has no capacity row, so the raise into the instant-form ad
    set is judged on the three territories multi_territories lists. Each has a current row,
    open before the pause date: the move is proposed and act applies it. No alert, and no
    change to the targeting."""
    f = _form_fakes()

    plan = _run(f, rules=FORM_RULES)
    _run(f, rules=FORM_RULES, mode="act")

    cut, up = _form_move(plan)
    assert (up["old"], up["new"]) == (60 * M, 75 * M) and cut["status"] == up["status"] == "proposed"
    assert _check(up, "capacity_open") == {
        "name": "capacity_open", "passed": True,
        "detail": "each territory multi covers (territory-a, territory-b, territory-c) has a current row and a next "
                  "open install date on or before 2026-12-10"}
    assert f.google.applied == [cut["key"], up["key"]]
    assert not [c for c in plan["changes"] if c["field"] == GEO]
    assert not [p for p in f.slack.posts if "CAPACITY SHEET NOT CURRENT" in p]


def test_a_stale_row_for_a_territory_multi_covers_holds_raises_into_multi_and_alerts_once():
    """4f rule 2. territory-b's row is 49 hours old and territory-c has none. The raise into
    'multi' is held, both halves, naming each. One Slack alert names both territories, not
    'multi', and says multi is held too; re-runs that day in either mode post no second."""
    f = _form_fakes(sheet=_sheet(b={"hours_old": 49}, c=None))

    plan = _run(f, rules=FORM_RULES)
    _run(f, rules=FORM_RULES)
    _run(f, rules=FORM_RULES, mode="act")

    cut, up = _form_move(plan)
    assert cut["status"] == up["status"] == "held" and _failed(cut) == _failed(up) == ["capacity_open"]
    assert _check(up, "capacity_open")["detail"] == (
        "multi covers territories whose capacity is not current: territory-b's capacity row was last updated 49 "
        "hours ago, over the 48 hour limit; the capacity sheet has no next open install date for territory-c")
    [alert] = [p for p in f.slack.posts if "CAPACITY SHEET NOT CURRENT" in p]
    assert alert.splitlines()[1:] == [
        "• territory-b: territory-b's capacity row was last updated 49 hours ago, over the 48 hour limit.",
        "• territory-c: the capacity sheet has no next open install date for territory-c.",
        "multi covers territory-b, territory-c, so no budget raise goes into multi either."]
    assert [r["target_id"] for r in f.warehouse.change_log if r["status"] == "capacity_alert"] == [
        "territory-b", "territory-c"]
    assert f.google.write_calls == []


def test_a_full_territory_multi_covers_holds_raises_and_proposes_removing_its_locations():
    """4f rule 3. territory-c's next open install date is after the pause date. The raise
    into 'multi' is held, and the plan proposes one change: the instant-form ad set's
    locations without territory-c's two cities. It passes the Housing check on the
    targeting it would leave, and act waits for approval even after weeks 1-2."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))

    plan = _run(f, rules=FORM_RULES)
    out = _run(f, rules=FORM_RULES, mode="act")

    cut, up = _form_move(plan)
    assert cut["status"] == up["status"] == "held" and _failed(up) == ["capacity_open"]
    assert _check(up, "capacity_open")["detail"] == (
        "multi covers a full territory: territory-c's next open install date 2026-12-14 is after 2026-12-10")
    geo = _removal(plan)
    assert (geo["target_type"], geo["target_id"], geo["status"]) == ("ad_set", "6003", "proposed")
    assert geo["reason"] == ("territory-c is full (next open install date 2026-12-14, after 2026-12-10), so the ad "
                             "set stops targeting it")
    assert [(k["name"], k["passed"]) for k in geo["checks"]] == [
        ("brand_untouched", True), ("housing_safe", True), ("location_removal", True)]
    assert _check(geo, "housing_safe")["detail"] == "targeting after the change is Housing-safe"
    assert "• Fake instant-form ad set: locations: remove 2 (Fake city 930001, Fake city 930002), keep 3." in (
        f.slack.posts[0])
    assert out["waiting"] == [geo["key"]] and f.google.write_calls == []
    assert _form_cities(f) == ["910001", "910002", "920001", "930001", "930002"]


def test_approving_the_removal_takes_out_only_the_full_territorys_locations():
    """4f rule 3. Once the Head of GTM approves it, act writes the change through the Meta
    adapter like any other: territory-c's cities leave the targeting, every other city and
    setting stays, and the change log holds the plan, approval and apply rows."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))
    geo = _removal(_run(f, rules=FORM_RULES))

    approve(warehouse=f.warehouse, rules=FORM_RULES, key=geo["key"], by="Fake Head of GTM", now=NOW)
    out = _run(f, rules=FORM_RULES, mode="act")

    assert f.google.applied == [geo["key"]] and [r["status"] for r in out["results"]] == ["applied"]
    assert _form_cities(f) == ["910001", "910002", "920001"]
    form = next(s for s in f.google.read_settings([META_ACCOUNT]) if s["ad_set_id"] == "6003")
    assert form["targeting"] == {"geo_locations": {"cities": FORM_TARGETING[GEO]["cities"][:3],
                                                   "location_types": ["home", "recent"]},
                                 "publisher_platforms": ["facebook", "instagram"]}
    assert [r["status"] for r in f.warehouse.change_log if r["key"].startswith(geo["key"])] == [
        "proposed", "approved", "applied"]


def test_after_the_removal_the_plan_is_out_of_step_until_a_person_updates_multi_territories():
    """4f rules 1 and 3. The day after territory-c's cities came out, multi_territories still
    lists it: the plan holds an out-of-step row naming the missing keys, and raises into
    'multi' stay held. Once a person takes territory-c off the list, the raise goes ahead."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))
    approve(warehouse=f.warehouse, rules=FORM_RULES, key=_removal(_run(f, rules=FORM_RULES))["key"],
            by="Fake Head of GTM", now=NOW)
    _run(f, rules=FORM_RULES, mode="act")
    f.capacity.rows = _sheet(_at("2026-10-07"), c=C_FULL)

    next_day = _run(f, rules=FORM_RULES, now=_at("2026-10-07"))
    f.capacity.rows = _sheet(_at("2026-10-08"), c=C_FULL)
    in_step = dict(FORM_RULES, multi_territories={t: k for t, k in COVERS.items() if t != "territory-c"})
    after = _run(f, rules=in_step, now=_at("2026-10-08"))

    stale = _removal(next_day)
    assert stale["status"] == "held" and _check(stale, "location_removal")["detail"] == (
        "out of step: multi_territories lists location keys the targeting does not have (930001, 930002 for "
        "territory-c); a person brings multi_territories in step with the targeting")
    assert [c["status"] for c in _form_move(next_day)] == ["held", "held"]
    assert [c["status"] for c in _form_move(after)] == ["proposed", "proposed"]
    assert not [c for c in after["changes"] if c["field"] == GEO]


@pytest.mark.parametrize("targeting, covers, failed, detail", [
    (dict(FORM_TARGETING, age_min=25), COVERS, "housing_safe",
     "targeting after the change breaks Meta's Housing rules: an age limit (25-65)"),
    (FORM_TARGETING, dict(COVERS, **{"territory-c": ["930001", "930002", "939999"]}), "location_removal",
     "out of step: multi_territories lists location keys the targeting does not have (939999 for territory-c); a "
     "person brings multi_territories in step with the targeting"),
], ids=["not-housing-safe", "out-of-step"])
def test_a_removal_is_held_unless_it_is_housing_safe_in_step_and_leaves_a_location(targeting, covers, failed,
                                                                                   detail):
    """4f rule 3. The removal is held when the targeting it would leave breaks the Housing
    rules, or when multi_territories lists a key the targeting does not have. Act never
    writes a held change. A removal that would leave no location is held too: 4g's stale-row
    case shows it, since a current full row for every listed territory pauses instead."""
    f = _form_fakes(sheet=_sheet(c=C_FULL), targeting=targeting)
    rules = dict(FORM_RULES, multi_territories=covers)

    geo = _removal(_run(f, rules=rules))
    _run(f, rules=rules, mode="act")

    assert geo["status"] == "held" and _failed(geo) == [failed]
    assert _check(geo, failed)["detail"] == detail
    assert GEO not in [c[1] for c in f.google.write_calls] and f.google.applied == []


def test_act_keeps_the_locations_of_a_territory_with_room_again():
    """4f rule 3, at write time. Planned and approved while territory-c was full; by the
    time act runs, its row shows room before the pause date. Act refuses the change and
    the targeting keeps every city."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))
    geo = _removal(_run(f, rules=FORM_RULES))
    approve(warehouse=f.warehouse, rules=FORM_RULES, key=geo["key"], by="Fake Head of GTM", now=NOW)
    f.capacity.rows = _sheet()

    out = _run(f, rules=FORM_RULES, mode="act")

    assert _reason(out, geo["key"]) == "no territory multi_territories lists is full today, so no location is removed"
    assert f.google.write_calls == [] and len(_form_cities(f)) == 5


@pytest.mark.parametrize("rules", [META_RULES, dict(META_RULES, multi_territories=None),
                                   dict(META_RULES, multi_territories={})], ids=["missing", "null", "empty"])
def test_without_multi_territories_no_raise_goes_into_multi_and_the_run_says_why(rules):
    """4f rule 5. With the key missing, null or empty, the territories 'multi' covers are
    unknown: the raise into it is held, both halves, and the notes say why. No capacity
    alert names 'multi', and no location is removed."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))

    plan = _run(f, rules=rules)

    cut, up = _form_move(plan)
    assert cut["status"] == up["status"] == "held" and _failed(up) == ["capacity_open"]
    assert _check(up, "capacity_open")["detail"] == (
        "multi_territories is not set in the rules file, so the territories multi covers are unknown")
    assert ("multi_territories is not set in the rules file, so no raise goes into multi: the territories it covers, "
            "and their capacity, are unknown") in plan["notes"]
    assert not [r for r in f.warehouse.change_log if r["status"] == "capacity_alert"]
    assert not [c for c in plan["changes"] if c["field"] == GEO]


@pytest.mark.parametrize("sheet, passed, detail", [
    (_sheet(c=C_FULL), True, "territory-a's next open install date 2026-11-20 is on or before 2026-12-10"),
    (_sheet(c=None), True, "territory-a's next open install date 2026-11-20 is on or before 2026-12-10"),
    (_sheet(a={"hours_old": 49}), False,
     "territory-a's capacity row was last updated 49 hours ago, over the 48 hour limit"),
], ids=["a-covered-territory-is-full", "a-covered-territory-has-no-row", "its-own-row-is-stale"])
def test_a_site_ad_sets_capacity_check_reads_only_its_own_territory(sheet, passed, detail):
    """4f rule 4. A raise into a site ad set is judged on its own territory's row, as before
    BC-28579: territory-c, which only 'multi' covers, being full or missing changes nothing,
    and territory-a's own stale row still holds it."""
    f = _form_fakes(to="6001", sheet=sheet)

    cut, up = _form_move(_run(f, rules=FORM_RULES), to="6001")

    assert (up["old"], up["new"]) == (100 * M, 120 * M)
    assert _check(up, "capacity_open") == {"name": "capacity_open", "passed": passed, "detail": detail}


def test_multi_territories_has_a_meaning_and_may_be_left_out():
    """BC-28579. A one-line meaning, and not in RULES here: the season tests above run
    without it."""
    assert set(MULTI_RULES) == {"multi_territories"} and all(MULTI_RULES.values())
    assert not set(MULTI_RULES) & set(RULES)


# --- 4g: every territory 'multi' covers is full (BC-28580) -----------------------------------


def _all_full(now=NOW, **edits):
    """The capacity sheet with every territory full, each row current. `edits` as in _sheet."""
    return _sheet(now, **{**dict.fromkeys("abc", C_FULL), **edits})


ALL_FULL_WHY = ("every territory multi covers is full (territory-a's next open install date 2026-12-14 is after "
                "2026-12-10; territory-b's next open install date 2026-12-14 is after 2026-12-10; territory-c's next "
                "open install date 2026-12-14 is after 2026-12-10), so the ad set pauses rather than lose every "
                "location")


def _kept(geo):
    """The keys of the cities a planned locations change keeps."""
    return [c["key"] for c in json.loads(geo["new"]).get("cities", [])]


def test_when_every_territory_multi_covers_is_full_the_instant_form_ad_set_pauses_once():
    """4g. Each territory multi_territories lists has a current row past the pause date, so
    removing each one's cities would leave the instant-form ad set no location. The plan
    pauses it instead: one change, and no location removal. A pause only lowers spend, so
    act applies it with no approval after weeks 1-2, like any capacity pause. The site ad
    sets in full territories pause too, and the raise into 'multi' stays held."""
    f = _form_fakes(sheet=_all_full())

    plan = _run(f, rules=FORM_RULES)
    out = _run(f, rules=FORM_RULES, mode="act")

    pause = _rows(plan)[("6003", "status")]
    assert (pause["target_type"], pause["old"], pause["new"], pause["status"]) == (
        "ad_set", "ENABLED", "PAUSED", "proposed")
    assert pause["reason"] == ALL_FULL_WHY
    assert [(k["name"], k["passed"]) for k in pause["checks"]] == [("brand_untouched", True)]
    assert not [c for c in plan["changes"] if c["field"] == GEO]
    assert sorted((c["target_id"], c["field"]) for c in plan["changes"] if c["status"] == "proposed") == [
        ("6001", "status"), ("6002", "status"), ("6003", "status")]
    assert [c["status"] for c in _form_move(plan)] == ["held", "held"]
    assert pause["key"] in f.google.applied and out["waiting"] == []
    assert "6003" not in [s["ad_set_id"] for s in f.google.read_settings([META_ACCOUNT])]


@pytest.mark.parametrize("sheet, status, kept, failed", [
    (_sheet(a=C_FULL, c=C_FULL), "proposed", ["920001"], []),
    (_sheet(a=C_FULL, b=None, c=C_FULL), "proposed", ["920001"], []),
    (_all_full(b=dict(C_FULL, hours_old=49)), "held", [], ["location_removal"]),
], ids=["two-of-three-full", "two-full-and-one-row-missing", "all-full-but-one-row-stale"])
def test_when_only_some_territories_multi_covers_are_known_full_the_removal_stands(sheet, status, kept, failed):
    """4g. The pause needs a current row past the pause date for every listed territory.
    With one territory open, or its row missing or stale, BC-28579 stands: no pause of the
    instant-form ad set, raises into 'multi' held, and one removal of the full territories'
    cities. With every territory full but one row stale, that removal would leave no
    location, so it is held."""
    f = _form_fakes(sheet=sheet)

    plan = _run(f, rules=FORM_RULES)

    geo = _removal(plan)
    assert ("6003", "status") not in _rows(plan)
    assert (geo["status"], _kept(geo), _failed(geo)) == (status, kept, failed)
    if failed:
        assert _check(geo, "location_removal")["detail"] == (
            "removing territory-a and territory-b and territory-c would leave the ad set no location")
    assert _form_move(plan)[1]["status"] == "held"


def test_a_rerun_the_same_day_plans_nothing_new_and_the_paused_ad_set_drops_out_after():
    """4g. Propose twice, then act twice, on one day: the second propose plans nothing new,
    the change log holds one pause row and one applied row, and the ad set is written once.
    The next day it is paused, so no run lists it and nothing is planned for it."""
    f = _form_fakes(sheet=_all_full())

    first = _run(f, rules=FORM_RULES)
    again = _run(f, rules=FORM_RULES)
    _run(f, rules=FORM_RULES, mode="act")
    _run(f, rules=FORM_RULES, mode="act")
    f.capacity.rows = _all_full(_at("2026-10-07"))
    tomorrow = _run(f, rules=FORM_RULES, now=_at("2026-10-07"))

    pause = _rows(first)[("6003", "status")]
    assert again["changes"] == [] and again["already_logged"] == len(first["changes"])
    assert [r["status"] for r in f.warehouse.change_log if r["key"].startswith(pause["key"])] == [
        "proposed", "applied"]
    assert f.google.applied.count(pause["key"]) == 1
    assert not [c for c in tomorrow["changes"] if c["target_id"] == "6003"]


def test_the_emergency_stop_still_blocks_the_pause():
    """4g. With the emergency stop on, act plans and logs the pause but writes nothing: the
    instant-form ad set stays on."""
    f = _form_fakes(sheet=_all_full())

    out = _run(f, rules=dict(FORM_RULES, emergency_stop=True), mode="act")

    assert _rows(out)[("6003", "status")]["status"] == "proposed"
    assert out["emergency_stop"] is True and out["results"] == [] and f.google.write_calls == []
    assert "6003" in [s["ad_set_id"] for s in f.google.read_settings([META_ACCOUNT])]


def test_the_data_freeze_still_blocks_the_pause():
    """4g. Yesterday's lead count row is missing, so the run is frozen: it plans and writes
    nothing, the pause included, and logs only the frozen row."""
    f = _form_fakes(sheet=_all_full())
    f.warehouse.lead_reconciliation = []

    out = _run(f, rules=FORM_RULES, mode="act")

    assert out["frozen"]["status"] == "frozen" and out["changes"] == [] and out["results"] == []
    assert f.google.write_calls == []
    assert [r["status"] for r in f.warehouse.change_log] == ["frozen"]


def test_the_agent_never_turns_the_paused_instant_form_ad_set_back_on():
    """4g. The day after the pause, every territory has room again. The agent plans nothing
    for the paused ad set: turning it back on is a person's call. Even an approved plan row
    that would turn it back on, which the planner never makes, is refused at write time."""
    f = _form_fakes(sheet=_all_full())
    _run(f, rules=FORM_RULES, mode="act")
    day = "2026-10-07"
    f.capacity.rows = _sheet(_at(day))

    plan = _run(f, rules=FORM_RULES, now=_at(day))
    f.warehouse.write_change_log([{
        "run_date": day, "mode": "propose", "platform": "meta_ads", "status": "proposed",
        "account_id": META_ACCOUNT, "target_type": "ad_set", "target_id": "6003",
        "target_name": "Fake instant-form ad set", "field": "status", "old": "PAUSED", "new": "ENABLED",
        "reason": "seeded by the test", "checks": [], "key": "seed-unpause-6003"}])
    approve(warehouse=f.warehouse, rules=FORM_RULES, key="seed-unpause-6003", by="Fake Head of GTM", now=_at(day))
    out = _run(f, rules=FORM_RULES, now=_at(day), mode="act")

    assert not [c for c in plan["changes"] if c["target_id"] == "6003"]
    assert _reason(out, "seed-unpause-6003") == "the agent never turns a paused ad set back on: a person does"
    assert "seed-unpause-6003" not in f.google.applied
    assert "6003" not in [s["ad_set_id"] for s in f.google.read_settings([META_ACCOUNT])]


def test_act_refuses_an_approved_removal_once_every_territory_multi_covers_is_full():
    """4g, at write time. The removal was planned and approved while only territory-c was
    full. By the time act runs, territory-a and territory-b are full too: act refuses the
    removal, since the ad set now pauses instead, and the targeting keeps every city."""
    f = _form_fakes(sheet=_sheet(c=C_FULL))
    geo = _removal(_run(f, rules=FORM_RULES))
    approve(warehouse=f.warehouse, rules=FORM_RULES, key=geo["key"], by="Fake Head of GTM", now=NOW)
    f.capacity.rows = _all_full()

    out = _run(f, rules=FORM_RULES, mode="act")

    assert _reason(out, geo["key"]) == "every territory multi covers is full today, so the ad set is paused instead"
    assert geo["key"] not in f.google.applied and len(_form_cities(f)) == 5


# --- every value is a rule setting -----------------------------------------------------------


def _refill():
    """territory-a's campaign was cut $20 on Oct 1; nothing is booked anywhere."""
    f = _fakes(campaigns=REFILL, bookings=())
    _applied(f.warehouse, "2026-10-01", "1001", 100 * M, 80 * M)
    return f


def _outcome(plan):
    """Each planned row in short: (target id, field, new value, status)."""
    return sorted((c["target_id"], c["field"], c["new"], c["status"]) for c in plan["changes"])


def _move_rows(raise_to, status):
    return [("1001", BUDGET, raise_to, status), ("1002", BUDGET, 60 * M, status)]


def _taper(*new):
    return [(c, BUDGET, dollars * M, "proposed") for c, dollars in zip(("1001", "1002", "1003"), new)]


@pytest.mark.parametrize("key, a, b, setup, extra, out_a, out_b", [
    ("season_start", "2026-09-28", "2026-10-02", _refill, {}, _move_rows(100 * M, "proposed"),
     _move_rows(100 * M, "held")),
    ("step_up_cost_per_booked", 300, 250, _fakes, {}, _move_rows(120 * M, "proposed"), _move_rows(120 * M, "held")),
    ("step_up_weeks", 2, 3, lambda: _fakes(bookings=[_booked("territory-a", w, 280.0) for w in LAST_TWO]), {},
     _move_rows(120 * M, "proposed"), _move_rows(120 * M, "held")),
    ("capacity_pause_date", "2026-12-10", "2026-12-15",
     lambda: _fakes(campaigns=QUIET, sheet=_sheet(c={"open_on": date(2026, 12, 14)})), {},
     [("1003", "status", "PAUSED", "proposed")], [(None, None, None, "no_change")]),
    ("capacity_max_age_hours", 48, 24, lambda: _fakes(sheet=_sheet(a={"hours_old": 30})), {},
     _move_rows(120 * M, "proposed"), _move_rows(120 * M, "held")),
    ("taper_start", "2026-12-01", TODAY, _fakes, {}, _move_rows(120 * M, "proposed"), _taper(90, 72, 54)),
    ("taper_daily_pct", 0.10, 0.20, _fakes, {"taper_start": TODAY}, _taper(90, 72, 54), _taper(80, 64, 48)),
    ("territory_freeze_date", "2026-11-09", TODAY, _fakes, {}, _move_rows(120 * M, "proposed"),
     _move_rows(120 * M, "held")),
], ids=lambda v: v if isinstance(v, str) and v in SEASON else None)
def test_every_season_rule_value_comes_from_the_rules_file(key, a, b, setup, extra, out_a, out_b):
    """Changing one value in the rules file, and nothing else, changes what the agent plans.
    No season value lives in code."""
    plans = [_run(setup(), rules=dict(RULES, **extra, **{key: value})) for value in (a, b)]

    assert [_outcome(p) for p in plans] == [out_a, out_b]


def test_every_season_rule_has_a_meaning_and_is_required():
    assert set(SEASON_RULES) == set(SEASON)
    assert all(SEASON_RULES.values())


def test_each_gate_rule_has_a_meaning_and_may_be_left_out():
    """gate_clients and gate_channels (BC-28577) have a one-line meaning each. RULES here
    has neither: they have defaults (the gate-choice test's "default" case)."""
    assert set(GATE_RULES) == {"gate_clients", "gate_channels"}
    assert all(GATE_RULES.values()) and not set(GATE_RULES) & set(RULES)


@pytest.mark.parametrize("rules, name", [
    *[pytest.param({k: v for k, v in RULES.items() if k != key}, key, id=f"missing-{key}")
      for key in SEASON if key != "taper_daily_pct"],
    pytest.param(dict(RULES, capacity_pause_date="December 10"), "capacity_pause_date", id="not-a-date"),
    pytest.param(dict(RULES, season_start=None), "season_start", id="null-date"),
    pytest.param(dict(RULES, step_up_weeks=0), "step_up_weeks", id="zero-weeks"),
    pytest.param(dict(RULES, step_up_weeks=2.5), "step_up_weeks", id="part-weeks"),
    pytest.param(dict(RULES, step_up_cost_per_booked="300"), "step_up_cost_per_booked", id="cost-as-text"),
    pytest.param(dict(RULES, capacity_max_age_hours=-1), "capacity_max_age_hours", id="negative-hours"),
    pytest.param(dict(RULES, taper_daily_pct=10), "taper_daily_pct", id="taper-not-a-fraction"),
    pytest.param(dict(RULES, gate_clients="New"), "gate_clients", id="gate-clients-typo"),
    pytest.param(dict(RULES, gate_clients=None), "gate_clients", id="gate-clients-null"),
    pytest.param(dict(RULES, gate_channels="organic"), "gate_channels", id="gate-channels-unknown"),
    *[pytest.param(dict(RULES, multi_territories=value), "multi_territories", id=f"multi-{name}") for name, value in [
        ("a-list-of-names", ["territory-a", "territory-b"]),
        ("a-key-not-in-a-list", {"territory-a": "910001"}),
        ("no-keys", {"territory-a": []}),
        ("a-key-as-a-number", {"territory-a": [910001]}),
        ("a-blank-key", {"territory-a": [" "]}),
        ("a-territory-twice", {"Territory-A": ["910001"], "territory-a ": ["910002"]}),
        ("a-key-twice", {"territory-a": ["910001"], "territory-b": ["910001"]}),
        ("multi-itself", {"multi": ["910001"]}),
    ]],
])
def test_season_rule_settings_are_checked_before_any_read(rules, name):
    """A missing or malformed season setting stops plan, act and approve before they read
    anything. Only taper_daily_pct may be missing, and only before taper_start; the gate
    rules may be missing, for their defaults, but a value must be one of their choices.
    multi_territories may be missing (4f rule 5), but a value must map each territory, once,
    to its own Meta location keys as text (BC-28579)."""
    f = _fakes()

    with pytest.raises(ValueError, match=name):
        _run(f, rules=rules)
    with pytest.raises(ValueError, match=name):
        _run(f, rules=rules, mode="act")
    with pytest.raises(ValueError, match=name):
        approve(warehouse=f.warehouse, rules=rules, key="f" * 12, by="Fake Head of GTM", now=NOW)
    assert f.warehouse.calls == f.google.calls == f.capacity.calls == []


# --- the real adapters, on fakes -------------------------------------------------------------


def test_real_warehouse_reads_booked_appointments_from_the_territory_weekly_mart(monkeypatch):
    """BC-28577. One read of the territory weekly mart: the run's platform, from the oldest
    gate week on. The connector's date and Decimal values come back as YYYY-MM-DD and
    floats; a null count stays None, which the gate reads as no data. The gate's record of
    applied changes is one ranged read of the change log."""
    from ads_agent import adapters

    for name in adapters.SnowflakeWarehouse.ENV:
        monkeypatch.setenv(name, "fake")
    warehouse, sent = adapters.SnowflakeWarehouse(), []
    replies = iter([[{"platform": "google_ads", "territory": "multi", "week_start": date(2026, 9, 21),
                      "spend": Decimal("840.00"), "booked_paid_new": Decimal(3), "booked_paid_any_client": Decimal(4),
                      "booked_all_new": Decimal(5), "booked_all_any_client": None}], []])
    monkeypatch.setattr(warehouse, "_query",
                        lambda sql, params=None, many=None: sent.append((sql, params)) or next(replies))

    assert warehouse.read_booked_appointments("google_ads", "2026-09-21") == [
        {"platform": "google_ads", "territory": "multi", "week_start": "2026-09-21", "spend": 840.0,
         "booked_paid_new": 3.0, "booked_paid_any_client": 4.0, "booked_all_new": 5.0, "booked_all_any_client": None}]
    assert warehouse.read_change_log_since("2026-09-28") == []
    (sql, params), (log_sql, log_params) = sent
    assert sql == ("select platform, territory, week_start, spend, booked_paid_new, booked_paid_any_client, "
                   "booked_all_new, booked_all_any_client from ANALYTICS.MARTS.MART_ADS_AGENT_TERRITORY_WEEKLY "
                   "where platform = %(p)s and week_start >= %(w)s")
    assert params == {"p": "google_ads", "w": "2026-09-21"}
    assert log_sql.endswith("from ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG where run_date >= %(d)s")
    assert log_params == {"d": "2026-09-28"}


def test_capacity_sheet_reads_serial_dates_in_the_sheets_time_zone(monkeypatch):
    """The real reader against a fake Sheets API. Column names find the columns in any
    order; serial numbers become dates, and times in the spreadsheet's own zone; ISO text
    works too; a cell that is not a date reads as none; a row with no territory is
    skipped. A missing column stops the read."""
    from ads_agent.adapters import CapacitySheet

    monkeypatch.setenv("ADS_AGENT_CAPACITY_SHEET_ID", "fake-sheet")
    monkeypatch.setenv("ADS_AGENT_CAPACITY_RANGE", "Capacity!A:D")
    monkeypatch.setenv("ADS_AGENT_CAPACITY_SERVICE_ACCOUNT_JSON", "{}")
    values = [["Notes", "Territory", "Last Updated", "Next Open Install Date"],
              ["", "territory-a", 46300.75, 46346],  # 18:00 Oct 5, and Nov 20, as Sheets serial numbers
              ["", "  territory-b ", "2026-10-05T09:30:00", "2026-12-14"],
              ["", "territory-c", "", "full"],
              ["a note on a row with no territory"]]
    calls = []

    def sheets(method, url, headers, body=None):
        calls.append((method, url, headers))
        if url.endswith("?fields=properties.timeZone"):
            return {"properties": {"timeZone": "America/Chicago"}}
        return {"values": values}

    rows = CapacitySheet(http=sheets, token=lambda: "fake-token").read_capacity()

    chicago = ZoneInfo("America/Chicago")
    assert rows == [
        {"territory": "territory-a", "updated_at": datetime(2026, 10, 5, 18, 0, tzinfo=chicago),
         "next_open_install_date": date(2026, 11, 20)},
        {"territory": "territory-b", "updated_at": datetime(2026, 10, 5, 9, 30, tzinfo=chicago),
         "next_open_install_date": date(2026, 12, 14)},
        {"territory": "territory-c", "updated_at": None, "next_open_install_date": None},
    ]
    assert {(method, headers["Authorization"]) for method, _, headers in calls} == {("GET", "Bearer fake-token")}
    assert calls[1][1] == ("https://sheets.googleapis.com/v4/spreadsheets/fake-sheet/values/Capacity%21A%3AD"
                           "?valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER")
    values[0] = ["Territory", "Next Open"]
    with pytest.raises(RuntimeError, match="columns not found: Next Open Install Date, Last Updated"):
        CapacitySheet(http=sheets, token=lambda: "fake-token").read_capacity()


def test_a_run_reads_the_capacity_row_age_against_its_own_clock():
    """A capacity row's age is measured from the run's clock, not the machine's, and in UTC
    terms: a row updated at 18:00 Chicago time is 15 hours old at 14:00 UTC the next day."""
    updated = datetime(2026, 10, 5, 18, 0, tzinfo=ZoneInfo("America/Chicago"))  # 23:00 UTC Oct 5
    f = _fakes(sheet=[{"territory": t, "next_open_install_date": date(2026, 11, 20), "updated_at": updated}
                      for t in TERRITORIES])

    fresh = _run(f, rules=dict(RULES, capacity_max_age_hours=16), now=datetime(2026, 10, 6, 14, 0, tzinfo=timezone.utc))
    stale = _run(_fakes(sheet=f.capacity.rows), rules=dict(RULES, capacity_max_age_hours=14),
                 now=datetime(2026, 10, 6, 14, 0, tzinfo=timezone.utc))

    assert _check(_move(fresh)[1], "capacity_open")["passed"]
    assert _check(_move(stale)[1], "capacity_open")["detail"] == (
        "territory-a's capacity row was last updated 15 hours ago, over the 14 hour limit")
