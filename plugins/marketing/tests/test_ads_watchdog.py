"""Ads watchdog (BC-28219) — tested at the run seam with fake Google and Meta adapters.

Every account id, name, limit and user below is synthetic. This repo is public: real ad
account ids, ceilings and shares live only in the private runner's config.

Run with `pytest plugins/marketing/tests/test_ads_watchdog.py`.
"""

from __future__ import annotations

import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ads_watchdog.watchdog import Account, DayStats, audit, emergency_stop, hourly  # noqa: E402

TZ = "America/Denver"
# Wednesday 2026-11-04 12:00 in Denver (UTC-7): half the account's day has elapsed.
NOON_WEDNESDAY = datetime(2026, 11, 4, 19, 0, tzinfo=timezone.utc)
MON, TUE, WED = date(2026, 11, 2), date(2026, 11, 3), date(2026, 11, 4)

BRITE_G = Account("google", "100-000-0001", "Brite system - Territory A", TZ)
VENDOR_G = Account("google", "100-000-0002", "Vendor tool one - Territory B", TZ)
BRITE_M = Account("meta", "act_2000001", "Brite system - Territory C", TZ)
VENDOR_M = Account("meta", "act_2000002", "Vendor tool two - Territory D", TZ)

# weekly_ceiling x share = 700 a week = 100 a day per account.
CONFIG = {
    "weekly_ceiling": 7000.0,
    "shares": {
        "google:100-000-0001": 0.1,
        "google:100-000-0002": 0.1,
        "meta:act_2000001": 0.1,
        "meta:act_2000002": 0.1,
    },
    "pace_tolerance": 1.5,
    "pace_floor": 0.25,
    "expected_cost_per_lead": [50.0, 250.0],
    "lead_alert_probability": 0.01,
    "partner_exclusion_list": "Partner brand exclusions",
    "brite_admins": ["admin@brite.example", "900001"],
    "emergency_stop": False,
}


class FakeAdapter:
    """A platform adapter that records every call.

    It offers only the four methods the watchdog may use. Asking it for anything else —
    a budget, a bid, an ad edit — fails the test on the spot.
    """

    def __init__(self, accounts, stats=None, settings=None):
        self._accounts = accounts
        self._stats = stats or {}
        self._settings = settings or {}
        self._paused = set()
        self.calls = []

    def accounts(self):
        self.calls.append(("accounts", None))
        return list(self._accounts)

    def daily_stats(self, account, start, end):
        self.calls.append(("daily_stats", account.id))
        return [d for d in self._stats.get(account.id, []) if start <= d.day <= end]

    def settings(self, account):
        self.calls.append(("settings", account.id))
        return self._settings.get(account.id, {})

    def pause(self, account):
        self.calls.append(("pause", account.id))
        if account.id in self._paused:
            return []
        self._paused.add(account.id)
        return [f"{account.name} campaign"]

    def __getattr__(self, name):
        raise AssertionError(f"the watchdog asked the adapter for {name!r}; it may only pause")

    def paused(self):
        return [account_id for call, account_id in self.calls if call == "pause"]


def week(mon, tue, wed, leads=0):
    return [DayStats(MON, mon, 0), DayStats(TUE, tue, 0), DayStats(WED, wed, leads)]


def test_vendor_account_ahead_of_pace_is_paused_and_named_in_an_alert():
    google = FakeAdapter(
        [BRITE_G, VENDOR_G],
        stats={BRITE_G.id: week(100, 100, 60), VENDOR_G.id: week(100, 100, 150)},
    )
    meta = FakeAdapter([BRITE_M], stats={BRITE_M.id: week(100, 100, 50)})
    alerts = []

    hourly([google, meta], CONFIG, alerts.append, NOON_WEDNESDAY)

    assert google.paused() == [VENDOR_G.id]
    assert meta.paused() == []
    assert len(alerts) == 1
    assert VENDOR_G.name in alerts[0]
    # The alert gives the expected range for this hour, not a bare threshold:
    # 100 a day, half the day gone, tolerance 1.5 -> 33.33 to 75.00.
    assert "33.33" in alerts[0] and "75.00" in alerts[0]
    assert "150.00" in alerts[0]


def test_account_over_its_weekly_share_is_paused_even_when_today_is_on_pace():
    # 380 + 330 + 40 = 750 this week, over its 700 share; today's 40 is inside today's range.
    meta = FakeAdapter([VENDOR_M], stats={VENDOR_M.id: week(380, 330, 40)})
    alerts = []

    hourly([meta], CONFIG, alerts.append, NOON_WEDNESDAY)

    assert meta.paused() == [VENDOR_M.id]
    assert VENDOR_M.name in alerts[0]
    assert "750.00" in alerts[0] and "700.00" in alerts[0]


def test_a_quiet_hour_inside_the_expected_range_raises_nothing():
    google = FakeAdapter([BRITE_G], stats={BRITE_G.id: week(100, 100, 0)})
    alerts = []

    hourly([google], CONFIG, alerts.append, NOON_WEDNESDAY)

    assert google.paused() == []
    assert alerts == []


def test_an_account_already_paused_is_not_alerted_again_next_hour():
    google = FakeAdapter([VENDOR_G], stats={VENDOR_G.id: week(100, 100, 150)})
    alerts = []

    hourly([google], CONFIG, alerts.append, NOON_WEDNESDAY)
    hourly([google], CONFIG, alerts.append, NOON_WEDNESDAY)

    assert google.paused() == [VENDOR_G.id, VENDOR_G.id]  # re-paused, in case someone re-enabled it
    assert len(alerts) == 1


UNMAPPED_G = Account("google", "100-000-0099", "Account missing from the config", TZ)


def all_accounts():
    quiet = week(10, 10, 0)
    google = FakeAdapter([BRITE_G, VENDOR_G, UNMAPPED_G], stats={a.id: quiet for a in (BRITE_G, VENDOR_G)})
    meta = FakeAdapter([BRITE_M, VENDOR_M], stats={a.id: quiet for a in (BRITE_M, VENDOR_M)})
    return google, meta


def test_emergency_stop_pauses_every_account_on_both_platforms():
    google, meta = all_accounts()
    alerts = []

    emergency_stop([google, meta], alerts.append)

    assert google.paused() == [BRITE_G.id, VENDOR_G.id, UNMAPPED_G.id]
    assert meta.paused() == [BRITE_M.id, VENDOR_M.id]
    assert len(alerts) == 1
    assert all(a.name in alerts[0] for a in (BRITE_G, VENDOR_G, UNMAPPED_G, BRITE_M, VENDOR_M))


def test_while_the_stop_flag_is_on_every_hourly_run_pauses_everything():
    google, meta = all_accounts()

    hourly([google, meta], {**CONFIG, "emergency_stop": True}, lambda _: None, NOON_WEDNESDAY)

    assert google.paused() == [BRITE_G.id, VENDOR_G.id, UNMAPPED_G.id]
    assert meta.paused() == [BRITE_M.id, VENDOR_M.id]


# The agreed settings, as an adapter reports them: each "must be off" setting lists what has
# it on (empty = fine); negative lists are per campaign; the spending limit and who can change it.
CLEAN = {
    "auto_apply": [],
    "auto_ad_edits": [],
    "search_partners": [],
    "ai_max": [],
    "broad_match": [],
    "non_presence": [],
    "negative_lists": {"Territory B": ["Shared negatives", "Partner brand exclusions"]},
    "spending_limit": 3000.0,
    "limit_holders": ["admin@brite.example"],
}


@pytest.mark.parametrize(
    ("drift", "named"),
    [
        ({"auto_apply": ["CAMPAIGN_BUDGET"]}, "auto-apply"),
        ({"auto_ad_edits": ["Territory B"]}, "automatic ad edits"),
        ({"search_partners": ["Territory B"]}, "search partners"),
        ({"ai_max": ["Territory B"]}, "AI Max"),
        ({"broad_match": ["Territory B"]}, "broad match"),
        ({"non_presence": ["Territory B"]}, "Presence"),
        ({"negative_lists": {"Territory B": ["Shared negatives"]}}, "partner brand exclusions"),
        ({"spending_limit": None}, "spending limit"),
        ({"limit_holders": ["admin@brite.example", "someone@vendor.example"]}, "someone@vendor.example"),
    ],
)
def test_daily_audit_flags_each_drifted_setting(drift, named):
    google = FakeAdapter([VENDOR_G], settings={VENDOR_G.id: {**CLEAN, **drift}})
    posted = []

    findings = audit([google], CONFIG, posted.append, NOON_WEDNESDAY)

    assert len(findings) == 1
    assert VENDOR_G.name in findings[0] and named in findings[0]
    assert findings[0] in posted[0]


def test_a_clean_audit_still_posts_so_silence_means_the_watchdog_is_down():
    google = FakeAdapter([VENDOR_G], settings={VENDOR_G.id: CLEAN})
    meta = FakeAdapter([VENDOR_M], settings={VENDOR_M.id: {"auto_ad_edits": [], "spending_limit": 3000.0, "limit_holders": ["900001"]}})
    posted = []

    findings = audit([google, meta], CONFIG, posted.append, NOON_WEDNESDAY)

    assert findings == []
    assert len(posted) == 1 and "2 accounts" in posted[0]


def test_audit_names_an_account_the_config_does_not_cover():
    google = FakeAdapter([UNMAPPED_G], settings={UNMAPPED_G.id: CLEAN})

    findings = audit([google], CONFIG, lambda _: None, NOON_WEDNESDAY)

    assert len(findings) == 1
    assert UNMAPPED_G.name in findings[0] and "not in the watchdog config" in findings[0]


def last_seven_days(spend_per_day, leads):
    # The seven full days before NOON_WEDNESDAY: Wed 2026-10-28 to Tue 2026-11-03.
    return [DayStats(date(2026, 10, 28) + timedelta(days=i), spend_per_day, leads if i == 6 else 0) for i in range(7)]


@pytest.mark.parametrize(
    ("spend_per_day", "leads", "alerted"),
    [
        (30.0, 0, False),  # 210 spent: 0.8 to 4.2 leads expected, so zero is normal noise
        (300.0, 5, False),  # 2,100 spent: 8.4 to 42 expected; 5 is low but not improbable
        (300.0, 0, True),  # 2,100 spent and nothing: tracking or the account is broken
    ],
)
def test_lead_alert_uses_the_expected_range_not_zero_leads(spend_per_day, leads, alerted):
    google = FakeAdapter([BRITE_G], stats={BRITE_G.id: last_seven_days(spend_per_day, leads)}, settings={BRITE_G.id: CLEAN})

    findings = audit([google], CONFIG, lambda _: None, NOON_WEDNESDAY)

    assert bool(findings) is alerted
    if alerted:
        assert BRITE_G.name in findings[0]
        assert "2,100.00" in findings[0] and "8.4–42.0" in findings[0]


ADAPTER_METHODS = {"accounts", "daily_stats", "settings", "pause"}


def test_the_watchdog_uses_nothing_but_reads_and_pause():
    google = FakeAdapter([BRITE_G, VENDOR_G], stats={VENDOR_G.id: week(100, 100, 150)}, settings={VENDOR_G.id: {**CLEAN, "search_partners": ["Territory B"]}})
    meta = FakeAdapter([VENDOR_M], stats={VENDOR_M.id: week(380, 330, 40)})

    hourly([google, meta], CONFIG, lambda _: None, NOON_WEDNESDAY)
    audit([google, meta], CONFIG, lambda _: None, NOON_WEDNESDAY)
    emergency_stop([google, meta], lambda _: None)

    # FakeAdapter fails on any other attribute, so a budget, bid or ad call cannot hide here.
    called = {name for fake in (google, meta) for name, _ in fake.calls}
    assert called <= ADAPTER_METHODS
    assert {name for name in called if name not in {"accounts", "daily_stats", "settings"}} == {"pause"}


# ---------------------------------------------------------------------------------------
# The real adapters, at their HTTP boundary. Nothing reaches the network: `http` is a fake
# that answers from canned (synthetic) API responses and records every request.
# ---------------------------------------------------------------------------------------

from ads_watchdog.platforms import GoogleAds, MetaAds  # noqa: E402

FAKE_ENV = {
    "GOOGLE_ADS_DEVELOPER_TOKEN": "dev-token",
    "GOOGLE_ADS_CLIENT_ID": "client-id",
    "GOOGLE_ADS_CLIENT_SECRET": "client-secret",
    "GOOGLE_ADS_REFRESH_TOKEN": "refresh-token",
    "GOOGLE_ADS_LOGIN_CUSTOMER_ID": "1000000000",
    "META_ADS_SYSTEM_USER_TOKEN": "system-user-token",
    "META_BUSINESS_ID": "4000000",
}


class FakeHttp:
    def __init__(self, answer):
        self._answer = answer
        self.requests = []

    def __call__(self, method, url, headers=None, body=None, form=False):
        self.requests.append((method, url, body))
        return self._answer(method, url, body)


def google_api(method, url, body):
    if "oauth2" in url:
        return {"access_token": "access-token"}
    if url.endswith("campaigns:mutate"):
        return {"results": [{}]}
    query = body["query"]
    rows = []
    if "FROM customer_client" in query:
        rows = [{"customerClient": {"id": "1000000002", "descriptiveName": VENDOR_G.name, "timeZone": TZ}}]
    elif "FROM customer " in query:
        rows = [
            {"segments": {"date": "2026-11-03"}, "metrics": {"costMicros": "100000000", "conversions": 1.0}},
            {"segments": {"date": "2026-11-04"}, "metrics": {"costMicros": "150000000"}},
        ]
    elif "FROM campaign " in query:
        rows = [
            {
                "campaign": {
                    "resourceName": "customers/1000000002/campaigns/11",
                    "name": "Territory B",
                    "networkSettings": {"targetSearchNetwork": True},
                    "geoTargetTypeSetting": {"positiveGeoTargetType": "PRESENCE"},
                }
            }
        ]
    return [{"results": rows}]


def meta_api(method, url, body):
    if method == "POST":
        return {"success": True}
    path = url.split("graph.facebook.com/")[1].split("?")[0].split("/", 1)[1]
    if path.endswith("owned_ad_accounts"):
        return {"data": [{"id": VENDOR_M.id, "name": VENDOR_M.name, "timezone_name": TZ}]}
    if path.endswith("/campaigns"):
        return {"data": [{"id": "3000001", "name": "Territory D", "status": "ACTIVE"}, {"id": "3000002", "name": "Old test", "status": "PAUSED"}]}
    if path.endswith("/insights"):
        return {"data": [{"date_start": "2026-11-04", "spend": "380.5", "actions": [{"action_type": "lead", "value": "2"}]}]}
    if path.endswith("/ads"):
        return {"data": [{"name": "Ad 1", "creative": {"degrees_of_freedom_spec": {"creative_features_spec": {"image_touchups": {"enroll_status": "OPT_IN"}}}}}]}
    if path.endswith("/assigned_users"):
        return {"data": [{"id": "900001", "tasks": ["MANAGE", "ADVERTISE"]}, {"id": "900777", "tasks": ["ADVERTISE"]}]}
    return {"id": VENDOR_M.id, "spend_cap": "300000"}


def test_real_adapters_offer_no_method_but_reads_and_pause():
    for adapter in (GoogleAds, MetaAds):
        assert {name for name in vars(adapter) if not name.startswith("_")} == ADAPTER_METHODS


def test_real_google_adapter_sends_no_write_but_a_campaign_pause():
    http = FakeHttp(google_api)
    google = GoogleAds(env=FAKE_ENV, http=http)
    config = {**CONFIG, "shares": {"google:1000000002": 0.1}}
    alerts = []

    hourly([google], config, alerts.append, NOON_WEDNESDAY)
    findings = audit([google], config, alerts.append, NOON_WEDNESDAY)
    emergency_stop([google], alerts.append)

    writes = [(url, body) for method, url, body in http.requests if not url.endswith(":searchStream") and "oauth2" not in url]
    assert writes, "the breach and the emergency stop should each have paused"
    for url, body in writes:
        assert url.endswith("/customers/1000000002/campaigns:mutate")
        assert body == {"operations": [{"update": {"resourceName": "customers/1000000002/campaigns/11", "status": "PAUSED"}, "updateMask": "status"}]}
    assert VENDOR_G.name in alerts[0] and "150.00" in alerts[0]
    assert any("search partners on: Territory B" in f for f in findings)


def test_real_meta_adapter_sends_no_write_but_a_campaign_pause():
    http = FakeHttp(meta_api)
    meta = MetaAds(env=FAKE_ENV, http=http)
    config = {**CONFIG, "shares": {VENDOR_M.key: 0.1}}

    hourly([meta], config, lambda _: None, NOON_WEDNESDAY)
    findings = audit([meta], config, lambda _: None, NOON_WEDNESDAY)
    emergency_stop([meta], lambda _: None)

    writes = [(method, url, body) for method, url, body in http.requests if method != "GET"]
    assert writes, "the breach and the emergency stop should each have paused"
    for method, url, body in writes:
        assert (method, url.rsplit("/", 1)[1], body) == ("POST", "3000001", {"status": "PAUSED"})
    assert any("automatic ad edits on: Ad 1" in f for f in findings)
    assert not any("not a Brite admin" in f for f in findings)


class BrokenAdapter:
    def accounts(self):
        raise ConnectionError("platform unreachable")


@pytest.mark.parametrize("job", ["hourly", "audit", "stop"])
def test_one_platform_failing_does_not_stop_the_other_and_is_alerted(job):
    from ads_watchdog.__main__ import run

    google, meta = all_accounts()
    alerts = []

    failures = run(job, [BrokenAdapter(), meta], {**CONFIG, "emergency_stop": job == "stop"}, alerts.append, NOON_WEDNESDAY)

    assert failures == 1
    assert any("FAILED" in a and "platform unreachable" in a for a in alerts)
    assert meta.calls, "the healthy platform was still checked"
    if job == "stop":
        assert meta.paused() == [BRITE_M.id, VENDOR_M.id]
