"""The ads-agent run on Meta (BC-28218 with its 2026-10-06 amendment; spec BC-28205).

The same seam as test_ads_agent_run.py: fixture snapshots, settings and rules in, the plan
and the fakes' recorded calls out. FakeMetaAds stands in for the Graph API. Each run test
names the brief item it covers in its docstring: 3 (a rule Meta shares with Google) or
4a-4f (Meta's own rules). The adapter tests at the end check MetaAds' requests against a
fake Graph API; nothing here calls Meta.

Every id, name and number here is synthetic. This repo is public: no real account ids,
page ids, pixel ids, budgets, ceilings or results, ever.
"""

from __future__ import annotations

import copy
import json
import sys
import urllib.parse
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent.fakes import FakeCapacity, FakeGoogleAds, FakeMetaAds, FakeSlack, FakeWarehouse  # noqa: E402
from ads_agent.run import approve, run  # noqa: E402

NOW = datetime(2026, 10, 6, 14, 0, tzinfo=timezone.utc)      # 08:00 Oct 6 in Denver
EVENING = datetime(2026, 10, 7, 0, 30, tzinfo=timezone.utc)  # 18:30 Oct 6 in Denver
TODAY, YESTERDAY = "2026-10-06", "2026-10-05"
START = "2026-09-22"  # a path test start two weeks before TODAY: the path test is due today
ACCOUNT = "0000000002"
BUDGET, GOAL = "daily_budget_micros", "optimization_goal"

# Weeks 1-2 rules plus Meta's own. The time zone is an example. The season rules (BC-28220,
# tested in test_ads_agent_season.py) are mid-season: every territory has room and meets
# the step-up gate.
RULES = {"weekly_ceiling": 2000, "max_move_pct": 0.25, "min_conversions": 3,
         "weeks_1_2": True, "emergency_stop": False,
         "target_cpl": 50, "kill_multiple": 3, "compare_multiple": 5,
         "timezone": "America/Denver", "max_lead_count_gap": 0.20,
         "season_start": "2026-09-28", "step_up_cost_per_booked": 300, "step_up_weeks": 2,
         "capacity_pause_date": "2026-12-10", "taper_start": "2026-12-01", "taper_daily_pct": 0.10,
         "territory_freeze_date": "2026-11-09", "capacity_max_age_hours": 48,
         "meta_path_test_start": None, "retire_after_days": 7, "retire_spend_floor": 5,
         "meta_budget_limited_spend_pct": 0.95}
AUTONOMOUS = dict(RULES, weeks_1_2=False)  # from about week 3

# Each ad set's territory, as the ad results snapshot names it.
TERRITORY = {"6001": "territory-a", "6002": "territory-b", "6003": "territory-c"}
BOOKED = [{"platform": p, "territory": t, "week_start": week, "spend": 840.0, "booked_appointments": 3}
          for p in ("google_ads", "meta_ads") for t in TERRITORY.values() for week in ("2026-09-21", "2026-09-28")]
OPEN = [{"territory": t, "next_open_install_date": date(2026, 11, 20), "updated_at": NOW - timedelta(hours=2)}
        for t in TERRITORY.values()]

SAFE = {"geo_locations": {"cities": [{"key": "900001", "name": "Fake City", "radius": 15, "distance_unit": "mile"}]}}
DESTINATION = {"site": "WEBSITE", "instant_form": "ON_AD"}


def _ad_set(ad_set_id, budget, path="site", **edit):
    """One ad set as FakeMetaAds serves it: its own daily budget, optimised for leads,
    Housing-safe targeting."""
    return {"account_id": ACCOUNT, "campaign_id": "5001" if path == "site" else "5002",
            "campaign_name": f"Fake {path} campaign", "ad_set_id": ad_set_id, "ad_set_name": f"Fake ad set {ad_set_id}",
            "daily_budget_micros": budget, "budget_level": "ad_set", "budget_limited": False,
            "budget_shared": False, "brand": False, "status": "ENABLED", "optimization_goal": "leads",
            "destination_type": DESTINATION[path], "targeting": copy.deepcopy(SAFE), **edit}


# Two site ad sets (one per territory) and the one instant-form ad set.
AD_SETS = [_ad_set("6001", 100_000_000), _ad_set("6002", 80_000_000), _ad_set("6003", 60_000_000, path="instant_form")]


def _spent(holder_id, dollars, level="ad_set"):
    """One row of yesterday's spend, as read_spend serves it."""
    return {"account_id": ACCOUNT, "level": level, "id": holder_id, "spend": dollars}


FULL = [_spent("6001", 100.0), _spent("6002", 80.0), _spent("6003", 60.0)]  # each spent its whole budget


def _ad(ad_set_id, ad_id, status="ENABLED", created="2026-09-01T09:00:00-06:00"):
    return {"account_id": ACCOUNT, "campaign_id": "5001", "ad_group_id": ad_set_id, "ad_id": ad_id,
            "ad_name": f"Fake ad {ad_id}", "status": status, "created_time": created}


def _result(ad_set_id, ad_id, spend, leads, booked=None):
    """One ad snapshot row. booked_appointments is there only when a test gives it: the
    mart has no such column yet."""
    row = {"platform": "meta_ads", "account_id": ACCOUNT, "campaign_id": "5001", "ad_group_id": ad_set_id,
           "ad_id": ad_id, "territory": TERRITORY.get(ad_set_id, "territory-a"), "spend": spend, "conversions": leads}
    if booked is not None:
        row["booked_appointments"] = booked
    return row


# One ad per ad set. Cost per lead: 6001 $50, 6002 $200 (the worst), 6003 $100.
ADS = [_ad("6001", "7001"), _ad("6002", "7002"), _ad("6003", "7003")]
RESULTS = [_result("6001", "7001", 500.0, 10), _result("6002", "7002", 800.0, 4), _result("6003", "7003", 300.0, 3)]


def _lead_counts(platform_leads, britebase_leads, gap_pct, platform="meta_ads"):
    return {"platform": platform, "lead_date": YESTERDAY, "platform_leads": platform_leads,
            "britebase_leads": britebase_leads, "gap_pct": gap_pct, "platform_spend": 500.0}


AGREED = [_lead_counts(20, 20, 0.0, platform=p) for p in ("google_ads", "meta_ads")]


def _creative(ad_id, ai_edited=False, approved_by=None, platform="meta_ads"):
    """One creative-inputs row, cut to the columns the agent reads."""
    return {"platform": platform, "ad_account_id": ACCOUNT, "ad_id": ad_id, "ai_edited": ai_edited,
            "approved_by": approved_by}


def _fakes(ad_sets=AD_SETS, ads=ADS, results=RESULTS, spend=FULL, lead_counts=AGREED, creative=()):
    return (FakeWarehouse([], results, lead_counts, creative, bookings=BOOKED), FakeMetaAds(ad_sets, ads, spend=spend),
            FakeSlack())


def _run(warehouse, meta, slack, rules=RULES, now=NOW, **kw):
    return run(warehouse=warehouse, adapter=meta, capacity=FakeCapacity(OPEN), slack=slack, rules=rules, now=now,
               mode="propose", **kw)


def _act(warehouse, meta, slack, rules=AUTONOMOUS, now=NOW, **kw):
    return run(warehouse=warehouse, adapter=meta, capacity=FakeCapacity(OPEN), slack=slack, rules=rules, now=now,
               mode="act", **kw)


def _approve(warehouse, key, rules=RULES, now=NOW):
    return approve(warehouse=warehouse, rules=rules, key=key, by="Fake Head of GTM", now=now)


def _moves(out):
    """The plan's budget rows by ad set: {target id: (old, new)}."""
    return {c["target_id"]: (c["old"], c["new"]) for c in out["changes"] if c["field"] == BUDGET}


def _keys(out):
    """(cut key, raise key) of the day's budget move."""
    move = sorted((c for c in out["changes"] if c["field"] == BUDGET), key=lambda c: c["new"] - c["old"])
    return move[0]["key"], move[1]["key"]


def _seed(warehouse, **edit):
    """Log a proposed Meta plan row for today that the planner itself would never make."""
    row = {"run_date": TODAY, "mode": "propose", "platform": "meta_ads", "status": "proposed",
           "account_id": ACCOUNT, "target_name": "Fake seeded change", "reason": "seeded by the test",
           "checks": [], **edit}
    warehouse.write_change_log([row])


def _reason(out, key):
    return next(r["reason"] for r in out["results"] if r["key"].startswith(key + ":"))


# --- propose mode, re-runs and rule settings -----------------------------------------------


def test_propose_mode_makes_no_meta_write():
    """Propose never writes to Meta, even with every change approved and weeks 1-2 over."""
    warehouse, meta, slack = _fakes()

    plan = _run(warehouse, meta, slack, rules=AUTONOMOUS)
    for c in plan["changes"]:
        _approve(warehouse, c["key"])
    _run(warehouse, meta, slack, rules=AUTONOMOUS)

    assert [(c["target_type"], c["status"]) for c in plan["changes"]] == [("ad_set", "proposed")] * 2
    assert meta.write_calls == []
    assert {c[0] for c in meta.calls} == {"read_settings", "read_ads", "read_spend"}


def test_a_rerun_applies_nothing_twice():
    """The raise fails once; the re-run retries only the raise and plans nothing new, and a
    third run writes nothing. The cut is written once."""
    warehouse, meta, slack = _fakes()
    meta.fail_on.add("6001")

    first = _act(warehouse, meta, slack)
    meta.fail_on.clear()
    second = _act(warehouse, meta, slack)
    third = _act(warehouse, meta, slack)

    cut, raise_ = _keys(first)
    assert meta.write_calls == [("apply", cut), ("apply", raise_), ("apply", raise_)]
    assert meta.applied == [cut, raise_]
    assert second["changes"] == third["changes"] == third["results"] == []
    budgets = {s["ad_set_id"]: s[BUDGET] for s in meta.read_settings([ACCOUNT])}
    assert budgets == {"6001": 120_000_000, "6002": 60_000_000, "6003": 60_000_000}


@pytest.mark.parametrize("rules, name", [
    ({k: v for k, v in RULES.items() if k != "retire_after_days"}, "retire_after_days"),
    ({k: v for k, v in RULES.items() if k != "meta_budget_limited_spend_pct"}, "meta_budget_limited_spend_pct"),
    (dict(RULES, meta_path_test_start="22 September"), "meta_path_test_start"),
], ids=["missing-retire", "missing-limited-pct", "bad-start-date"])
def test_a_meta_run_needs_its_own_rule_settings_before_any_read(rules, name):
    warehouse, meta, slack = _fakes()

    with pytest.raises(ValueError, match=name):
        _run(warehouse, meta, slack, rules=rules)
    assert warehouse.calls == [] and meta.calls == []


def test_an_unknown_platform_is_refused_before_any_read():
    class FakeOtherAds(FakeMetaAds):
        platform = "other_ads"

    warehouse, slack = FakeWarehouse([]), FakeSlack()
    other = FakeOtherAds(AD_SETS)

    with pytest.raises(ValueError, match="platform must be one of google_ads, meta_ads"):
        _run(warehouse, other, slack)
    assert warehouse.calls == [] and other.calls == []


# --- 3: every existing rule applies to Meta unchanged --------------------------------------


def test_meta_act_rechecks_the_hard_limits_before_each_write():
    """3, the hard limits. A move planned under a 40% limit is refused when act runs under
    25%. A raise that is not half of a planned move, a budget held by the campaign and a
    brand campaign's ad set are refused too. Nothing is written."""
    ad_sets = AD_SETS + [_ad_set("6004", 20_000_000, budget_level="campaign", budget_shared=True),
                         _ad_set("6005", 20_000_000, brand=True)]
    warehouse, meta, slack = _fakes(ad_sets=ad_sets)
    plan = _run(warehouse, meta, slack, rules=dict(RULES, max_move_pct=0.40, weekly_ceiling=5000))
    _seed(warehouse, key="seed-lone-raise-0001", target_type="ad_set", target_id="6003",
          field=BUDGET, old=60_000_000, new=70_000_000)
    _seed(warehouse, key="seed-campaign-budget-0001", target_type="ad_set", target_id="6004",
          field=BUDGET, old=20_000_000, new=15_000_000)
    _seed(warehouse, key="seed-brand-0001", target_type="ad_set", target_id="6005",
          field=BUDGET, old=20_000_000, new=15_000_000)

    out = _act(warehouse, meta, slack)

    assert _moves(plan) == {"6002": (80_000_000, 48_000_000), "6001": (100_000_000, 132_000_000)}
    assert meta.write_calls == []
    for key in _keys(plan):
        assert "(limit 25%)" in _reason(out, key)
    assert "only written as half of a planned move" in _reason(out, "seed-lone-raise-0001")
    assert "shared budget" in _reason(out, "seed-campaign-budget-0001")
    assert "brand" in _reason(out, "seed-brand-0001")


def test_meta_emergency_stop_blocks_every_write():
    """3, the emergency stop. With the stop on, act writes nothing, approved or not."""
    warehouse, meta, slack = _fakes()

    first = _act(warehouse, meta, slack, rules=dict(AUTONOMOUS, emergency_stop=True))
    for c in first["changes"]:
        _approve(warehouse, c["key"])
    second = _act(warehouse, meta, slack, rules=dict(RULES, emergency_stop=True))

    assert meta.write_calls == []
    assert first["emergency_stop"] and second["emergency_stop"]
    assert first["results"] == second["results"] == []
    assert "Emergency stop is on" in slack.posts[0]


def test_meta_data_freeze_plans_approves_and_writes_nothing():
    """3, the data freeze. Planned while the counts agreed; then Meta counted 20 leads
    yesterday and BriteBase 10. Google's agreeing counts do not unfreeze Meta."""
    warehouse, meta, slack = _fakes()
    cut, _ = _keys(_run(warehouse, meta, slack))
    warehouse.lead_reconciliation = [_lead_counts(20, 20, 0.0, platform="google_ads"), _lead_counts(20, 10, 0.5)]

    with pytest.raises(ValueError, match="meta_ads is frozen today"):
        _approve(warehouse, cut)
    out = _act(warehouse, meta, slack)

    assert out["frozen"]["platform"] == "meta_ads" and "a 50.0% gap" in out["frozen"]["reason"]
    assert out["changes"] == out["results"] == []
    assert meta.write_calls == []
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed", "frozen"]


def test_meta_weeks_1_2_apply_only_approved_changes_one_per_day():
    """3, weeks 1-2. Nothing applies until approved; then one change a day on Meta. The
    move is one change, approved through its raise's key."""
    ads = ADS + [_ad("6003", "7004")]
    results = RESULTS + [_result("6003", "7004", 150.0, 0)]  # zero leads at 3x target: the kill rule
    warehouse, meta, slack = _fakes(ads=ads, results=results)
    plan = _run(warehouse, meta, slack)
    cut, raise_ = _keys(plan)
    pause = next(c["key"] for c in plan["changes"] if c["target_type"] == "ad")

    before = _act(warehouse, meta, slack, rules=RULES)
    _approve(warehouse, raise_)
    _approve(warehouse, pause)
    after = _act(warehouse, meta, slack, rules=RULES)

    assert sorted(before["waiting"]) == sorted([cut, raise_, pause]) and before["results"] == []
    assert meta.applied == [cut, raise_]
    assert "one change per platform per day" in _reason(after, pause)


def test_meta_budget_move_is_one_linked_pair_of_ad_sets_cut_first():
    """3, the linked budget move. 6002 has the worst cost per lead ($200) and 6001 the best
    of the budget-limited ($50): 25% of the smaller budget ($80) is $20. The raise is keyed
    <cut key>:pair and written after its cut."""
    warehouse, meta, slack = _fakes()

    out = _act(warehouse, meta, slack)

    cut, raise_ = _keys(out)
    assert _moves(out) == {"6002": (80_000_000, 60_000_000), "6001": (100_000_000, 120_000_000)}
    assert {c["target_type"] for c in out["changes"]} == {"ad_set"}
    assert raise_ == f"{cut}:pair"
    assert meta.applied == [cut, raise_]


def test_meta_kill_rule_turns_off_ads_that_spend_without_leads():
    """3, the kill rule, with the ad set as the ad group. No leads turns an ad off at 3x the
    $50 target ($150), not a cent before. Two ads in one ad set compare on cost per lead
    once each has spent 5x ($250); the worse turns off."""
    ads = [_ad("6001", "7101"), _ad("6001", "7102"), _ad("6002", "7201"), _ad("6002", "7202")]
    results = [_result("6001", "7101", 149.99, 0), _result("6001", "7102", 150.0, 0),
               _result("6002", "7201", 300.0, 2), _result("6002", "7202", 260.0, 4)]
    warehouse, meta, slack = _fakes(ads=ads, results=results)

    out = _act(warehouse, meta, slack)

    pauses = {c["target_id"]: c for c in out["changes"] if c["target_type"] == "ad"}
    assert set(pauses) == {"6001~7102", "6002~7201"}
    assert "zero leads" in pauses["6001~7102"]["reason"]
    assert "Fake ad 7202" in pauses["6002~7201"]["reason"]
    assert sorted(meta.applied) == sorted(c["key"] for c in pauses.values())


def test_a_meta_cut_cannot_pay_for_a_google_raise():
    """3, cross-platform moves are refused. A Meta cut is seeded with a Google raise keyed
    as its pair. The Google run refuses the raise: its cut is not in Google's plan. The
    Meta run writes only the cut, which only lowers spend."""
    google = FakeGoogleAds([{"account_id": "0000000001", "campaign_id": "1001", "campaign_name": "Fake Google A",
                             "daily_budget_micros": 100_000_000, "budget_limited": True,
                             "budget_shared": False, "brand": False}])
    warehouse, meta, slack = _fakes()
    _seed(warehouse, key="seed-xcut-0002", target_type="ad_set", target_id="6002",
          field=BUDGET, old=80_000_000, new=60_000_000)
    _seed(warehouse, key="seed-xcut-0002:pair", platform="google_ads", account_id="0000000001",
          target_type="campaign", target_id="1001", field=BUDGET, old=100_000_000, new=120_000_000)

    _act(warehouse, meta, slack)
    out = run(warehouse=warehouse, adapter=google, capacity=FakeCapacity(OPEN), slack=slack, rules=AUTONOMOUS,
              now=NOW, mode="act")

    assert google.write_calls == []
    assert "only written as half of a planned move" in _reason(out, "seed-xcut-0002:pair")
    assert meta.applied == ["seed-xcut-0002"]


# --- 4a: Housing-safe targeting ------------------------------------------------------------


def test_targeting_that_breaks_the_housing_rules_is_held_and_never_written():
    """4a. Ad set 6001 targets a 10-mile radius, a 20 km (12.4-mile) radius, a ZIP code,
    ages 25-55, one gender and a lookalike audience: the plan holds a flag row naming each
    break, and holds the raise into 6001. The cut goes ahead: it only lowers spend. 6003's
    25 km radius (15.5 miles) is safe. A targeting write is refused even when approved."""
    bad = {"geo_locations": {"cities": [{"key": "900001", "name": "Fake City", "radius": 10, "distance_unit": "mile"}],
                             "custom_locations": [{"name": "Fake depot", "radius": 20, "distance_unit": "kilometer"}],
                             "zips": [{"key": "US:00000"}]},
           "age_min": 25, "age_max": 55, "genders": [1],
           "custom_audiences": [{"id": "800001", "name": "Fake lookalike", "subtype": "LOOKALIKE"}]}
    km = {"geo_locations": {"custom_locations": [{"name": "Fake office", "radius": 25, "distance_unit": "kilometer"}]}}
    ad_sets = [_ad_set("6001", 100_000_000, targeting=bad), _ad_set("6002", 80_000_000),
               _ad_set("6003", 60_000_000, path="instant_form", targeting=km)]
    warehouse, meta, slack = _fakes(ad_sets=ad_sets)

    plan = _run(warehouse, meta, slack)
    _seed(warehouse, key="seed-targeting-0001", target_type="ad_set", target_id="6002",
          field="targeting", old=None, new="a fake targeting spec")
    _approve(warehouse, "seed-targeting-0001")
    out = _act(warehouse, meta, slack)

    rows = {(c["target_id"], c["field"]): c for c in plan["changes"]}
    flag, raise_, cut = rows[("6001", "targeting")], rows[("6001", BUDGET)], rows[("6002", BUDGET)]
    [failed] = [k for k in flag["checks"] if not k["passed"]]
    assert flag["status"] == "held" and failed["name"] == "housing_safe"
    for part in ("Fake City has a 10.0 mile radius, under 15 miles", "Fake depot has a 12.4 mile radius",
                 "ZIP codes in geo_locations",
                 "an age limit (25-55)", "a gender limit", "lookalike audience Fake lookalike"):
        assert part in failed["detail"]
    assert raise_["status"] == "held"
    assert [k["name"] for k in raise_["checks"] if not k["passed"]] == ["housing_safe"]
    assert cut["status"] == "proposed"
    assert not [c for c in plan["changes"] if c["target_id"] == "6003"]
    assert "HELD Fake ad set 6001: targeting is not Housing-safe" in slack.posts[0]
    assert "targeting is not an ad setting the agent may write" in _reason(out, "seed-targeting-0001")
    assert meta.write_calls == [("apply", cut["key"])]


def test_a_custom_audience_of_unknown_type_is_treated_as_a_lookalike():
    """4a. The adapter could not read an audience's type, so it may be a lookalike: held."""
    unknown = dict(SAFE, custom_audiences=[{"id": "800002", "name": "Fake shared audience", "subtype": None}])
    plan = _run(*_fakes(ad_sets=[_ad_set("6001", 100_000_000, targeting=unknown)] + AD_SETS[1:]))

    flag = next(c for c in plan["changes"] if c["field"] == "targeting")
    assert flag["status"] == "held" and "audience of unknown type Fake shared audience" in flag["old"]


# --- 4b: two paths --------------------------------------------------------------------------


def test_each_ad_set_is_tagged_with_its_path_from_its_settings():
    """4b. The path comes from the ad set's destination, not its name. A lead form on the ad
    (ON_AD) is the instant-form path; a website destination is the site path. An ad set
    with neither is untagged and takes part in no path rule."""
    ad_sets = AD_SETS + [_ad_set("6004", 10_000_000, ad_set_name="Fake Instant Form (name only)"),
                         _ad_set("6005", 10_000_000, destination_type="MESSENGER")]

    out = _run(*_fakes(ad_sets=ad_sets))

    assert out["paths"] == {"site": ["6001", "6002", "6004"], "instant_form": ["6003"], "untagged": ["6005"]}


# --- 4c: the 50/50 path test ----------------------------------------------------------------


def test_the_path_test_moves_budget_toward_the_lower_cost_per_booked_appointment():
    """4c. Two weeks after the start, one linked move toward the cheaper path. Site spent
    $1,300 for 3 booked appointments ($433.33 each), the instant form $300 for 6 ($50). The
    cut comes from the site ad set with the highest cost per booked appointment (6002,
    $800); the raise goes to the instant-form ad set. 25% of the smaller budget ($60) is $15."""
    results = [_result("6001", "7001", 500.0, 10, booked=2), _result("6002", "7002", 800.0, 4, booked=1),
               _result("6003", "7003", 300.0, 3, booked=6)]
    warehouse, meta, slack = _fakes(results=results)

    out = _run(warehouse, meta, slack, rules=dict(RULES, meta_path_test_start=START))

    cut, raise_ = _keys(out)
    assert _moves(out) == {"6002": (80_000_000, 65_000_000), "6003": (60_000_000, 75_000_000)}
    assert raise_ == f"{cut}:pair"
    raise_row = next(c for c in out["changes"] if c["key"] == raise_)
    assert "path test: instant_form $50.00 per booked appointment against $433.33 for site" in raise_row["reason"]
    assert all(c["status"] == "proposed" for c in out["changes"] if c["field"] == BUDGET)


def test_the_path_test_without_booked_appointments_proposes_no_budget_move_and_says_why():
    """4c. The snapshot has no booked_appointments column yet (a warehouse follow-up). The
    path test proposes nothing, no other budget move takes its place, and the run says why."""
    out = _run(*_fakes(), rules=dict(RULES, meta_path_test_start=START))

    assert [c["status"] for c in out["changes"]] == ["no_change"]
    assert "the ad results snapshot has no booked_appointments column" in out["changes"][0]["reason"]
    assert any("path test cannot compare cost per booked appointment" in n for n in out["notes"])


def test_budget_moves_stay_inside_one_path_while_the_path_test_runs():
    """4c, with the steward's 2026-10-09 ruling. One day before the two weeks are up, a move
    between the paths would break the 50/50 split, so the move stays inside the site path.
    With no test set, the same results move money from the instant form to the site."""
    # Cost per lead: 6001 $50, 6002 $100, 6003 (the instant form) $200, the worst.
    results = [_result("6001", "7001", 500.0, 10), _result("6002", "7002", 400.0, 4), _result("6003", "7003", 600.0, 3)]

    running = _run(*_fakes(results=results), rules=dict(RULES, meta_path_test_start="2026-09-23"))
    no_test = _run(*_fakes(results=results))

    assert _moves(running) == {"6002": (80_000_000, 60_000_000), "6001": (100_000_000, 120_000_000)}
    assert _moves(no_test) == {"6003": (60_000_000, 45_000_000), "6001": (100_000_000, 115_000_000)}


# --- 4d: the switch to optimising for booked appointments -----------------------------------


def test_the_switch_to_booked_appointments_always_waits_for_approval():
    """4d. Ad set 6003 has 4 booked appointments, at least min_conversions (3): the plan
    proposes switching it from leads to booked appointments. With weeks 1-2 over, act
    applies the budget move at once but the switch only after the Head of GTM approves it."""
    results = [_result("6001", "7001", 500.0, 10, booked=0), _result("6002", "7002", 800.0, 4, booked=0),
               _result("6003", "7003", 300.0, 3, booked=4)]
    warehouse, meta, slack = _fakes(results=results)

    first = _act(warehouse, meta, slack)
    switch = next(c for c in first["changes"] if c["field"] == GOAL)
    _approve(warehouse, switch["key"])
    second = _act(warehouse, meta, slack)

    assert (switch["target_id"], switch["old"], switch["new"], switch["status"]) == (
        "6003", "leads", "booked_appointments", "proposed")
    assert first["waiting"] == [switch["key"]]
    assert meta.applied == [*_keys(first), switch["key"]]
    assert [r["key"] for r in second["results"]] == [f"{switch['key']}:applied"]
    assert next(s for s in meta.read_settings([ACCOUNT]) if s["ad_set_id"] == "6003")[GOAL] == "booked_appointments"


# --- 4e: ads from the approved shared library only ------------------------------------------


def test_an_ad_turns_on_only_from_the_approved_shared_library():
    """4e. Four paused ads are planned on. 7301 has no creative-inputs row on Meta (only a
    Google one), and 7302's AI-edited photo has no approver: both refused. 7303 (AI-edited,
    approved) and 7304 (not AI-edited) are in the library and turn on."""
    ads = ADS + [_ad("6001", ad_id, status="PAUSED") for ad_id in ("7301", "7302", "7303", "7304")]
    creative = [_creative("7301", platform="google_ads"), _creative("7302", ai_edited=True),
                _creative("7303", ai_edited=True, approved_by="Fake Reviewer"), _creative("7304")]
    warehouse, meta, slack = _fakes(ads=ads, creative=creative)
    for ad_id in ("7301", "7302", "7303", "7304"):
        _seed(warehouse, key=f"seed-on-{ad_id}", target_type="ad", target_id=f"6001~{ad_id}",
              field="status", old="PAUSED", new="ENABLED")

    out = _act(warehouse, meta, slack)

    assert sorted(meta.applied) == ["seed-on-7303", "seed-on-7304"]
    assert "not from the approved shared library" in _reason(out, "seed-on-7301")
    assert "AI-edited photo has no approved_by" in _reason(out, "seed-on-7302")
    assert ("read_creative_inputs", "meta_ads") in warehouse.calls


# --- 4f: retire an ad with near-zero spend --------------------------------------------------


def test_an_ad_with_near_zero_spend_is_retired_after_7_days():
    """4f. The floor is $5 and the age 7 days, counted in the rules' time zone. 7401 is 7
    days old in Denver, though 6 by its UTC date, and has no snapshot row: retired. 7402 is
    6 days old: kept. 7403 spent exactly the floor: retired. 7404 spent a cent more: kept.
    7405 is already paused."""
    ads = ADS + [_ad("6001", "7401", created="2026-09-30T03:00:00+00:00"),
                 _ad("6001", "7402", created="2026-09-30T09:00:00-06:00"),
                 _ad("6001", "7403", created="2026-09-26T09:00:00-06:00"),
                 _ad("6001", "7404", created="2026-09-26T09:00:00-06:00"),
                 _ad("6001", "7405", status="PAUSED")]
    results = RESULTS + [_result("6001", "7403", 5.0, 0), _result("6001", "7404", 5.01, 0)]
    warehouse, meta, slack = _fakes(ads=ads, results=results)

    out = _act(warehouse, meta, slack)

    retired = {c["target_id"]: c for c in out["changes"] if c["reason"].startswith("retired")}
    assert set(retired) == {"6001~7401", "6001~7403"}
    assert all((c["old"], c["new"]) == ("ENABLED", "PAUSED") for c in retired.values())
    assert "after 7 days live" in retired["6001~7401"]["reason"]
    assert {c["key"] for c in retired.values()} <= set(meta.applied)


# --- limited by budget, derived from yesterday's spend (steward ruling 2026-10-09) ----------


@pytest.mark.parametrize("spent, limited", [(76.0, True), (75.99, False), (None, False)],
                         ids=["at-95-percent", "under-95-percent", "no-spend-row"])
def test_an_ad_set_is_limited_by_budget_only_at_95_percent_of_its_budget_spent(spent, limited):
    """6001 has the best cost per lead and an $80 budget. It receives the move only if it
    spent at least 95% of that ($76) yesterday. The others spent half their budgets, so no
    other ad set can receive it. Missing spend is not limited."""
    ad_sets = [_ad_set("6001", 80_000_000), _ad_set("6002", 100_000_000), _ad_set("6003", 60_000_000, path="instant_form")]
    spend = [_spent("6002", 50.0), _spent("6003", 30.0)] + ([] if spent is None else [_spent("6001", spent)])

    out = _run(*_fakes(ad_sets=ad_sets, spend=spend))

    assert _moves(out) == ({"6002": (100_000_000, 80_000_000), "6001": (80_000_000, 100_000_000)} if limited else {})
    if not limited:
        assert "no judged ad set is limited by budget" in out["changes"][0]["reason"]


def test_a_failed_spend_read_limits_nothing_and_the_notes_say_so():
    """The insights read fails: no ad set counts as limited, so no raise, and the run's notes
    name the failure. Yesterday is the day before the run date in Denver, not in UTC."""
    warehouse, meta, slack = _fakes()
    meta.spend_fails = True

    out = _run(warehouse, meta, slack, now=EVENING)

    assert out["run_date"] == TODAY
    assert ("read_spend", (ACCOUNT,), YESTERDAY) in meta.calls
    assert [c["status"] for c in out["changes"]] == ["no_change"]
    assert any("yesterday's spend could not be read" in n for n in out["notes"])


# --- the CLI and the real adapters, on fakes -----------------------------------------------


def test_the_cli_runs_the_platform_it_is_given(monkeypatch, tmp_path):
    from ads_agent import __main__ as cli
    from ads_agent import adapters

    monkeypatch.setenv("META_ADS_SYSTEM_USER_TOKEN", "fake-token")
    seen = []
    monkeypatch.setattr(cli, "SnowflakeWarehouse", lambda: "a fake warehouse")
    monkeypatch.setattr(cli, "CapacitySheet", lambda: "a fake capacity sheet")
    monkeypatch.setattr(cli, "run", lambda **kw: seen.append(kw) or {"changes": []})
    rules = tmp_path / "rules.json"
    rules.write_text(json.dumps(RULES))

    assert cli.main(["propose", "--platform", "meta_ads", "--rules", str(rules), "--emit"]) == 0
    with pytest.raises(SystemExit) as no_platform:
        cli.main(["act", "--rules", str(rules)])

    [kw] = seen
    assert isinstance(kw["adapter"], adapters.MetaAds) and kw["mode"] == "propose" and kw["emit"]
    assert kw["capacity"] == "a fake capacity sheet"
    assert no_platform.value.code == 2


class FakeGraph:
    """Canned Graph API replies by (method, path after the version); records every call. A
    list reply serves one page per call."""

    def __init__(self, replies):
        self.replies, self.calls = replies, []

    def __call__(self, method, url, headers, body=None):
        assert headers == {"Authorization": "Bearer fake-token"}
        parts = urllib.parse.urlsplit(url)
        assert (parts.scheme, parts.netloc) == ("https", "graph.facebook.com")
        self.calls.append((method, parts.path, dict(urllib.parse.parse_qsl(parts.query)), body))
        reply = self.replies[(method, parts.path.split("/", 2)[2])]
        return reply.pop(0) if isinstance(reply, list) else reply


@pytest.fixture
def graph_env(monkeypatch):
    monkeypatch.setenv("META_ADS_SYSTEM_USER_TOKEN", "fake-token")
    monkeypatch.delenv("META_GRAPH_API_VERSION", raising=False)


def test_meta_adapter_reads_ad_sets_in_the_runs_units(graph_env):
    """Budgets in cents become micros. An ad set's own budget is movable; a campaign's
    budget or a lifetime budget is not. Brand comes from the campaign's `brand` ad label,
    a lookalike from the account's audience list. An ad set whose campaign is not active is
    left out."""
    from ads_agent.adapters import MetaAds

    graph = FakeGraph({
        ("GET", f"act_{ACCOUNT}"): {"currency": "USD"},
        ("GET", f"act_{ACCOUNT}/campaigns"): {"data": [
            {"id": "5001", "name": "Fake site campaign"},
            {"id": "5002", "name": "Fake pooled campaign", "daily_budget": "9000"},
            {"id": "5003", "name": "Fake brand campaign", "adlabels": [{"name": "Brand"}]}]},
        ("GET", f"act_{ACCOUNT}/adsets"): {"data": [
            {"id": "6001", "name": "Fake site A", "campaign_id": "5001", "daily_budget": "10000",
             "optimization_goal": "OFFSITE_CONVERSIONS", "promoted_object": {"custom_event_type": "LEAD"},
             "destination_type": "WEBSITE", "targeting": {"custom_audiences": [{"id": "800001", "name": "Fake LAL"}]}},
            {"id": "6002", "name": "Fake pooled", "campaign_id": "5002", "optimization_goal": "LEAD_GENERATION",
             "destination_type": "ON_AD"},
            {"id": "6003", "name": "Fake brand", "campaign_id": "5003", "lifetime_budget": "50000",
             "optimization_goal": "QUALITY_LEAD", "destination_type": "ON_AD"},
            {"id": "6004", "name": "Fake orphan", "campaign_id": "5999", "daily_budget": "100"}]},
        ("GET", f"act_{ACCOUNT}/customaudiences"): {"data": [{"id": "800001", "subtype": "LOOKALIKE"}]},
    })

    rows = {r["ad_set_id"]: r for r in MetaAds(http=graph).read_settings([ACCOUNT])}

    assert set(rows) == {"6001", "6002", "6003"}
    got = {k: (r[BUDGET], r["budget_level"], r["budget_shared"], r["brand"], r[GOAL]) for k, r in rows.items()}
    assert got == {"6001": (100_000_000, "ad_set", False, False, "leads"),
                   "6002": (90_000_000, "campaign", True, False, "leads"),
                   "6003": (None, None, True, True, "booked_appointments")}
    assert not any(r["budget_limited"] for r in rows.values())  # the run derives it
    assert rows["6001"]["targeting"]["custom_audiences"] == [{"id": "800001", "name": "Fake LAL", "subtype": "LOOKALIKE"}]
    assert graph.calls[0][1] == f"/v24.0/act_{ACCOUNT}"


def test_meta_adapter_reads_ads_and_one_days_spend(graph_env):
    """Ads come back in the run's status names, paged, with archived ads dropped. Spend is
    per ad set for the day asked, and per campaign as the sum of its ad sets."""
    from ads_agent.adapters import MetaAds

    graph = FakeGraph({
        ("GET", f"act_{ACCOUNT}/ads"): [
            {"data": [{"id": "7001", "name": "Fake ad", "campaign_id": "5001", "adset_id": "6001",
                       "status": "ACTIVE", "created_time": "2026-09-29T21:00:00-0600"}],
             "paging": {"next": f"https://graph.facebook.com/v24.0/act_{ACCOUNT}/ads?after=fake"}},
            {"data": [{"id": "7002", "campaign_id": "5001", "adset_id": "6001", "status": "ARCHIVED",
                       "created_time": "2026-09-01T09:00:00-0600"}]}],
        ("GET", f"act_{ACCOUNT}/insights"): {"data": [
            {"adset_id": "6001", "campaign_id": "5001", "spend": "95.50"},
            {"adset_id": "6002", "campaign_id": "5001", "spend": "4.50"}]},
    })
    meta = MetaAds(http=graph)

    ads = meta.read_ads([ACCOUNT])
    spend = meta.read_spend([ACCOUNT], YESTERDAY)

    assert ads == [{"account_id": ACCOUNT, "campaign_id": "5001", "ad_group_id": "6001", "ad_id": "7001",
                    "ad_name": "Fake ad", "status": "ENABLED", "created_time": "2026-09-29T21:00:00-06:00"}]
    assert {(r["level"], r["id"]): r["spend"] for r in spend} == {
        ("ad_set", "6001"): 95.5, ("ad_set", "6002"): 4.5, ("campaign", "5001"): 100.0}
    [insights] = [c for c in graph.calls if c[1].endswith("/insights")]
    assert insights[2]["level"] == "adset"
    assert json.loads(insights[2]["time_range"]) == {"since": YESTERDAY, "until": YESTERDAY}


def _change(**edit):
    return {"key": "fake-key", "account_id": ACCOUNT, "target_type": "ad_set", "target_id": "6001",
            "field": BUDGET, "old": 80_000_000, "new": 60_000_000, **edit}


def test_meta_adapter_writes_only_what_it_reread(graph_env):
    """A budget goes out in cents; an ad's status in Meta's name. The goal switch is
    conversion leads on an instant form, and the Schedule event on a site ad set's pixel."""
    from ads_agent.adapters import MetaAds

    graph = FakeGraph({
        ("GET", "6001"): {"account_id": ACCOUNT, "daily_budget": "8000"},
        ("GET", "7001"): {"account_id": ACCOUNT, "status": "ACTIVE"},
        ("GET", "6003"): {"account_id": ACCOUNT, "optimization_goal": "LEAD_GENERATION"},
        ("GET", "6002"): {"account_id": ACCOUNT, "optimization_goal": "OFFSITE_CONVERSIONS",
                          "promoted_object": {"pixel_id": "0", "custom_event_type": "LEAD"}},
        **{("POST", x): {"success": True} for x in ("6001", "7001", "6003", "6002")},
    })
    meta = MetaAds(http=graph)
    switch = {"field": GOAL, "old": "leads", "new": "booked_appointments"}

    meta.apply(_change())
    meta.apply(_change(target_type="ad", target_id="6001~7001", field="status", old="ENABLED", new="PAUSED"))
    meta.apply(_change(target_id="6003", **switch))
    meta.apply(_change(target_id="6002", **switch))

    assert [(path, body) for method, path, _, body in graph.calls if method == "POST"] == [
        ("/v24.0/6001", {"daily_budget": 6000}),
        ("/v24.0/7001", {"status": "PAUSED"}),
        ("/v24.0/6003", {"optimization_goal": "QUALITY_LEAD"}),
        ("/v24.0/6002", {"promoted_object": {"pixel_id": "0", "custom_event_type": "SCHEDULE"}}),
    ]


@pytest.mark.parametrize("change, reply, error", [
    (_change(old=90_000_000), {"account_id": ACCOUNT, "daily_budget": "8000"}, "changed after the plan"),
    (_change(), {"account_id": "0000000009", "daily_budget": "8000"}, "not in ad account"),
    (_change(new=60_000_001), {"account_id": ACCOUNT, "daily_budget": "8000"}, "whole number of cents"),
    (_change(field="targeting", old=None, new="a fake spec"), None, "not built for Meta"),
    (_change(target_id="6001/adcreatives"), None, "not all digits"),
], ids=["budget-moved", "other-account", "fraction-of-a-cent", "targeting", "bad-id"])
def test_meta_adapter_refuses_a_write_it_cannot_verify(graph_env, change, reply, error):
    from ads_agent.adapters import MetaAds

    graph = FakeGraph({("GET", "6001"): reply})

    with pytest.raises((RuntimeError, ValueError, NotImplementedError), match=error):
        MetaAds(http=graph).apply(change)
    assert not [c for c in graph.calls if c[0] == "POST"]


def test_meta_adapter_pauses_an_ad_set_and_never_turns_one_on(graph_env):
    """The capacity pause (BC-28220): an active ad set is paused after a re-read. One that is
    no longer active is left alone, and turning an ad set on is not built."""
    from ads_agent.adapters import MetaAds

    pause = _change(field="status", old="ENABLED", new="PAUSED")
    graph = FakeGraph({("GET", "6001"): [{"account_id": ACCOUNT, "status": "ACTIVE"},
                                         {"account_id": ACCOUNT, "status": "PAUSED"}],
                       ("POST", "6001"): {"success": True}})
    meta = MetaAds(http=graph)

    meta.apply(pause)
    with pytest.raises(RuntimeError, match="no longer active"):
        meta.apply(pause)
    with pytest.raises(NotImplementedError, match="not built for Meta"):
        meta.apply(_change(field="status", old="PAUSED", new="ENABLED"))

    posts = [(path, body) for method, path, _, body in graph.calls if method == "POST"]
    assert posts == [("/v24.0/6001", {"status": "PAUSED"})]


def _real_warehouse(monkeypatch, replies):
    from ads_agent import adapters

    for name in adapters.SnowflakeWarehouse.ENV:
        monkeypatch.setenv(name, "fake")
    warehouse, sent, replies = adapters.SnowflakeWarehouse(), [], iter(replies)
    monkeypatch.setattr(warehouse, "_query",
                        lambda sql, params=None, many=None: sent.append((sql, params)) or next(replies))
    return warehouse, sent


def test_real_warehouse_reads_booked_appointments_only_when_the_column_exists(monkeypatch):
    base = {"platform": "meta_ads", "account_id": ACCOUNT, "campaign_id": "5001", "ad_group_id": 6001,
            "ad_id": 7001, "territory": "territory-a", "spend": Decimal("12.5"), "conversions": Decimal(2),
            "window_start_date": "2026-09-22"}
    warehouse, sent = _real_warehouse(monkeypatch, [[base], [dict(base, booked_appointments=Decimal(1))]])

    before, after = warehouse.read_ad_snapshot(), warehouse.read_ad_snapshot()

    expected = {"platform": "meta_ads", "account_id": ACCOUNT, "campaign_id": "5001", "ad_group_id": "6001",
                "ad_id": "7001", "territory": "territory-a", "spend": 12.5, "conversions": 2.0}
    assert before == [expected]
    assert after == [dict(expected, booked_appointments=1.0)]
    assert all("MART_ADS_AGENT_AD_RESULTS_SNAPSHOT" in sql for sql, _ in sent)


def test_real_warehouse_reads_one_platforms_creative_inputs(monkeypatch):
    warehouse, sent = _real_warehouse(monkeypatch, [[
        {"platform": "meta_ads", "ad_account_id": ACCOUNT, "ad_id": 7001, "ai_edited": True, "approved_by": None}]])

    rows = warehouse.read_creative_inputs("meta_ads")

    assert rows == [_creative("7001", ai_edited=True)]
    [(sql, params)] = sent
    assert "ANALYTICS.OPERATIONS.ADS_CREATIVE_INPUTS" in sql and params == {"p": "meta_ads"}
