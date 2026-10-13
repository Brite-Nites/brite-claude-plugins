"""The ads-agent run seam (BC-28215, spec BC-28205 Testing Decisions).

Fixture results snapshot + fixture account settings + rule settings in, change plan
out, with fakes for Google Ads, the warehouse and Slack. Assertions are on the plan
and on the calls the fakes recorded — never on internal steps.

Every id, name and number here is synthetic. This repo is public: no real account
ids, budgets, ceilings or results, ever.
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_agent.fakes import FakeGoogleAds, FakeSlack, FakeWarehouse  # noqa: E402
from ads_agent.run import run  # noqa: E402

NOW = datetime(2026, 10, 6, 14, 0, tzinfo=timezone.utc)
ACCOUNT = "0000000001"

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
     "daily_budget_micros": 100_000_000, "budget_limited": True, "budget_shared": False},
    {"account_id": ACCOUNT, "campaign_id": "1002", "campaign_name": "Fake Territory B",
     "daily_budget_micros": 80_000_000, "budget_limited": False, "budget_shared": False},
    {"account_id": ACCOUNT, "campaign_id": "1003", "campaign_name": "Fake Territory C",
     "daily_budget_micros": 60_000_000, "budget_limited": False, "budget_shared": False},
]

RULES = {"weekly_ceiling": 2000, "max_move_pct": 0.25, "min_conversions": 3}


def _fakes(snapshot=SNAPSHOT, settings=SETTINGS):
    return FakeWarehouse(snapshot), FakeGoogleAds(settings), FakeSlack()


def _run(warehouse, google, slack, rules=RULES, **kw):
    return run(warehouse=warehouse, adapter=google, slack=slack, rules=rules,
               now=NOW, mode="propose", **kw)


def test_propose_mode_makes_no_writes():
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack)

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
        assert {k["name"] for k in c["checks"]} == {"max_move", "no_total_raise", "weekly_ceiling"}
        assert all(k["passed"] for k in c["checks"]), c["checks"]


def test_reads_results_from_snapshot_not_adapter():
    warehouse, google, slack = _fakes()

    _run(warehouse, google, slack)

    assert ("read_snapshot",) in warehouse.calls
    assert {c[0] for c in google.calls} == {"read_settings"}


def test_every_run_writes_its_plan_to_the_change_log():
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack)

    assert len(plan["changes"]) == 2
    assert warehouse.change_log == plan["changes"]
    assert all(r["key"] and r["run_date"] == "2026-10-06" and r["mode"] == "propose"
               for r in warehouse.change_log)


def test_a_run_with_nothing_to_change_still_logs_why():
    # No campaign is limited by budget, so there is nowhere useful to move money.
    settings = [dict(s, budget_limited=False) for s in SETTINGS]
    warehouse, google, slack = _fakes(settings=settings)

    plan = _run(warehouse, google, slack)

    assert [c["status"] for c in plan["changes"]] == ["no_change"]
    assert "limited by budget" in plan["changes"][0]["reason"]
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
    warehouse, google, slack = _fakes(settings=[dict(s, budget_limited=False) for s in SETTINGS])

    _run(warehouse, google, slack)

    assert len(slack.posts) == 1 and "No changes" in slack.posts[0]
    assert "limited by budget" in slack.posts[0]


def test_emit_mode_returns_the_plan_and_writes_nothing_anywhere():
    warehouse, google, slack = _fakes()

    plan = _run(warehouse, google, slack, emit=True)

    assert len(plan["changes"]) == 2
    assert warehouse.change_log == [] and slack.posts == [] and google.write_calls == []


def test_act_mode_is_not_built_yet():
    import pytest

    with pytest.raises(NotImplementedError, match="BC-28216"):
        run(warehouse=FakeWarehouse(SNAPSHOT), adapter=FakeGoogleAds(SETTINGS), slack=FakeSlack(),
            rules=RULES, now=NOW, mode="act")


def test_missing_rule_settings_stop_the_run_before_any_read():
    import pytest

    warehouse, google, slack = _fakes()
    rules = {k: v for k, v in RULES.items() if k != "max_move_pct"}

    with pytest.raises(ValueError, match="max_move_pct"):
        _run(warehouse, google, slack, rules=rules)
    assert warehouse.calls == [] and google.calls == []


def test_real_adapters_name_every_missing_env_var(monkeypatch):
    import pytest

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
