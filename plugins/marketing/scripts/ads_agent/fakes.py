"""Fakes for the ads-agent run seam. Each records every call so tests assert on calls.

Same method names as the real adapters in `adapters.py`. Act mode (BC-28216) asserts on
`write_calls`; Meta (BC-28218) has its own fake with the same shape.
"""

from __future__ import annotations

import copy


class FakeGoogleAds:
    platform = "google_ads"
    UNIT = "campaign_id"  # the settings key of the budget holder a write matches

    def __init__(self, settings, ads=(), fail_on=()):
        self._settings = copy.deepcopy(settings)
        self._ads = copy.deepcopy(list(ads))
        self.fail_on = set(fail_on)  # target ids whose write raises, to test partial failure
        self.calls: list[tuple] = []
        self.applied: list[str] = []  # keys of the writes that went through

    def read_settings(self, account_ids):
        self.calls.append(("read_settings", tuple(account_ids)))
        return [s for s in copy.deepcopy(self._settings) if s["account_id"] in account_ids]

    def read_ads(self, account_ids):
        self.calls.append(("read_ads", tuple(account_ids)))
        return [a for a in copy.deepcopy(self._ads) if a["account_id"] in account_ids]

    def apply(self, change):
        """Write one change, as the real adapter would. A budget, optimisation goal or ad
        status write changes what the next read returns; a campaign create or delete is only
        recorded."""
        self.calls.append(("apply", change["key"]))
        if change["target_id"] in self.fail_on:
            raise RuntimeError(f"fake write failure on {change['target_id']}")
        for s in self._settings:
            if change["target_type"] != "ad" and change["field"] in s and (s["account_id"], s[self.UNIT]) == (
                    change["account_id"], change["target_id"]):
                s[change["field"]] = change["new"]
        for a in self._ads:
            if change["target_type"] == "ad" and (a["account_id"], f"{a['ad_group_id']}~{a['ad_id']}") == (
                    change["account_id"], change["target_id"]):
                a["status"] = change["new"]
        self.applied.append(change["key"])

    @property
    def write_calls(self):
        return [c for c in self.calls if not c[0].startswith("read_")]


class FakeMetaAds(FakeGoogleAds):
    """Meta's shape: one settings row per ad set, keyed by ad_set_id, and an ad's
    ad_group_id is its ad set. `spend` holds yesterday's spend rows that `read_spend`
    serves: {"account_id", "level": "ad_set" | "campaign", "id", "spend"}."""

    platform = "meta_ads"
    UNIT = "ad_set_id"

    def __init__(self, settings, ads=(), fail_on=(), spend=()):
        super().__init__(settings, ads, fail_on)
        self.spend = copy.deepcopy(list(spend))
        self.spend_fails = False  # set True to make the insights read raise

    def read_spend(self, account_ids, day):
        self.calls.append(("read_spend", tuple(account_ids), day))
        if self.spend_fails:
            raise RuntimeError("fake insights failure")
        return [r for r in copy.deepcopy(self.spend) if r["account_id"] in account_ids]


class FakeWarehouse:
    def __init__(self, snapshot, ad_snapshot=(), lead_reconciliation=(), creative_inputs=()):
        self._snapshot = copy.deepcopy(snapshot)
        self._ad_snapshot = copy.deepcopy(list(ad_snapshot))
        # Public, like change_log, so a test can break the lead feed between runs (BC-28219).
        self.lead_reconciliation = copy.deepcopy(list(lead_reconciliation))
        self.creative_inputs = copy.deepcopy(list(creative_inputs))
        self.change_log: list[dict] = []
        self.calls: list[tuple] = []

    def read_snapshot(self):
        self.calls.append(("read_snapshot",))
        return copy.deepcopy(self._snapshot)

    def read_ad_snapshot(self):
        self.calls.append(("read_ad_snapshot",))
        return copy.deepcopy(self._ad_snapshot)

    def read_lead_reconciliation(self, lead_date):
        self.calls.append(("read_lead_reconciliation", lead_date))
        return [copy.deepcopy(r) for r in self.lead_reconciliation if r["lead_date"] == lead_date]

    def read_creative_inputs(self, platform):
        self.calls.append(("read_creative_inputs", platform))
        return [copy.deepcopy(r) for r in self.creative_inputs if r["platform"] == platform]

    def read_change_log(self, run_date):
        self.calls.append(("read_change_log", run_date))
        return [copy.deepcopy(r) for r in self.change_log if r["run_date"] == run_date]

    def write_change_log(self, rows):
        """Insert rows whose key is not logged yet, like the real MERGE."""
        self.calls.append(("write_change_log", len(rows)))
        logged = {r["key"] for r in self.change_log}
        self.change_log += [copy.deepcopy(r) for r in rows if r["key"] not in logged]


class FakeSlack:
    def __init__(self):
        self.posts: list[str] = []

    def post(self, text):
        self.posts.append(text)
