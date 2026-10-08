"""The ads-agent run seam (BC-28215 propose, BC-28216 act; spec BC-28205 Testing Decisions).

Fixture results snapshot + fixture account settings + rule settings in, change plan
out, with fakes for Google Ads, the warehouse and Slack. Assertions are on the plan
and on the calls the fakes recorded — never on internal steps.

Act-mode tests carry the hard-limit letter from BC-28216 (a-k) in their docstring.

Every id, name and number here is synthetic. This repo is public: no real account
ids, budgets, ceilings or results, ever.
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone
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

# Weeks 1-2 (the launch default): act applies approved changes only, one a day.
RULES = {"weekly_ceiling": 2000, "max_move_pct": 0.25, "min_conversions": 3,
         "weeks_1_2": True, "emergency_stop": False,
         "target_cpl": 50, "kill_multiple": 3, "compare_multiple": 5}
AUTONOMOUS = dict(RULES, weeks_1_2=False)  # from about week 3


def _ad(ad_group_id, ad_id, campaign_id="1003", status="ENABLED"):
    return {"account_id": ACCOUNT, "campaign_id": campaign_id, "ad_group_id": ad_group_id,
            "ad_id": ad_id, "ad_name": f"Fake ad {ad_id}", "status": status}


def _ad_result(ad_group_id, ad_id, spend, leads, campaign_id="1003"):
    return {"platform": "google_ads", "account_id": ACCOUNT, "campaign_id": campaign_id,
            "ad_group_id": ad_group_id, "ad_id": ad_id, "spend": spend, "conversions": leads}


def _fakes(snapshot=SNAPSHOT, settings=SETTINGS, ad_snapshot=(), ads=()):
    return FakeWarehouse(snapshot, ad_snapshot), FakeGoogleAds(settings, ads), FakeSlack()


def _run(warehouse, google, slack, rules=RULES, **kw):
    return run(warehouse=warehouse, adapter=google, slack=slack, rules=rules,
               now=NOW, mode="propose", **kw)


def _act(warehouse, google, slack, rules=AUTONOMOUS, **kw):
    return run(warehouse=warehouse, adapter=google, slack=slack, rules=rules,
               now=NOW, mode="act", **kw)


def _approve(warehouse, key, by="Fake Head of GTM"):
    return approve(warehouse=warehouse, key=key, by=by, now=NOW)


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


def test_missing_rule_settings_stop_the_run_before_any_read():
    warehouse, google, slack = _fakes()
    rules = {k: v for k, v in RULES.items() if k != "max_move_pct"}

    with pytest.raises(ValueError, match="max_move_pct"):
        _run(warehouse, google, slack, rules=rules)
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
