"""Command line and always-on runner for the ads watchdog. From `plugins/marketing/scripts/`:

    python -m ads_watchdog hourly   # pace check once: pause any account over pace or its share
    python -m ads_watchdog audit    # settings audit once, posted to Slack even when clean
    python -m ads_watchdog stop     # EMERGENCY STOP: pause every account on both platforms
    python -m ads_watchdog serve    # the runner: hourly at :05, plus the audit at 14:05 UTC

Environment, besides the platform credentials listed in platforms.py:
  ADS_WATCHDOG_CONFIG             path to the JSON config. Real values are private and live
                                  with the runner (n8n-automations), never in this repo.
  ADS_WATCHDOG_SLACK_WEBHOOK_URL  Slack incoming webhook for alerts. `serve` refuses to start
                                  without it: alerts that reach no one are a silent failure.
  ADS_WATCHDOG_EMERGENCY_STOP     "true" turns the emergency stop on, as does the config flag.
                                  Releasing it needs both off.

Config keys (all required; values are data, never constants in code):
  weekly_ceiling          the weekly ceiling the Head of GTM sets
  shares                  {"google:<customer id, digits only>" or "meta:act_<id>": fraction of the ceiling}
  pace_tolerance          how far above the straight-line pace spend may run (1.5 = 50% above)
  pace_floor              the smallest fraction of a day's share treated as "expected by now",
                          so one early-morning click cannot trip the pace check
  expected_cost_per_lead  [cheapest, dearest] — sets the expected lead range
  lead_alert_probability  alert only when this few leads is less likely than this
  partner_exclusion_list  the name of the shared negative keyword list every Google campaign carries
  brite_admins            Google emails and Meta user ids allowed to hold spending limits
  emergency_stop          true pauses everything, every hour, until released
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback
import urllib.request
from datetime import datetime, timedelta, timezone

from .platforms import GoogleAds, MetaAds
from .watchdog import audit, emergency_stop, hourly

AUDIT_HOUR_UTC = 14  # 08:00 in Denver in summer, 07:00 in winter


def load_config(env=os.environ) -> dict:
    with open(env["ADS_WATCHDOG_CONFIG"]) as f:
        config = json.load(f)
    unset = [key for key, value in config.items() if value is None]
    if unset:
        raise ValueError(f"config values not set yet: {', '.join(unset)}")
    if sum(config["shares"].values()) > 1 + 1e-9:
        raise ValueError("the shares add up to more than the whole weekly ceiling")
    config["emergency_stop"] = config["emergency_stop"] or env.get("ADS_WATCHDOG_EMERGENCY_STOP") == "true"
    return config


def slack(text: str, env=os.environ) -> None:
    print(text, flush=True)
    if env.get("ADS_WATCHDOG_SLACK_WEBHOOK_URL"):
        request = urllib.request.Request(
            env["ADS_WATCHDOG_SLACK_WEBHOOK_URL"], data=json.dumps({"text": text}).encode(), headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(request, timeout=30).close()


def run(job: str, adapters: list, config: dict | None, notify, now: datetime) -> int:
    """Run a job one platform at a time, so one platform's outage cannot blind the watchdog to
    the other. Returns how many platforms failed; each failure is alerted."""
    failures = 0
    for adapter in adapters:
        try:
            if job == "stop":
                emergency_stop([adapter], notify)
            elif job == "audit":
                audit([adapter], config, notify, now)
            else:
                hourly([adapter], config, notify, now)
        except Exception as error:
            failures += 1
            traceback.print_exc()
            notify(f"Ads watchdog {job} FAILED on {type(adapter).__name__}: {type(error).__name__}: {error}")
    return failures


def once(job: str, env=os.environ) -> int:
    def notify(text):
        slack(text, env)

    try:
        config = None if job == "stop" else load_config(env)  # the stop must not depend on the config
    except Exception as error:
        notify(f"Ads watchdog {job} FAILED: could not load the config: {type(error).__name__}: {error}")
        return 1
    return run(job, [GoogleAds(env), MetaAds(env)], config, notify, datetime.now(timezone.utc))


def serve(env=os.environ) -> None:
    if not env.get("ADS_WATCHDOG_SLACK_WEBHOOK_URL"):
        sys.exit("serve needs ADS_WATCHDOG_SLACK_WEBHOOK_URL: a watchdog whose alerts reach no one is not watching")
    while True:
        now = datetime.now(timezone.utc)
        once("hourly", env)
        if now.hour == AUDIT_HOUR_UTC:
            once("audit", env)
        next_run = (now + timedelta(hours=1)).replace(minute=5, second=0, microsecond=0)
        time.sleep(max(60.0, (next_run - datetime.now(timezone.utc)).total_seconds()))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="ads_watchdog", description="Pause-only ads watchdog (BC-28219).")
    parser.add_argument("job", choices=["hourly", "audit", "stop", "serve"])
    job = parser.parse_args(argv).job
    if job == "serve":
        serve()
    return 1 if once(job) else 0


if __name__ == "__main__":
    sys.exit(main())
