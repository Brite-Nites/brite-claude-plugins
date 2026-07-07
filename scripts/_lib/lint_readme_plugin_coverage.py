#!/usr/bin/env python3
"""README ⇄ marketplace plugin-coverage check for validate.sh §2b-readme (BC-16384).

Every plugin `name` registered in `.claude-plugin/marketplace.json` must be
mentioned in `README.md`. The front door otherwise silently omits a shipped
plugin — the 2026-07-05 audit found `brite-core` (the "strongly recommended"
hooks/brain plugin) absent from the README and its install snippet, and nothing
in CI could catch that class of drift.

Name-presence only, not content parsing (per the ticket). The name must appear
in its **backtick-wrapped** form — `` `<name>` `` — which is how the README's
plugin catalog and install commands render it. Anchoring on the backticked form
(rather than a bare substring) means a plugin whose name also occurs in ordinary
prose — e.g. "marketing" in "Domain plugins (marketing, engineering, …)" — can't
mask the very drift this check exists to catch. A marketplace entry with an
empty/missing name, or a marketplace registering no plugins at all, is itself a
defect.

Prints `OK` (exit 0) or `MISSING:<details>` (exit 1).
Args: <marketplace.json> <README.md>
"""
import json
import sys


def main(argv):
    if len(argv) != 3:
        print("MISSING:usage: lint_readme_plugin_coverage.py <marketplace.json> <README.md>")
        return 1
    marketplace_path, readme_path = argv[1], argv[2]

    try:
        with open(marketplace_path) as f:
            plugins = json.load(f).get("plugins", [])
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"MISSING:marketplace.json unreadable ({e})")
        return 1
    try:
        with open(readme_path) as f:
            readme = f.read()
    except (FileNotFoundError, OSError) as e:
        print(f"MISSING:README.md unreadable ({e})")
        return 1

    names = [p.get("name", "") if isinstance(p, dict) else "" for p in plugins]
    errors = []
    if not names:
        errors.append("marketplace.json registers no plugins")
    if any(not n for n in names):
        errors.append(f"{sum(1 for n in names if not n)} marketplace entry(ies) with empty/missing name")
    absent = [n for n in names if n and f"`{n}`" not in readme]
    if absent:
        errors.append("registered but absent from README.md (as `name`): " + ", ".join(absent))

    if errors:
        print("MISSING:" + "; ".join(errors))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
