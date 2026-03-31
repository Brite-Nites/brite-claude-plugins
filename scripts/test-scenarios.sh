#!/usr/bin/env bash
set -euo pipefail

# ── Test E2E Scenario Validation ────────────────────────────────────
# Validates the mapping tables in project-start.md against 60 PRD
# scenarios (Section 10 + Appendix C), 12 false positive regressions,
# and 6 express mode file marker scenarios.
#
# Pattern: same as test-skill-triggers.sh — shell wrapper + embedded
# Python + JSON fixtures.
#
# BC-2005: End-to-end scenario validation for project-start
# ────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/scenario-registry.json"
# Intentionally workflows-specific: validates project-start command against PRD scenarios.
# Domain plugins (marketing, etc.) do not have equivalent E2E scenario tests.
PROJECT_START="$REPO_ROOT/plugins/workflows/commands/project-start.md"

pass_count=0
fail_count=0
total=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); total=$((total + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); total=$((total + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# ── Prereqs ─────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found." >&2
  exit 2
fi

if [ ! -f "$FIXTURE" ]; then
  echo "ERROR: scenario-registry.json not found at $FIXTURE" >&2
  exit 2
fi

if [ ! -f "$PROJECT_START" ]; then
  echo "ERROR: project-start.md not found at $PROJECT_START" >&2
  exit 2
fi

# ── Run validation engine ───────────────────────────────────────────
results=$(FIXTURE_PATH="$FIXTURE" PROJECT_START_PATH="$PROJECT_START" python3 << 'PYEOF'
import json, os, re, sys

fixture_path = os.environ["FIXTURE_PATH"]
project_start_path = os.environ["PROJECT_START_PATH"]

with open(fixture_path) as f:
    fixture = json.load(f)

with open(project_start_path) as f:
    project_start_lines = f.readlines()

project_start_text = "".join(project_start_lines)

# ── Parsing helpers ─────────────────────────────────────────────────

def parse_markdown_table(text, header_pattern):
    """Parse a markdown table that follows a line matching header_pattern.
    Returns list of dicts keyed by column headers."""
    lines = text.split("\n")
    table_start = None
    for i, line in enumerate(lines):
        if re.search(header_pattern, line):
            table_start = i
            break
    if table_start is None:
        return []

    # Header row is at table_start, separator at table_start+1, data starts at table_start+2
    header_line = lines[table_start]
    headers = [h.strip() for h in header_line.split("|") if h.strip()]

    rows = []
    for i in range(table_start + 2, len(lines)):
        line = lines[i].strip()
        if not line or not line.startswith("|"):
            break
        cells = [c.strip() for c in line.split("|") if c.strip()]
        if len(cells) >= len(headers):
            rows.append(dict(zip(headers, cells[:len(headers)])))
    return rows


def extract_trait_names_from_table(rows, trait_col="Trait"):
    """Extract trait names (backtick-wrapped) from a parsed table."""
    traits = []
    for row in rows:
        val = row.get(trait_col, "")
        match = re.search(r"`([^`]+)`", val)
        if match:
            traits.append(match.group(1))
    return traits


def extract_trait_to_docs_from_table(rows):
    """Extract trait -> docs mapping from the trait-to-doc table."""
    mapping = {}
    for row in rows:
        trait_val = row.get("Trait", "")
        docs_val = row.get("File(s) to Create", row.get("Expected File", ""))
        trait_match = re.search(r"`([^`]+)`", trait_val)
        if not trait_match:
            continue
        trait = trait_match.group(1)
        # Extract file paths (backtick-wrapped or bare paths)
        doc_matches = re.findall(r"`([^`]+\.md)`", docs_val)
        if not doc_matches:
            # Try bare paths
            doc_matches = re.findall(r"(docs/[a-z-]+\.md)", docs_val)
        mapping[trait] = sorted(doc_matches)
    return mapping


def extract_file_markers_from_table(rows):
    """Extract file marker -> traits mapping from the file marker table."""
    mapping = {}
    for row in rows:
        file_val = row.get("File/Directory", "")
        traits_val = row.get("Trait(s) Detected", "")
        confidence_val = row.get("Confidence", "")

        # Clean up the file marker key
        file_key = re.sub(r"`", "", file_val).strip()
        if not file_key or file_key == "—":
            continue

        # Extract trait names
        trait_matches = re.findall(r"`([^`]+)`", traits_val)
        if not trait_matches:
            continue

        mapping[file_key] = {
            "traits": sorted(trait_matches),
            "confidence": confidence_val.strip()
        }
    return mapping


def extract_trait_signals(rows):
    """Extract trait -> detection signals from the trait definition table."""
    mapping = {}
    for row in rows:
        trait_val = row.get("Trait", "")
        signals_val = row.get("Detection Signals", "")
        trait_match = re.search(r"`([^`]+)`", trait_val)
        if trait_match:
            mapping[trait_match.group(1)] = signals_val
    return mapping


def extract_trait_to_sections():
    """Extract trait -> CLAUDE.md section names from project-start.md.
    Skips compound conditions (e.g., 'produces-code AND Autonomy B')
    which are autonomy-conditional, not purely trait-conditional."""
    mapping = {}
    section_pattern = re.compile(
        r"^####\s+(.+?)\s+\(if\s+`([^`]+)`"
    )
    for line in project_start_lines:
        stripped = line.strip()
        m = section_pattern.match(stripped)
        if m:
            # Skip compound conditions (contain "AND")
            paren_content = stripped[stripped.index("("):]
            if " AND " in paren_content:
                continue
            section_name = m.group(1).strip()
            trait = m.group(2).strip()
            if trait not in mapping:
                mapping[trait] = []
            mapping[trait].append(section_name)
    return mapping


def compute_docs_for_traits(traits, trait_to_docs):
    """Given a list of traits, compute the expected doc set."""
    docs = set()
    for trait in traits:
        for doc in trait_to_docs.get(trait, []):
            docs.add(doc)
    return sorted(docs)


def compute_plugins_for_traits(traits, trait_to_plugins):
    """Given a list of traits, compute the expected plugin set.
    Workflows always activates."""
    plugins = {"Workflows"}
    for trait in traits:
        for plugin in trait_to_plugins.get(trait, []):
            plugins.add(plugin)
    return sorted(plugins)


def compute_infrastructure_for_traits(traits, trait_to_infra):
    """Given a list of traits, compute the expected infrastructure set."""
    infra = set()
    for trait in traits:
        for item in trait_to_infra.get(trait, []):
            infra.add(item)
    return sorted(infra)


def compute_sections_for_traits(traits, trait_to_sections):
    """Given a list of traits, compute the expected CLAUDE.md sections."""
    sections = set()
    for trait in traits:
        for section in trait_to_sections.get(trait, []):
            sections.add(section)
    return sorted(sections)


# ── Parse mapping tables from project-start.md ─────────────────────

# 1. Trait definition table (lines 11-23)
trait_def_rows = parse_markdown_table(project_start_text, r"^\| Trait \| Category \| Description \| Detection Signals")
impl_traits = extract_trait_names_from_table(trait_def_rows)
impl_signals = extract_trait_signals(trait_def_rows)

# 2. File marker table (lines 60-75)
file_marker_rows = parse_markdown_table(project_start_text, r"^\| File/Directory \| Trait\(s\) Detected \| Confidence")
impl_file_markers = extract_file_markers_from_table(file_marker_rows)

# 3. Trait-to-doc mapping table (lines 527-539) — use the scaffold table
doc_map_rows = parse_markdown_table(project_start_text, r"^\| Trait \| File\(s\) to Create")
impl_trait_to_docs = extract_trait_to_docs_from_table(doc_map_rows)

# 4. Post-setup verification table (lines 1001-1013) — used as cross-check
verify_rows = parse_markdown_table(project_start_text, r"^\| Trait \| Expected File")
impl_verify_docs = extract_trait_to_docs_from_table(verify_rows)

# 5. Trait -> CLAUDE.md sections (parsed from #### headings)
impl_trait_to_sections = extract_trait_to_sections()

# ── Fixture data ────────────────────────────────────────────────────
fix_traits = fixture["canonical_traits"]
fix_trait_to_docs = fixture["mapping_tables"]["trait_to_docs"]
fix_trait_to_plugins = fixture["mapping_tables"]["trait_to_plugins"]
fix_trait_to_infra = fixture["mapping_tables"]["trait_to_infrastructure"]
fix_trait_to_sections = fixture["mapping_tables"]["trait_to_claudemd_sections"]
fix_file_markers = fixture["mapping_tables"]["file_markers"]

results = []

def ok(desc):
    results.append(f"PASS:{desc}")

def fail_msg(desc, detail):
    results.append(f"FAIL:{desc}|{detail}")


# ════════════════════════════════════════════════════════════════════
# Category A: Mapping Table Consistency (fixture vs project-start.md)
# ════════════════════════════════════════════════════════════════════

# A1: Trait set matches
if sorted(fix_traits) == sorted(impl_traits):
    ok("A1: Trait set matches (11 traits)")
else:
    missing = sorted(set(fix_traits) - set(impl_traits))
    extra = sorted(set(impl_traits) - set(fix_traits))
    fail_msg("A1: Trait set mismatch", f"missing_from_impl={missing}, extra_in_impl={extra}")

# A2: Trait-to-doc mapping matches
a2_ok = True
a2_issues = []
for trait in fix_traits:
    fix_docs = sorted(fix_trait_to_docs.get(trait, []))
    imp_docs = sorted(impl_trait_to_docs.get(trait, []))
    if fix_docs != imp_docs:
        a2_ok = False
        a2_issues.append(f"{trait}: fixture={fix_docs} impl={imp_docs}")
if a2_ok:
    ok("A2: Trait-to-doc mapping matches (scaffold table)")
else:
    fail_msg("A2: Trait-to-doc mapping mismatch", "; ".join(a2_issues))

# A3: Post-setup verification table matches scaffold table
a3_ok = True
a3_issues = []
for trait in fix_traits:
    scaffold_docs = sorted(impl_trait_to_docs.get(trait, []))
    verify_docs = sorted(impl_verify_docs.get(trait, []))
    if scaffold_docs != verify_docs:
        a3_ok = False
        a3_issues.append(f"{trait}: scaffold={scaffold_docs} verify={verify_docs}")
if a3_ok:
    ok("A3: Scaffold table matches verification table")
else:
    fail_msg("A3: Scaffold/verification table mismatch", "; ".join(a3_issues))

# A4: File marker table — fixture traits match implementation
a4_ok = True
a4_issues = []
for marker_key, fix_data in fix_file_markers.items():
    # Find matching marker in implementation (flexible matching)
    imp_data = None
    for imp_key, imp_val in impl_file_markers.items():
        # Normalize: strip "or" alternatives, match core name
        if marker_key.split(" or ")[0].replace("`", "").strip() in imp_key or imp_key in marker_key:
            imp_data = imp_val
            break
    if imp_data is None:
        # Some fixture markers may not have exact match (e.g., "docs/ (3+ files)")
        for imp_key, imp_val in impl_file_markers.items():
            if marker_key.split("(")[0].strip().rstrip("/") in imp_key.split("(")[0].strip().rstrip("/"):
                imp_data = imp_val
                break
    if imp_data is None:
        a4_issues.append(f"{marker_key}: not found in implementation")
        a4_ok = False
    elif sorted(fix_data["traits"]) != sorted(imp_data["traits"]):
        a4_issues.append(f"{marker_key}: fixture={sorted(fix_data['traits'])} impl={sorted(imp_data['traits'])}")
        a4_ok = False
if a4_ok:
    ok("A4: File marker trait mappings match")
else:
    fail_msg("A4: File marker mismatch", "; ".join(a4_issues))

# A5: CLAUDE.md section headings — fixture matches implementation
a5_ok = True
a5_issues = []
for trait in fix_traits:
    fix_secs = sorted(fix_trait_to_sections.get(trait, []))
    imp_secs = sorted(impl_trait_to_sections.get(trait, []))
    if fix_secs != imp_secs:
        a5_ok = False
        a5_issues.append(f"{trait}: fixture={fix_secs} impl={imp_secs}")
if a5_ok:
    ok("A5: CLAUDE.md trait-conditional sections match")
else:
    fail_msg("A5: CLAUDE.md section mismatch", "; ".join(a5_issues))


# ════════════════════════════════════════════════════════════════════
# Category B: Trait -> Doc Mapping (per scenario)
# ════════════════════════════════════════════════════════════════════

# Section 10 scenarios — check explicit docs field
for s in fixture["section10_scenarios"]:
    computed = compute_docs_for_traits(s["traits"], fix_trait_to_docs)
    expected = sorted(s["docs"])
    if computed == expected:
        ok(f"B:{s['id']}: docs match ({s['name']})")
    else:
        missing = sorted(set(expected) - set(computed))
        extra = sorted(set(computed) - set(expected))
        fail_msg(f"B:{s['id']}: docs mismatch ({s['name']})", f"missing={missing}, extra={extra}")

# Appendix C scenarios — verify derivation is non-empty and uses only valid traits
for s in fixture["appendix_c_scenarios"]:
    # Verify all traits are canonical
    invalid_traits = [t for t in s["traits"] if t not in fix_traits]
    if invalid_traits:
        fail_msg(f"B:{s['id']}: invalid traits ({s['name']})", f"invalid={invalid_traits}")
        continue
    computed = compute_docs_for_traits(s["traits"], fix_trait_to_docs)
    if len(computed) > 0:
        ok(f"B:{s['id']}: docs derivable ({s['name']}, {len(computed)} docs)")
    else:
        fail_msg(f"B:{s['id']}: no docs derived ({s['name']})", f"traits={s['traits']}")


# ════════════════════════════════════════════════════════════════════
# Category C: Trait -> Plugin Activation (per scenario)
# ════════════════════════════════════════════════════════════════════

# Section 10 — check explicit plugins field
for s in fixture["section10_scenarios"]:
    computed = compute_plugins_for_traits(s["traits"], fix_trait_to_plugins)
    expected = sorted(s["plugins"])
    if computed == expected:
        ok(f"C:{s['id']}: plugins match ({s['name']})")
    else:
        fail_msg(f"C:{s['id']}: plugins mismatch ({s['name']})", f"expected={expected}, got={computed}")

# Appendix C — verify derivation includes Workflows and is non-empty
for s in fixture["appendix_c_scenarios"]:
    computed = compute_plugins_for_traits(s["traits"], fix_trait_to_plugins)
    if "Workflows" in computed:
        ok(f"C:{s['id']}: plugins derivable ({s['name']}, {computed})")
    else:
        fail_msg(f"C:{s['id']}: Workflows missing ({s['name']})", f"got={computed}")


# ════════════════════════════════════════════════════════════════════
# Category D: Trait -> Infrastructure (Section 10 only)
# ════════════════════════════════════════════════════════════════════

for s in fixture["section10_scenarios"]:
    computed = compute_infrastructure_for_traits(s["traits"], fix_trait_to_infra)
    expected = sorted(s["infrastructure"])
    if computed == expected:
        ok(f"D:{s['id']}: infrastructure match ({s['name']})")
    else:
        missing = sorted(set(expected) - set(computed))
        extra = sorted(set(computed) - set(expected))
        fail_msg(f"D:{s['id']}: infrastructure mismatch ({s['name']})", f"missing={missing}, extra={extra}")

    # Non-code scenarios must not have code infrastructure
    if not s["has_code"]:
        code_infra = [i for i in computed if i in ("github-repo", "gitignore-extend", "pre-commit-hook", "vscode-settings")]
        if code_infra:
            fail_msg(f"D:{s['id']}: non-code scenario has code infrastructure ({s['name']})", f"unwanted={code_infra}")
        else:
            ok(f"D:{s['id']}: no code infrastructure for non-code scenario ({s['name']})")


# ════════════════════════════════════════════════════════════════════
# Category E: Trait -> CLAUDE.md Sections (per scenario)
# ════════════════════════════════════════════════════════════════════

# Section 10
for s in fixture["section10_scenarios"]:
    computed = compute_sections_for_traits(s["traits"], fix_trait_to_sections)
    # Verify non-empty
    if len(computed) > 0:
        ok(f"E:{s['id']}: CLAUDE.md sections derivable ({s['name']}, {len(computed)} sections)")
    else:
        fail_msg(f"E:{s['id']}: no CLAUDE.md sections ({s['name']})", f"traits={s['traits']}")

    # Non-code scenarios must not have Engineering Standards
    if not s["has_code"] and "Engineering Standards" in computed:
        fail_msg(f"E:{s['id']}: non-code has Engineering Standards ({s['name']})", "")
    elif not s["has_code"]:
        ok(f"E:{s['id']}: no Engineering Standards for non-code ({s['name']})")

# Appendix C
for s in fixture["appendix_c_scenarios"]:
    computed = compute_sections_for_traits(s["traits"], fix_trait_to_sections)
    has_code = "produces-code" in s["traits"]
    if len(computed) > 0:
        ok(f"E:{s['id']}: CLAUDE.md sections derivable ({s['name']}, {len(computed)} sections)")
    else:
        fail_msg(f"E:{s['id']}: no CLAUDE.md sections ({s['name']})", f"traits={s['traits']}")

    # Non-code check
    if not has_code and "Engineering Standards" in computed:
        fail_msg(f"E:{s['id']}: non-code has Engineering Standards ({s['name']})", "")


# ════════════════════════════════════════════════════════════════════
# Category F: False Positive Regressions
# ════════════════════════════════════════════════════════════════════

for fp in fixture["false_positive_regressions"]:
    signal = fp["signal"]
    trait = fp["trait_tested"]
    signals_text = impl_signals.get(trait, "")

    # Check that the bare signal word is not a standalone trigger
    # For "deadline", "stakeholder", "deliverable" — should NOT appear
    # as bare signals in client-facing detection
    if fp["id"] in ("FP-1", "FP-2", "FP-3"):
        # "deadline" should not be in client-facing signals
        # The corrected signals use "client" prefix terms only
        if f'"{signal}"' in signals_text:
            fail_msg(f"F:{fp['id']}: bare '{signal}' in {trait} signals", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: '{signal}' not a bare {trait} signal")

    elif fp["id"] in ("FP-4", "FP-5"):
        # "stakeholder" alone should not trigger client-facing
        # Corrected signal is "external stakeholder"
        if f'"{signal}"' in signals_text and "external" not in signals_text.lower().split(signal.lower())[0][-30:]:
            fail_msg(f"F:{fp['id']}: bare '{signal}' in {trait} signals", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: '{signal}' properly qualified in {trait} signals")

    elif fp["id"] == "FP-6":
        # "deliverable" alone should not trigger client-facing
        if f'"{signal}"' in signals_text and "client" not in signals_text.lower().split(signal.lower())[0][-30:]:
            fail_msg(f"F:{fp['id']}: bare '{signal}' in {trait} signals", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: '{signal}' properly qualified in {trait} signals")

    elif fp["id"] in ("FP-7", "FP-8"):
        # "CI/CD" in automation should have "only when it's the project's core purpose" qualifier
        if "CI/CD" in signals_text:
            if "core purpose" in signals_text or "only when" in signals_text or "PRIMARY" in signals_text.upper():
                ok(f"F:{fp['id']}: CI/CD has purpose qualifier in {trait} signals")
            else:
                fail_msg(f"F:{fp['id']}: CI/CD lacks purpose qualifier in {trait}", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: CI/CD not in {trait} signals (acceptable)")

    elif fp["id"] in ("FP-9", "FP-10"):
        # "metrics" in involves-data should require co-occurrence terms
        if '"metrics"' in signals_text:
            # Should have "only with" or similar co-occurrence qualifier
            if "only with" in signals_text.lower() or "co-term" in signals_text.lower() or "warehouse" in signals_text.lower() or "pipeline" in signals_text.lower():
                ok(f"F:{fp['id']}: 'metrics' has co-occurrence qualifier in {trait} signals")
            else:
                fail_msg(f"F:{fp['id']}: 'metrics' lacks co-occurrence qualifier in {trait}", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: 'metrics' not a bare signal in {trait}")

    elif fp["id"] == "FP-11":
        # involves-data should reference Snowflake, not only BigQuery
        if "Snowflake" in signals_text:
            ok(f"F:{fp['id']}: Snowflake in {trait} signals (not stale)")
        else:
            fail_msg(f"F:{fp['id']}: Snowflake missing from {trait} signals", f"signals={signals_text[:100]}")

    elif fp["id"] == "FP-12":
        # "pipeline" in automation should have qualifier
        if "pipeline" in signals_text.lower():
            if "data" in signals_text.lower() or "automation" in signals_text.lower():
                ok(f"F:{fp['id']}: 'pipeline' has qualifier in {trait} signals")
            else:
                fail_msg(f"F:{fp['id']}: 'pipeline' lacks qualifier in {trait}", f"signals={signals_text[:100]}")
        else:
            ok(f"F:{fp['id']}: 'pipeline' not in {trait} signals")


# ════════════════════════════════════════════════════════════════════
# Category G: Express Mode File Markers
# ════════════════════════════════════════════════════════════════════

for em in fixture["express_mode_scenarios"]:
    # Compute traits by looking up each file marker
    computed_traits = set()
    confidence_map = {}
    for marker in em["file_markers"]:
        # Look up in fixture file_markers
        marker_data = fix_file_markers.get(marker)
        if marker_data:
            for t in marker_data["traits"]:
                computed_traits.add(t)
                # Track highest confidence per trait
                conf = marker_data["confidence"]
                if t not in confidence_map or conf == "High":
                    confidence_map[t] = conf

    expected_traits = sorted(em["expected_traits"])
    computed_sorted = sorted(computed_traits)

    if computed_sorted == expected_traits:
        ok(f"G:{em['id']}: traits match ({em['name']})")
    else:
        missing = sorted(set(expected_traits) - computed_traits)
        extra = sorted(computed_traits - set(expected_traits))
        fail_msg(f"G:{em['id']}: trait mismatch ({em['name']})", f"expected={expected_traits}, got={computed_sorted}, missing={missing}, extra={extra}")

    # Verify confidence levels
    conf_ok = True
    conf_issues = []
    for trait, expected_conf in em["expected_confidence"].items():
        actual_conf = confidence_map.get(trait, "None")
        if actual_conf != expected_conf:
            conf_ok = False
            conf_issues.append(f"{trait}: expected={expected_conf}, got={actual_conf}")
    if conf_ok:
        ok(f"G:{em['id']}: confidence levels match ({em['name']})")
    else:
        fail_msg(f"G:{em['id']}: confidence mismatch ({em['name']})", "; ".join(conf_issues))


# ── Output results ──────────────────────────────────────────────────
for r in results:
    print(r)

PYEOF
)

# ── Parse Python output ─────────────────────────────────────────────
while IFS= read -r line; do
  if [[ "$line" == PASS:* ]]; then
    pass "${line#PASS:}"
  elif [[ "$line" == FAIL:* ]]; then
    msg="${line#FAIL:}"
    desc="${msg%%|*}"
    detail="${msg#*|}"
    fail "$desc ($detail)"
  elif [[ "$line" == ERROR:* ]]; then
    echo "ERROR: ${line#ERROR:}" >&2
    exit 2
  fi
done <<< "$results"

if [ "$total" -eq 0 ]; then
  echo "ERROR: no test cases executed — fixture may be empty or Python output malformed" >&2
  exit 2
fi

# ════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════
section "Summary"

echo "  Total: $total  Passed: $pass_count  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d test(s) failed\033[0m\n" "$fail_count"
  echo ""
  exit 1
else
  printf "  \033[32mAll tests passed\033[0m\n"
  echo ""
  exit 0
fi
