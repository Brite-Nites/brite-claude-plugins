"""Contract tests for the /revops:doctor slash command.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, the nine
required checks, the table+Overall+remediation reporting shape, zero-gate /
zero-mutation / no-retry rules, version bump) rather than runtime execution.
The live walk (zero-mutation diff + idempotent re-run against brite-sandbox) is
recorded as a Linear comment on BC-10660, not asserted here.

Pattern mirrors test_setup_sandbox_contracts.py: read the artifact, assert the
contract is met. No mocks, no subprocess, no SF org dependency. Stdlib only —
the repo has no third-party deps; embedded YAML is parsed with regex, not yaml.

No pytest installed locally? Run as a plain script:
    cd plugins/revops/tests
    python3 -c "import test_doctor_contracts as t; \
[getattr(t,n)() for n in dir(t) if n.startswith('test_')]; print('all pass')"
"""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "doctor.md"
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT.parents[1] / ".claude-plugin" / "marketplace.json"


@functools.lru_cache(maxsize=1)
def read_command() -> str:
    # Cached: the command file is immutable for the duration of a test run,
    # and every test reads it — one disk read instead of one per assertion.
    return COMMAND_PATH.read_text()


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "Expected YAML frontmatter wrapped in --- markers"
    return match.group(1), match.group(2)


def test_command_file_exists() -> None:
    assert COMMAND_PATH.is_file(), f"Slash command file missing: {COMMAND_PATH}"


def test_frontmatter_has_description_and_allowed_tools() -> None:
    frontmatter, _ = split_frontmatter(read_command())
    assert re.search(r"^description: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare a `description` field"
    assert re.search(r"^allowed-tools: ", frontmatter, re.MULTILINE), \
        "Frontmatter must declare an `allowed-tools` field"


def test_allowed_tools_is_exactly_bash() -> None:
    """doctor is read-only and zero-gate by design: no mutating Bash gate, no
    AskUserQuestion, no Read, no MCP tools. The only tool it needs is Bash to
    run the probe script. This is the AC's headline contract.
    """
    frontmatter, _ = split_frontmatter(read_command())
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    assert tools_line, "allowed-tools line not found"
    declared = {t.strip() for t in tools_line.split(":", 1)[1].split(",") if t.strip()}
    assert declared == {"Bash"}, (
        f"allowed-tools must be exactly {{Bash}} (read-only, zero-gate); got {sorted(declared)}"
    )


def test_no_gate_prompts() -> None:
    """doctor has NO gates — it never prompts. This is the headline behavioral
    contract (the design difference from setup-sandbox), so lock it on what the
    file actually contains, two ways: (1) the sibling's gate-prompt marker must
    be absent, and (2) "AskUserQuestion" may appear at most in the single Rules
    sentence that *forbids* gates. A real gate added in any phrasing introduces a
    second occurrence and breaks (2); a gate using the sibling marker breaks (1).
    Belt-and-suspenders with test_allowed_tools_is_exactly_bash, which already
    blocks a *functional* gate via the tool surface.

    Counting the sibling marker alone (as an earlier version did) was tautological
    here — the marker never appears in doctor.md, so `== 0` passed regardless of
    content and protected nothing (caught in review, BC-10660).
    """
    body = read_command()
    assert "Ask via `AskUserQuestion`:" not in body, (
        "doctor must contain no AskUserQuestion gate-prompt marker (it is zero-gate)"
    )
    occurrences = body.count("AskUserQuestion")
    assert occurrences == 1, (
        "AskUserQuestion may appear exactly once — the lone Rules sentence that "
        f"forbids gates; found {occurrences} (a real gate would add a second)"
    )


def test_all_check_topics_present() -> None:
    """Every AC-required check (nine) must be greppable so the contract is auditable."""
    body = read_command().lower()
    topics = {
        "sf CLI version": ["sf --version"],
        "node": ["node --version"],
        "gh auth": ["gh auth status"],
        "plugin-installed": ["claude plugin list"],
        "mcp-connected": ["claude mcp list"],
        "brite-sandbox authed": ["sf org list", "connectedstatus"],
        "default target-org": ["sf config get target-org"],
        "trivial SOQL": ["select id from organization limit 1"],
        "permset self-probe": ["permissionsetassignment"],
    }
    missing = {
        topic: absent
        for topic, needles in topics.items()
        if (absent := [s for s in needles if s not in body])
    }
    assert not missing, f"Check topics missing from command body: {missing}"


def test_nine_emit_labels_present() -> None:
    """The AC names exactly nine checks. test_all_check_topics_present greps a
    representative command per topic, but that passes even if a check's `emit`
    row were deleted while its prose needle survived. Lock the actual emit labels
    (the second arg of each `emit STATUS "<label>"`) by set-equality so dropping,
    merging, renaming, or adding a check fails until the contract is updated
    intentionally. The regex matches only the script's emit lines, not the report
    example table (which uses `| sf CLI | PASS |`, no `emit`).
    """
    _, body = split_frontmatter(read_command())
    labels = set(re.findall(r'emit (?:PASS|FAIL|WARN|SKIP) "([^"]+)"', body))
    expected = {
        "sf CLI", "node", "gh auth", "revops plugin", "revops MCP",
        "brite-sandbox auth", "default target-org", "trivial SOQL",
        "permset self-probe",
    }
    assert labels == expected, (
        "doctor must emit exactly the nine AC check labels; "
        f"missing={expected - labels}, unexpected={labels - expected}"
    )


def test_key_commands_present_verbatim() -> None:
    body = read_command()
    expected = [
        "sf --version",
        "claude plugin list",
        "claude mcp list",
        "sf org list",
        "sf config get target-org",
        "sf data query --target-org brite-sandbox",
        "SELECT Id FROM Organization LIMIT 1",
        "PermissionSetAssignment",
    ]
    missing = [cmd for cmd in expected if cmd not in body]
    assert not missing, f"Key commands missing verbatim from command body: {missing}"


def test_status_vocabulary_is_pass_fail_warn_skip() -> None:
    """The reporting contract is a PASS/FAIL/WARN/SKIP table — all four statuses
    must appear (WARN distinguishes advisory states like a wrong default-org
    from hard FAILs).
    """
    body = read_command()
    missing = [s for s in ("PASS", "FAIL", "WARN", "SKIP") if s not in body]
    assert not missing, f"Status vocabulary tokens missing: {missing}"


def test_warn_and_skip_severity_routing() -> None:
    """The AC's severity contract: a wrong/unset default-target-org and a missing
    permset group are advisory (emit WARN, never FAIL); a missing prerequisite is
    emit SKIP (never FAIL) — the SKIP-cascade is what keeps the report
    deterministic across runs. test_status_vocabulary only proves the four tokens
    appear *somewhere* (they also appear in prose), so it can't catch a future
    edit flipping a WARN/SKIP to FAIL. Lock the actual emit lines.
    """
    _, body = split_frontmatter(read_command())
    required = [
        r'emit WARN "default target-org"',
        r'emit WARN "permset self-probe"',
        r'emit SKIP "brite-sandbox auth"',
        r'emit SKIP "trivial SOQL"',
    ]
    missing = [pat for pat in required if not re.search(pat, body)]
    assert not missing, f"Required WARN/SKIP severity routing missing: {missing}"

    # Bidirectional lock: the advisory checks must NEVER emit FAIL. Asserting the
    # WARN line *exists* would not catch an additive regression that keeps the
    # WARN branch but also adds an `emit FAIL` branch for the same check. doctor
    # has exactly four advisory (PASS/WARN/SKIP-only) checks: default-target-org
    # and permset (AC-named), plus gh auth and revops MCP (not hard SF-auth
    # prerequisites). The other five checks legitimately FAIL on a hard problem.
    forbidden = [
        r'emit FAIL "default target-org"',
        r'emit FAIL "permset self-probe"',
        r'emit FAIL "gh auth"',
        r'emit FAIL "revops MCP"',
    ]
    present = [pat for pat in forbidden if re.search(pat, body)]
    assert not present, (
        "the four advisory checks (default-target-org, permset, gh auth, revops "
        f"MCP) emit only PASS/WARN/SKIP — they must never emit FAIL: {present}"
    )


def test_reporting_has_overall_and_remediation() -> None:
    """Output is a table + an Overall line + per-FAIL/WARN remediation, and the
    auth/default-org remediation must route back to /revops:setup-sandbox.
    """
    body = read_command()
    assert "Overall" in body, "Report must include an Overall line (mirror smoke-test)"
    assert "Remediation" in body, "Report must include a Remediation section for FAIL/WARN"
    assert "/revops:setup-sandbox" in body, (
        "Auth/default-org remediation must point at /revops:setup-sandbox"
    )


def test_zero_mutation_and_no_retry_rules_present() -> None:
    """Two load-bearing safety properties a future edit could silently drop:
    zero-mutation (the whole point of a re-runnable health check) and no-retry.
    """
    body = read_command().lower()
    assert "zero mutation" in body, \
        "Command must promise zero mutation (greppable as 'zero mutation')"
    assert "no retry" in body, \
        "Command must document the no-retry rule (greppable as 'no retry')"


def test_idempotent_documented() -> None:
    body = read_command().lower()
    assert "idempotent" in body, \
        "Command must document its idempotent contract"
    assert "identical" in body, (
        "Idempotent contract must promise identical reports across runs, not just "
        "use the word 'idempotent'"
    )


def test_overall_verdict_vocabulary_present() -> None:
    """The Overall line carries a three-state verdict; lock all three tiers so one
    can't be silently dropped or renamed while the bare word 'Overall' survives.
    """
    body = read_command()
    for verdict in ("healthy", "ready, with advisories", "not ready"):
        assert verdict in body, f"Overall verdict tier missing: {verdict!r}"


def test_no_sfdx_legacy_invocations() -> None:
    """Rules: `sf`, not legacy `sfdx`. Prose may *mention* `sfdx` to forbid it;
    only an actual `sfdx <subcommand>` invocation violates the contract.
    """
    body = read_command()
    invocation = re.search(r"\bsfdx\s+\w", body)
    assert not invocation, (
        "Command must use `sf`, never a legacy `sfdx <subcommand>` invocation; "
        f"found: {invocation.group(0)!r}"
    )


def test_command_has_no_emoji() -> None:
    """User convention: no emojis in generated content. Check emoji codepoint
    ranges specifically — NOT a blanket non-ASCII check, which would wrongly
    reject the command's legitimate em-dashes (U+2014) and section signs.
    """
    body = read_command()
    emoji = sorted({
        c for c in body
        if 0x1F000 <= ord(c) <= 0x1FAFF      # emoji & pictographs (incl. supplemental)
        or 0x2600 <= ord(c) <= 0x27BF        # misc symbols + dingbats
        or 0x2B00 <= ord(c) <= 0x2BFF        # misc symbols & decorative arrows
        or ord(c) in (0x2122, 0x2139, 0xFE0F, 0x20E3)  # tm, info, VS16, keycap
    })
    assert not emoji, (
        f"Command must contain no emoji (no-emoji convention); found: "
        f"{[(c, hex(ord(c))) for c in emoji]}"
    )


def test_plugin_json_version_bumped() -> None:
    """plugin-cache gotcha: BC-10660 adds a new command, so revops version MUST
    be bumped above the 0.3.0 baseline on main in plugin.json.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    version = plugin_data["version"]
    parts = tuple(int(p) for p in version.split("."))
    assert parts > (0, 3, 0), (
        f"revops version {version} must be bumped above the 0.3.0 baseline on main "
        "— BC-10660 adds a new command and clients' plugin cache is keyed by version"
    )


def test_marketplace_json_version_mirrors_plugin_json() -> None:
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    marketplace_data = json.loads(MARKETPLACE_JSON.read_text())
    revops_entry = next(
        (p for p in marketplace_data["plugins"] if p["name"] == "revops"),
        None,
    )
    assert revops_entry, "revops plugin entry missing from marketplace.json"
    assert revops_entry["version"] == plugin_data["version"], (
        f"marketplace.json revops version ({revops_entry['version']}) must match "
        f"plugin.json ({plugin_data['version']}) — per CLAUDE.md plugin-cache gotcha"
    )
