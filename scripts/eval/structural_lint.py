#!/usr/bin/env python3
"""M1 structural lint — skill/command spec → findings[] (BC-12588, ADR-028 Phase-1).

A deterministic, stdlib-only checker. Two public entry points, both returning the
SAME ``Finding`` shape:

  * ``lint_spec(path)``       — R1 (commands only) + R2–R6 over a command/SKILL.md spec.
  * ``lint_evals_json(path)`` — R7 over an ``evals/evals.json`` file.

Each ``Finding`` is ``{rule_id, severity, message, file, line?}``. This is the
**M5 consumer contract** (BC-12590): M5 imports these functions, runs them over the
git-diff "changed" set, filters via the grandfather/debt list, and flips the
``severity == "gate"`` findings to build-failing — by reading ``severity`` alone,
with zero re-detection. M5 will layer additional fields (e.g. ``blocking``,
``grandfathered``) ON TOP of this shape; do NOT add them here.

THIS MODULE NEVER FAILS A BUILD ITSELF: the CLI exits 0 even with findings, and
``validate.sh`` §15a-bc-12588 surfaces them WARN-only. ``severity == "gate"`` is the
TIER the eval-gate consumes as build-failing (see CONTEXT.md § "Gate"): the M5
diff-gate blocks gate-tier findings on changed commands, and the ADR-034 full-surface
gate (``eval_gate.py --structural``, BC-13213) blocks them across the whole
commands+skills surface unless covered by a ``docs/structural-lint-debt.md`` row.
The CLI's human renderer labels gate-tier findings ``[gate-tier · blocking via
eval-gate]`` so a human reading ``validate.sh`` output knows which warnings are
enforced; the durable ``message`` stays a plain violation description the gate
reuses verbatim as the blocking error.

Severities follow the ``[GATE]``/``[ADV]`` tags in
``docs/guides/skill-command-design-standards.md``. Advisory rules are promoted to
gate one at a time, each only after its surface is clean or grandfathered — the
BC-12700 bullet-#2 per-rule ratchet (R3 flipped first, BC-13213).

The R1 side-effecting heuristic below is the FIRST executable encoding of ADR-028's
prose ("Detecting side-effecting", Consequences). It is intentionally DISTINCT from
the destructive-command security regex in ``scripts/test-hooks.sh`` (force-push /
rm-rf / drop) — different patterns, different jobs. This module is the single
canonical copy; M5 imports it rather than re-deriving.

Exit codes (CLI): 0 = ran successfully (even WITH findings — findings never fail this
slice); 2 = usage / internal error (the check could not run). Stdlib-only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

# scripts/eval/structural_lint.py → repo root is two parents up.
REPO_ROOT = Path(__file__).resolve().parents[2]

SEV_GATE = "gate"
SEV_ADVISORY = "advisory"

# ── Public consumer contract (imported by eval_gate.py, ADR-028/ADR-034) ──────
# COMMAND_GLOB, SKILL_GLOB, SEV_GATE, Finding, body_lines, finding_loc, lint_path,
# lint_spec, parse_marker, scan_surface. Renaming any of these breaks the gate at
# import time — treat them as API, not module-private helpers.

# The lintable spec surface — the canonical copy (scan_surface consumes them;
# eval_gate imports them for its changed-set filter and structural-debt row guard,
# so the two modules can't drift). NOTE: consumers use these both as fnmatch
# patterns (fnmatch's `*` crosses `/`) and as Path.glob patterns (glob's `*` does
# not) — shared TEXT; each consumer's semantics happen to coincide at this depth.
COMMAND_GLOB = "plugins/*/commands/*.md"
SKILL_GLOB = "plugins/*/skills/*/SKILL.md"


@dataclass
class Finding:
    """One lint result. The stable M5 consumer contract — keep field names + order."""

    rule_id: str
    severity: str  # SEV_GATE | SEV_ADVISORY
    message: str
    file: str
    line: int | None = None


# ── ADR-028 side-effecting heuristic (canonical executable copy) ──────────────
# Prose source of truth: ADR-028 Consequences § "Detecting side-effecting" +
# standards guide § 0. Namespace class includes '-' (server names like
# `linear-server`, `emailbison-b2b`). A `mcp__<ns>__*` wildcard is intentionally
# NOT matched (the heuristic names mutating verbs, not broad grants) — a known,
# documented gap, refinable in M5.
SIDE_EFFECTING_RE = re.compile(
    r"mcp__[A-Za-z0-9_-]+__(?:save|create|update|delete|deploy|send)(?:_|\b)"
    r"|gh\s+pr\s+create"
    r"|git\s+(?:push|commit|branch)\b"
)

# Comment-anchored opt-out / waiver marker parser — the ONE canonical copy (the
# "single canonical copy" discipline this epic keeps teaching). BOTH the R1
# `# lint:not-side-effecting <reason>` override (this module) and BC-12590's
# `# eval-waiver: <reason>` (scripts/eval/eval_gate.py imports this function) route
# through it so the two markers can never drift into subtly-different parsers.
def parse_marker(text: str, token: str) -> str | None:
    """First comment-anchored ``# <token><reason>`` marker in ``text``.

    ANCHORED to a comment prefix (``#`` / ``<!--``) so a prose or inline-code MENTION
    of the token — e.g. a body documenting the override syntax — cannot accidentally
    suppress a real gate (the BC-12534 substring-lint gotcha: a grep can't tell an
    instruction from a prohibition). ``token`` is the literal marker prefix INCLUDING
    whatever separator the form uses: ``"lint:not-side-effecting"`` (space then
    reason) vs ``"eval-waiver:"`` (colon then reason). Returns None when absent, ''
    when present but with no reason (an empty marker — callers treat that as "does not
    suppress"), else the reason string with a trailing HTML-comment close stripped.
    """
    rx = re.compile(rf"^\s*(?:#+|<!--)\s*{re.escape(token)}[ \t]*(.*)$")
    for line in text.splitlines():
        m = rx.search(line)
        if m:
            return re.sub(r"\s*-->\s*$", "", m.group(1)).strip()
    return None


# The R1 override token (ADR-028: non-silent opt-out; form `# lint:not-side-effecting <reason>`).
LINT_OVERRIDE_TOKEN = "lint:not-side-effecting"

# disable-model-invocation is read directly via fm_value(fm, "disable-model-invocation")
# in rule_r1_side_effecting — there is intentionally no separate regex constant for it
# (one code path, so M5 importers can't fork a second, subtly-different check).


# ── Spec parsing helpers ──────────────────────────────────────────────────────


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def split_frontmatter(text: str) -> tuple[str, int]:
    """Return (frontmatter_text, body_start_lineno).

    Frontmatter is the block between the first two ``---`` lines (the repo's
    convention; matches validate.sh's ``frontmatter()``). If absent, returns
    ("", 1) and the whole file is body.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return "", 1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            fm = "\n".join(lines[1:i])
            return fm, i + 2  # 1-based line number of the first body line
    return "", 1


def fm_value(frontmatter: str, key: str) -> str | None:
    """First top-level single-line ``key: value`` from frontmatter (None if absent)."""
    for line in frontmatter.splitlines():
        m = re.match(rf"^{re.escape(key)}:[ \t]*(.*)$", line)
        if m:
            return m.group(1).strip()
    return None


def body_lines(text: str) -> list[str]:
    """Body lines (everything after the frontmatter block)."""
    lines = text.splitlines()
    _, start = split_frontmatter(text)
    return lines[start - 1 :]


def spec_kind(path: Path) -> str:
    """'command' for plugins/*/commands/*.md, else 'skill'."""
    return "command" if "/commands/" in path.as_posix() else "skill"


# ── R1 — side-effecting command needs disable-model-invocation (severity gate) ──


def _side_effecting_hit(text: str) -> tuple[int, str] | None:
    """First (line_no, matched_snippet) where the ADR-028 heuristic fires within
    the spec's ``allowed-tools`` value OR its body. Returns None if no hit.

    Assumes a single-line ``allowed-tools:`` value — the repo's canonical
    comma-separated form (enforced for skills by validate.sh § 8). A multi-line YAML
    block/sequence value would leave its continuation lines unscanned: a known gap,
    alongside the ``mcp__<ns>__*`` wildcard gap above. No spec on the current surface
    uses the multi-line form.
    """
    lines = text.splitlines()
    fm, body_start = split_frontmatter(text)
    has_fm = fm != ""
    for idx, line in enumerate(lines, start=1):
        in_fm = has_fm and 2 <= idx <= body_start - 2
        is_allowed_tools = in_fm and re.match(r"^allowed-tools:", line) is not None
        is_body = idx >= body_start
        if is_allowed_tools or is_body:
            m = SIDE_EFFECTING_RE.search(line)
            if m:
                return idx, m.group(0)
    return None


def _override_reason(text: str) -> str | None:
    """`# lint:not-side-effecting <reason>` marker: None = absent, '' = present but
    no reason (an empty marker), else the reason string. Delegates to the canonical
    parse_marker so the R1 override and eval_gate's `# eval-waiver` share one parser."""
    return parse_marker(text, LINT_OVERRIDE_TOKEN)


def rule_r1_side_effecting(path: Path, text: str) -> list[Finding]:
    hit = _side_effecting_hit(text)
    if hit is None:
        return []
    line, snippet = hit
    fm, _ = split_frontmatter(text)
    if (fm_value(fm, "disable-model-invocation") or "").lower() == "true":
        return []  # the flag satisfies the gate; an emit mode does NOT (default run still mutates)
    rel = _rel(path)
    reason = _override_reason(text)
    if reason is None:
        return [
            Finding(
                "R1-side-effecting-needs-flag", SEV_GATE,
                f"declares side-effecting '{snippet}' without disable-model-invocation: true "
                "(add the flag, or a `# lint:not-side-effecting <reason>` override if this is a false positive)",
                rel, line,
            )
        ]
    if reason == "":
        # An empty marker is a silent-bypass attempt — it does NOT suppress R1.
        return [
            Finding(
                "R1-side-effecting-needs-flag", SEV_GATE,
                f"declares side-effecting '{snippet}' without disable-model-invocation: true "
                "(a `# lint:not-side-effecting` marker is present but has no reason, so it is ignored)",
                rel, line,
            ),
            Finding(
                "R1-override-missing-reason", SEV_ADVISORY,
                "`# lint:not-side-effecting` marker has no <reason>; an empty marker does not suppress the gate",
                rel, line,
            ),
        ]
    # Valid override: downgrade gate → advisory and record the reason (non-silent).
    return [
        Finding(
            "R1-side-effecting-needs-flag", SEV_ADVISORY,
            f"side-effecting override accepted: {reason}",
            rel, line,
        )
    ]


# ── R2 — body too long (GATE — flipped BC-13216, ratchet 4/5) ───────────────────
# Fourth advisory rule promoted to gate. Its 13 oversized command/skill bodies are
# NOT split (weeks of refactor risk); each is grandfathered with a line-count
# BASELINE in docs/structural-lint-debt.md (suppresses while the body stays <=
# baseline, blocks once it GROWS past) — enforced by eval_gate's --structural full
# surface, ADR-034. R2 is deliberately NOT enforced by the changed-set diff-gate
# (see structural_gate_reasons): the diff-gate can't read the structural-debt
# baselines, so it would block every edit to a grandfathered command.
BODY_LINE_LIMIT = 500  # standards guide § 1: body < ~500 lines


def rule_r2_body_too_long(path: Path, text: str) -> list[Finding]:
    n = len(body_lines(text))
    if n >= BODY_LINE_LIMIT:
        return [
            Finding(
                "R2-body-too-long", SEV_GATE,
                f"body is {n} lines (>= {BODY_LINE_LIMIT}); split into reference files "
                "(every loaded line is a recurring per-session token cost)",
                _rel(path), None,
            )
        ]
    return []


# ── R3 — description quality: first-person (GATE — flipped BC-13213, ratchet 1/5) ──
# Leading first-person framing only (highest-signal, lowest false-positive). The
# `\s+\S` tail (pronoun then whitespace then non-space) excludes "I/O", "AI", "CI"
# (no boundary / no following space). "Missing description" is already a hard FAIL
# in validate.sh § 7/§ 8, so R3 covers the first-person case only. First advisory
# rule promoted to gate (surface was clean: 0 findings at flip time) — enforced by
# eval_gate's diff-gate (changed commands) + --structural (full surface, ADR-034).
FIRST_PERSON_RE = re.compile(r"^\s*(?:I|I'll|I'm|We|We'll|We're|My|Me|Our)\s+\S", re.IGNORECASE)


def _fm_keyline(text: str, key: str) -> int | None:
    for idx, line in enumerate(text.splitlines(), start=1):
        if re.match(rf"^{re.escape(key)}:", line):
            return idx
    return None


def rule_r3_description(path: Path, text: str) -> list[Finding]:
    fm, _ = split_frontmatter(text)
    desc = fm_value(fm, "description")
    if desc and FIRST_PERSON_RE.match(desc):
        return [
            Finding(
                "R3-description-quality", SEV_GATE,
                "description is first-person; use a third-person form stating what it does AND when to use it",
                _rel(path), _fm_keyline(text, "description"),
            )
        ]
    return []


# ── R5 — MCP tool names must be fully-qualified (GATE — flipped BC-13214, 2/5) ──
# Second advisory rule promoted to gate (surface cleaned in the same PR: the one
# live finding was sf-connected-apps' space-separated allowed-tools line) —
# enforced by eval_gate's diff-gate (changed commands) + --structural (full
# surface, ADR-034).
# A fully-qualified MCP name is `mcp__<ns>__<tool|*>`. We can't require the
# `plugin_<plugin>_` segment — user-level servers (e.g. `mcp__emailbison-b2b__*`)
# are legitimately un-prefixed. So R5 flags allowed-tools entries that are neither a
# known built-in nor a well-formed mcp__ name (catches a bare `salesforce` /
# `run_soql_query` and malformed `mcp__` entries). The allowlist is maintained.
# Reads a single-line allowed-tools value (canonical comma-separated form, enforced
# for skills by validate.sh § 8); a multi-line YAML value is a known unscanned gap
# (no spec on the surface uses it) — same assumption as R1's _side_effecting_hit.
BUILTIN_TOOLS = {
    "Read", "Write", "Edit", "MultiEdit", "NotebookEdit",
    "Bash", "BashOutput", "KillBash", "KillShell",
    "Glob", "Grep", "Task", "Agent", "Skill", "SlashCommand",
    "WebFetch", "WebSearch", "TodoWrite",
    "AskUserQuestion", "ExitPlanMode", "EnterPlanMode",
    "ListMcpResourcesTool", "ReadMcpResourceTool",
}
MCP_TOOL_RE = re.compile(r"^mcp__[A-Za-z0-9_-]+__(?:[A-Za-z0-9_]+|\*)$")


def rule_r5_mcp_qualified(path: Path, text: str) -> list[Finding]:
    fm, _ = split_frontmatter(text)
    at = fm_value(fm, "allowed-tools")
    if not at:
        return []
    line = _fm_keyline(text, "allowed-tools")
    rel = _rel(path)
    out: list[Finding] = []
    for raw in at.split(","):
        entry = raw.strip()
        if not entry:
            continue
        base = entry.split("(", 1)[0].strip()  # strip a Bash(cmd:*) arg constraint
        if base in BUILTIN_TOOLS:
            continue
        if MCP_TOOL_RE.match(entry) or MCP_TOOL_RE.match(base):
            continue
        out.append(
            Finding(
                "R5-mcp-not-fully-qualified", SEV_GATE,
                f"allowed-tools entry '{entry}' is neither a known built-in nor a "
                "fully-qualified mcp__<ns>__<tool|*> name",
                rel, line,
            )
        )
    return out


# ── R6 — hardcoded absolute / backslash paths (GATE — flipped BC-13215, ratchet 3/5) ──
# Third advisory rule promoted to gate (surface cleaned in the same PR by refining
# the detector — the 4 live findings were all placeholder-prose false positives, now
# exempted below) — enforced by eval_gate's diff-gate (changed commands) +
# --structural (full surface, ADR-034).
# Conservative + high-precision: developer-home absolute prefixes + drive-letter
# Windows paths only. The lookbehind skips prefixes embedded in a longer path or a
# URL (e.g. github.com/Users/...). Relative `plugins/<p>/` paths are NOT flagged —
# they appear legitimately in prose everywhere. Generic backslashes are NOT flagged
# (markdown is full of \b, \s, \d regex examples).
ABS_PATH_RE = re.compile(r"(?<![\w./:-])(?:/Users/|/home/|/root/)")
WIN_PATH_RE = re.compile(r"(?<![\w])[A-Za-z]:\\")

# The path segment immediately after a matched prefix is a placeholder — prohibition
# prose like `/Users/...` (the BC-12534 substring class), not a hardcoded path — when
# it is one of these structurally-fake forms. Exempt by structural FORM only: never by
# formatting (a real path in a code span is exactly what R6 must still catch) and never
# by literal placeholder WORDS like `user`/`yourname` (those can be real account names).
#   - `...` / `…` : an ellipsis, but it must be a COMPLETE token — the `(?![\w.])`
#     boundary stops a real path with a fake-looking lead (`/Users/...holden/secret`)
#     from dodging the now-blocking gate.
#   - `<` / `$`   : an `<angle>` or `$VAR` opener — no real username contains `<`/`$`,
#     so a leading one is always a placeholder (matched loose, by the opener char).
_PLACEHOLDER_AT_RE = re.compile(r"(?:\.\.\.|…)(?![\w.])|[<$]")


def _is_placeholder_username(line: str, m: re.Match) -> bool:
    return _PLACEHOLDER_AT_RE.match(line, m.end()) is not None


def _first_hardcoded_path(line: str) -> re.Match | None:
    """First NON-placeholder absolute/Windows path match on ``line``, ABS prefixes
    before WIN. Rescanning past exempted placeholders stops a placeholder from giving
    the rest of its line a free pass (`/Users/...` then a real `/Users/<name>/`); the
    first real match per line is reported, preserving R6's one-finding-per-line shape.
    """
    for rx in (ABS_PATH_RE, WIN_PATH_RE):
        m = next((c for c in rx.finditer(line) if not _is_placeholder_username(line, c)), None)
        if m:
            return m
    return None


def rule_r6_hardcoded_paths(path: Path, text: str) -> list[Finding]:
    lines = text.splitlines()
    _, body_start = split_frontmatter(text)
    rel = _rel(path)
    out: list[Finding] = []
    for idx in range(body_start, len(lines) + 1):
        m = _first_hardcoded_path(lines[idx - 1])
        if m:
            out.append(
                Finding(
                    "R6-hardcoded-paths", SEV_GATE,
                    f"hardcoded absolute/backslash path near '{m.group(0)}'; "
                    "use ${CLAUDE_PLUGIN_ROOT} / ${CLAUDE_SKILL_DIR}",
                    rel, idx,
                )
            )
    return out


# ── R4 — reference chain > 1 level deep (GATE — flipped BC-13217, ratchet 5/5) ──
# Fifth and FINAL advisory rule promoted to gate — completes the BC-12700 bullet-#2
# ratchet (R3→R5→R6→R2→R4). Surface at flip time: email-copywriting's one chain was
# CLEANED (its SKILL→presets/README citation severed); the 8 revops upstream-subtree
# skills (sf-apex/-connected-apps/-data/-debug/-diagram-mermaid/-flow/-integration/-lwc)
# are grandfathered file-level (NO baseline) in docs/structural-lint-debt.md —
# restructuring an upstream reference tree is ADR-007 augment-not-replace drift.
# Enforced full-surface by eval_gate --structural (ADR-034); NOT the changed-set
# diff-gate, which is commands-only (COMMAND_GLOB) and never sees these skills — so
# structural_gate_reasons needs no R4 change (unlike R2's fork ①).
#
# High precision: fire ONLY when spec → ref-A → ref-B all resolve to EXISTING
# in-plugin .md files. References resolve against the spec's own dir (or, for
# ${CLAUDE_PLUGIN_ROOT}/${CLAUDE_SKILL_DIR}, the plugin/skill dir) — never the repo
# root, so a prose path mention can't accidentally resolve.
MD_PATH_RE = re.compile(r"[\w./${}-]+\.md\b")


def _plugin_root(spec: Path) -> Path | None:
    for parent in spec.resolve().parents:
        if parent.parent.name == "plugins":
            return parent
    return None


def _resolve_ref(token: str, spec: Path) -> Path | None:
    spec = spec.resolve()
    skill_dir = spec.parent
    proot = _plugin_root(spec)
    if token.startswith("${CLAUDE_SKILL_DIR}/"):
        cand = skill_dir / token[len("${CLAUDE_SKILL_DIR}/") :]
        return cand.resolve() if cand.is_file() else None
    if token.startswith("${CLAUDE_PLUGIN_ROOT}/"):
        if proot is None:
            return None
        cand = proot / token[len("${CLAUDE_PLUGIN_ROOT}/") :]
        return cand.resolve() if cand.is_file() else None
    if token.startswith("${"):
        return None  # an unresolvable variable — don't guess
    for base in [skill_dir] + ([proot] if proot else []):
        cand = base / token
        if cand.is_file():
            return cand.resolve()
    return None


def _is_spec(p: Path) -> bool:
    """A top-level spec (SKILL.md / a command / an agent). Cross-references BETWEEN
    specs are a normal navigation graph, NOT the progressive-disclosure bundled-ref
    chain R4 targets — so they're excluded from the chain test."""
    s = p.as_posix()
    return p.name == "SKILL.md" or "/commands/" in s or "/agents/" in s


def _md_refs(text: str, spec: Path) -> list[tuple[str, Path]]:
    """(matched_token, resolved_path) for each resolved, existing, NON-spec .md
    reference (the bundled support files progressive disclosure chains through).
    The token is kept so callers can report the exact source line even when two
    refs share a basename."""
    out: list[tuple[str, Path]] = []
    seen: set[Path] = set()
    for m in MD_PATH_RE.finditer(text):
        token = m.group(0)
        r = _resolve_ref(token, spec)
        if r is not None and r not in seen and not _is_spec(r):
            seen.add(r)
            out.append((token, r))
    return out


def _first_token_line(text: str, needle: str) -> int | None:
    for idx, line in enumerate(text.splitlines(), start=1):
        if needle in line:
            return idx
    return None


def rule_r4_nested_refs(path: Path, text: str) -> list[Finding]:
    spec = Path(path).resolve()
    skill_dir = spec.parent
    rel = _rel(spec)

    def under(p: Path) -> bool:
        # Only the spec's OWN bundled reference files (its dir + subdirs like
        # references/). Excludes ADRs (docs/decisions/), CLAUDE.md/README.md, and
        # docs/** citations — those are a provenance graph that naturally cross-links,
        # not the progressive-disclosure bundle the standards § 1 rule targets.
        return skill_dir == p.parent or skill_dir in p.parents

    out: list[Finding] = []
    for token, ref in _md_refs(text, spec):
        if not under(ref):
            continue
        try:
            ref_text = ref.read_text(encoding="utf-8")
        except OSError:
            continue
        deeper = [p for _, p in _md_refs(ref_text, ref) if under(p) and p != ref and p != spec]
        if deeper:
            out.append(
                Finding(
                    "R4-nested-refs", SEV_GATE,
                    f"bundled reference '{_rel(ref)}' itself references further bundled file(s) "
                    f"(e.g. '{_rel(deeper[0])}'); keep references one level deep",
                    rel, _first_token_line(text, token),
                )
            )
    return out


# ── Rule registry ─────────────────────────────────────────────────────────────
# Each rule is a function (path, text) -> list[Finding]. R1 is command-only; the
# advisory structural rules run on every spec (commands + skills).
SPEC_RULES_ALL: list = [
    rule_r2_body_too_long,
    rule_r3_description,
    rule_r4_nested_refs,
    rule_r5_mcp_qualified,
    rule_r6_hardcoded_paths,
]
SPEC_RULES_COMMAND_ONLY: list = [rule_r1_side_effecting]  # command files only


def lint_spec(path: str | Path) -> list[Finding]:
    """Lint one command/SKILL.md spec → findings[]."""
    p = Path(path)
    text = _read(p)
    findings: list[Finding] = []
    for rule in SPEC_RULES_ALL:
        findings.extend(rule(p, text))
    if spec_kind(p) == "command":
        for rule in SPEC_RULES_COMMAND_ONLY:
            findings.extend(rule(p, text))
    return findings


DEPRECATION_KEY = "_deprecated"  # ADR-028 D3: marks an evals.json as non-executing seed


def lint_evals_json(path: str | Path) -> list[Finding]:
    """Lint one evals/evals.json → findings[] (R7).

    Fires R7 (advisory) when the file lacks the top-level ``_deprecated`` marker key,
    so a newly-authored evals.json warns with no git-diff needed. Presence-only — the
    value isn't validated. A malformed evals.json is surfaced as the same advisory
    (never a crash) so one bad file can't fail the whole WARN-only scan.
    """
    p = Path(path)
    rel = _rel(p)
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        # ValueError covers JSONDecodeError + UnicodeDecodeError; OSError covers a
        # missing/unreadable file. Degrade to the advisory, never crash — one bad
        # evals.json must not abort the whole WARN-only scan (docstring promise),
        # and M5 imports this as a library expecting findings[], not an exception.
        return [
            Finding(
                "R7-evals-json-undeprecated", SEV_ADVISORY,
                f"evals.json could not be read as valid JSON ({e}); ADR-028 D3 deprecates this format",
                rel, None,
            )
        ]
    if not isinstance(data, dict) or DEPRECATION_KEY not in data:
        return [
            Finding(
                "R7-evals-json-undeprecated", SEV_ADVISORY,
                f"evals.json lacks the top-level `{DEPRECATION_KEY}` marker; ADR-028 D3 deprecates "
                "this format — mark existing files non-executing seed and do not author new ones",
                rel, None,
            )
        ]
    return []


# ── CLI ───────────────────────────────────────────────────────────────────────


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def scan_surface(repo_root: Path) -> list[Path]:
    """The repo-wide lint surface: all command + SKILL.md specs + evals.json."""
    targets: list[Path] = []
    targets += sorted(repo_root.glob(COMMAND_GLOB))
    for skill in sorted(repo_root.glob(SKILL_GLOB)):
        if skill.parent.name == "_shared":
            continue
        targets.append(skill)
    targets += sorted(repo_root.glob("plugins/*/skills/*/evals/evals.json"))
    return targets


def lint_path(path: Path) -> list[Finding]:
    return lint_evals_json(path) if path.name == "evals.json" else lint_spec(path)


def finding_loc(f: Finding) -> str:
    """``file`` or ``file:line`` — the ONE rendering of a Finding's location
    (eval_gate's --structural renderer imports it, so the two can't drift)."""
    return f.file if f.line is None else f"{f.file}:{f.line}"


def _human_line(f: Finding) -> str:
    tag = "[gate-tier · blocking via eval-gate]" if f.severity == SEV_GATE else "[advisory]"
    return f"{tag} {f.rule_id} {finding_loc(f)} — {f.message}"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="M1 structural lint (ADR-028 / BC-12588)")
    ap.add_argument("paths", nargs="*", help="spec files / evals.json to lint")
    ap.add_argument("--scan-repo", action="store_true", help="lint the whole repo surface")
    ap.add_argument("--repo-root", default=str(REPO_ROOT))
    ap.add_argument("--json", action="store_true", help="emit findings[] as a JSON array")
    args = ap.parse_args(argv)

    root = Path(args.repo_root)
    if args.scan_repo:
        targets = scan_surface(root)
    else:
        targets = [Path(p) for p in args.paths]
    if not targets:
        print("ERROR: no paths given (use --scan-repo or pass files)", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    try:
        for t in targets:
            findings.extend(lint_path(t))
    except Exception as e:  # internal error → exit 2 (the check could not run)
        print(f"ERROR: lint failed: {e}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps([asdict(f) for f in findings], indent=2))
    else:
        for f in findings:
            print(_human_line(f))
        g = sum(1 for f in findings if f.severity == SEV_GATE)
        a = len(findings) - g
        files = len({f.file for f in findings})
        print(f"SUMMARY findings={len(findings)} gate={g} advisory={a} files={files}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
