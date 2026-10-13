"""Fakes for the ads-agent run seam. Each records every call so tests assert on calls.

Same method names as the real adapters in `adapters.py`. Later tickets reuse these:
act mode (BC-28216) asserts on `FakeGoogleAds.write_calls`; Meta (BC-28218) adds a
fake with the same shape.
"""

from __future__ import annotations

import copy


class FakeGoogleAds:
    platform = "google_ads"

    def __init__(self, settings):
        self._settings = copy.deepcopy(settings)
        self.calls: list[tuple] = []

    def read_settings(self, account_ids):
        self.calls.append(("read_settings", tuple(account_ids)))
        return [s for s in copy.deepcopy(self._settings) if s["account_id"] in account_ids]

    def apply(self, change):
        self.calls.append(("apply", change["key"]))

    @property
    def write_calls(self):
        return [c for c in self.calls if c[0] != "read_settings"]


class FakeWarehouse:
    def __init__(self, snapshot):
        self._snapshot = copy.deepcopy(snapshot)
        self.change_log: list[dict] = []
        self.calls: list[tuple] = []

    def read_snapshot(self):
        self.calls.append(("read_snapshot",))
        return copy.deepcopy(self._snapshot)

    def read_logged_keys(self, run_date):
        self.calls.append(("read_logged_keys", run_date))
        return {r["key"] for r in self.change_log if r["run_date"] == run_date}

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
