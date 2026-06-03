#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/icypeas_client.py
# Changes: verbatim port + find-companies query-object remap (BC-12163)

"""
IcyPeas client — keyword-based company search.

Reads an ICP JSON, queries IcyPeas `/find-companies`, paginates via pagination.token.

Usage:
  python scripts/icypeas_client.py --icp ./output/{slug}/icp.json > ./output/{slug}/icypeas.jsonl

Notes:
- Auth: raw API key in Authorization header (no "Bearer" prefix)
- Response uses `total` (not count) and `leads` (not items)
- Max 100 per page
- Some common terms return 0 (retail, ecommerce, fashion). Try synonyms if empty.
"""
import argparse
import json
import os
import sys
import requests
from dotenv import load_dotenv

load_dotenv()

ICYPEAS_API_KEY = os.getenv("ICYPEAS_API_KEY")
BASE_URL = "https://app.icypeas.com/api"


def search(icp: dict) -> list[dict]:
    if not ICYPEAS_API_KEY:
        print("ERROR: ICYPEAS_API_KEY not set in .env", file=sys.stderr)
        sys.exit(1)

    headers = {"Authorization": ICYPEAS_API_KEY, "Content-Type": "application/json"}
    industries = icp.get("industries", [])
    regions = icp.get("geo", {}).get("regions", [])

    companies = []
    for industry in industries:
        # IcyPeas redesigned find-companies to require a structured `query` object
        # (BC-12163). Map the consumer's free-text industry term -> query.keyword
        # (free-text across the company profile — the old top-level `keywords`
        # semantic); regions -> query.location. NB: query.industry is a controlled
        # taxonomy, so free-text terms there return success:true + total 0 (silently
        # unfiltered); query.keyword is the faithful mapping. Old `limit` -> pagination.size.
        query = {"keyword": {"include": [industry]}}
        if regions:
            query["location"] = {"include": regions}
        payload = {"query": query, "pagination": {"size": 100}}
        while True:
            r = requests.post(f"{BASE_URL}/find-companies", json=payload, headers=headers, timeout=30)
            r.raise_for_status()
            data = r.json()
            if not data.get("success", False):
                # 200 + success:false is a structured rejection (e.g. EmptyQueryError),
                # NOT an empty result set — surface it loudly instead of silently
                # returning zero companies (BC-12163; mirrors the BC-12128 loud-logging
                # in enrich_waterfall.py). Non-fatal: IcyPeas is one of several discovery
                # sources, so log this industry's failure and move on. Name the stage
                # (initial request vs mid-pagination, e.g. token expiry) so a later-page
                # failure isn't misread in the logs as a query-shape rejection.
                detail = data.get("validationErrors") or data.get("error") or data
                stage = "mid-pagination" if "token" in payload["pagination"] else "initial request"
                print(f"  [icypeas] ⚠ find-companies returned success=false for "
                      f"'{industry}' on the {stage}: {detail}", file=sys.stderr)
                break
            leads = data.get("leads", [])
            if not leads:
                break
            companies.extend(leads)
            token = data.get("pagination", {}).get("token")
            if not token:
                break
            payload["pagination"]["token"] = token

    # Normalize + dedupe by website/domain
    seen = set()
    unique = []
    for c in companies:
        website = (c.get("website") or "").lower().strip()
        # extract domain from website URL
        from urllib.parse import urlparse
        domain = urlparse(website).netloc.replace("www.", "") if website else ""
        if domain and domain not in seen:
            seen.add(domain)
            c["domain"] = domain
            unique.append(c)
    return unique


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icp", required=True)
    args = ap.parse_args()

    with open(args.icp) as f:
        icp = json.load(f)

    companies = search(icp)
    for c in companies:
        print(json.dumps(c))
    print(f"[IcyPeas] {len(companies)} unique companies", file=sys.stderr)


if __name__ == "__main__":
    main()
