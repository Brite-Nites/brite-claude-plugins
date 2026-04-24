#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/aiark_client.py
# Changes: verbatim port, no functional edits

"""
AI Ark client — firmographic company discovery.

Reads an ICP JSON, queries AI Ark's similarity + semantic search API,
paginates until exhausted, dedupes by domain, writes JSONL.

Usage:
  python scripts/aiark_client.py --icp ./output/{slug}/icp.json > ./output/{slug}/aiark.jsonl
"""
import argparse
import json
import os
import sys
import requests
from dotenv import load_dotenv

load_dotenv()

AIARK_API_KEY = os.getenv("AIARK_API_KEY")
BASE_URL = "https://api.ai-ark.com"  # verify against docs.ai-ark.com


def discover(icp: dict) -> list[dict]:
    """Query AI Ark with structured ICP filters."""
    if not AIARK_API_KEY:
        print("ERROR: AIARK_API_KEY not set in .env", file=sys.stderr)
        sys.exit(1)

    headers = {"Authorization": f"Bearer {AIARK_API_KEY}"}
    payload = {
        "filters": {
            "industries": icp.get("industries", []),
            "geo": icp.get("geo", {}),
            "size_band": icp.get("size_band"),
            "exclusions": icp.get("exclusions", []),
        },
        "limit": 1000,
    }

    companies = []
    page_token = None
    while True:
        if page_token:
            payload["page_token"] = page_token
        r = requests.post(f"{BASE_URL}/v1/search", json=payload, headers=headers, timeout=30)
        r.raise_for_status()
        data = r.json()
        companies.extend(data.get("companies", []))
        page_token = data.get("next_page_token")
        if not page_token:
            break

    # dedupe by domain
    seen = set()
    unique = []
    for c in companies:
        d = c.get("domain", "").lower().strip()
        if d and d not in seen:
            seen.add(d)
            unique.append(c)
    return unique


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icp", required=True, help="Path to icp.json")
    args = ap.parse_args()

    with open(args.icp) as f:
        icp = json.load(f)

    companies = discover(icp)
    for c in companies:
        print(json.dumps(c))
    print(f"[AI Ark] {len(companies)} unique companies", file=sys.stderr)


if __name__ == "__main__":
    main()
