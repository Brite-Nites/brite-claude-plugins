"""Run the ads agent against the real adapters.

    cd plugins/marketing/scripts
    bws run --project-id <ads-agent project> -- python3 -m ads_agent propose --rules <file> [--emit]
    bws run --project-id <ads-agent project> -- python3 -m ads_agent approve <key> --by <name> --rules <file>
    bws run --project-id <ads-agent project> -- python3 -m ads_agent act --rules <file> [--emit]

Prints the plan (or the approval row) as JSON. Exit 2 on a missing secret, a missing or
bad rule setting, a key that matches no proposed change in today's plan, or an approval
while the platform is frozen. Today is the date in the rules file's `timezone`. A frozen
run (BC-28219) exits 0 and prints its reason under "frozen".
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone

from .adapters import GoogleAds, MissingEnv, SlackWebhook, SnowflakeWarehouse
from .run import approve, run


def main(argv=None):
    p = argparse.ArgumentParser(prog="ads_agent", description="One bounded ads-agent run (BC-28215, BC-28216).")
    sub = p.add_subparsers(dest="command", required=True)
    for mode, text in (
        ("propose", "plan, log and post; never writes to the ad account"),
        ("act", "plan once a day, then apply what the hard limits allow"),
    ):
        s = sub.add_parser(mode, help=text)
        s.add_argument("--rules", required=True, help="rule settings JSON, kept outside this repo")
        s.add_argument("--emit", action="store_true",
                       help="print the plan only: no change-log write, no Slack post, no ad-account write")
    s = sub.add_parser("approve", help="log the Head of GTM's approval of one proposed change in today's plan")
    s.add_argument("key", help="the change key, or a unique prefix of 8 or more characters")
    s.add_argument("--by", required=True, help="the approver, logged as logged_by")
    s.add_argument("--rules", required=True, help="rule settings JSON; its timezone sets today's date")
    a = p.parse_args(argv)
    now = datetime.now(timezone.utc)
    try:
        with open(a.rules, encoding="utf-8") as f:
            rules = json.load(f)
        if a.command == "approve":
            out = approve(warehouse=SnowflakeWarehouse(), rules=rules, key=a.key, by=a.by, now=now)
        else:
            out = run(
                warehouse=SnowflakeWarehouse(),
                adapter=GoogleAds(),
                slack=None if a.emit else SlackWebhook(),
                rules=rules,
                now=now,
                mode=a.command,
                emit=a.emit,
            )
    except (MissingEnv, ValueError) as e:
        print(f"ads_agent: {e}", file=sys.stderr)
        return 2
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
