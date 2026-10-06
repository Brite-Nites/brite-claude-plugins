"""Real adapters for the ads-agent run: Google Ads (settings read), Snowflake, Slack.

None of these accounts exist yet (BC-28209). Each adapter asserts its env vars when it
is built, so a missing secret fails loudly by name and never prints a value. Secrets
come from Bitwarden Secrets Manager (`bws run --project-id <ads-agent project> -- ...`,
ADR-044) or Railway service variables.

Third-party libraries load lazily inside methods: CI installs only pytest, so this
module must import on a stdlib-only interpreter. Runtime needs `google-ads`,
`snowflake-connector-python` and `cryptography`.

Untested against the live APIs: they need the accounts above. The fakes in
`fakes.py` carry the same method names.
"""

from __future__ import annotations

import json
import os
import urllib.request


class MissingEnv(RuntimeError):
    pass


def _require(names):
    missing = [n for n in names if not os.environ.get(n)]
    if missing:
        raise MissingEnv(f"missing env vars: {', '.join(missing)}")
    return {n: os.environ[n] for n in names}


class GoogleAds:
    """Reads current campaign settings. No write method: act mode (BC-28216) adds `apply`."""

    platform = "google_ads"
    ENV = (
        "GOOGLE_ADS_DEVELOPER_TOKEN",
        "GOOGLE_ADS_CLIENT_ID",
        "GOOGLE_ADS_CLIENT_SECRET",
        "GOOGLE_ADS_REFRESH_TOKEN",
        "GOOGLE_ADS_LOGIN_CUSTOMER_ID",  # the manager account
    )
    QUERY = """
        SELECT campaign.id, campaign.name, campaign.primary_status_reasons,
               campaign_budget.amount_micros, campaign_budget.explicitly_shared
        FROM campaign
        WHERE campaign.status = 'ENABLED' AND campaign.advertising_channel_type = 'SEARCH'
    """

    def __init__(self):
        self._env = _require(self.ENV)

    def read_settings(self, account_ids):
        from google.ads.googleads.client import GoogleAdsClient

        e = self._env
        client = GoogleAdsClient.load_from_dict({
            "developer_token": e["GOOGLE_ADS_DEVELOPER_TOKEN"],
            "client_id": e["GOOGLE_ADS_CLIENT_ID"],
            "client_secret": e["GOOGLE_ADS_CLIENT_SECRET"],
            "refresh_token": e["GOOGLE_ADS_REFRESH_TOKEN"],
            "login_customer_id": e["GOOGLE_ADS_LOGIN_CUSTOMER_ID"],
            "use_proto_plus": True,
        })
        service = client.get_service("GoogleAdsService")
        return [
            {
                "account_id": account_id,
                "campaign_id": str(row.campaign.id),
                "campaign_name": row.campaign.name,
                "daily_budget_micros": row.campaign_budget.amount_micros,
                "budget_limited": any(r.name == "BUDGET_CONSTRAINED" for r in row.campaign.primary_status_reasons),
                "budget_shared": row.campaign_budget.explicitly_shared,
            }
            for account_id in account_ids
            for row in service.search(customer_id=account_id, query=self.QUERY)
        ]


class SnowflakeWarehouse:
    """Reads the results snapshot and the change log; writes the change log (MERGE on key)."""

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
    CHANGE_LOG = "ANALYTICS.OPERATIONS.ADS_AGENT_CHANGE_LOG"
    COLUMNS = {  # change-log column: plan row key
        "change_key": "key", "run_date": "run_date", "mode": "mode", "platform": "platform",
        "status": "status", "account_id": "account_id", "target_type": "target_type",
        "target_id": "target_id", "target_name": "target_name", "field": "field",
        "old_value": "old", "new_value": "new", "reason": "reason", "checks": "checks",
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

    def read_logged_keys(self, run_date):
        rows = self._query(f"select change_key from {self.CHANGE_LOG} where run_date = %(d)s", {"d": run_date})
        return {r["change_key"] for r in rows}

    def write_change_log(self, rows):
        cols = list(self.COLUMNS)
        source = ", ".join(
            f"parse_json(%({c})s) as {c}" if c == "checks" else f"%({c})s as {c}" for c in cols
        )
        sql = (
            f"merge into {self.CHANGE_LOG} t using (select {source}) s on t.change_key = s.change_key "
            f"when not matched then insert ({', '.join(cols)}) values ({', '.join('s.' + c for c in cols)})"
        )
        params = [
            {
                c: json.dumps(r[k]) if c == "checks" else (None if r[k] is None else str(r[k]))
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
