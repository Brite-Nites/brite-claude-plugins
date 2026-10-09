"""The ads agent's season rules and step-up gate (BC-28220 with its 2026-10-06 amendment;
spec BC-28205, workstream 4).

The same seam as test_ads_agent_run.py: fixture snapshots, settings, capacity sheet rows,
booked appointments and rules in; the plan and the fakes' recorded calls out. Each rule
test names the brief item it covers in its docstring: 4a step-up gate, 4b capacity pause,
4c stale capacity row, 4d taper, 4e territory freeze. The real capacity sheet reader is
checked against a fake Sheets API at the end; nothing here calls Google or Snowflake.

Every id, name, number and date here is synthetic. This repo is public: no real account
ids, budgets, ceilings, results, sheet ids or step-up cost, ever.
"""

from __future__ import annotations

import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent.fakes import FakeCapacity, FakeGoogleAds, FakeMetaAds, FakeSlack, FakeWarehouse  # noqa: E402
from ads_agent.run import SEASON_RULES, approve, run  # noqa: E402

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


def _booked(territory, week, per_booked, platform="google_ads"):
    """One week of booked appointments in a territory, at `per_booked` dollars each."""
    return {"platform": platform, "territory": territory, "week_start": week, "spend": per_booked * 3,
            "booked_appointments": 3}


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
    """4a, and the gap. No booked-appointment data exists yet (BC-28562), so a move that
    lifts territory-a past its $100 launch budget is held, both halves, and act writes
    nothing. The notes say why."""
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
     "the step-up gate is met: cost per booked appointment $280.00 the week of 2026-09-28, "
     "$280.00 the week of 2026-09-21, against $300.00"),
    ([_booked("territory-a", w, 300.0) for w in LAST_TWO], "proposed", "the step-up gate is met"),
    ([_booked("territory-a", "2026-09-28", 280.0), _booked("territory-a", "2026-09-21", 310.0)], "held",
     "$310.00 the week of 2026-09-21, against $300.00"),
    ([_booked("territory-a", "2026-09-28", 280.0)], "held",
     "no booked-appointment data for territory-a the week of 2026-09-21"),
    ([_booked("territory-a", "2026-09-28", 280.0), _booked("territory-a", "2026-10-05", 280.0)], "held",
     "no booked-appointment data for territory-a the week of 2026-09-21"),
    ([dict(_booked("territory-a", w, 280.0), booked_appointments=0) for w in LAST_TWO], "held",
     "none booked the week of 2026-09-28"),
    ([_booked("territory-a", w, 280.0, platform="meta_ads") for w in LAST_TWO], "held",
     "no booked-appointment data for territory-a"),
    ([_booked("territory-b", w, 280.0) for w in LAST_TWO], "held", "no booked-appointment data for territory-a"),
], ids=["met", "at-the-cost", "one-week-over", "one-week-missing", "this-week-is-not-full", "none-booked",
        "other-platform", "other-territory"])
def test_step_up_gate_needs_each_of_the_last_full_weeks_at_or_under_the_cost(bookings, status, detail):
    """4a. Past its launch budget, territory-a needs step_up_weeks (2) full weeks, Monday to
    Sunday before this week, each at or under step_up_cost_per_booked ($300 here). The
    week in progress, another platform's bookings and the cut's territory do not count."""
    plan = _run(_fakes(bookings=bookings))

    cut, up = _move(plan)
    assert cut["status"] == up["status"] == status
    assert detail in _check(up, "step_up_gate")["detail"]


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
])
def test_season_rule_settings_are_checked_before_any_read(rules, name):
    """A missing or malformed season setting stops plan, act and approve before they read
    anything. Only taper_daily_pct may be missing, and only before taper_start."""
    f = _fakes()

    with pytest.raises(ValueError, match=name):
        _run(f, rules=rules)
    with pytest.raises(ValueError, match=name):
        _run(f, rules=rules, mode="act")
    with pytest.raises(ValueError, match=name):
        approve(warehouse=f.warehouse, rules=rules, key="f" * 12, by="Fake Head of GTM", now=NOW)
    assert f.warehouse.calls == f.google.calls == f.capacity.calls == []


# --- the real adapters, on fakes -------------------------------------------------------------


def test_real_warehouse_has_no_booked_appointments_yet(monkeypatch):
    """The gap (BC-28562): no table holds booked appointments per territory, so the real
    read returns nothing and sends no query. The gate's record of applied changes is one
    ranged read of the change log."""
    from ads_agent import adapters

    for name in adapters.SnowflakeWarehouse.ENV:
        monkeypatch.setenv(name, "fake")
    warehouse, sent = adapters.SnowflakeWarehouse(), []
    monkeypatch.setattr(warehouse, "_query", lambda sql, params=None, many=None: sent.append((sql, params)) or [])

    assert warehouse.read_booked_appointments("google_ads", "2026-09-21") == [] and sent == []
    assert warehouse.read_change_log_since("2026-09-28") == []
    [(sql, params)] = sent
    assert sql.endswith("from ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG where run_date >= %(d)s")
    assert params == {"d": "2026-09-28"}


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
