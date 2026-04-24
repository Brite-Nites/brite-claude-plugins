#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/enrich_waterfall.py
# Changes: verbatim port, no functional edits

"""
Enrichment waterfall — BlitzAPI (owner discovery) → Prospeo (fallback).

Reads crawled.jsonl, attempts to find an owner/decision-maker email
for each company. BlitzAPI first (5 req/s serialized, unlimited credits).
Prospeo fallback for LinkedIn-sourced profiles (20 workers max).

Usage:
  python scripts/enrich_waterfall.py --in crawled.jsonl --out enriched.jsonl

Notes:
- BlitzAPI: 5 req/s hard, serialized single instance
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

BLITZ_URL = "https://api.blitz-api.ai/v2/enrich"
PROSPEO_URL = "https://api.prospeo.io/enrich-person"


async def blitz_enrich(session, company: dict) -> dict | None:
    payload = {"website": company.get("domain")}
    headers = {"Authorization": f"Bearer {BLITZAPI_KEY}"}
    try:
        async with session.post(BLITZ_URL, json=payload, headers=headers, timeout=30) as r:
            if r.status != 200:
                return None
            data = await r.json()
            if data.get("email"):
                return {"email": data["email"], "source": "blitzapi", "raw": data}
    except Exception:
        pass
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
    # try BlitzAPI first (serialized, 5 req/s)
    async with blitz_sem:
        result = await blitz_enrich(session, company)
        await asyncio.sleep(0.2)  # 5 req/s

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

    async with aiohttp.ClientSession() as session, open(outfile, "w") as f:
        tasks = [enrich_one(session, blitz_sem, prospeo_sem, c) for c in companies]
        done = 0
        for coro in asyncio.as_completed(tasks):
            result = await coro
            f.write(json.dumps(result) + "\n")
            f.flush()
            done += 1
            if done % 100 == 0:
                print(f"  [enrich] {done}/{len(companies)}", file=sys.stderr)


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
