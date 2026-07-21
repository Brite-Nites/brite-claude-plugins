#!/usr/bin/env python3
"""Manifest-consistency check for validate.sh §2b (BC-16373 version; BC-16293 description + URL).

Per plugin: plugin.json's `version` AND `description` must equal its
marketplace.json entry's. A **missing or empty** `version` on either side — or a
plugin.json with no marketplace entry at all — is a HARD ERROR, not a silent
skip: the whole version-bump machinery (same-commit bump rule, plugin-cache
keying) relies on this field being present AND matched, so a blank version
silently defeats cache invalidation. (The pre-BC-16373 inline check compared
only when both sides were truthy — `if pj_ver and mp_ver and pj_ver != mp_ver` —
so an empty version passed.)

Cross-plugin (BC-16293): every plugin.json's `homepage`/`repository` must agree
with the others. This is a single monorepo, so a divergent repo URL in any
manifest misdirects whoever reads it (three spellings drifted before BC-16293:
lowercase org, a wrong repo name, and the canonical form). Empty/absent URL
fields are not required, but any that ARE present must all match.

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

    mp_entries = {}  # name -> (version, description)
    try:
        with open(marketplace_path) as f:
            data = json.load(f)
        for entry in data.get("plugins", []):
            mp_entries[entry.get("name", "")] = (
                entry.get("version", ""),
                entry.get("description", ""),
            )
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"MISMATCH:marketplace.json unreadable ({e})")
        return 1

    homepages = {}      # name -> homepage (only when present/non-empty)
    repositories = {}   # name -> repository (only when present/non-empty)

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
        if pj_name not in mp_entries:
            errors.append(f"{pj_name}: no marketplace.json entry (cannot verify version)")
            continue
        mp_ver, mp_desc = mp_entries[pj_name]
        if not mp_ver:
            errors.append(f"{pj_name}: marketplace.json entry missing/empty version")
            continue
        if pj_ver != mp_ver:
            errors.append(f"{pj_name}: plugin.json={pj_ver} marketplace={mp_ver}")
        # Description parity (BC-16293): the two manifests must tell the same story.
        if pj.get("description", "") != mp_desc:
            errors.append(f"{pj_name}: description differs between plugin.json and marketplace.json")
        # Collect URLs for the cross-plugin consistency check below.
        if pj.get("homepage"):
            homepages[pj_name] = pj["homepage"]
        if pj.get("repository"):
            repositories[pj_name] = pj["repository"]

    # Cross-plugin URL consistency (BC-16293): all present homepage/repository
    # values must agree — one repo, one URL.
    if len(set(homepages.values())) > 1:
        detail = ", ".join(f"{n}={v}" for n, v in sorted(homepages.items()))
        errors.append(f"homepage differs across plugins: {detail}")
    if len(set(repositories.values())) > 1:
        detail = ", ".join(f"{n}={v}" for n, v in sorted(repositories.items()))
        errors.append(f"repository differs across plugins: {detail}")

    if errors:
        print("MISMATCH:" + ", ".join(errors))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
