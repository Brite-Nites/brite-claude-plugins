"""Contract tests for the /revops:setup-sandbox slash command.

Slash commands are Claude-orchestrated markdown, not executable code, so these
tests verify the markdown's contract (frontmatter, declared tools, the seven
gated phases, key verbatim commands, idempotent early-exit, version bump)
rather than runtime execution. The live walk (a dev not currently authed to
brite-sandbox reaching "connected + trivial SOQL returns a row") is recorded
as a Linear comment on BC-10657, not asserted here.

Pattern mirrors test_create_sf_campaign_contracts.py: read the artifact, assert
the contract is met. No mocks, no subprocess, no SF org dependency.

No pytest installed locally? Run as a plain script:
    cd plugins/revops/tests
    python3 -c "import test_setup_sandbox_contracts as t; \
[getattr(t,n)() for n in dir(t) if n.startswith('test_')]; print('all pass')"
"""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMAND_PATH = ROOT / "commands" / "setup-sandbox.md"
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


def test_allowed_tools_is_exactly_bash_read_askuserquestion() -> None:
    """The command is CLI-only by design (sf-mcp-username-not-alias gotcha: the
    connectivity probe uses the sf CLI, not the MCP run_soql_query). So no MCP
    tools belong in allowed-tools — only Bash, Read, AskUserQuestion.
    """
    frontmatter, _ = split_frontmatter(read_command())
    tools_line = next(
        (line for line in frontmatter.splitlines() if line.startswith("allowed-tools:")),
        None,
    )
    assert tools_line, "allowed-tools line not found"
    declared = {t.strip() for t in tools_line.split(":", 1)[1].split(",") if t.strip()}
    assert declared == {"Bash", "Read", "AskUserQuestion"}, (
        "allowed-tools must be exactly {Bash, Read, AskUserQuestion}; "
        f"got {sorted(declared)}"
    )


def test_all_seven_phases_present() -> None:
    body = read_command()
    missing = [n for n in range(1, 8) if f"## Phase {n}" not in body]
    assert not missing, f"Missing phase headings: {missing}"


def test_seven_phase_topics_present() -> None:
    """Each AC-required phase topic must be greppable so the contract is auditable."""
    body = read_command().lower()
    topics = {
        "tool detect (sf/node/gh)": ["sf --version", "node --version", "gh auth status"],
        "plugin-installed check": ["claude plugin list"],
        "authenticate": ["sf org login web --alias brite-sandbox"],
        "default target-org": ["sf config set target-org brite-sandbox"],
        "connectivity probe": ["select id from organization limit 1"],
        "permission self-probe": ["permissionsetassignment"],
        "first-login handoff": ["new-user-first-login.md"],
    }
    missing = {
        topic: absent
        for topic, needles in topics.items()
        if (absent := [s for s in needles if s not in body])
    }
    assert not missing, f"Phase topics missing from command body: {missing}"


def test_key_commands_present_verbatim() -> None:
    body = read_command()
    expected = [
        "sf org login web --alias brite-sandbox",
        "sf config set target-org brite-sandbox",
        "claude plugin list",
        "sf org list",
        "sf org display --target-org brite-sandbox",
        "SELECT Id FROM Organization LIMIT 1",
    ]
    missing = [cmd for cmd in expected if cmd not in body]
    assert not missing, f"Key commands missing verbatim from command body: {missing}"


def test_idempotent_early_exit_documented() -> None:
    """Re-running when already authed + default-set must early-exit with zero
    mutations. The contract phrase must be greppable so reviewers can audit it.
    """
    body = read_command().lower()
    assert "already set up" in body, \
        "Phase 1 must early-exit with an 'already set up' message"
    assert "zero mutations" in body, (
        "Phase 1 early-exit must explicitly promise 'zero mutations'"
    )


def test_askuserquestion_at_each_gate() -> None:
    """Exactly one gate prompt per non-terminal phase (no batched questions).

    Count the literal gate marker the command uses, not raw "AskUserQuestion"
    substrings (which are inflated by the frontmatter, intro prose, and Rules
    mentions). Pinning to the 6 gated phases (Phase 7 is the terminal summary)
    means the assertion breaks if a gate is added, removed, or two are batched
    into one — which is exactly the AC this test names.
    """
    body = read_command()
    gate_prompts = body.count("Ask via `AskUserQuestion`:")
    assert gate_prompts == 6, (
        "Expected exactly 6 gate prompts (one per non-terminal phase, Phases 1-6); "
        f"found {gate_prompts}. A batched or dropped gate would change this count."
    )


def test_no_sfdx_legacy_invocations() -> None:
    """deploy-sandbox Rules: `sf`, not legacy `sfdx`. Prose may *mention* `sfdx`
    to forbid it (as deploy-sandbox does); only an actual `sfdx <subcommand>`
    invocation violates the contract.
    """
    body = read_command()
    invocation = re.search(r"\bsfdx\s+\w", body)
    assert not invocation, (
        "Command must use `sf`, never a legacy `sfdx <subcommand>` invocation; "
        f"found: {invocation.group(0)!r}"
    )


def test_no_auto_retry_and_halt_rules_present() -> None:
    """Two load-bearing safety rules a future edit could silently drop while
    every other test stays green: 'do not auto-retry' and 'halt on non-proceed'.
    """
    body = read_command().lower()
    assert "auto-retry" in body, \
        "Command must document the no-auto-retry rule (greppable as 'auto-retry')"
    assert "halt" in body, \
        "Command must document halting on a non-proceed gate answer ('halt')"


def test_command_has_no_emoji() -> None:
    """User convention: no emojis in generated content. Check emoji codepoint
    ranges specifically — NOT a blanket non-ASCII check, which would wrongly
    reject the command's legitimate typographic `->`-style arrows (U+2192),
    em-dashes (U+2014), and section signs (U+00A7).
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
    """plugin-cache gotcha: BC-10657 adds a new command, so revops version MUST
    be bumped above the 0.2.9 baseline on main in plugin.json.
    """
    plugin_data = json.loads(PLUGIN_JSON.read_text())
    version = plugin_data["version"]
    parts = tuple(int(p) for p in version.split("."))
    assert parts > (0, 2, 9), (
        f"revops version {version} must be bumped above the 0.2.9 baseline on main "
        "— BC-10657 adds a new command and clients' plugin cache is keyed by version"
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
