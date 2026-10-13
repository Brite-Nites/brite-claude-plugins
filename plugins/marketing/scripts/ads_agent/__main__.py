"""Run the ads agent against the real adapters.

    cd plugins/marketing/scripts
    bws run --project-id <ads-agent project> -- python3 -m ads_agent propose --rules <file> [--emit]

Prints the plan as JSON. Exit 2 on a missing secret or rule setting.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone

from .adapters import GoogleAds, MissingEnv, SlackWebhook, SnowflakeWarehouse
from .run import run


def main(argv=None):
    p = argparse.ArgumentParser(prog="ads_agent", description="One bounded ads-agent run (BC-28215).")
    p.add_argument("mode", choices=["propose"], help="act mode arrives with BC-28216")
    p.add_argument("--rules", required=True, help="rule settings JSON, kept outside this repo")
    p.add_argument("--emit", action="store_true", help="print the plan only: no change-log write, no Slack post")
    a = p.parse_args(argv)
    with open(a.rules, encoding="utf-8") as f:
        rules = json.load(f)
    try:
        plan = run(
            warehouse=SnowflakeWarehouse(),
            adapter=GoogleAds(),
            slack=None if a.emit else SlackWebhook(),
            rules=rules,
            now=datetime.now(timezone.utc),
            mode=a.mode,
            emit=a.emit,
        )
    except (MissingEnv, ValueError) as e:
        print(f"ads_agent: {e}", file=sys.stderr)
        return 2
    print(json.dumps(plan, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
