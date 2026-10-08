"""Fakes for the ads-agent run seam. Each records every call so tests assert on calls.

Same method names as the real adapters in `adapters.py`. Act mode (BC-28216) asserts on
`FakeGoogleAds.write_calls`; Meta (BC-28218) adds a fake with the same shape.
"""

from __future__ import annotations

import copy


class FakeGoogleAds:
    platform = "google_ads"

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
        """Write one change, as the real adapter would. A budget or ad status write changes
        what the next read returns; a campaign create or delete is only recorded."""
        self.calls.append(("apply", change["key"]))
        if change["target_id"] in self.fail_on:
            raise RuntimeError(f"fake write failure on {change['target_id']}")
        for s in self._settings:
            if change["field"] == "daily_budget_micros" and (s["account_id"], s["campaign_id"]) == (
                    change["account_id"], change["target_id"]):
                s["daily_budget_micros"] = change["new"]
        for a in self._ads:
            if change["target_type"] == "ad" and (a["account_id"], f"{a['ad_group_id']}~{a['ad_id']}") == (
                    change["account_id"], change["target_id"]):
                a["status"] = change["new"]
        self.applied.append(change["key"])

    @property
    def write_calls(self):
        return [c for c in self.calls if not c[0].startswith("read_")]


class FakeWarehouse:
    def __init__(self, snapshot, ad_snapshot=()):
        self._snapshot = copy.deepcopy(snapshot)
        self._ad_snapshot = copy.deepcopy(list(ad_snapshot))
        self.change_log: list[dict] = []
        self.calls: list[tuple] = []

    def read_snapshot(self):
        self.calls.append(("read_snapshot",))
        return copy.deepcopy(self._snapshot)

    def read_ad_snapshot(self):
        self.calls.append(("read_ad_snapshot",))
        return copy.deepcopy(self._ad_snapshot)

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
