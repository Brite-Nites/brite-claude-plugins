"""Real adapters for the ads-agent run: Google Ads and Meta (settings read, act-mode
writes), Snowflake, Slack, and Operations' capacity sheet (BC-28220, read only).

None of these accounts exist yet (BC-28209). Each adapter asserts its env vars when it
is built, so a missing secret fails loudly by name and never prints a value. Secrets
come from Bitwarden Secrets Manager (`bws run --project-id <ads-agent project> -- ...`,
ADR-044) or Railway service variables.

Third-party libraries load lazily inside methods: CI installs only pytest, so this
module must import on a stdlib-only interpreter. Runtime needs `google-ads`,
`snowflake-connector-python`, `cryptography` and, for the capacity sheet, `google-auth`.
Meta needs none: it is plain HTTPS.

Untested against the live APIs: they need the accounts above. The fakes in
`fakes.py` carry the same method names.
"""

from __future__ import annotations

import copy
import json
import os
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo


class MissingEnv(RuntimeError):
    pass


def _require(names):
    missing = [n for n in names if not os.environ.get(n)]
    if missing:
        raise MissingEnv(f"missing env vars: {', '.join(missing)}")
    return {n: os.environ[n] for n in names}


def _http(method, url, headers, body=None):
    """One HTTPS call with an optional JSON body; returns the parsed JSON reply."""
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def _float_or_none(value):
    """A warehouse number (often a Decimal) as a float; a null stays None."""
    return None if value is None else float(value)


def _digits(value, what):
    """An id that goes into an API path: digits only, so a bad id cannot reach another path."""
    text = str(value)
    if not text.isdigit():
        raise ValueError(f"{what} {value!r} is not all digits")
    return text


class GoogleAds:
    """Reads campaign and ad settings. Act mode (BC-28216) writes through `apply`: a
    campaign's daily budget, or an ad's status. Nothing else is written."""

    platform = "google_ads"
    ENV = (
        "GOOGLE_ADS_DEVELOPER_TOKEN",
        "GOOGLE_ADS_CLIENT_ID",
        "GOOGLE_ADS_CLIENT_SECRET",
        "GOOGLE_ADS_REFRESH_TOKEN",
        "GOOGLE_ADS_LOGIN_CUSTOMER_ID",  # the manager account
    )
    # A campaign with this Google Ads label holds brand keywords; the agent never touches it
    # (ADR-0033 §2). Confirm the label with the Head of GTM before the first act run.
    BRAND_LABEL = "brand"
    QUERY = """
        SELECT campaign.id, campaign.name, campaign.primary_status_reasons,
               campaign_budget.amount_micros, campaign_budget.explicitly_shared
        FROM campaign
        WHERE campaign.status = 'ENABLED' AND campaign.advertising_channel_type = 'SEARCH'
    """
    LABELS = "SELECT campaign.id, label.name FROM campaign_label"
    ADS = """
        SELECT campaign.id, ad_group.id, ad_group_ad.ad.id, ad_group_ad.ad.name, ad_group_ad.status
        FROM ad_group_ad
        WHERE campaign.status = 'ENABLED' AND campaign.advertising_channel_type = 'SEARCH'
          AND ad_group_ad.status != 'REMOVED'
    """

    def __init__(self):
        self._env = _require(self.ENV)

    def _client(self):
        from google.ads.googleads.client import GoogleAdsClient

        e = self._env
        return GoogleAdsClient.load_from_dict({
            "developer_token": e["GOOGLE_ADS_DEVELOPER_TOKEN"],
            "client_id": e["GOOGLE_ADS_CLIENT_ID"],
            "client_secret": e["GOOGLE_ADS_CLIENT_SECRET"],
            "refresh_token": e["GOOGLE_ADS_REFRESH_TOKEN"],
            "login_customer_id": e["GOOGLE_ADS_LOGIN_CUSTOMER_ID"],
            "use_proto_plus": True,
        })

    def read_settings(self, account_ids):
        service = self._client().get_service("GoogleAdsService")
        out = []
        for account_id in account_ids:
            brand = {
                str(row.campaign.id)
                for row in service.search(customer_id=account_id, query=self.LABELS)
                if row.label.name.lower() == self.BRAND_LABEL
            }
            out += [
                {
                    "account_id": account_id,
                    "campaign_id": str(row.campaign.id),
                    "campaign_name": row.campaign.name,
                    "daily_budget_micros": row.campaign_budget.amount_micros,
                    "budget_limited": any(r.name == "BUDGET_CONSTRAINED" for r in row.campaign.primary_status_reasons),
                    "budget_shared": row.campaign_budget.explicitly_shared,
                    "brand": str(row.campaign.id) in brand,
                }
                for row in service.search(customer_id=account_id, query=self.QUERY)
            ]
        return out

    def read_ads(self, account_ids):
        service = self._client().get_service("GoogleAdsService")
        return [
            {
                "account_id": account_id,
                "campaign_id": str(row.campaign.id),
                "ad_group_id": str(row.ad_group.id),
                "ad_id": str(row.ad_group_ad.ad.id),
                "ad_name": row.ad_group_ad.ad.name or f"ad {row.ad_group_ad.ad.id}",
                "status": row.ad_group_ad.status.name,
            }
            for account_id in account_ids
            for row in service.search(customer_id=account_id, query=self.ADS)
        ]

    def apply(self, change):
        """Write one change, or raise. A budget write first re-reads the campaign's budget
        and writes only if it still holds the planned old value. A campaign's status is
        written only to pause it (the capacity pause, BC-28220), never to turn it on."""
        from google.api_core import protobuf_helpers

        client = self._client()
        account, where = change["account_id"], (change["target_type"], change["field"])
        if where == ("campaign", "daily_budget_micros"):
            query = (
                "SELECT campaign.campaign_budget, campaign_budget.amount_micros FROM campaign "
                f"WHERE campaign.id = {int(change['target_id'])}"
            )
            rows = list(client.get_service("GoogleAdsService").search(customer_id=account, query=query))
            if len(rows) != 1:
                raise RuntimeError(f"campaign {change['target_id']} not found")
            if rows[0].campaign_budget.amount_micros != change["old"]:
                raise RuntimeError("the budget changed after the plan; nothing written")
            op = client.get_type("CampaignBudgetOperation")
            op.update.resource_name = rows[0].campaign.campaign_budget
            op.update.amount_micros = int(change["new"])
            client.copy_from(op.update_mask, protobuf_helpers.field_mask(None, op.update._pb))
            client.get_service("CampaignBudgetService").mutate_campaign_budgets(customer_id=account, operations=[op])
        elif where == ("ad", "status") and change["new"] in ("ENABLED", "PAUSED"):
            ad_group_id, ad_id = (str(int(x)) for x in change["target_id"].split("~"))
            service = client.get_service("AdGroupAdService")
            op = client.get_type("AdGroupAdOperation")
            op.update.resource_name = service.ad_group_ad_path(account, ad_group_id, ad_id)
            op.update.status = getattr(client.enums.AdGroupAdStatusEnum, change["new"])
            client.copy_from(op.update_mask, protobuf_helpers.field_mask(None, op.update._pb))
            service.mutate_ad_group_ads(customer_id=account, operations=[op])
        elif where == ("campaign", "status") and (change["old"], change["new"]) == ("ENABLED", "PAUSED"):
            service = client.get_service("CampaignService")
            op = client.get_type("CampaignOperation")
            op.update.resource_name = service.campaign_path(account, str(int(change["target_id"])))
            op.update.status = client.enums.CampaignStatusEnum.PAUSED
            client.copy_from(op.update_mask, protobuf_helpers.field_mask(None, op.update._pb))
            service.mutate_campaigns(customer_id=account, operations=[op])
        else:
            raise NotImplementedError(f"{where[0]} {where[1]} -> {change['new']} is not built for Google Ads")


def _act(account_id):
    """The Graph API id of an ad account: the snapshot's digits, prefixed with act_."""
    return "act_" + _digits(str(account_id).removeprefix("act_"), "ad account id")


def _meta_goal(ad_set):
    """The run's name for what an ad set optimises for. leads: the pixel's Lead event on a
    site ad set, or an instant form's leads. booked_appointments: Meta's Schedule event on a
    site ad set, or conversion leads (QUALITY_LEAD) on an instant form. Any other goal keeps
    Meta's own name, and the agent never switches it."""
    goal = ad_set.get("optimization_goal")
    event = (ad_set.get("promoted_object") or {}).get("custom_event_type")
    if goal == "LEAD_GENERATION" or (goal == "OFFSITE_CONVERSIONS" and event == "LEAD"):
        return "leads"
    if goal == "QUALITY_LEAD" or (goal == "OFFSITE_CONVERSIONS" and event == "SCHEDULE"):
        return "booked_appointments"
    return goal


class MetaAds:
    """Reads campaign, ad set and ad settings through the Meta Graph API. Act mode
    (BC-28218) writes through `apply`: an ad set's daily budget, an ad's status, an ad
    set's switch from optimising for leads to booked appointments, or an ad set paused for
    capacity (BC-28220). Nothing else is written: no targeting, no creative, no campaign,
    ad set or ad is created, and no ad set is turned on.

    Plain HTTPS, no SDK. The watchdog has its own Meta adapter (ads_watchdog/platforms.py);
    the two share no code, only the env var names.

    Budgets: Meta counts in the currency's minor unit (cents), the run in micros, so one
    cent is 10,000 micros. USD accounts only: any other currency stops the read.

    Settings rows are one per active ad set, carrying its campaign. budget_level says who
    holds the daily budget: the ad set, or its campaign (Advantage campaign budget), or
    None for a lifetime budget. Only an ad set's own budget is ever moved; the others are
    reported as shared. A campaign budget is counted once per ad set in the weekly ceiling,
    as Google counts a shared budget once per campaign: the total errs high, never low.
    budget_limited is always False here; the run derives it from `read_spend`.

    Untested against the live API. Before the first act run, confirm with the Head of GTM:
    the `brand` ad label, and the booked-appointment events in `_meta_goal` (Meta's
    Schedule event on the site pixel, conversion leads on instant forms)."""

    platform = "meta_ads"
    ENV = ("META_ADS_SYSTEM_USER_TOKEN",)  # a Brite business system user with access to the ad accounts
    # A campaign with this ad label holds brand ads; the agent never touches it (ADR-0033 §2).
    BRAND_LABEL = "brand"
    MICROS_PER_CENT = 10_000
    STATUS = {"ACTIVE": "ENABLED", "PAUSED": "PAUSED"}  # Meta's ad status: the run's name
    AD_SET_FIELDS = ("id,name,campaign_id,daily_budget,lifetime_budget,optimization_goal,"
                     "promoted_object,destination_type,targeting")

    def __init__(self, http=_http):
        self._env = _require(self.ENV)
        self._http = http
        self._base = f"https://graph.facebook.com/{os.environ.get('META_GRAPH_API_VERSION', 'v24.0')}"

    def _auth(self):
        return {"Authorization": f"Bearer {self._env['META_ADS_SYSTEM_USER_TOKEN']}"}

    def _get(self, path, **params):
        return self._http("GET", f"{self._base}/{path}?{urllib.parse.urlencode(params)}", self._auth())

    def _list(self, path, **params):
        page, rows = self._get(path, **params), []
        while True:
            rows += page.get("data", [])
            following = page.get("paging", {}).get("next")
            if not following:
                return rows
            if not following.startswith("https://graph.facebook.com/"):  # the token goes nowhere else
                raise RuntimeError("a paging link left graph.facebook.com; stopped")
            page = self._http("GET", following, self._auth())

    def read_settings(self, account_ids):
        out = []
        for account_id in account_ids:
            act = _act(account_id)
            currency = self._get(act, fields="currency").get("currency")
            if currency != "USD":
                raise RuntimeError(f"ad account {account_id} bills in {currency}, not USD: budget units unknown")
            active = '["ACTIVE"]'
            campaigns = {c["id"]: c for c in self._list(
                f"{act}/campaigns", fields="id,name,daily_budget,lifetime_budget,adlabels{name}", effective_status=active)}
            ad_sets = [a for a in self._list(f"{act}/adsets", fields=self.AD_SET_FIELDS, effective_status=active)
                       if a["campaign_id"] in campaigns]
            subtypes = self._audience_subtypes(act, ad_sets)
            for a in ad_sets:
                camp = campaigns[a["campaign_id"]]
                own, theirs = int(a.get("daily_budget") or 0), int(camp.get("daily_budget") or 0)
                level = "ad_set" if own else "campaign" if theirs else None
                labels = camp.get("adlabels") or []
                labels = labels.get("data", []) if isinstance(labels, dict) else labels
                out.append({
                    "account_id": account_id,
                    "campaign_id": camp["id"],
                    "campaign_name": camp["name"],
                    "ad_set_id": a["id"],
                    "ad_set_name": a["name"],
                    "daily_budget_micros": (own or theirs) * self.MICROS_PER_CENT or None,
                    "budget_level": level,
                    "budget_limited": False,
                    "budget_shared": level != "ad_set",
                    "brand": any((x.get("name") or "").lower() == self.BRAND_LABEL for x in labels),
                    "status": "ENABLED",
                    "optimization_goal": _meta_goal(a),
                    "destination_type": a.get("destination_type"),
                    "targeting": self._with_subtypes(a.get("targeting"), subtypes),
                })
        return out

    def _audience_subtypes(self, act, ad_sets):
        """Each custom audience's subtype (LOOKALIKE, CUSTOM, ...) by id, from the account's
        own audiences. One the account cannot list stays unknown, and the run's Housing check
        treats an unknown audience as a lookalike."""
        if not any((a.get("targeting") or {}).get(side) for a in ad_sets
                   for side in ("custom_audiences", "excluded_custom_audiences")):
            return {}
        return {c["id"]: c.get("subtype") for c in self._list(f"{act}/customaudiences", fields="id,subtype")}

    @staticmethod
    def _with_subtypes(targeting, subtypes):
        t = copy.deepcopy(targeting or {})
        for side in ("custom_audiences", "excluded_custom_audiences"):
            for audience in t.get(side) or []:
                audience["subtype"] = subtypes.get(audience.get("id"))
        return t

    def read_ads(self, account_ids):
        out = []
        for account_id in account_ids:
            for ad in self._list(f"{_act(account_id)}/ads", fields="id,name,campaign_id,adset_id,status,created_time"):
                if ad.get("status") not in self.STATUS:  # archived and deleted ads are never touched
                    continue
                out.append({
                    "account_id": account_id,
                    "campaign_id": ad["campaign_id"],
                    "ad_group_id": ad["adset_id"],
                    "ad_id": ad["id"],
                    "ad_name": ad.get("name") or f"ad {ad['id']}",
                    "status": self.STATUS[ad["status"]],
                    "created_time": datetime.strptime(ad["created_time"], "%Y-%m-%dT%H:%M:%S%z").isoformat(),
                })
        return out

    def read_spend(self, account_ids, day):
        """One day's spend in dollars per ad set, and per campaign as its ad sets' sum, from
        the insights API (read only). `day` is YYYY-MM-DD; Meta reads it in the ad account's
        time zone. An ad set or campaign with no row has no spend to report."""
        out = []
        for account_id in account_ids:
            rows = self._list(f"{_act(account_id)}/insights", level="adset", fields="adset_id,campaign_id,spend",
                              time_range=json.dumps({"since": day, "until": day}))
            campaigns = {}
            for r in rows:
                spend = float(r.get("spend") or 0)
                out.append({"account_id": account_id, "level": "ad_set", "id": r["adset_id"], "spend": spend})
                campaigns[r["campaign_id"]] = campaigns.get(r["campaign_id"], 0.0) + spend
            out += [{"account_id": account_id, "level": "campaign", "id": c, "spend": s} for c, s in campaigns.items()]
        return out

    def apply(self, change):
        """Write one change, or raise. Each write first re-reads the object, and writes only
        if it sits in the planned ad account and still holds the planned old value."""
        account = _digits(str(change["account_id"]).removeprefix("act_"), "ad account id")
        where = (change["target_type"], change["field"])
        if where == ("ad_set", "daily_budget_micros"):
            ad_set_id = _digits(change["target_id"], "ad set id")
            now = self._reread(ad_set_id, account, "daily_budget")
            if int(now.get("daily_budget") or 0) * self.MICROS_PER_CENT != change["old"]:
                raise RuntimeError("the budget changed after the plan; nothing written")
            cents, rest = divmod(int(change["new"]), self.MICROS_PER_CENT)
            if rest or cents <= 0:
                raise ValueError(f"{change['new']} micros is not a whole number of cents above zero")
            self._post(ad_set_id, {"daily_budget": cents})
        elif where == ("ad", "status") and change["new"] in ("ENABLED", "PAUSED"):
            ad_id = _digits(str(change["target_id"]).split("~")[-1], "ad id")
            now = self._reread(ad_id, account, "status")
            if self.STATUS.get(now.get("status")) != change["old"]:
                raise RuntimeError("the ad's status changed after the plan; nothing written")
            self._post(ad_id, {"status": "ACTIVE" if change["new"] == "ENABLED" else "PAUSED"})
        elif where == ("ad_set", "status") and (change["old"], change["new"]) == ("ENABLED", "PAUSED"):
            ad_set_id = _digits(change["target_id"], "ad set id")
            now = self._reread(ad_set_id, account, "status")
            if self.STATUS.get(now.get("status")) != "ENABLED":
                raise RuntimeError("the ad set is no longer active; nothing written")
            self._post(ad_set_id, {"status": "PAUSED"})
        elif where == ("ad_set", "optimization_goal") and (change["old"], change["new"]) == ("leads", "booked_appointments"):
            ad_set_id = _digits(change["target_id"], "ad set id")
            now = self._reread(ad_set_id, account, "optimization_goal,promoted_object")
            if _meta_goal(now) != "leads":
                raise RuntimeError("the ad set no longer optimises for leads; nothing written")
            if now["optimization_goal"] == "LEAD_GENERATION":
                self._post(ad_set_id, {"optimization_goal": "QUALITY_LEAD"})
            else:
                self._post(ad_set_id, {"promoted_object": {**now["promoted_object"], "custom_event_type": "SCHEDULE"}})
        else:
            raise NotImplementedError(f"{where[0]} {where[1]} -> {change['new']} is not built for Meta")

    def _reread(self, object_id, account, fields):
        """Read one object just before a write, and refuse the write if it sits in another
        ad account."""
        now = self._get(object_id, fields=f"account_id,{fields}")
        if str(now.get("account_id")) != account:
            raise RuntimeError(f"{object_id} is not in ad account {account}; nothing written")
        return now

    def _post(self, object_id, body):
        return self._http("POST", f"{self._base}/{object_id}", self._auth(), body)


class SnowflakeWarehouse:
    """Reads the results snapshots, the lead reconciliation, the territory weekly bookings,
    the creative inputs and the change log; writes the change log (MERGE on key). Approval,
    apply-result and frozen rows use the same columns as plan rows (BC-28216, BC-28219): no
    ALTER."""

    ENV = (
        "ADS_AGENT_SNOWFLAKE_ACCOUNT",
        "ADS_AGENT_SNOWFLAKE_USER",
        "ADS_AGENT_SNOWFLAKE_PRIVATE_KEY",  # PEM, unencrypted, key-pair auth
        "ADS_AGENT_SNOWFLAKE_ROLE",
        "ADS_AGENT_SNOWFLAKE_WAREHOUSE",
    )
    # One row per campaign over a trailing window, filtered to Brite's own system:
    # platform, account_id, campaign_id, territory, spend, conversions.
    # Not built yet: brite-data-platform builds it on PR #1402's int_paid_ads_campaign_daily,
    # the BC-28210 account map, and a conversion read rule. Rename here if it lands elsewhere.
    SNAPSHOT = "ANALYTICS.MARTS.MART_ADS_AGENT_RESULTS_SNAPSHOT"
    # The same at ad grain, for the ad kill rule (BC-28216): platform, account_id,
    # campaign_id, ad_group_id, ad_id, territory (the campaign's, for the season rules,
    # BC-28220), spend, conversions (a conversion is a lead), and booked_appointments, calls
    # counted (BC-28577), for Meta's path test and goal switch (BC-28218). On Meta,
    # ad_group_id is the ad set, so Meta's ad set results are these rows summed.
    # booked_appointments is built by brite-data-platform's BC-28577 spec; the read names it,
    # so a mart without it stops the run.
    AD_SNAPSHOT = "ANALYTICS.MARTS.MART_ADS_AGENT_AD_RESULTS_SNAPSHOT"
    AD_COLUMNS = ("platform", "account_id", "campaign_id", "ad_group_id", "ad_id", "territory", "spend",
                  "conversions", "booked_appointments")
    # One row per platform, territory and week, for the step-up gate (BC-28577): platform,
    # territory ('multi' for an ad set that serves several), week_start (the Monday of a
    # Monday-to-Sunday week, local time), spend (dollars) and four counts of booked
    # appointments, calls counted. In each count's name, paid means credited to that
    # platform's paid ads and all means any channel; new means new clients only and
    # any_client means any client. Built by brite-data-platform's BC-28577 spec.
    TERRITORY_WEEKLY = "ANALYTICS.MARTS.MART_ADS_AGENT_TERRITORY_WEEKLY"
    BOOKED_COLUMNS = ("booked_paid_new", "booked_paid_any_client", "booked_all_new", "booked_all_any_client")
    # One row per published ad: what went into it, and for an AI-edited photo who approved
    # it (BC-28221; brite-data-platform services/sql/ads_creative_inputs/schema.sql). An ad is
    # in the approved shared library when its row exists (BC-28218).
    CREATIVE_INPUTS = "ANALYTICS.OPERATIONS.ADS_CREATIVE_INPUTS"
    # One row per platform per day, for the data freeze (BC-28219): platform, lead_date,
    # platform_leads, britebase_leads, gap_pct, platform_spend (dollars). gap_pct is
    # |platform_leads - britebase_leads| / the larger, a fraction from 0 to 1, null only when
    # both counts are zero. Built by brite-data-platform's BC-28219 lead reconciliation spec.
    LEAD_RECONCILIATION = "ANALYTICS.MARTS.MART_ADS_AGENT_LEAD_RECONCILIATION"
    CHANGE_LOG = "ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG"
    COLUMNS = {  # change-log column: plan row key
        "change_key": "key", "run_date": "run_date", "mode": "mode", "platform": "platform",
        "status": "status", "account_id": "account_id", "target_type": "target_type",
        "target_id": "target_id", "target_name": "target_name", "field": "field",
        "old_value": "old", "new_value": "new", "reason": "reason", "checks": "checks",
        "logged_by": "logged_by",  # the approver on an approval row; else current_user()
    }

    def __init__(self):
        self._env = _require(self.ENV)

    def _query(self, sql, params=None, many=None):
        import snowflake.connector
        from cryptography.hazmat.primitives import serialization

        e = self._env
        key = serialization.load_pem_private_key(e["ADS_AGENT_SNOWFLAKE_PRIVATE_KEY"].encode(), password=None)
        conn = snowflake.connector.connect(
            account=e["ADS_AGENT_SNOWFLAKE_ACCOUNT"],
            user=e["ADS_AGENT_SNOWFLAKE_USER"],
            private_key=key.private_bytes(
                serialization.Encoding.DER, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
            ),
            role=e["ADS_AGENT_SNOWFLAKE_ROLE"],
            warehouse=e["ADS_AGENT_SNOWFLAKE_WAREHOUSE"],
        )
        try:
            cur = conn.cursor()
            if many is not None:
                cur.executemany(sql, many)
                return []
            cur.execute(sql, params)
            names = [d[0].lower() for d in cur.description]
            return [dict(zip(names, row)) for row in cur.fetchall()]
        finally:
            conn.close()

    def read_snapshot(self):
        rows = self._query(
            f"select platform, account_id, campaign_id, territory, spend, conversions from {self.SNAPSHOT}"
        )
        return [dict(r, spend=float(r["spend"]), conversions=float(r["conversions"])) for r in rows]

    def read_ad_snapshot(self):
        """The ad snapshot's rows. A null booked_appointments stays None: the run reads it as
        unknown, never as zero."""
        rows = self._query(f"select {', '.join(self.AD_COLUMNS)} from {self.AD_SNAPSHOT}")
        return [dict(r, ad_group_id=str(r["ad_group_id"]), ad_id=str(r["ad_id"]), spend=float(r["spend"]),
                     conversions=float(r["conversions"]), booked_appointments=_float_or_none(r["booked_appointments"]))
                for r in rows]

    def read_creative_inputs(self, platform):
        rows = self._query(
            f"select platform, ad_account_id, ad_id, ai_edited, approved_by from {self.CREATIVE_INPUTS} "
            "where platform = %(p)s", {"p": platform}
        )
        return [dict(r, ad_account_id=str(r["ad_account_id"]), ad_id=str(r["ad_id"]), ai_edited=bool(r["ai_edited"]))
                for r in rows]

    def read_lead_reconciliation(self, lead_date):
        rows = self._query(
            "select platform, lead_date, platform_leads, britebase_leads, gap_pct, platform_spend "
            f"from {self.LEAD_RECONCILIATION} where lead_date = %(d)s", {"d": lead_date}
        )
        # Plain ints and floats: a frozen row carries these values into the change log's JSON.
        kinds = {"platform_leads": int, "britebase_leads": int, "gap_pct": float, "platform_spend": float}
        return [
            dict(r, lead_date=str(r["lead_date"]), **{k: None if r[k] is None else f(r[k]) for k, f in kinds.items()})
            for r in rows
        ]

    def read_booked_appointments(self, platform, first_week):
        """Booked appointments per territory and week, calls counted, for the step-up gate
        (BC-28220, BC-28577): the platform's rows of TERRITORY_WEEKLY from first_week (a
        Monday, YYYY-MM-DD) on. week_start comes back as YYYY-MM-DD; spend and each count as
        a float, or None where the mart holds a null."""
        rows = self._query(
            f"select platform, territory, week_start, spend, {', '.join(self.BOOKED_COLUMNS)} "
            f"from {self.TERRITORY_WEEKLY} where platform = %(p)s and week_start >= %(w)s",
            {"p": platform, "w": first_week},
        )
        return [dict(r, week_start=str(r["week_start"]),
                     **{k: _float_or_none(r[k]) for k in ("spend", *self.BOOKED_COLUMNS)})
                for r in rows]

    def read_change_log(self, run_date):
        return self._change_log("run_date = %(d)s", run_date)

    def read_change_log_since(self, first_day):
        """Every row from first_day on: the step-up gate's record of applied changes (BC-28220)."""
        return self._change_log("run_date >= %(d)s", first_day)

    def _change_log(self, where, day):
        rows = self._query(f"select {', '.join(self.COLUMNS)} from {self.CHANGE_LOG} where {where}", {"d": day})
        out = []
        for r in rows:
            row = {k: r[c] for c, k in self.COLUMNS.items()}
            row["run_date"] = str(row["run_date"])
            if row["field"] == "daily_budget_micros":  # old_value / new_value are varchar
                row["old"], row["new"] = (None if v is None else int(v) for v in (row["old"], row["new"]))
            if isinstance(row["checks"], str):
                row["checks"] = json.loads(row["checks"])
            out.append(row)
        return out

    def write_change_log(self, rows):
        cols = list(self.COLUMNS)
        source = ", ".join(
            f"parse_json(%({c})s) as {c}" if c == "checks"
            else f"coalesce(%({c})s, current_user()) as {c}" if c == "logged_by"
            else f"%({c})s as {c}"
            for c in cols
        )
        sql = (
            f"merge into {self.CHANGE_LOG} t using (select {source}) s on t.change_key = s.change_key "
            f"when not matched then insert ({', '.join(cols)}) values ({', '.join('s.' + c for c in cols)})"
        )
        params = [
            {
                c: json.dumps(r[k]) if c == "checks" else (None if r.get(k) is None else str(r[k]))
                for c, k in self.COLUMNS.items()
            }
            for r in rows
        ]
        self._query(sql, many=params)


class SlackWebhook:
    ENV = ("ADS_AGENT_SLACK_WEBHOOK_URL",)

    def __init__(self):
        self._url = _require(self.ENV)["ADS_AGENT_SLACK_WEBHOOK_URL"]

    def post(self, text):
        req = urllib.request.Request(
            self._url, data=json.dumps({"text": text}).encode(), headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            resp.read()


class CapacitySheet:
    """Reads each territory's next open install date, and when its row was last updated,
    from Operations' capacity sheet ("Operations Health 2025-2026") through the Google
    Sheets API (BC-28220). Read only.

    Credentials by env var name: a Google service account's JSON key, shared on the sheet
    as a viewer. The sheet id and the range to read are env vars too, so neither is in this
    repo. The range's first row holds the column names in COLUMNS; confirm them with the
    sheet's owner before the first run. Dates and times are read as Sheets serial numbers,
    in the spreadsheet's own time zone, so the sheet's display format does not matter. A
    cell that is not a date reads as none: no date blocks raises into that territory.

    Untested against the live API: the credentials do not exist yet. `http` and `token`
    are for tests."""

    ENV = (
        "ADS_AGENT_CAPACITY_SHEET_ID",
        "ADS_AGENT_CAPACITY_RANGE",  # e.g. a tab name, or Tab!A:F
        "ADS_AGENT_CAPACITY_SERVICE_ACCOUNT_JSON",
    )
    COLUMNS = {"territory": "Territory", "next_open_install_date": "Next Open Install Date",
               "updated_at": "Last Updated"}
    SCOPE = "https://www.googleapis.com/auth/spreadsheets.readonly"
    BASE = "https://sheets.googleapis.com/v4/spreadsheets"
    DAY_ZERO = datetime(1899, 12, 30)  # serial number 0 in Google Sheets

    def __init__(self, http=_http, token=None):
        self._env = _require(self.ENV)
        self._http = http
        self._token = token or self._service_account_token

    def _service_account_token(self):
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        info = json.loads(self._env["ADS_AGENT_CAPACITY_SERVICE_ACCOUNT_JSON"])
        creds = service_account.Credentials.from_service_account_info(info, scopes=[self.SCOPE])
        creds.refresh(Request())
        return creds.token

    def read_capacity(self):
        """[{"territory", "next_open_install_date": a date or None, "updated_at": a datetime
        with the sheet's time zone, or None}], one per row that names a territory."""
        sheet = urllib.parse.quote(self._env["ADS_AGENT_CAPACITY_SHEET_ID"], safe="")
        auth = {"Authorization": f"Bearer {self._token()}"}
        meta = self._http("GET", f"{self.BASE}/{sheet}?fields=properties.timeZone", auth)
        zone = ZoneInfo(meta["properties"]["timeZone"])
        cells = urllib.parse.quote(self._env["ADS_AGENT_CAPACITY_RANGE"], safe="")
        query = urllib.parse.urlencode({"valueRenderOption": "UNFORMATTED_VALUE",
                                        "dateTimeRenderOption": "SERIAL_NUMBER"})
        values = self._http("GET", f"{self.BASE}/{sheet}/values/{cells}?{query}", auth).get("values") or []
        head = [str(h).strip() for h in (values[0] if values else [])]
        missing = [name for name in self.COLUMNS.values() if name not in head]
        if missing:
            raise RuntimeError(f"capacity sheet columns not found: {', '.join(missing)}")
        at = {key: head.index(name) for key, name in self.COLUMNS.items()}
        out = []
        for row in values[1:]:
            cell = {key: row[i] if i < len(row) else None for key, i in at.items()}
            territory = str(cell["territory"] or "").strip()
            if territory:
                when = self._time(cell["updated_at"], zone)
                out.append({"territory": territory, "updated_at": when,
                            "next_open_install_date": self._time(cell["next_open_install_date"], zone, day=True)})
        return out

    def _time(self, value, zone, day=False):
        """A Sheets serial number, or an ISO text date or time, as a date (`day`) or as a
        datetime in `zone`. Anything else is None."""
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            when = self.DAY_ZERO + timedelta(days=value)
        elif isinstance(value, str):
            try:
                when = datetime.fromisoformat(value.strip())
            except ValueError:
                return None
        else:
            return None
        if day:
            return date(when.year, when.month, when.day)
        return when.replace(tzinfo=zone) if when.utcoffset() is None else when
