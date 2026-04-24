#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/spider_crawl.py
# Changes: verbatim port, no functional edits

"""
Spider.cloud crawler — pull structured data from company websites.

Reads companies.jsonl (one per line, must have `domain` field), crawls
the homepage + /about + /contact, extracts signals (tech + content),
summarizes via Claude Haiku.

Usage:
  python scripts/spider_crawl.py --in ./output/{slug}/companies.jsonl --out ./output/{slug}/crawled.jsonl

Docs: https://spider.cloud/docs/api
"""
import argparse
import json
import os
import sys
import time
import asyncio
import aiohttp
from dotenv import load_dotenv

load_dotenv()

SPIDER_API_KEY = os.getenv("SPIDER_API_KEY")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

SPIDER_URL = "https://api.spider.cloud/v1/crawl"
CONCURRENCY = 50


async def crawl_one(session, company: dict) -> dict:
    domain = company.get("domain")
    if not domain:
        return {**company, "crawl_error": "no domain"}

    url = f"https://{domain}"
    headers = {"Authorization": f"Bearer {SPIDER_API_KEY}", "Content-Type": "application/json"}
    payload = {"url": url, "limit": 5, "return_format": "markdown"}

    try:
        async with session.post(SPIDER_URL, json=payload, headers=headers, timeout=60) as r:
            if r.status != 200:
                return {**company, "crawl_error": f"status {r.status}"}
            data = await r.json()
            pages = data if isinstance(data, list) else data.get("pages", [])
            markdown = "\n\n".join(p.get("content", "") for p in pages[:5])[:8000]
            return {**company, "crawl": {"markdown": markdown, "pages": len(pages)}}
    except Exception as e:
        return {**company, "crawl_error": str(e)}


async def crawl_all(companies: list[dict]) -> list[dict]:
    sem = asyncio.Semaphore(CONCURRENCY)
    async with aiohttp.ClientSession() as session:
        async def bound(c):
            async with sem:
                return await crawl_one(session, c)
        return await asyncio.gather(*[bound(c) for c in companies])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="infile", required=True)
    ap.add_argument("--out", dest="outfile", required=True)
    args = ap.parse_args()

    if not SPIDER_API_KEY:
        print("ERROR: SPIDER_API_KEY not set in .env", file=sys.stderr)
        sys.exit(1)

    companies = []
    with open(args.infile) as f:
        for line in f:
            if line.strip():
                companies.append(json.loads(line))

    print(f"[Spider] Crawling {len(companies)} companies...", file=sys.stderr)
    t0 = time.time()
    results = asyncio.run(crawl_all(companies))
    dt = time.time() - t0

    with open(args.outfile, "w") as f:
        for r in results:
            f.write(json.dumps(r) + "\n")

    ok = sum(1 for r in results if "crawl" in r)
    print(f"[Spider] {ok}/{len(results)} crawled in {dt:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
