#!/usr/bin/env bash
set -euo pipefail

# ── Test Cross-Skill Contracts ──────────────────────────────────────
# Parses contract blocks in docs/workflow-spec.md and validates them
# against actual skill/command files. Catches broken handoffs.
# No external dependencies — uses only Python stdlib.
# ────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_FILE="$REPO_ROOT/docs/workflow-spec.md"

pass_count=0
fail_count=0

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass_count=$((pass_count + 1)); }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail_count=$((fail_count + 1)); }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$1"; }

# ── Prereqs ──────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found." >&2
  exit 2
fi

if [ ! -f "$SPEC_FILE" ]; then
  echo "ERROR: workflow-spec.md not found at $SPEC_FILE" >&2
  exit 2
fi

# ── Run contract validation ──────────────────────────────────────────
results=$(SPEC_FILE="$SPEC_FILE" REPO_ROOT="$REPO_ROOT" python3 << 'PYEOF'
import os, re, sys

spec_file = os.environ["SPEC_FILE"]
repo_root = os.environ["REPO_ROOT"]

with open(spec_file) as f:
    spec_text = f.read()

# ── Extract contract blocks ──────────────────────────────────────────
# Each contract is between <!-- spec:contract:<name> --> and the closing ```
contract_pattern = re.compile(
    r'<!-- spec:contract:(\S+?) -->\s*```yaml\s*\n(.*?)```',
    re.DOTALL
)

raw_contracts = {}
for m in contract_pattern.finditer(spec_text):
    raw_contracts[m.group(1)] = m.group(2)

expected = [
    "inner-loop-chain", "artifact-registry", "post-plan-chain",
    "project-start-chain", "context-skill-standard", "decision-trace"
]

for name in expected:
    if name in raw_contracts:
        print(f"PASS:extraction: {name} found")
    else:
        print(f"FAIL:extraction: {name} not found")

# ── Helpers ──────────────────────────────────────────────────────────

def unquote(s):
    """Strip whitespace and surrounding quotes from a YAML value."""
    return s.strip().strip('"').strip("'")

def ensure_list(v):
    """Coerce a value to a list (handles str from scalar YAML parsing)."""
    if isinstance(v, list):
        return v
    if isinstance(v, str):
        return [v]
    return []

def check_file(label, path):
    """Check if a file exists and print PASS/FAIL."""
    if os.path.isfile(os.path.join(repo_root, path)):
        print(f"PASS:{label}: '{path}' exists")
    else:
        print(f"FAIL:{label}: '{path}' does not exist")

def extract_scalar(key, text):
    """Extract a scalar value like 'key: value' from YAML text."""
    m = re.search(rf'(?:^|\n)\s*{re.escape(key)}:\s*(.+)', text)
    if m:
        val = unquote(m.group(1))
        return None if val == 'null' else val
    return None

def extract_inline_or_block_list(key, text):
    """Extract a YAML list — handles inline [a, b] and block (- item) forms."""
    # Inline: key: [a, b, c] or key: []
    inline = re.search(rf'(?:^|\n)(\s*){re.escape(key)}:\s*\[([^\]]*)\]', text)
    if inline:
        content = inline.group(2).strip()
        if not content:
            return []
        return [unquote(item) for item in content.split(',')]

    # Block: key:\n  - item\n  - item
    block = re.search(rf'(?:^|\n)(\s*){re.escape(key)}:\s*\n', text)
    if block:
        indent = len(block.group(1))
        # Collect subsequent lines that are more indented and start with -
        remainder = text[block.end():]
        items = []
        for line in remainder.split('\n'):
            stripped = line.lstrip()
            line_indent = len(line) - len(stripped)
            if not stripped:
                continue
            if line_indent <= indent:
                break
            if stripped.startswith('- '):
                items.append(unquote(stripped[2:]))
        return items

    return []

def extract_block_map(key, text):
    """Extract a nested YAML mapping like 'key:\\n  subkey: value'."""
    block = re.search(rf'(?:^|\n)(\s*){re.escape(key)}:\s*\n', text)
    if not block:
        return {}
    indent = len(block.group(1))
    remainder = text[block.end():]
    result = {}
    for line in remainder.split('\n'):
        stripped = line.lstrip()
        line_indent = len(line) - len(stripped)
        if not stripped:
            continue
        if line_indent <= indent:
            break
        if ':' in stripped and not stripped.startswith('- '):
            k, _, v = stripped.partition(':')
            result[k.strip()] = unquote(v)
    return result

def extract_sequence_items(key, text):
    """Extract a list of dicts from YAML sequence: key:\\n  - field: val."""
    block = re.search(rf'(?:^|\n)(\s*){re.escape(key)}:\s*\n', text)
    if not block:
        return []
    base_indent = len(block.group(1))
    remainder = text[block.end():]
    items = []
    current = None

    for line in remainder.split('\n'):
        stripped = line.lstrip()
        line_indent = len(line) - len(stripped)
        if not stripped:
            continue
        if line_indent <= base_indent:
            break
        # Skip YAML comments (they contain ':' which confuses the KV parser)
        if stripped.startswith('#'):
            if current is not None:
                current['_raw'] += line + '\n'
            continue
        # New item starts with "- key: value"
        item_match = re.match(r'-\s+(\S+):\s*(.*)', stripped)
        if item_match and line_indent == base_indent + 2:
            if current is not None:
                items.append(current)
            current = {'_raw': ''}
            k = item_match.group(1)
            v = unquote(item_match.group(2))
            current[k] = None if v == 'null' else v
            current['_raw'] = line + '\n'
        elif current is not None:
            # Continuation of current item
            if ':' in stripped and not stripped.startswith('-'):
                k, _, v = stripped.partition(':')
                k = k.strip()
                v = v.strip()
                if v.startswith('['):
                    # Inline list
                    content = v[1:-1].strip()
                    current[k] = [unquote(i) for i in content.split(',')] if content else []
                elif v:
                    current[k] = None if unquote(v) == 'null' else unquote(v)
                else:
                    current[k] = None  # placeholder for block list; second pass extracts it
            current['_raw'] += line + '\n'

    if current is not None:
        items.append(current)

    # Second pass: extract block lists within each item's raw text
    for item in items:
        raw = item.pop('_raw', '')
        for k in list(item.keys()):
            if item[k] is None or item[k] == '':
                # Might be a block list
                block_items = extract_inline_or_block_list(k, raw)
                if block_items:
                    item[k] = block_items

    return items

# ── Name resolution ──────────────────────────────────────────────────

SKIP_REASONS = {"terminal", "issue_ref", "annotation"}

def resolve_name(name):
    """Resolve a contract entity name to a file path relative to repo root.
    Returns (path, skip_reason). skip_reason is in SKIP_REASONS for
    legitimate skips, or 'error:...' for resolution failures."""
    if name is None:
        return None, "terminal"

    original = name

    # Issue references like "BC-1944 (trait-conditional...)"
    if re.match(r'^[A-Z]+-\d+', name):
        return None, "issue_ref"

    # Annotations with "via" like "session-start (via CLAUDE.md @import)"
    if "(via " in name:
        return None, "annotation"

    # Strip parenthetical qualifiers: "ship (command)" → "ship"
    if " (" in name:
        name = name.split(" (")[0].strip()

    # Strip /workflows: prefix
    name = re.sub(r'^/workflows:', '', name)

    # Try as skill first
    skill_path = f"plugins/workflows/skills/{name}/SKILL.md"
    if os.path.isfile(os.path.join(repo_root, skill_path)):
        return skill_path, None

    # Try as command
    cmd_path = f"plugins/workflows/commands/{name}.md"
    if os.path.isfile(os.path.join(repo_root, cmd_path)):
        return cmd_path, None

    return None, f"error: could not resolve '{original}'"

# ── Validate chain contracts ─────────────────────────────────────────

chain_names = ["inner-loop-chain", "post-plan-chain"]

for chain_name in chain_names:
    if chain_name not in raw_contracts:
        continue

    steps = extract_sequence_items("sequence", raw_contracts[chain_name])

    for step in steps:
        from_name = step.get("from")
        to_name = step.get("to")

        # Validate 'from'
        from_path, from_reason = resolve_name(from_name)
        if from_reason in SKIP_REASONS:
            pass  # terminal/annotation/issue ref — skip silently
        elif from_path:
            print(f"PASS:{chain_name}: from '{from_name}' → {from_path}")
        else:
            print(f"FAIL:{chain_name}: from '{from_name}' — {from_reason}")

        # Validate 'to'
        to_path, to_reason = resolve_name(to_name)
        if to_reason == "terminal":
            print(f"PASS:{chain_name}: to 'null' (terminal)")
        elif to_reason in SKIP_REASONS:
            pass  # annotation/issue ref — skip silently
        elif to_path:
            print(f"PASS:{chain_name}: to '{to_name}' → {to_path}")
        else:
            print(f"FAIL:{chain_name}: to '{to_name}' — {to_reason}")

    # Handoff connectivity: adjacent A.provides should overlap B.requires
    for i in range(len(steps) - 1):
        step_a = steps[i]
        step_b = steps[i + 1]
        provides = ensure_list(step_a.get("provides", []))
        requires = ensure_list(step_b.get("requires", []))

        from_a = step_a.get("from", "?")
        handoff = step_a.get("to", "?")
        to_b = step_b.get("to", "?")
        label = f"{from_a}→[{handoff}]→{to_b}"

        if not requires:
            print(f"PASS:{chain_name}: handoff {label} (no requirements)")
            continue

        # Pre-split and lowercase to avoid O(n³) inside loop
        provide_words = set()
        for p in provides:
            for word in p.lower().split():
                if len(word) > 3:
                    provide_words.add(word)

        requires_lower = [r.lower() for r in requires]

        connected = any(word in req for word in provide_words for req in requires_lower)

        if connected:
            print(f"PASS:{chain_name}: handoff {label} connected")
        else:
            print(f"WARN:{chain_name}: handoff {label} — no obvious provides/requires overlap (may be implicit)")

# ── Validate artifact registry ───────────────────────────────────────

if "artifact-registry" in raw_contracts:
    artifacts = extract_sequence_items("artifacts", raw_contracts["artifact-registry"])

    for artifact in artifacts:
        art_id = artifact.get("id", "?")
        producer = artifact.get("producer")
        consumers = ensure_list(artifact.get("consumers", []))

        # Validate producer
        prod_path, prod_reason = resolve_name(producer)
        if prod_reason in SKIP_REASONS:
            pass  # annotation/issue ref — skip
        elif prod_path:
            print(f"PASS:artifact-registry: [{art_id}] producer '{producer}' exists")
        else:
            print(f"FAIL:artifact-registry: [{art_id}] producer '{producer}' — {prod_reason}")

        # Validate consumers
        for consumer in consumers:
            cons_path, cons_reason = resolve_name(consumer)
            if cons_reason in SKIP_REASONS:
                continue
            if cons_path:
                print(f"PASS:artifact-registry: [{art_id}] consumer '{consumer}' exists")
            else:
                print(f"FAIL:artifact-registry: [{art_id}] consumer '{consumer}' — {cons_reason}")

# ── Validate structural contracts ────────────────────────────────────

# context-skill-standard
if "context-skill-standard" in raw_contracts:
    text = raw_contracts["context-skill-standard"]
    spec_path = extract_scalar("spec", text)
    if spec_path:
        check_file("context-skill-standard: spec", spec_path)

    t2d = extract_block_map("trait-to-domain", text)
    t2c = extract_block_map("trait-to-context-doc", text)
    if t2d and t2c and set(t2d.keys()) == set(t2c.keys()):
        print(f"PASS:context-skill-standard: trait mappings consistent ({len(t2d)} traits)")
    elif t2d and t2c:
        diff = set(t2d.keys()).symmetric_difference(set(t2c.keys()))
        print(f"FAIL:context-skill-standard: trait mapping keys differ — {diff}")
    else:
        print(f"FAIL:context-skill-standard: could not extract trait mappings")

# decision-trace
if "decision-trace" in raw_contracts:
    text = raw_contracts["decision-trace"]
    spec_path = extract_scalar("spec", text)
    if spec_path:
        check_file("decision-trace: spec", spec_path)

    storage = extract_block_map("storage", text)
    index_path = storage.get("index")
    if index_path:
        check_file("decision-trace: index", index_path)

# project-start-chain
if "project-start-chain" in raw_contracts:
    text = raw_contracts["project-start-chain"]
    valid_traits = extract_inline_or_block_list("valid-traits", text)
    if valid_traits:
        print(f"PASS:project-start-chain: valid-traits has {len(valid_traits)} entries")
    else:
        print(f"FAIL:project-start-chain: valid-traits is empty or missing")

    consumers = extract_inline_or_block_list("consumers", text)
    if consumers:
        print(f"PASS:project-start-chain: consumers has {len(consumers)} entries")
    else:
        print(f"FAIL:project-start-chain: consumers is empty or missing")

PYEOF
)

# ── Parse results ────────────────────────────────────────────────────
section "Cross-Skill Contract Validation"

while IFS= read -r line; do
  if [[ "$line" == PASS:* ]]; then
    pass "${line#PASS:}"
  elif [[ "$line" == FAIL:* ]]; then
    fail "${line#FAIL:}"
  elif [[ "$line" == WARN:* ]]; then
    printf "  \033[33mWARN\033[0m  %s\n" "${line#WARN:}"
  fi
done <<< "$results"

if [ "$((pass_count + fail_count))" -eq 0 ]; then
  echo "ERROR: no checks executed — spec may be empty or Python output malformed" >&2
  exit 2
fi

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
section "Summary"

echo "  Total: $((pass_count + fail_count))  Passed: $pass_count  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
  printf "  \033[31m%d check(s) failed\033[0m\n" "$fail_count"
  echo ""
  exit 1
else
  printf "  \033[32mAll checks passed\033[0m\n"
  echo ""
  exit 0
fi
