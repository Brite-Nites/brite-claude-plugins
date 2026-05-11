#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/verify_smtp.py
# Changes: verbatim port + BC-7051 local fix (split async/sync CMs at line 68 — see UPSTREAM.md)

"""
SMTP verification via MillionVerifier.

Reads enriched.jsonl, sends each email through MillionVerifier,
tags catch-all separately. Keeps codes 1 (valid) + 2 (catch_all).
Drops codes 3-6 (invalid/unknown/disposable).

Usage:
  python scripts/verify_smtp.py --in enriched.jsonl --out verified.jsonl

Notes:
- Rate limit: 160 req/sec
- User-Agent header required
- catch_all records are kept but flagged (route separately downstream)
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

MV_KEY = os.getenv("MILLIONVERIFIER_API_KEY")
MV_URL = "https://api.millionverifier.com/api/v3/"
CONCURRENCY = 150


async def verify_one(session, record: dict) -> dict:
    email = record.get("email")
    if not email:
        return {**record, "smtp": {"result": "no_email", "keep": False}}

    params = {"api": MV_KEY, "email": email, "timeout": 10}
    headers = {"User-Agent": "tam-map/1.0"}
    try:
        async with session.get(MV_URL, params=params, headers=headers, timeout=20) as r:
            data = await r.json()
            result_code = data.get("resultcode")
            result = data.get("result", "unknown")
            keep = result_code in (1, 2)  # valid + catch_all
            is_catch_all = result_code == 2
            return {
                **record,
                "smtp": {
                    "result": result,
                    "result_code": result_code,
                    "catch_all": is_catch_all,
                    "keep": keep,
                },
            }
    except Exception as e:
        return {**record, "smtp": {"result": "error", "error": str(e), "keep": False}}


async def run(records: list[dict], outfile: str):
    sem = asyncio.Semaphore(CONCURRENCY)
    with open(outfile, "w") as f:
        async with aiohttp.ClientSession() as session:
            async def bound(rec):
                async with sem:
                    return await verify_one(session, rec)
            tasks = [bound(r) for r in records]
            done = 0
            for coro in asyncio.as_completed(tasks):
                result = await coro
                f.write(json.dumps(result) + "\n")
                f.flush()
                done += 1
                if done % 500 == 0:
                    print(f"  [smtp] {done}/{len(records)}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="infile", required=True)
    ap.add_argument("--out", dest="outfile", required=True)
    args = ap.parse_args()

    if not MV_KEY:
        print("ERROR: MILLIONVERIFIER_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    records = []
    with open(args.infile) as f:
        for line in f:
            if line.strip():
                records.append(json.loads(line))

    print(f"[SMTP] Verifying {len(records)} emails...", file=sys.stderr)
    t0 = time.time()
    asyncio.run(run(records, args.outfile))
    dt = time.time() - t0

    # quick summary
    kept = 0
    catch = 0
    with open(args.outfile) as f:
        for line in f:
            r = json.loads(line)
            s = r.get("smtp", {})
            if s.get("keep"):
                kept += 1
            if s.get("catch_all"):
                catch += 1
    print(f"[SMTP] {kept} kept ({catch} catch-all, {kept - catch} valid) in {dt:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
