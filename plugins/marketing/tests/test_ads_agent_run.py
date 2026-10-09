"""The ads-agent run seam (BC-28215 propose, BC-28216 act, BC-28522 run date, BC-28219 data
freeze; spec BC-28205 Testing Decisions).

Fixture results snapshot + fixture account settings + rule settings in, change plan
out, with fakes for Google Ads, the warehouse and Slack. Assertions are on the plan
and on the calls the fakes recorded — never on internal steps.

Act-mode tests carry the hard-limit letter from BC-28216 (a-k) in their docstring.

Every id, name and number here is synthetic. This repo is public: no real account
ids, budgets, ceilings or results, ever.
"""

from __future__ import annotations

import json
import sys
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path
from types import MappingProxyType

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent.fakes import FakeGoogleAds, FakeSlack, FakeWarehouse  # noqa: E402
from ads_agent.run import approve, run  # noqa: E402

NOW = datetime(2026, 10, 6, 14, 0, tzinfo=timezone.utc)
TODAY = "2026-10-06"
ACCOUNT = "0000000001"
BUDGET = "daily_budget_micros"

# Trailing-window results per campaign, as the warehouse snapshot serves them.
SNAPSHOT = [
    {"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": "1001",
     "territory": "territory-a", "spend": 500.0, "conversions": 10},  # $50 per conversion
    {"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": "1002",
     "territory": "territory-b", "spend": 800.0, "conversions": 4},   # $200 per conversion
    {"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": "1003",
     "territory": "territory-c", "spend": 300.0, "conversions": 3},   # $100 per conversion
]

# Current Google settings, as the adapter reads them.
SETTINGS = [
    {"account_id": ACCOUNT, "campaign_id": "1001", "campaign_name": "Fake Territory A",
     "daily_budget_micros": 100_000_000, "budget_limited": True, "budget_shared": False, "brand": False},
    {"account_id": ACCOUNT, "campaign_id": "1002", "campaign_name": "Fake Territory B",
     "daily_budget_micros": 80_000_000, "budget_limited": False, "budget_shared": False, "brand": False},
    {"account_id": ACCOUNT, "campaign_id": "1003", "campaign_name": "Fake Territory C",
     "daily_budget_micros": 60_000_000, "budget_limited": False, "budget_shared": False, "brand": False},
]
QUIET = [dict(s, budget_limited=False) for s in SETTINGS]  # no budget move to plan

# Weeks 1-2 (the launch default): act applies approved changes only, one a day. The time
# zone is an example; NOW is 08:00 there, so TODAY is the same date in it and in UTC.
RULES = {"weekly_ceiling": 2000, "max_move_pct": 0.25, "min_conversions": 3,
         "weeks_1_2": True, "emergency_stop": False,
         "target_cpl": 50, "kill_multiple": 3, "compare_multiple": 5,
         "timezone": "America/Denver", "max_lead_count_gap": 0.20}
AUTONOMOUS = dict(RULES, weeks_1_2=False)  # from about week 3

YESTERDAY = "2026-10-05"  # the day before TODAY: the lead counts the data freeze reads


def _lead_counts(platform_leads, britebase_leads, gap_pct, spend=500.0, day=YESTERDAY, platform="google_ads"):
    """One row of the lead reconciliation mart (BC-28219)."""
    return {"platform": platform, "lead_date": day, "platform_leads": platform_leads,
            "britebase_leads": britebase_leads, "gap_pct": gap_pct, "platform_spend": spend}


# Lead counts that agree, on both platforms, for the day before every run date used here.
# A run is frozen only when a test says so.
AGREED = [_lead_counts(20, 20, 0.0, day=day, platform=p)
          for day in (YESTERDAY, TODAY) for p in ("google_ads", "meta_ads")]


def _ad(ad_group_id, ad_id, campaign_id="1003", status="ENABLED"):
    return {"account_id": ACCOUNT, "campaign_id": campaign_id, "ad_group_id": ad_group_id,
            "ad_id": ad_id, "ad_name": f"Fake ad {ad_id}", "status": status}


def _ad_result(ad_group_id, ad_id, spend, leads, campaign_id="1003"):
    return {"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": campaign_id,
            "ad_group_id": ad_group_id, "ad_id": ad_id, "spend": spend, "conversions": leads}


def _fakes(snapshot=SNAPSHOT, settings=SETTINGS, ad_snapshot=(), ads=(), lead_counts=AGREED):
    return FakeWarehouse(snapshot, ad_snapshot, lead_counts), FakeGoogleAds(settings, ads), FakeSlack()


def _run(warehouse, google, slack, rules=RULES, now=NOW, **kw):
    return run(warehouse=warehouse, adapter=google, slack=slack, rules=rules,
               now=now, mode="propose", **kw)


def _act(warehouse, google, slack, rules=AUTONOMOUS, now=NOW, **kw):
    return run(warehouse=warehouse, adapter=google, slack=slack, rules=rules,
               now=now, mode="act", **kw)


def _approve(warehouse, key, by="Fake Head of GTM", rules=RULES, now=NOW):
    return approve(warehouse=warehouse, rules=rules, key=key, by=by, now=now)


def _keys(plan):
    """(cut key, raise key) of the day's budget move."""
    by_target = {c["target_id"]: c["key"] for c in plan["changes"]}
    return by_target["1002"], by_target["1001"]


def _seed(warehouse, **edit):
    """Log a proposed plan row for today that the planner itself would never make."""
    row = {"run_date": TODAY, "mode": "propose", "platform": "google_ads", "status": "proposed",
           "account_id": ACCOUNT, "target_name": "Fake seeded change", "reason": "seeded by the test",
           "checks": [], **edit}
    warehouse.write_change_log([row])
    return row


def _reason(out, key):
    return next(r["reason"] for r in out["results"] if r["key"].startswith(key + ":"))


# --- propose mode (BC-28215) ---------------------------------------------------------------


def test_propose_mode_makes_no_adapter_write():
    """h. Propose mode never writes, even with every change approved and act's flag off."""
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack, rules=AUTONOMOUS)
    for c in plan["changes"]:
        _approve(warehouse, c["key"])
    _run(warehouse, google, slack, rules=AUTONOMOUS)
    run(warehouse=warehouse, adapter=google, slack=slack, rules=AUTONOMOUS, now=NOW)  # no mode: propose

    assert [c for c in plan["changes"] if c["status"] == "proposed"], plan
    assert google.write_calls == []


def test_rerun_same_inputs_plans_no_new_changes():
    warehouse, google, slack = _fakes()
    first = _run(warehouse, google, slack)

    second = _run(warehouse, google, slack)

    assert len(first["changes"]) == 2
    assert second["changes"] == []
    assert second["already_logged"] == 2
    assert len(warehouse.change_log) == 2


def test_each_change_lists_target_old_new_reason_checks():
    # Worked example: worst cost per conversion is B ($200), best budget-limited is A
    # ($50). The move is 25% of the smaller budget (B's $80) = $20, B -> A.
    plan = _run(*_fakes())

    got = {(c["target_id"], c["old"], c["new"]) for c in plan["changes"]}
    assert got == {("1002", 80_000_000, 60_000_000), ("1001", 100_000_000, 120_000_000)}
    for c in plan["changes"]:
        assert c["status"] == "proposed"
        assert c["account_id"] == ACCOUNT and c["target_name"] and c["reason"]
        assert {k["name"] for k in c["checks"]} == {"max_move", "no_total_raise", "weekly_ceiling",
                                                     "brand_untouched"}
        assert all(k["passed"] for k in c["checks"]), c["checks"]


def test_reads_results_from_snapshot_not_adapter():
    warehouse, google, slack = _fakes()

    _run(warehouse, google, slack)

    assert ("read_snapshot",) in warehouse.calls and ("read_ad_snapshot",) in warehouse.calls
    assert {c[0] for c in google.calls} == {"read_settings", "read_ads"}


def test_every_run_writes_its_plan_to_the_change_log():
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack)

    assert len(plan["changes"]) == 2
    assert warehouse.change_log == plan["changes"]
    assert all(r["key"] and r["run_date"] == TODAY and r["mode"] == "propose"
               for r in warehouse.change_log)


def test_a_run_with_nothing_to_change_still_logs_why():
    # No campaign is limited by budget, so there is nowhere useful to move money.
    warehouse, google, slack = _fakes(settings=QUIET)

    plan = _run(warehouse, google, slack)

    assert [c["status"] for c in plan["changes"]] == ["no_change"]
    assert "limited by budget" in plan["changes"][0]["reason"]
    assert "kill rule" in plan["changes"][0]["reason"]
    assert warehouse.change_log == plan["changes"]


def test_a_change_that_fails_a_limit_check_is_held_not_proposed():
    # Current budgets total $240 a day = $1,680 a week, over a $1,000 ceiling.
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack, rules=dict(RULES, weekly_ceiling=1000))

    assert [c["status"] for c in plan["changes"]] == ["held", "held"]
    for c in plan["changes"]:
        assert [k["name"] for k in c["checks"] if not k["passed"]] == ["weekly_ceiling"]
    assert "HELD" in slack.posts[0] and "weekly_ceiling" in slack.posts[0]
    assert google.write_calls == []


def test_slack_message_lists_the_days_proposed_changes_once():
    warehouse, google, slack = _fakes()

    _run(warehouse, google, slack)
    _run(warehouse, google, slack)  # re-run: nothing new, so no second post

    assert len(slack.posts) == 1
    text = slack.posts[0]
    assert "2026-10-06" in text and "2 proposed" in text
    assert "Fake Territory B" in text and "$80.00 → $60.00" in text
    assert "Fake Territory A" in text and "$100.00 → $120.00" in text
    assert "limited by budget" in text


def test_slack_message_on_a_quiet_day_says_why():
    warehouse, google, slack = _fakes(settings=QUIET)

    _run(warehouse, google, slack)

    assert len(slack.posts) == 1 and "No changes" in slack.posts[0]
    assert "limited by budget" in slack.posts[0]


def test_emit_mode_returns_the_plan_and_writes_nothing_anywhere():
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack, emit=True)

    assert len(plan["changes"]) == 2
    assert warehouse.change_log == [] and slack.posts == [] and google.write_calls == []


def test_unknown_mode_is_refused_before_any_read():
    warehouse, google, slack = _fakes()

    with pytest.raises(ValueError, match="propose or act"):
        run(warehouse=warehouse, adapter=google, slack=slack, rules=RULES, now=NOW, mode="apply")
    assert warehouse.calls == [] and google.calls == []


@pytest.mark.parametrize("missing", ["max_move_pct", "max_lead_count_gap"])
def test_missing_rule_settings_stop_the_run_before_any_read(missing):
    warehouse, google, slack = _fakes()
    rules = {k: v for k, v in RULES.items() if k != missing}

    with pytest.raises(ValueError, match=missing):
        _run(warehouse, google, slack, rules=rules)
    with pytest.raises(ValueError, match=missing):
        _approve(warehouse, "f" * 12, rules=rules)
    assert warehouse.calls == [] and google.calls == []


def test_flag_settings_must_be_true_or_false():
    # A string "false" would read as true; the run refuses it rather than guess.
    warehouse, google, slack = _fakes()

    with pytest.raises(ValueError, match="emergency_stop"):
        _act(warehouse, google, slack, rules=dict(AUTONOMOUS, emergency_stop="false"))
    assert warehouse.calls == [] and google.calls == []


def test_real_adapters_name_every_missing_env_var(monkeypatch):
    from ads_agent import adapters

    for cls in (adapters.GoogleAds, adapters.SnowflakeWarehouse, adapters.SlackWebhook):
        for name in cls.ENV:
            monkeypatch.delenv(name, raising=False)
        with pytest.raises(adapters.MissingEnv) as err:
            cls()
        assert all(name in str(err.value) for name in cls.ENV), (cls, err.value)


def test_a_move_under_one_cent_plans_nothing():
    tiny = [dict(s, daily_budget_micros=30_000) for s in SETTINGS]  # 3 cents a day each

    plan = _run(*_fakes(settings=tiny))

    assert [c["status"] for c in plan["changes"]] == ["no_change"]
    assert "one cent" in plan["changes"][0]["reason"]


def test_too_few_conversions_to_judge_plans_nothing():
    plan = _run(*_fakes(), rules=dict(RULES, min_conversions=5))  # only A has 5+

    assert [c["status"] for c in plan["changes"]] == ["no_change"]
    assert "5 conversions" in plan["changes"][0]["reason"]


# --- approval -----------------------------------------------------------------------------


def test_approval_is_a_new_row_logged_by_the_approver():
    warehouse, google, slack = _fakes()
    cut, _ = _keys(_run(warehouse, google, slack))
    plan_rows = [dict(r) for r in warehouse.change_log]

    row = _approve(warehouse, cut[:12], by="Fake Approver")
    _approve(warehouse, cut, by="Fake Approver")  # twice: still one row

    assert row["key"] == f"{cut}:approved" and row["status"] == "approved"
    assert row["logged_by"] == "Fake Approver" and row["mode"] == "approve"
    assert row["target_id"] == "1002" and (row["old"], row["new"]) == (80_000_000, 60_000_000)
    assert warehouse.change_log[:2] == plan_rows  # the plan rows are untouched
    assert [r["status"] for r in warehouse.change_log].count("approved") == 1
    assert google.write_calls == []


def test_only_a_proposed_change_in_todays_plan_can_be_approved():
    warehouse, google, slack = _fakes()
    held = _run(warehouse, google, slack, rules=dict(RULES, weekly_ceiling=1000))["changes"][0]

    with pytest.raises(ValueError, match="held"):
        _approve(warehouse, held["key"])
    with pytest.raises(ValueError, match="0 planned changes"):
        _approve(warehouse, "f" * 12)
    with pytest.raises(ValueError, match="approver"):
        _approve(warehouse, held["key"], by=" ")


# --- run date (BC-28522): the date in the rules' time zone, not in UTC --------------------
# Tests carry their BC-28522 letter (a-c) in the docstring. Denver is UTC-6 in October.

PLANNED = datetime(2026, 10, 6, 21, 0, tzinfo=timezone.utc)          # 15:00 Oct 6 in Denver
EVENING = datetime(2026, 10, 7, 0, 30, tzinfo=timezone.utc)          # 18:30 Oct 6 in Denver
AFTER_MIDNIGHT = datetime(2026, 10, 7, 6, 30, tzinfo=timezone.utc)   # 00:30 Oct 7 in Denver


def test_an_approval_after_utc_midnight_finds_the_same_local_days_plan():
    """a. Planned at 15:00 local. At 00:30 UTC the next day it is still the same date
    locally, so the approval finds the plan and act applies it."""
    warehouse, google, slack = _fakes()
    plan = _run(warehouse, google, slack, now=PLANNED)
    cut, raise_ = _keys(plan)

    approval = _approve(warehouse, cut[:12], now=EVENING)
    out = _act(warehouse, google, slack, rules=RULES, now=EVENING)

    assert plan["run_date"] == approval["run_date"] == out["run_date"] == TODAY
    assert approval["key"] == f"{cut}:approved"
    assert out["changes"] == []  # act found the day's plan, so it planned nothing new
    assert google.applied == [cut, raise_]


def test_an_approval_after_local_midnight_finds_no_plan_for_the_new_day():
    """b. Past local midnight it is a new run date with no plan yet: refused, nothing logged."""
    warehouse, google, slack = _fakes()
    cut, _ = _keys(_run(warehouse, google, slack, now=PLANNED))

    with pytest.raises(ValueError, match="0 planned changes in the 2026-10-07 plan"):
        _approve(warehouse, cut, now=AFTER_MIDNIGHT)
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed"]


@pytest.mark.parametrize("rules", [
    {k: v for k, v in RULES.items() if k != "timezone"},
    dict(RULES, timezone="America/Nowhere"),
    dict(RULES, timezone="america/denver"),  # macOS's case-blind disk loads it; Linux does not
    dict(RULES, timezone=-6),                # an offset is not a zone: it misses daylight saving
], ids=["missing", "unknown", "wrong-case", "offset"])
def test_a_missing_or_unknown_timezone_is_refused_before_any_read(rules):
    """c. Plan, act and approve all refuse it before reading anything."""
    warehouse, google, slack = _fakes()

    with pytest.raises(ValueError, match="timezone"):
        _run(warehouse, google, slack, rules=rules)
    with pytest.raises(ValueError, match="timezone"):
        _act(warehouse, google, slack, rules=rules)
    with pytest.raises(ValueError, match="timezone"):
        _approve(warehouse, "f" * 12, rules=rules)
    assert warehouse.calls == [] and google.calls == []


def test_a_clock_with_no_time_zone_is_refused_before_any_read():
    # A bare clock time has no date until it has a zone; guessing the machine's would be silent.
    warehouse, google, slack = _fakes()
    bare = NOW.replace(tzinfo=None)

    with pytest.raises(ValueError, match="no time zone"):
        _run(warehouse, google, slack, now=bare)
    with pytest.raises(ValueError, match="no time zone"):
        _approve(warehouse, "f" * 12, now=bare)
    assert warehouse.calls == [] and google.calls == []


# --- act mode (BC-28216): the hard limits of ADR-0033 -------------------------------------


def test_act_applies_the_plan_and_logs_each_result_next_to_it():
    warehouse, google, slack = _fakes()

    out = _act(warehouse, google, slack)

    cut, raise_ = _keys(out)
    assert google.applied == [cut, raise_]  # the cut first
    results = {r["key"]: r for r in out["results"]}
    assert set(results) == {f"{cut}:applied", f"{raise_}:applied"}
    assert all(r["mode"] == "act" and r["status"] == "applied" for r in results.values())
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed", "applied", "applied"]
    assert "APPLIED Fake Territory B" in slack.posts[0]


def test_act_never_raises_total_budget():
    """a. A move whose raise is bigger than its cut would lift total budget: the cut goes
    through on its own, the raise is refused. (WS4 rule 2: no_total_raise on the pair.)"""
    warehouse, google, slack = _fakes()
    _seed(warehouse, key="seed-cut-0001", target_type="campaign", target_id="1002",
          field=BUDGET, old=80_000_000, new=60_000_000)                     # -$20
    _seed(warehouse, key="seed-cut-0001:pair", target_type="campaign", target_id="1001",
          field=BUDGET, old=100_000_000, new=125_000_000)                   # +$25

    out = _act(warehouse, google, slack)

    assert google.applied == ["seed-cut-0001"]
    assert "would raise total daily budget by $5.00" in _reason(out, "seed-cut-0001:pair")


def test_a_raise_is_written_only_after_its_cut_succeeds():
    """WS4 rule 3: cut first; its write fails, so the raise is never sent. Both halves
    log their own result."""
    warehouse, google, slack = _fakes()
    google.fail_on.add("1002")

    out = _act(warehouse, google, slack)

    cut, raise_ = _keys(out)
    assert google.write_calls == [("apply", cut)]
    assert "write failed" in _reason(out, cut)
    assert "paired cut has not been applied" in _reason(out, raise_)
    assert [r["status"] for r in warehouse.change_log[2:]] == ["apply_failed", "apply_failed"]


def test_a_raise_with_no_linked_cut_is_refused():
    """WS4 rule 5: a raise that is not the planner's `<cut key>:pair` is refused, even when
    a lone cut the same day would cover it, and a pair whose cut is missing is refused."""
    warehouse, google, slack = _fakes()
    _seed(warehouse, key="seed-lone-cut-0001", target_type="campaign", target_id="1002",
          field=BUDGET, old=80_000_000, new=60_000_000)
    _seed(warehouse, key="seed-lone-raise-0001", target_type="campaign", target_id="1001",
          field=BUDGET, old=100_000_000, new=120_000_000)
    _seed(warehouse, key="seed-no-cut-0001:pair", target_type="campaign", target_id="1003",
          field=BUDGET, old=60_000_000, new=70_000_000)

    out = _act(warehouse, google, slack)

    assert google.applied == ["seed-lone-cut-0001"]
    for key in ("seed-lone-raise-0001", "seed-no-cut-0001:pair"):
        assert "only written as half of a planned move" in _reason(out, key)
    with pytest.raises(ValueError, match="has no cut"):
        _approve(warehouse, "seed-no-cut-0001")


def test_act_never_moves_a_setting_more_than_25_percent_in_one_run():
    """b. Planned under a 40% limit; a person set it back to 25% before act ran."""
    warehouse, google, slack = _fakes()
    _run(warehouse, google, slack, rules=dict(RULES, max_move_pct=0.40))

    out = _act(warehouse, google, slack)

    assert google.write_calls == []
    assert len(out["results"]) == 2
    assert all(r["status"] == "apply_failed" and "(limit 25%)" in r["reason"] for r in out["results"])


def test_act_never_creates_or_deletes_a_campaign_without_approval():
    """c. Even with the weeks 1-2 flag off, a create or delete waits for approval."""
    warehouse, google, slack = _fakes()
    _seed(warehouse, key="seed-create-0001", target_type="campaign", target_id="1009",
          field="status", old=None, new="ENABLED")
    _seed(warehouse, key="seed-delete-0001", target_type="campaign", target_id="1003",
          field="status", old="ENABLED", new="REMOVED")

    before = _act(warehouse, google, slack)
    _approve(warehouse, "seed-delete-0001")
    after = _act(warehouse, google, slack)

    assert sorted(before["waiting"]) == ["seed-create-0001", "seed-delete-0001"]
    assert google.applied == ["seed-delete-0001"]
    assert after["waiting"] == ["seed-create-0001"]


def test_act_never_touches_brand_keywords():
    """d. Brand campaigns, and the ads in them, are never planned and never written."""
    settings = [dict(s, brand=s["campaign_id"] == "1001") for s in SETTINGS]
    ads = [_ad("2001", "3001", campaign_id="1001")]
    results = [_ad_result("2001", "3001", spend=500.0, leads=0, campaign_id="1001")]  # 10x target, no leads
    warehouse, google, slack = _fakes(settings=settings, ads=ads, ad_snapshot=results)

    plan = _run(warehouse, google, slack)
    _seed(warehouse, key="seed-brand-0001", target_type="campaign", target_id="1001",
          field=BUDGET, old=100_000_000, new=90_000_000)
    _approve(warehouse, "seed-brand-0001")
    out = _act(warehouse, google, slack, rules=RULES)

    assert not [c for c in plan["changes"] if c["target_id"] in ("1001", "2001~3001")]
    assert google.write_calls == []
    assert "brand" in _reason(out, "seed-brand-0001")


def test_weeks_1_2_apply_only_approved_changes_one_per_platform_per_day():
    """e. Nothing applies until approved; then one change per platform per day. A budget
    move is one change: approving either half approves both (WS4 rule 1)."""
    ads = [_ad("2002", "3002")]
    results = [_ad_result("2002", "3002", spend=150.0, leads=0)]  # meets the kill rule
    warehouse, google, slack = _fakes(ads=ads, ad_snapshot=results)
    plan = _run(warehouse, google, slack)
    cut, raise_ = _keys(plan)
    pause = next(c["key"] for c in plan["changes"] if c["target_type"] == "ad")

    before = _act(warehouse, google, slack, rules=RULES)
    approval = _approve(warehouse, raise_)  # the raise's key approves the whole move
    _approve(warehouse, pause)
    after = _act(warehouse, google, slack, rules=RULES)

    assert sorted(before["waiting"]) == sorted([cut, raise_, pause]) and before["results"] == []
    assert approval["key"] == f"{cut}:approved" and raise_ == f"{cut}:pair"
    assert google.applied == [cut, raise_]  # the move, as one change
    assert "one change per platform per day" in _reason(after, pause)


def test_emergency_stop_blocks_every_write():
    """f. With the stop on, act writes nothing to the ad account, approved or not."""
    warehouse, google, slack = _fakes()

    first = _act(warehouse, google, slack, rules=dict(AUTONOMOUS, emergency_stop=True))
    for c in first["changes"]:
        _approve(warehouse, c["key"])
    second = _act(warehouse, google, slack, rules=dict(RULES, emergency_stop=True))

    assert google.write_calls == []
    assert first["emergency_stop"] and second["emergency_stop"]
    assert first["results"] == second["results"] == []
    assert not [r for r in warehouse.change_log if r["status"] in ("applied", "apply_failed")]
    assert "Emergency stop is on" in slack.posts[0]


def test_agent_never_writes_its_rule_settings_so_it_cannot_clear_the_stop():
    """g. The rules are read-only to the run, and a planned change to a rule setting is
    refused even when approved."""
    warehouse, google, slack = _fakes()
    stopped = MappingProxyType(dict(AUTONOMOUS, emergency_stop=True))  # any write would raise

    _act(warehouse, google, slack, rules=stopped)
    _seed(warehouse, key="seed-rules-0001", target_type="rule", target_id="emergency_stop",
          field="emergency_stop", old=True, new=False)
    _approve(warehouse, "seed-rules-0001")
    out = _act(warehouse, google, slack, rules=MappingProxyType(dict(RULES)))

    assert stopped["emergency_stop"] is True
    assert google.write_calls == []
    assert "not an ad setting the agent may write" in _reason(out, "seed-rules-0001")


def test_rerun_after_a_partial_failure_applies_nothing_twice():
    """i. The raise fails; the re-run retries only the raise and plans nothing new. The
    cut is never written twice (WS4 rule 4)."""
    warehouse, google, slack = _fakes()
    google.fail_on.add("1001")

    first = _act(warehouse, google, slack)
    google.fail_on.clear()
    second = _act(warehouse, google, slack)
    third = _act(warehouse, google, slack)

    cut, raise_ = _keys(first)
    assert google.applied == [cut, raise_]
    assert google.write_calls == [("apply", cut), ("apply", raise_), ("apply", raise_)]  # one retry
    assert second["changes"] == [] and third["changes"] == []
    assert third["results"] == []


def test_rerun_after_a_lost_log_write_does_not_write_again():
    """i. The writes went through but their result rows were lost: no second write."""
    warehouse, google, slack = _fakes()
    _act(warehouse, google, slack)
    warehouse.change_log = [r for r in warehouse.change_log if r["status"] != "applied"]

    out = _act(warehouse, google, slack)

    assert len(google.write_calls) == 2  # the first run's two writes only
    assert [r["status"] for r in out["results"]] == ["applied", "applied"]
    assert all("no write was made" in r["reason"] for r in out["results"])


def test_a_second_plan_the_same_day_cannot_move_a_setting_again():
    # Act applied the move; a later propose run plans a fresh move from the new budgets.
    # An act re-run must not move B or A a second time today.
    warehouse, google, slack = _fakes()
    first = _act(warehouse, google, slack)
    second_plan = _run(warehouse, google, slack, rules=AUTONOMOUS)

    out = _act(warehouse, google, slack)

    assert google.applied == list(_keys(first))
    assert len(second_plan["changes"]) == 2
    assert all("already changed today" in r["reason"] for r in out["results"]) and len(out["results"]) == 2


def test_act_never_moves_a_shared_budget():
    warehouse, google, slack = _fakes(settings=[dict(s, budget_shared=s["campaign_id"] == "1003") for s in SETTINGS])
    _seed(warehouse, key="seed-shared-0001", target_type="campaign", target_id="1003",
          field=BUDGET, old=60_000_000, new=50_000_000)

    out = _act(warehouse, google, slack)

    assert google.write_calls == []
    assert "shared budget" in _reason(out, "seed-shared-0001")


class FakeMetaAds(FakeGoogleAds):
    platform = "meta_ads"  # test stand-in only; the Meta adapter is BC-28218


def test_cross_platform_move_is_refused():
    """j. A Google cut cannot pay for a Meta raise, even one keyed as its pair: a move's
    halves must sit in one platform's plan, and a run never writes another platform's row."""
    meta_account = "0000000002"
    meta = FakeMetaAds([{"account_id": meta_account, "campaign_id": "5001", "campaign_name": "Fake Meta A",
                         "daily_budget_micros": 100_000_000, "budget_limited": True,
                         "budget_shared": False, "brand": False}])
    warehouse, google, slack = _fakes()
    _seed(warehouse, key="seed-xcut-0001", target_type="campaign", target_id="1002",
          field=BUDGET, old=80_000_000, new=60_000_000)
    _seed(warehouse, key="seed-xcut-0001:pair", platform="meta_ads", account_id=meta_account,
          target_type="campaign", target_id="5001", field=BUDGET, old=100_000_000, new=120_000_000)

    _act(warehouse, google, slack)
    out = _act(warehouse, meta, slack)

    assert ("apply", "seed-xcut-0001:pair") not in google.write_calls
    assert meta.write_calls == []
    assert "only written as half of a planned move" in _reason(out, "seed-xcut-0001:pair")


def test_an_ad_turns_off_only_at_zero_leads_after_3x_target_cost_per_lead():
    """k. Target $50 a lead: an ad with no leads turns off at $150 spent, not a cent before."""
    ads = [_ad("2001", "3001"), _ad("2002", "3002"), _ad("2003", "3003")]
    results = [_ad_result("2001", "3001", spend=149.99, leads=0),
               _ad_result("2002", "3002", spend=150.00, leads=0),
               _ad_result("2003", "3003", spend=900.00, leads=1)]  # has a lead: not this rule
    warehouse, google, slack = _fakes(settings=QUIET, ads=ads, ad_snapshot=results)

    out = _act(warehouse, google, slack)

    pauses = [c for c in out["changes"] if c["target_type"] == "ad"]
    assert [(c["target_id"], c["old"], c["new"]) for c in pauses] == [("2002~3002", "ENABLED", "PAUSED")]
    assert "zero leads" in pauses[0]["reason"]
    assert google.applied == [pauses[0]["key"]]


def test_ads_compare_on_cost_only_after_5x_target_cost_per_lead_spend():
    """k. Two ads in one group are compared only once each has spent $250 (5x $50)."""
    ads = [_ad("2004", "3004"), _ad("2004", "3005"), _ad("2005", "3006"), _ad("2005", "3007")]
    results = [_ad_result("2004", "3004", spend=300.0, leads=2),   # $150 a lead
               _ad_result("2004", "3005", spend=260.0, leads=4),   # $65 a lead
               _ad_result("2005", "3006", spend=600.0, leads=2),   # $300 a lead, but...
               _ad_result("2005", "3007", spend=240.0, leads=4)]   # ...its rival is under 5x
    warehouse, google, slack = _fakes(settings=QUIET, ads=ads, ad_snapshot=results)

    out = _act(warehouse, google, slack)

    pauses = [c for c in out["changes"] if c["target_type"] == "ad"]
    assert [c["target_id"] for c in pauses] == ["2004~3004"]
    assert "Fake ad 3005" in pauses[0]["reason"]
    assert google.applied == [pauses[0]["key"]]


def test_act_emit_writes_nothing_anywhere():
    warehouse, google, slack = _fakes()

    out = _act(warehouse, google, slack, emit=True)

    assert [r["status"] for r in out["results"]] == ["would_apply", "would_apply"]
    assert warehouse.change_log == [] and slack.posts == [] and google.write_calls == []


# --- data freeze (BC-28219): yesterday's lead counts must agree --------------------------
# If the lead feed breaks, the snapshot shows no leads and the kill rule turns off good ads.
# Tests carry their case letter (a-d) from the BC-28219 amendment in the docstring.


def test_a_lead_count_gap_over_the_limit_freezes_the_run():
    """a. Google counted 20 leads yesterday and BriteBase 15: a 25% gap, over the 20% limit.
    The run plans nothing and logs one frozen row with the reason and both counts."""
    warehouse, google, slack = _fakes(lead_counts=[_lead_counts(20, 15, 0.25)])

    out = _run(warehouse, google, slack)

    assert out["changes"] == []
    assert warehouse.change_log == [out["frozen"]]
    row = out["frozen"]
    assert row["status"] == "frozen" and row["platform"] == "google_ads" and row["run_date"] == TODAY
    assert row["reason"] == f"google_ads counted 20 leads on {YESTERDAY} and BriteBase 15: a 25.0% gap, over the 20.0% limit"
    [check] = row["checks"]
    assert (check["platform_leads"], check["britebase_leads"], check["lead_date"]) == (20, 15, YESTERDAY)
    assert google.write_calls == []


def test_a_gap_that_cannot_be_measured_freezes_the_run():
    """a. A null gap is only an agreed count when both counts are zero. With one count above
    zero it is a broken row, so the run freezes."""
    out = _run(*_fakes(lead_counts=[_lead_counts(20, None, None)]))

    assert out["changes"] == [] and "the gap is unknown" in out["frozen"]["reason"]


@pytest.mark.parametrize("lead_counts", [
    [],
    [_lead_counts(20, 20, 0.0, platform="meta_ads")],
    [_lead_counts(20, 20, 0.0, day=TODAY)],
], ids=["no-row", "other-platform-only", "today-only"])
def test_no_lead_count_row_for_yesterday_freezes_the_run(lead_counts):
    """b. No row for this platform for yesterday: the feed is broken, so the run freezes."""
    warehouse, google, slack = _fakes(lead_counts=lead_counts)

    out = _run(warehouse, google, slack)

    assert out["changes"] == []
    assert out["frozen"]["reason"] == f"0 lead count rows for {YESTERDAY}, not one: the lead feed may be broken"
    assert [r["status"] for r in warehouse.change_log] == ["frozen"]


def test_no_leads_and_no_spend_on_either_side_does_not_freeze():
    """c. Both counts zero (gap null) and nothing spent: nothing disagrees, so the run plans."""
    warehouse, google, slack = _fakes(lead_counts=[_lead_counts(0, 0, None, spend=0.0)])

    out = _run(warehouse, google, slack)

    assert out["frozen"] is None and len(out["changes"]) == 2
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed"]


def test_spend_with_no_leads_on_either_side_freezes_the_run():
    """c. Both counts zero but the platform spent money: BriteBase's forms may be broken,
    which reads as zero on both sides. Frozen (WS4 grill rule C5)."""
    out = _run(*_fakes(lead_counts=[_lead_counts(0, 0, None, spend=120.0)]))

    assert out["changes"] == []
    assert out["frozen"]["reason"] == (f"spend with no leads: google_ads spent $120.00 on {YESTERDAY} "
                                       "and neither it nor BriteBase counted a lead")


@pytest.mark.parametrize("platform_leads, britebase_leads, gap_pct", [(20, 20, 0.0), (20, 16, 0.20)],
                         ids=["agree", "at-the-limit"])
def test_a_gap_at_or_under_the_limit_does_not_freeze(platform_leads, britebase_leads, gap_pct):
    """d. A gap of exactly 20% is not above the limit: the run plans as usual."""
    warehouse, google, slack = _fakes(lead_counts=[_lead_counts(platform_leads, britebase_leads, gap_pct)])

    out = _run(warehouse, google, slack)

    assert out["frozen"] is None and len(out["changes"]) == 2
    assert "frozen" not in [r["status"] for r in warehouse.change_log]


def test_yesterday_is_the_day_before_the_local_run_date():
    """At 18:30 on Oct 6 in Denver it is already Oct 7 in UTC. Yesterday is Oct 5, the day
    before the local date, so Oct 5's agreed row is the one read and the run plans."""
    warehouse, google, slack = _fakes(lead_counts=[_lead_counts(20, 20, 0.0)])

    out = _run(warehouse, google, slack, now=EVENING)

    assert out["run_date"] == TODAY and out["frozen"] is None
    assert ("read_lead_reconciliation", YESTERDAY) in warehouse.calls


def test_a_frozen_act_run_writes_nothing_to_the_ad_account():
    """Planned and approved while the counts agreed, then the feed broke: act applies
    nothing, approved or not, and plans nothing new."""
    warehouse, google, slack = _fakes()
    cut, _ = _keys(_run(warehouse, google, slack))
    _approve(warehouse, cut)
    warehouse.lead_reconciliation = []

    out = _act(warehouse, google, slack, rules=RULES)

    assert google.write_calls == []
    assert out["frozen"] and out["changes"] == [] and out["results"] == [] and out["waiting"] == []
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed", "approved", "frozen"]


def test_a_frozen_approve_is_refused():
    """Planned while the counts agreed; by approval time they disagree. Nothing is logged."""
    warehouse, google, slack = _fakes()
    cut, _ = _keys(_run(warehouse, google, slack))
    warehouse.lead_reconciliation = [_lead_counts(20, 10, 0.5)]

    with pytest.raises(ValueError, match="google_ads is frozen today, so nothing can be approved"):
        _approve(warehouse, cut)
    assert [r["status"] for r in warehouse.change_log] == ["proposed", "proposed"]


def test_real_warehouse_reads_one_days_lead_counts_as_plain_values(monkeypatch):
    """The connector returns Decimal and date values. A frozen row carries them into the
    change log's JSON and the printed output, so they must come back as int, float and str."""
    from ads_agent import adapters

    for name in adapters.SnowflakeWarehouse.ENV:
        monkeypatch.setenv(name, "fake")
    warehouse, sent = adapters.SnowflakeWarehouse(), []
    monkeypatch.setattr(warehouse, "_query", lambda sql, params=None, many=None: sent.append((sql, params)) or [
        {"platform": "google_ads", "lead_date": date(2026, 10, 5), "platform_leads": Decimal(20),
         "britebase_leads": Decimal(15), "gap_pct": Decimal("0.25"), "platform_spend": None}])

    rows = warehouse.read_lead_reconciliation(YESTERDAY)

    assert rows == [_lead_counts(20, 15, 0.25, spend=None)]
    assert json.loads(json.dumps(rows)) == rows
    [(sql, params)] = sent
    assert "MART_ADS_AGENT_LEAD_RECONCILIATION" in sql and params == {"d": YESTERDAY}


def test_a_freeze_posts_one_alert_a_day():
    """A preview posts nothing. Then one alert, and re-runs that day in either mode log and
    post nothing new."""
    warehouse, google, slack = _fakes(lead_counts=[])

    preview = _run(warehouse, google, slack, emit=True)
    assert preview["frozen"] and slack.posts == [] and warehouse.change_log == []
    _run(warehouse, google, slack)
    _run(warehouse, google, slack)
    _act(warehouse, google, slack)

    assert len(slack.posts) == 1
    assert slack.posts[0].startswith(f"Ads agent, google_ads, {TODAY} (propose mode): FROZEN.")
    assert "the lead feed may be broken" in slack.posts[0] and "The watchdog still runs." in slack.posts[0]
    assert [r["status"] for r in warehouse.change_log] == ["frozen"]
