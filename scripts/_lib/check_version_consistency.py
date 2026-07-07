#!/usr/bin/env python3
"""Version-consistency check for validate.sh §2b (BC-16373).

Every plugin.json's `version` must equal its marketplace.json entry's `version`.
A **missing or empty** `version` on either side — or a plugin.json with no
marketplace entry at all — is a HARD ERROR, not a silent skip: the whole
version-bump machinery (same-commit bump rule, plugin-cache keying) relies on
this field being present AND matched, so a blank version silently defeats
cache invalidation. (The pre-BC-16373 inline check compared only when both
sides were truthy — `if pj_ver and mp_ver and pj_ver != mp_ver` — so an empty
version passed.)

Prints `OK` (exit 0) or `MISMATCH:<comma-separated details>` (exit 1).
Args: <marketplace.json> <plugin.json>...
"""
import json
import sys


def main(argv):
    if len(argv) < 2:
        print("MISMATCH:usage: check_version_consistency.py <marketplace.json> <plugin.json>...")
        return 1
    marketplace_path = argv[1]
    plugin_paths = argv[2:]
    errors = []

    mp_versions = {}
    try:
        with open(marketplace_path) as f:
            data = json.load(f)
        for entry in data.get("plugins", []):
            mp_versions[entry.get("name", "")] = entry.get("version", "")
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"MISMATCH:marketplace.json unreadable ({e})")
        return 1

    for path in plugin_paths:
        try:
            with open(path) as f:
                pj = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            errors.append(f"{path}=UNREADABLE")
            continue
        pj_name = pj.get("name", "")
        pj_ver = pj.get("version", "")
        if not pj_name:
            errors.append(f"{path}: plugin.json missing/empty name")
            continue
        if not pj_ver:
            errors.append(f"{pj_name}: plugin.json missing/empty version")
            continue
        if pj_name not in mp_versions:
            errors.append(f"{pj_name}: no marketplace.json entry (cannot verify version)")
            continue
        mp_ver = mp_versions[pj_name]
        if not mp_ver:
            errors.append(f"{pj_name}: marketplace.json entry missing/empty version")
            continue
        if pj_ver != mp_ver:
            errors.append(f"{pj_name}: plugin.json={pj_ver} marketplace={mp_ver}")

    if errors:
        print("MISMATCH:" + ", ".join(errors))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
