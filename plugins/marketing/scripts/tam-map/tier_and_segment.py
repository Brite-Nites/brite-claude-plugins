#!/usr/bin/env python3
# Source: Revgrowth1/tam-map@9f5c72e74b (MIT)
# Ported: 2026-04-24
# License: MIT — see plugins/marketing/references/tam/UPSTREAM.md
# Upstream path: scripts/tier_and_segment.py
# Changes: verbatim port, no functional edits

"""
Tier + segment — classify each verified record into A/B/C via Claude Haiku,
split catch-all into its own segment, export campaign-ready CSVs.

Usage:
  python scripts/tier_and_segment.py \
    --in verified.jsonl \
    --icp icp.json \
    --out-dir ./output/{slug}/segments/

Outputs:
  tier-a.csv        high-fit, valid, non-catch-all
  tier-b.csv        medium-fit, valid, non-catch-all
  tier-c.csv        lower-fit, valid, non-catch-all
  catch-all.csv     any catch-all (across tiers) — ROUTE SEPARATELY
  report.md         step counts + drop reasons
"""
import argparse
import asyncio
import csv
import json
import os
import sys
import time
from dataclasses import dataclass
from dotenv import load_dotenv
import anthropic

load_dotenv()

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
MODEL = "claude-haiku-4-5-20251001"
CONCURRENCY = 20


async def score_fit(client, icp: dict, record: dict) -> str:
    """Return 'A' | 'B' | 'C' based on ICP match strength."""
    crawl = record.get("crawl", {}).get("markdown", "")[:3000]
    prompt = f"""ICP:
{json.dumps(icp, indent=2)}

Company data:
Domain: {record.get("domain")}
Name: {record.get("name") or record.get("company_name", "unknown")}
Website content (truncated):
{crawl}

Task: rate this company's fit for the ICP. Reply with exactly one letter:
A = strong fit (primary target, high confidence)
B = medium fit (secondary target, some signals match)
C = weak fit (adjacent, might work but not ideal)

Letter only, nothing else."""

    msg = await asyncio.to_thread(
        client.messages.create,
        model=MODEL,
        max_tokens=5,
        messages=[{"role": "user", "content": prompt}],
    )
    text = msg.content[0].text.strip().upper()
    if text and text[0] in ("A", "B", "C"):
        return text[0]
    return "C"


async def run(records: list[dict], icp: dict, out_dir: str):
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    sem = asyncio.Semaphore(CONCURRENCY)

    async def bound(r):
        async with sem:
            try:
                return r, await score_fit(client, icp, r)
            except Exception as e:
                return r, "C"

    tasks = [bound(r) for r in records]
    scored = await asyncio.gather(*tasks)

    os.makedirs(out_dir, exist_ok=True)

    buckets = {"A": [], "B": [], "C": [], "catch_all": []}
    for rec, tier in scored:
        smtp = rec.get("smtp", {})
        if smtp.get("catch_all"):
            buckets["catch_all"].append((rec, tier))
        else:
            buckets[tier].append((rec, tier))

    def write_csv(path, rows):
        if not rows:
            return 0
        fields = ["domain", "name", "email", "first_name", "last_name", "title", "linkedin_url", "phone", "tier", "source", "smtp_result"]
        with open(path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
            w.writeheader()
            for rec, tier in rows:
                row = {k: rec.get(k, "") for k in fields}
                row["tier"] = tier
                row["smtp_result"] = rec.get("smtp", {}).get("result", "")
                row["domain"] = rec.get("domain", "")
                w.writerow(row)
        return len(rows)

    counts = {
        "A": write_csv(os.path.join(out_dir, "tier-a.csv"), buckets["A"]),
        "B": write_csv(os.path.join(out_dir, "tier-b.csv"), buckets["B"]),
        "C": write_csv(os.path.join(out_dir, "tier-c.csv"), buckets["C"]),
        "catch_all": write_csv(os.path.join(out_dir, "catch-all.csv"), buckets["catch_all"]),
    }

    with open(os.path.join(out_dir, "report.md"), "w") as f:
        f.write("# TAM Build Report\n\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("## ICP\n\n")
        f.write(f"```json\n{json.dumps(icp, indent=2)}\n```\n\n")
        f.write("## Segment counts\n\n")
        f.write(f"- Tier A (high fit, valid): {counts['A']}\n")
        f.write(f"- Tier B (medium fit, valid): {counts['B']}\n")
        f.write(f"- Tier C (weak fit, valid): {counts['C']}\n")
        f.write(f"- Catch-all (isolated): {counts['catch_all']}\n")
        f.write(f"- **Total deliverable**: {sum(counts.values())}\n\n")
        f.write("## Next steps\n\n")
        f.write("1. Upload `tier-a.csv` to your primary campaign first\n")
        f.write("2. Run `tier-b.csv` with a softer opener\n")
        f.write("3. `catch-all.csv` — route to an isolated sender group, monitor bounce closely\n")
        f.write("4. `tier-c.csv` — warm-up cadence only\n")

    return counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="infile", required=True)
    ap.add_argument("--icp", dest="icp_file", required=True)
    ap.add_argument("--out-dir", dest="out_dir", required=True)
    args = ap.parse_args()

    if not ANTHROPIC_API_KEY:
        print("ERROR: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    records = []
    with open(args.infile) as f:
        for line in f:
            if line.strip():
                r = json.loads(line)
                if r.get("smtp", {}).get("keep"):
                    records.append(r)

    with open(args.icp_file) as f:
        icp = json.load(f)

    print(f"[Tier] Scoring {len(records)} verified records...", file=sys.stderr)
    t0 = time.time()
    counts = asyncio.run(run(records, icp, args.out_dir))
    dt = time.time() - t0
    print(f"[Tier] A={counts['A']} B={counts['B']} C={counts['C']} catch_all={counts['catch_all']} in {dt:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
