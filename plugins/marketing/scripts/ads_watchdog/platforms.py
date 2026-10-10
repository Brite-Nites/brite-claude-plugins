"""The real platform adapters: the Google Ads API (REST) and the Meta Marketing API (Graph),
over plain HTTPS with the standard library. No SDK, so the package imports anywhere.

Each adapter has the four methods `watchdog.py` describes and nothing else. The only write
either can send is one campaign's status set to PAUSED.

Not yet run against a live account: Brite-held API credentials do not exist yet (BC-28209).
The request and response shapes follow the published API references.

Environment (secrets come from the runner, never from this repo):
  GOOGLE_ADS_DEVELOPER_TOKEN, GOOGLE_ADS_CLIENT_ID, GOOGLE_ADS_CLIENT_SECRET,
  GOOGLE_ADS_REFRESH_TOKEN  — OAuth for a Brite-held user with admin access on the manager account
  GOOGLE_ADS_LOGIN_CUSTOMER_ID — the manager account id, digits only
  GOOGLE_ADS_API_VERSION    — optional, default v24 (v22 sunsets October 2026)
  META_ADS_SYSTEM_USER_TOKEN — a Brite business system user with access to every ad account
  META_BUSINESS_ID           — the business portfolio that owns the ad accounts
  META_GRAPH_API_VERSION     — optional, default v24.0
"""

from __future__ import annotations

import json
import os
import urllib.parse
import urllib.request
from datetime import date

from .watchdog import Account, DayStats


def http(method: str, url: str, headers: dict | None = None, body: dict | None = None, form: bool = False):
    data = None if body is None else (urllib.parse.urlencode(body) if form else json.dumps(body)).encode()
    content_type = "application/x-www-form-urlencoded" if form else "application/json"
    request = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": content_type, **(headers or {})})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


class GoogleAds:
    def __init__(self, env=os.environ, http=http):
        self._env, self._http, self._token = env, http, None
        self._base = f"https://googleads.googleapis.com/{env.get('GOOGLE_ADS_API_VERSION', 'v24')}"

    def _headers(self) -> dict:
        if self._token is None:  # one token per adapter; the runner builds a new adapter each run
            self._token = self._http(
                "POST",
                "https://oauth2.googleapis.com/token",
                body={
                    "client_id": self._env["GOOGLE_ADS_CLIENT_ID"],
                    "client_secret": self._env["GOOGLE_ADS_CLIENT_SECRET"],
                    "refresh_token": self._env["GOOGLE_ADS_REFRESH_TOKEN"],
                    "grant_type": "refresh_token",
                },
                form=True,
            )["access_token"]
        return {
            "Authorization": f"Bearer {self._token}",
            "developer-token": self._env["GOOGLE_ADS_DEVELOPER_TOKEN"],
            "login-customer-id": self._env["GOOGLE_ADS_LOGIN_CUSTOMER_ID"],
        }

    def _search(self, customer_id: str, query: str) -> list[dict]:
        url = f"{self._base}/customers/{customer_id}/googleAds:searchStream"
        return [row for batch in self._http("POST", url, self._headers(), {"query": query}) for row in batch.get("results", [])]

    def accounts(self) -> list[Account]:
        rows = self._search(
            self._env["GOOGLE_ADS_LOGIN_CUSTOMER_ID"],
            "SELECT customer_client.id, customer_client.descriptive_name, customer_client.time_zone "
            "FROM customer_client WHERE customer_client.manager = FALSE AND customer_client.status = 'ENABLED'",
        )
        return [Account("google", c["id"], c.get("descriptiveName", ""), c["timeZone"]) for c in (r["customerClient"] for r in rows)]

    def daily_stats(self, account: Account, start: date, end: date) -> list[DayStats]:
        rows = self._search(
            account.id,
            "SELECT segments.date, metrics.cost_micros, metrics.conversions "
            f"FROM customer WHERE segments.date BETWEEN '{start}' AND '{end}'",
        )
        return [
            DayStats(date.fromisoformat(r["segments"]["date"]), int(r.get("metrics", {}).get("costMicros", 0)) / 1e6, float(r.get("metrics", {}).get("conversions", 0)))
            for r in rows
        ]

    def settings(self, account: Account) -> dict:
        def names(query):
            return [r["campaign"]["name"] for r in self._search(account.id, query)]

        campaigns = [
            r["campaign"]
            for r in self._search(
                account.id,
                "SELECT campaign.name, campaign.network_settings.target_search_network, "
                "campaign.geo_target_type_setting.positive_geo_target_type, campaign.ai_max_setting.enable_ai_max, "
                "campaign.keyword_match_type, campaign.asset_automation_settings "
                "FROM campaign WHERE campaign.status = 'ENABLED'",
            )
        ]
        negative_lists = {c["name"]: [] for c in campaigns}
        for r in self._search(
            account.id,
            "SELECT campaign.name, shared_set.name FROM campaign_shared_set WHERE shared_set.type = 'NEGATIVE_KEYWORDS' "
            "AND campaign_shared_set.status = 'ENABLED' AND campaign.status = 'ENABLED'",
        ):
            negative_lists.setdefault(r["campaign"]["name"], []).append(r["sharedSet"]["name"])
        today = date.today().isoformat()
        limits = [
            int(b["approvedSpendingLimitMicros"]) / 1e6
            for b in (
                r["accountBudget"]
                for r in self._search(
                    account.id,
                    "SELECT account_budget.approved_spending_limit_micros, account_budget.approved_end_date_time "
                    "FROM account_budget WHERE account_budget.status = 'APPROVED'",
                )
            )
            if "approvedSpendingLimitMicros" in b and b.get("approvedEndDateTime", "9999") >= today
        ]
        return {
            "auto_apply": [
                r["recommendationSubscription"]["type"]
                for r in self._search(
                    account.id,
                    "SELECT recommendation_subscription.type FROM recommendation_subscription "
                    "WHERE recommendation_subscription.status = 'ENABLED'",
                )
            ],
            "auto_ad_edits": [
                c["name"] for c in campaigns if any(s.get("assetAutomationStatus") == "OPTED_IN" for s in c.get("assetAutomationSettings", []))
            ],
            "search_partners": [c["name"] for c in campaigns if c.get("networkSettings", {}).get("targetSearchNetwork")],
            "ai_max": [c["name"] for c in campaigns if c.get("aiMaxSetting", {}).get("enableAiMax")],
            "broad_match": sorted(
                {c["name"] for c in campaigns if c.get("keywordMatchType") == "BROAD"}
                | set(
                    names(
                        "SELECT campaign.name FROM ad_group_criterion WHERE ad_group_criterion.type = 'KEYWORD' "
                        "AND ad_group_criterion.keyword.match_type = 'BROAD' AND ad_group_criterion.negative = FALSE "
                        "AND ad_group_criterion.status = 'ENABLED' AND campaign.status = 'ENABLED'"
                    )
                )
            ),
            "non_presence": [c["name"] for c in campaigns if c.get("geoTargetTypeSetting", {}).get("positiveGeoTargetType") != "PRESENCE"],
            "negative_lists": negative_lists,
            "spending_limit": max(limits, default=None),
            "limit_holders": [
                r["customerUserAccess"]["emailAddress"]
                for r in self._search(
                    account.id,
                    "SELECT customer_user_access.email_address FROM customer_user_access "
                    "WHERE customer_user_access.access_role = 'ADMIN'",
                )
            ],
        }

    def pause(self, account: Account) -> list[str]:
        rows = self._search(account.id, "SELECT campaign.resource_name, campaign.name FROM campaign WHERE campaign.status = 'ENABLED'")
        if rows:
            operations = [{"update": {"resourceName": r["campaign"]["resourceName"], "status": "PAUSED"}, "updateMask": "status"} for r in rows]
            self._http("POST", f"{self._base}/customers/{account.id}/campaigns:mutate", self._headers(), {"operations": operations})
        return [r["campaign"]["name"] for r in rows]


class MetaAds:
    def __init__(self, env=os.environ, http=http):
        self._env, self._http = env, http
        self._base = f"https://graph.facebook.com/{env.get('META_GRAPH_API_VERSION', 'v24.0')}"

    def _get(self, path: str, **params) -> dict:
        return self._http("GET", f"{self._base}/{path}?{urllib.parse.urlencode(params)}", self._auth())

    def _list(self, path: str, **params) -> list[dict]:
        page, rows = self._get(path, **params), []
        while True:
            rows += page.get("data", [])
            if not page.get("paging", {}).get("next"):
                return rows
            page = self._http("GET", page["paging"]["next"], self._auth())

    def _auth(self) -> dict:
        return {"Authorization": f"Bearer {self._env['META_ADS_SYSTEM_USER_TOKEN']}"}

    def accounts(self) -> list[Account]:
        rows = self._list(f"{self._env['META_BUSINESS_ID']}/owned_ad_accounts", fields="id,name,timezone_name")
        return [Account("meta", a["id"], a.get("name", ""), a["timezone_name"]) for a in rows]

    def daily_stats(self, account: Account, start: date, end: date) -> list[DayStats]:
        rows = self._list(
            f"{account.id}/insights",
            fields="spend,actions",
            time_increment=1,
            time_range=json.dumps({"since": str(start), "until": str(end)}),
        )
        return [
            DayStats(date.fromisoformat(r["date_start"]), float(r.get("spend", 0)), sum(float(a["value"]) for a in r.get("actions", []) if a["action_type"] == "lead"))
            for r in rows
        ]

    def settings(self, account: Account) -> dict:
        ads = self._list(f"{account.id}/ads", fields="name,creative{degrees_of_freedom_spec}", effective_status='["ACTIVE"]')
        users = self._list(f"{account.id}/assigned_users", business=self._env["META_BUSINESS_ID"], fields="id,tasks")
        # ponytail: spend_cap is in the currency's minor unit; /100 assumes a two-decimal currency (USD).
        cap = int(self._get(account.id, fields="spend_cap").get("spend_cap") or 0) / 100
        return {
            "auto_ad_edits": [
                ad["name"]
                for ad in ads
                if any(
                    f.get("enroll_status") == "OPT_IN"
                    for f in ad.get("creative", {}).get("degrees_of_freedom_spec", {}).get("creative_features_spec", {}).values()
                )
            ],
            "spending_limit": cap or None,
            "limit_holders": [u["id"] for u in users if "MANAGE" in u.get("tasks", [])],
        }

    def pause(self, account: Account) -> list[str]:
        running = [c for c in self._list(f"{account.id}/campaigns", fields="id,name,status") if c["status"] == "ACTIVE"]
        for campaign in running:
            self._http("POST", f"{self._base}/{campaign['id']}", self._auth(), {"status": "PAUSED"})
        return [c["name"] for c in running]
