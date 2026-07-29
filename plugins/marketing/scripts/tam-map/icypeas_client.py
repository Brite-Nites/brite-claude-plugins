#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/icypeas_client.py
# Changes: verbatim port + find-companies query-object remap (BC-12163)
#          + size_band -> query.headcount range filter (BC-13013)

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
- The ICP's `size_band` narrows the pull via `query.headcount` (BC-13013). IcyPeas
  bills per record RETURNED and this client pages the whole result set, so an
  unnarrowed industry keyword is a cost event as well as a quality problem.
"""
import argparse
import json
import os
import sys

BASE_URL = "https://app.icypeas.com/api"


def _num(value):
    """Return value if it is a usable numeric bound, else None.

    `bool` is excluded explicitly — it subclasses `int` in Python, so a stray
    `"employee_min": true` would otherwise silently become `headcount >= 1`.
    """
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return value


def build_headcount(icp: dict) -> dict:
    """Map the ICP's `size_band` to IcyPeas's numeric `headcount` range object.

    IcyPeas numeric filters key on comparison OPERATORS — `">"`, `">="`, `"<"`,
    `"<="` — NOT `min`/`max` (that shape belongs to `headcountGrowth`). Source:
    api-doc.icypeas.com/leads-db/find-companies. Bounds are independently
    optional, so an ICP carrying only `employee_min` still narrows the pull.

    Inclusive operators are used because `size_band` bounds are inclusive: the
    corporate-campuses ICP's "1,000+ employees" means >= 1000, not > 1000.

    Returns {} when the ICP declares no usable band — the caller then omits the
    key entirely rather than sending an empty object.
    """
    band = icp.get("size_band") or {}
    lo = _num(band.get("employee_min"))
    hi = _num(band.get("employee_max"))

    headcount = {}
    if lo is not None:
        headcount[">="] = lo
    if hi is not None:
        headcount["<="] = hi

    if lo is not None and hi is not None and hi < lo:
        # Inverted band matches nothing. Keep the filter (an empty result costs
        # no credits; dropping it would silently restore the unbounded pull this
        # filter exists to prevent) but say so loudly — a silent 0 would other-
        # wise read as "this keyword has no companies".
        print(
            f"  [icypeas] ⚠ size_band is inverted (employee_min={lo} > "
            f"employee_max={hi}) — headcount filter will match nothing",
            file=sys.stderr,
        )
    return headcount


def build_query(icp: dict, industry: str) -> dict:
    """Build the `query` object for one industry keyword. Pure — no IO."""
    # IcyPeas redesigned find-companies to require a structured `query` object
    # (BC-12163). Map the consumer's free-text industry term -> query.keyword
    # (free-text across the company profile — the old top-level `keywords`
    # semantic); regions -> query.location. NB: query.industry is a controlled
    # taxonomy, so free-text terms there return success:true + total 0 (silently
    # unfiltered); query.keyword is the faithful mapping. Old `limit` -> pagination.size.
    query = {"keyword": {"include": [industry]}}
    regions = icp.get("geo", {}).get("regions", [])
    if regions:
        query["location"] = {"include": regions}
    headcount = build_headcount(icp)
    if headcount:
        query["headcount"] = headcount
    return query


def search(icp: dict) -> list[dict]:
    # Imported lazily so the pure query builders above stay importable (and unit
    # testable) on a stdlib-only interpreter — CI installs pytest, not requests.
    import requests
    from dotenv import load_dotenv

    load_dotenv()
    api_key = os.getenv("ICYPEAS_API_KEY")
    if not api_key:
        print("ERROR: ICYPEAS_API_KEY not set in .env", file=sys.stderr)
        sys.exit(1)

    headers = {"Authorization": api_key, "Content-Type": "application/json"}
    industries = icp.get("industries", [])

    companies = []
    for industry in industries:
        query = build_query(icp, industry)
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
