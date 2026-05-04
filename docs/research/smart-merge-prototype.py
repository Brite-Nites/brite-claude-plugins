#!/usr/bin/env python3
"""Smart-merge formula prototype — BC-6557.

Demonstrates the per-variable formula language proposed in
docs/research/smart-merge-formula-design.md against a sample CSV of
leads + a JSON of variable definitions with formulas.

Implements the render-order pseudocode from § Formula language:
    1. Check raw against valid_if predicate (default: non-null/non-empty)
    2. If valid, return raw
    3. Else, render formula.if_missing through the substitution engine
    4. Else, return the bare default (always present per belt-and-suspenders)

Usage:
    python smart-merge-prototype.py --leads <leads.csv> --variables <vars.json>

Output: rendered template body per lead, with formulas evaluated.
"""
import argparse
import csv
import json
import re
import sys


# Sample template body exercising the four priority variables from the design doc.
TEMPLATE = (
    "Hey {FIRST_NAME}, saw {COMPANY}'s {RECENCY_ANCHOR} and figured I'd reach out "
    "before the season sets.\n"
    "Most {VERTICAL_DESCRIPTOR} teams we work with run into {SPECIFIC_FRICTION}, "
    "and one that solved it was {PROOF_POINT_COMPANY}.\n"
    "Best,\n"
    "{SENDER_FIRST_NAME}"
)


# Allowlist of valid_if predicate forms. Unknown forms fail closed (treat as invalid).
PREDICATE_PATTERNS = {
    "not_in_list": re.compile(r"^raw not in \[(.+)\]$"),
    "in_list": re.compile(r"^raw in \[(.+)\]$"),
    "length_gt": re.compile(r"^len\(raw\) > (\d+)$"),
    "regex_match": re.compile(r"^regex\.match\('(.+)', raw\)$"),
}


def evaluate_predicate(predicate: str, raw: str) -> bool:
    """Evaluate a valid_if predicate string against a raw value.

    Returns True if the predicate passes (raw is good enough to use).
    Allowlist-only — unknown patterns fail closed.
    """
    if not raw:
        return False

    m = PREDICATE_PATTERNS["not_in_list"].match(predicate)
    if m:
        items = [s.strip().strip("'\"") for s in m.group(1).split(",")]
        return raw not in items

    m = PREDICATE_PATTERNS["in_list"].match(predicate)
    if m:
        items = [s.strip().strip("'\"") for s in m.group(1).split(",")]
        return raw in items

    m = PREDICATE_PATTERNS["length_gt"].match(predicate)
    if m:
        return len(raw) > int(m.group(1))

    m = PREDICATE_PATTERNS["regex_match"].match(predicate)
    if m:
        return bool(re.match(m.group(1), raw))

    return False


def render_string(text: str, lead: dict, campaign: dict) -> str:
    """Substitute {VAR} tokens in text. Lookup order: lead, then campaign.

    Used both for resolving fallback strings (with raw lead values) and the
    final template (with resolved per-lead formula outputs).
    """
    def replace(match):
        token = match.group(1)
        if token in lead and lead[token]:
            return str(lead[token])
        if token in campaign and campaign[token]:
            return str(campaign[token])
        return match.group(0)  # leave token literal if unresolved

    return re.sub(r"\{([A-Z_]+)\}", replace, text)


def render_value(variable: dict, lead: dict, campaign: dict) -> str:
    """Apply the BC-6557 render-order pseudocode to one (variable, lead) pair."""
    name = variable["name"]
    if "default" not in variable or not variable["default"]:
        raise ValueError(
            f"Variable {name!r} missing required non-empty 'default' "
            "(belt-and-suspenders rule, BC-6557 § Formula language)"
        )

    raw = lead.get(name)
    formula = variable.get("formula")

    valid = bool(raw)
    if formula and "valid_if" in formula:
        valid = valid and evaluate_predicate(formula["valid_if"], raw)

    if valid:
        return raw

    if formula and "if_missing" in formula:
        return render_string(formula["if_missing"], lead, campaign)

    return variable["default"]


def render_lead(template: str, variables: list, lead: dict, campaign: dict) -> str:
    """Render the full template body for a single lead."""
    resolved = {v["name"]: render_value(v, lead, campaign) for v in variables}
    merged = {**campaign, **resolved, **{k: v for k, v in lead.items() if v}}
    return render_string(template, merged, {})


def load_leads(path: str) -> list:
    """Load leads from CSV, normalizing empty strings to None."""
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        return [{k: (v if v else None) for k, v in row.items()} for row in reader]


def load_spec(path: str) -> tuple:
    """Load variables JSON. Returns (custom_variables, campaign_variables)."""
    with open(path) as f:
        spec = json.load(f)
    return spec["custom_variables"], spec.get("campaign_variables", {})


def main():
    parser = argparse.ArgumentParser(description="Smart-merge formula prototype (BC-6557)")
    parser.add_argument("--leads", required=True, help="Path to leads CSV")
    parser.add_argument("--variables", required=True, help="Path to variables JSON")
    args = parser.parse_args()

    variables, campaign = load_spec(args.variables)
    leads = load_leads(args.leads)

    if not leads:
        print("No leads in CSV.", file=sys.stderr)
        return 1

    for i, lead in enumerate(leads, 1):
        rendered = render_lead(TEMPLATE, variables, lead, campaign)
        print(f"--- Lead {i}: {lead.get('email') or '(no email)'} ---")
        print(rendered)
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
