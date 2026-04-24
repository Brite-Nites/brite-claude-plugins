#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/discolike_client.py
# Changes: verbatim port, no functional edits

"""
Discolike client — lookalike + natural-language company discovery.

Reads an ICP JSON, queries Discolike's /discover endpoint (GET with query params),
paginates via offset + X-Total-Count, dedupes by domain, writes JSONL.

Usage:
  python scripts/discolike_client.py --icp ./output/{slug}/icp.json > ./output/{slug}/discolike.jsonl

Docs: https://api.discolike.com/v1/docs/api/endpoints/discover/

Wire details (verified 2026-04):
  GET https://api.discolike.com/v1/discover?icp_text=...&country=US&max_records=100&offset=0
  Header: x-discolike-key: API_KEY
  Response: array of { domain, name, similarity, score, employees, industry_groups, ... }
  Pagination: X-Total-Count response header + offset param
"""
import argparse
import json
import os
import sys
import time
import requests
from dotenv import load_dotenv

load_dotenv()

DISCOLIKE_API_KEY = os.getenv("DISCOLIKE_API_KEY")
BASE_URL = "https://api.discolike.com/v1/discover"
PAGE_SIZE = 100


def build_icp_text(icp: dict) -> str:
    industries = ", ".join(icp.get("industries", []))
    regions = ", ".join(icp.get("geo", {}).get("regions", []))
    size = icp.get("size_band", {})
    text = industries or "companies"
    if regions:
        text += f" in {regions}"
    if size.get("employee_min") or size.get("employee_max"):
        text += f", {size.get('employee_min', 1)}-{size.get('employee_max', 10000)} employees"
    return text


def discover(icp: dict) -> list[dict]:
    if not DISCOLIKE_API_KEY:
        print("ERROR: DISCOLIKE_API_KEY not set in .env", file=sys.stderr)
        sys.exit(1)

    headers = {"x-discolike-key": DISCOLIKE_API_KEY}
    country = icp.get("geo", {}).get("country", "US")
    size = icp.get("size_band", {})
    employee_range = None
    if size.get("employee_min") or size.get("employee_max"):
        employee_range = f"{size.get('employee_min', 1)},{size.get('employee_max', 10000)}"

    base_params = {
        "icp_text": build_icp_text(icp),
        "country": country,
        "max_records": PAGE_SIZE,
    }
    if employee_range:
        base_params["employee_range"] = employee_range

    companies = []
    offset = 0
    while True:
        params = {**base_params, "offset": offset}
        r = requests.get(BASE_URL, params=params, headers=headers, timeout=30)
        if r.status_code == 429:
            time.sleep(2)
            continue
        r.raise_for_status()
        results = r.json()
        if not isinstance(results, list):
            results = results.get("results", [])
        if not results:
            break
        companies.extend(results)
        total = int(r.headers.get("X-Total-Count", len(companies)))
        offset += len(results)
        if offset >= total or len(results) < PAGE_SIZE:
            break

    # dedupe by domain
    seen = set()
    unique = []
    for c in companies:
        d = (c.get("domain") or "").lower().strip()
        if d and d not in seen:
            seen.add(d)
            unique.append(c)
    return unique


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icp", required=True)
    args = ap.parse_args()

    with open(args.icp) as f:
        icp = json.load(f)

    companies = discover(icp)
    for c in companies:
        print(json.dumps(c))
    print(f"[Discolike] {len(companies)} unique companies", file=sys.stderr)


if __name__ == "__main__":
    main()
