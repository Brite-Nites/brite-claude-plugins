#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/enrich_waterfall.py
# Changes: verbatim port + BC-7051 local fix (split async/sync CMs) + BC-12128 BlitzAPI
#          redesign re-application (x-api-key auth + domain→owner-email chain) — see UPSTREAM.md

"""
Enrichment waterfall — BlitzAPI (owner discovery) → Prospeo (fallback).

Reads crawled.jsonl, attempts to find an owner/decision-maker email
for each company. BlitzAPI first (5 req/s serialized), Prospeo fallback for
LinkedIn-sourced profiles (20 workers max).

BlitzAPI redesigned its API (BC-12128, 2026-05-31): the one-shot
`POST /v2/enrich {website}→{email}` was removed. domain→owner-email is now a
3-call chain — domain→company LinkedIn, employee-finder (C-Team/VP/Director),
then per-person work-email lookup, iterating candidates until one resolves.
Hit-rate is company-dependent; misses fall through to Prospeo. BC-6170
(brite-enrichment MCP) supersedes this interim waterfall.

Usage:
  python scripts/enrich_waterfall.py --in crawled.jsonl --out enriched.jsonl

Notes:
- BlitzAPI: 5 req/s hard, serialized single instance, x-api-key auth, credit-metered
- Prospeo: 20 workers max (429s otherwise on mobile endpoint)
- Saves incrementally — safe to kill/resume
"""
import argparse
import asyncio
import aiohttp
import json
import os
import sys
import time
from dotenv import load_dotenv

load_dotenv()

BLITZAPI_KEY = os.getenv("BLITZAPI_KEY")
PROSPEO_API_KEY = os.getenv("PROSPEO_API_KEY")

BLITZ_BASE = "https://api.blitz-api.ai"
PROSPEO_URL = "https://api.prospeo.io/enrich-person"

# BlitzAPI redesign (BC-12128): owner-email discovery is a chain of these endpoints.
BLITZ_DECISION_MAKER_LEVELS = ["C-Team", "VP", "Director"]  # owner/C-level first
BLITZ_MAX_CANDIDATES = 5  # decision-makers to try per company (credit-metered; 5 rps cap)
BLITZ_THROTTLE_S = 0.21   # ≥1/5 s between BlitzAPI calls to honor the 5 req/s limit

# Run-scoped BlitzAPI counters. Blitz calls are serialized under Semaphore(1), so
# plain dict mutation is race-free on the Blitz path. Surfaced in run()'s end-of-run
# summary so an exhausted credit budget is distinguishable from a genuine low
# hit-rate (BC-12128 — the key is credit-metered, ~1000/period).
_BLITZ_STATS = {"calls": 0, "quota_errors": 0}
_BLITZ_QUOTA_STATUSES = {402, 403, 429}  # credit / quota / rate-limit signals


def _clean_domain(raw: str | None) -> str | None:
    """Reduce a website/domain field to a bare registrable host for the API.

    crawled.jsonl domains can arrive as full URLs (e.g. 'http://www.jet.com/');
    BlitzAPI's domain-to-linkedin wants a bare host ('jet.com').
    """
    if not raw or not isinstance(raw, str):
        return None
    d = raw.strip().lower()
    d = d.split("://", 1)[-1]          # drop scheme
    d = d.split("/", 1)[0]             # drop path
    d = d.split("@", 1)[-1]            # drop any userinfo
    if d.startswith("www."):
        d = d[4:]
    return d or None


async def _blitz_post(session, path: str, payload: dict) -> dict | None:
    """POST to BlitzAPI with x-api-key auth. Non-200s and errors are logged to
    stderr (never silently swallowed — BC-12128), then None is returned."""
    headers = {"x-api-key": BLITZAPI_KEY, "Content-Type": "application/json"}
    _BLITZ_STATS["calls"] += 1
    try:
        async with session.post(f"{BLITZ_BASE}{path}", json=payload, headers=headers, timeout=30) as r:
            if r.status != 200:
                body = (await r.text())[:200]
                if r.status in _BLITZ_QUOTA_STATUSES:
                    _BLITZ_STATS["quota_errors"] += 1
                    print(f"  [blitz] ⚠ quota/credit/rate limit (HTTP {r.status}) on {path} — check key-info credits", file=sys.stderr)
                else:
                    print(f"  [blitz] {path} -> HTTP {r.status}: {body}", file=sys.stderr)
                return None
            return await r.json()
    except Exception as e:
        print(f"  [blitz] {path} -> request error: {e}", file=sys.stderr)
        return None
    finally:
        await asyncio.sleep(BLITZ_THROTTLE_S)  # 5 req/s cap, applies to every call


async def blitz_enrich(session, company: dict) -> dict | None:
    """Find an owner/decision-maker work email for a company via BlitzAPI.

    BC-12128: BlitzAPI removed the one-shot `/v2/enrich`. Reconstruct domain→email
    as a 3-step chain, preserving this function's company→{email}|None contract:
      1. /v2/enrichment/domain-to-linkedin  {domain} -> company_linkedin_url
      2. /v2/search/employee-finder         {company_linkedin_url, job_level} -> decision-makers
      3. /v2/enrichment/email               {person_linkedin_url} -> work email
    Step 3 is iterated over candidates (owner/C-level first) until one resolves.
    """
    domain = _clean_domain(company.get("domain"))
    if not domain:
        return None

    # 1. domain -> company LinkedIn
    d2l = await _blitz_post(session, "/v2/enrichment/domain-to-linkedin", {"domain": domain})
    company_linkedin = (d2l or {}).get("company_linkedin_url")
    if not company_linkedin:
        print(f"  [blitz] no company LinkedIn for {domain}", file=sys.stderr)
        return None

    # 2. company -> decision-makers (owner/C-level first)
    emp = await _blitz_post(session, "/v2/search/employee-finder", {
        "company_linkedin_url": company_linkedin,
        "job_level": BLITZ_DECISION_MAKER_LEVELS,
        "max_results": BLITZ_MAX_CANDIDATES,
    })
    people = (emp or {}).get("results") or []
    if not people:
        print(f"  [blitz] no decision-makers for {domain} ({company_linkedin})", file=sys.stderr)
        return None

    # 3. iterate candidates until one yields a work email. Cap locally — don't
    #    trust the API to honor max_results, and each lookup is credit-metered.
    for person in people[:BLITZ_MAX_CANDIDATES]:
        if not isinstance(person, dict):
            continue
        plu = person.get("linkedin_url")
        if not plu:
            continue
        em = await _blitz_post(session, "/v2/enrichment/email", {"person_linkedin_url": plu})
        if em and em.get("found") and em.get("email"):
            return {
                "email": em["email"],
                "source": "blitzapi",
                "person_name": person.get("full_name"),
                "person_linkedin": plu,
                "company_linkedin": company_linkedin,
                "raw": em,
            }
    print(f"  [blitz] no work email across {len(people)} candidates for {domain}", file=sys.stderr)
    return None


async def prospeo_enrich(session, company: dict) -> dict | None:
    linkedin = company.get("linkedin_url")
    if not linkedin:
        return None
    payload = {"only_verified_email": False, "data": {"linkedin_url": linkedin}}
    headers = {"X-KEY": PROSPEO_API_KEY, "Content-Type": "application/json"}
    try:
        async with session.post(PROSPEO_URL, json=payload, headers=headers, timeout=30) as r:
            if r.status == 400:  # NO_MATCH
                return None
            if r.status != 200:
                return None
            data = await r.json()
            if data.get("email"):
                return {"email": data["email"], "source": "prospeo", "raw": data}
    except Exception:
        pass
    return None


async def enrich_one(session, blitz_sem, prospeo_sem, company: dict) -> dict:
    # try BlitzAPI first (serialized; the 5 req/s throttle lives in _blitz_post,
    # which sleeps after every call in the now-multi-call chain — BC-12128)
    async with blitz_sem:
        result = await blitz_enrich(session, company)

    if result:
        return {**company, **result}

    # Prospeo fallback (20 workers max)
    async with prospeo_sem:
        result = await prospeo_enrich(session, company)

    if result:
        return {**company, **result}

    return {**company, "enrichment_error": "no email found"}


async def run(companies: list[dict], outfile: str):
    blitz_sem = asyncio.Semaphore(1)  # serialized
    prospeo_sem = asyncio.Semaphore(20)

    tallies = {"blitzapi": 0, "prospeo": 0, "miss": 0}
    with open(outfile, "w") as f:
        async with aiohttp.ClientSession() as session:
            tasks = [enrich_one(session, blitz_sem, prospeo_sem, c) for c in companies]
            done = 0
            for coro in asyncio.as_completed(tasks):
                result = await coro
                f.write(json.dumps(result) + "\n")
                f.flush()
                src = result.get("source") or "miss"
                tallies[src] = tallies.get(src, 0) + 1
                done += 1
                if done % 100 == 0:
                    print(f"  [enrich] {done}/{len(companies)}", file=sys.stderr)

    print(f"[Waterfall] sources: blitzapi={tallies['blitzapi']} prospeo={tallies['prospeo']} "
          f"no-email={tallies['miss']} (BlitzAPI calls={_BLITZ_STATS['calls']})", file=sys.stderr)
    if _BLITZ_STATS["quota_errors"]:
        print(f"[Waterfall] ⚠⚠ BlitzAPI returned {_BLITZ_STATS['quota_errors']} quota/credit/rate "
              f"errors — owner-email coverage is DEGRADED (credit budget likely exhausted). Verify "
              f"credits via /v2/account/key-info or wait for reset; misses fell through to Prospeo.",
              file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="infile", required=True)
    ap.add_argument("--out", dest="outfile", required=True)
    args = ap.parse_args()

    if not BLITZAPI_KEY:
        print("ERROR: BLITZAPI_KEY not set", file=sys.stderr)
        sys.exit(1)

    companies = []
    with open(args.infile) as f:
        for line in f:
            if line.strip():
                companies.append(json.loads(line))

    print(f"[Waterfall] Enriching {len(companies)} companies...", file=sys.stderr)
    t0 = time.time()
    asyncio.run(run(companies, args.outfile))
    dt = time.time() - t0
    print(f"[Waterfall] Done in {dt:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
