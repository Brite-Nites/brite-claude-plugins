#!/usr/bin/env python3
"""Validate the gate-respect contract across cadence skill and command files.

Usage: python3 lint_cadence_gates.py <plugin-dir>

Emits one line per finding, in traversal order:
  OK:<relpath> — gate-respect header + <N> call-site reminder(s)
  ERROR:<relpath> — missing gate-respect header
  ERROR:<relpath>:<section> — AskUserQuestion call without gate-respect reminder (cadence section titles already start with "§ N", so the literal prefix is unnecessary)

Rules enforced (per plugins/cadence/skills/_shared/gate-respect.md):
  1. Every skill/command that calls AskUserQuestion in a structured section
     must link `_shared/gate-respect.md` in a top-of-file "## Gate-respect"
     section.
  2. Every AskUserQuestion occurrence inside a `## ` / `### ` structured
     section must have at least one `gate-respect:` comment in the same
     section above the call. A single top-of-section comment covers every
     AskUserQuestion within that section.
  3. Exempt files (allowlisted): the pure `issue-quality-gate/SKILL.md`
     primitive, which never renders AskUserQuestion itself (consumers do).

Exits 0 on normal runs (success or validation errors); callers parse
OK:/ERROR: lines to decide pass/fail. Exits 2 only on bad argv.
"""

import re
import sys
from pathlib import Path

ALLOWLIST = {"issue-quality-gate/SKILL.md"}

# Sections whose bodies never count as "structured AskUserQuestion sites" —
# prose mentions here (e.g. spec notes, deferred-work entries) are ignored.
EXCLUDED_SECTION_PREFIXES = (
    "references",
    "deferred",
    "notes",
    "gate-respect",
)

SECTION_HEADER_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
AUQ_RE = re.compile(r"\bAskUserQuestion\b")
GATE_RESPECT_COMMENT_RE = re.compile(r"gate-respect:")
GATE_RESPECT_LINK_RE = re.compile(r"_shared/gate-respect\.md")
CODE_FENCE_RE = re.compile(r"^\s*(?:```|~~~)")
BLOCKQUOTE_RE = re.compile(r"^\s*>")

# Prose-mention filters: a line matching any of these is NOT a call site,
# even though it mentions AskUserQuestion. Two intent-driven patterns:
#   (1) hedges/quantifiers/negations before AUQ — "no", "any", "before",
#       "each", "every", "inside", "without", "Three".
#   (2) nominal uses after AUQ — "`AskUserQuestion` convention", "gates",
#       "pattern", "tool" — prose references to the mechanism, not calls.
PROSE_PATTERNS = [
    re.compile(
        r"\b(?:no|any|before|each|every|inside|without|three)\s+(?:the\s+|any\s+)?`?AskUserQuestion`?",
        re.IGNORECASE,
    ),
    re.compile(r"`?AskUserQuestion`?\s+(?:convention|gates|pattern|tool\b)", re.IGNORECASE),
]


def _is_excluded_section(title: str) -> bool:
    t = title.lstrip("§").strip().lower()
    # Strip leading "N.N " / "0.3 " / "§ 1 " prefixes so "## § 9 References"
    # and "### 5.3 Close out" both match the excluded prefixes by keyword.
    t = re.sub(r"^[\d.]+\s*", "", t)
    t = re.sub(r"^§\s*[\d.]+\s*", "", t)
    return any(t.startswith(p) for p in EXCLUDED_SECTION_PREFIXES)


def _walk_sections(lines: list[str]):
    """Yield (section_title, start_line, end_line) for every ## / ### header.

    end_line is exclusive. The implicit "preamble" (content above the first
    header) is yielded with title="<preamble>". Header detection skips
    content that isn't a real section start:

    - Fenced code blocks (stateful — toggle `in_code_fence` on each ```).
    - Blockquote lines (stateless — each `>`-prefixed line skipped independently
      since blockquotes don't nest; a `## foo` inside a `> quoted prompt` is
      content, not a section header).
    """
    current_title = "<preamble>"
    current_start = 0
    in_code_fence = False
    for i, line in enumerate(lines):
        if CODE_FENCE_RE.match(line):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue
        if BLOCKQUOTE_RE.match(line):
            continue
        m = SECTION_HEADER_RE.match(line)
        if m and len(m.group(1)) in (2, 3):  # ## or ###
            yield current_title, current_start, i
            current_title = m.group(2)
            current_start = i
    yield current_title, current_start, len(lines)


def _is_call_site(line: str) -> bool:
    """True iff the line is an actual AskUserQuestion call site, not prose.

    Rejects lines whose AUQ token is framed by prose/negation markers
    (no/any/before/each/every/Three/inside/without) or whose AUQ token
    appears only in a section-header-style inline mention.
    """
    if not AUQ_RE.search(line):
        return False
    for prose in PROSE_PATTERNS:
        if prose.search(line):
            return False
    return True


def _iter_active_lines(body_lines: list[str]):
    """Yield (body_idx, line) for body lines that are NOT inside a fenced code
    block or a blockquote. Fences toggle state on every `` ``` `` / `~~~` marker;
    blockquotes skip per-line (they don't nest in CommonMark).

    Prevents false-positive call sites against (a) `AskUserQuestion` written
    inside an example code fence and (b) `AskUserQuestion` quoted inside a
    `>`-prefixed prompt template body.
    """
    in_code_fence = False
    for i, line in enumerate(body_lines):
        if CODE_FENCE_RE.match(line):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue
        if BLOCKQUOTE_RE.match(line):
            continue
        yield i, line


def _has_top_of_file_gate_respect_header(sections: list[tuple[str, int, int]], lines: list[str]) -> bool:
    """True iff a ## Gate-respect section exists and its body links _shared/gate-respect.md."""
    for title, start, end in sections:
        if title.strip().lower().startswith("gate-respect"):
            body = "\n".join(lines[start:end])
            if GATE_RESPECT_LINK_RE.search(body):
                return True
    return False


def _lint_file(path: Path, repo_root: Path) -> list[str]:
    """Return a list of OK:/ERROR: lines for this file."""
    rel = str(path.relative_to(repo_root))
    out: list[str] = []

    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        # UnicodeDecodeError is a ValueError subclass, not an OSError — catch
        # it explicitly so a non-UTF-8 file doesn't abort the whole validate.sh
        # run under `set -e`.
        return [f"ERROR:{rel}: cannot read file ({e})"]

    lines = text.splitlines()
    # Walk sections once; reused by both the header check and the per-section scan.
    sections = list(_walk_sections(lines))

    # 1. Inventory AskUserQuestion call-sites in structured sections.
    violations: list[tuple[str, int]] = []  # (section_title, line_no)
    auq_sections_seen: set[str] = set()
    for title, start, end in sections:
        if title == "<preamble>":
            continue
        if _is_excluded_section(title):
            continue
        # Skip the header line itself; only scan the body for call sites.
        # This prevents a section title like "§ 6 Per-group approval via
        # AskUserQuestion" from counting as a call site within its own body.
        body_lines = lines[start + 1 : end]
        # Iterate only "active" body lines (outside fenced code blocks and
        # blockquotes) so an AskUserQuestion example inside a ```python fence
        # or a `> quoted prompt` body doesn't get flagged as a call site.
        first_auq_idx = next(
            (i for i, line in _iter_active_lines(body_lines) if _is_call_site(line)),
            None,
        )
        if first_auq_idx is None:
            continue
        auq_sections_seen.add(title)
        # Does this section contain at least one gate-respect reminder
        # above the first AskUserQuestion call site? Scope the search to
        # active lines (outside fences + blockquotes) — symmetric with the
        # call-site detection above. Otherwise a `gate-respect:` string shown
        # inside a fenced example would falsely satisfy the contract.
        head_active = "\n".join(
            line for i, line in _iter_active_lines(body_lines) if i <= first_auq_idx
        )
        if not GATE_RESPECT_COMMENT_RE.search(head_active):
            violations.append((title, start + 1 + first_auq_idx + 1))

    # 2. If this file has any AUQ in a structured section, header rule fires.
    if auq_sections_seen and not _has_top_of_file_gate_respect_header(sections, lines):
        out.append(f"ERROR:{rel}: missing gate-respect header (## Gate-respect section linking _shared/gate-respect.md)")

    for title, line_no in violations:
        # Titles parsed from `## § N …` headers already include the § glyph;
        # emit `{title}` directly (not f"§{title}") to avoid the §§ duplication.
        out.append(
            f"ERROR:{rel}:{title!s}: AskUserQuestion at line {line_no} without gate-respect reminder in the same section"
        )

    if not out and auq_sections_seen:
        out.append(
            f"OK:{rel} — gate-respect header + {len(auq_sections_seen)} call-site reminder(s)"
        )
    elif not out and not auq_sections_seen:
        # File has no structured AskUserQuestion calls — contract does not apply.
        out.append(f"OK:{rel} — no structured AskUserQuestion calls; contract N/A")

    return out


def _collect_targets(plugin_dir: Path) -> list[Path]:
    targets: list[Path] = []
    skills_dir = plugin_dir / "skills"
    commands_dir = plugin_dir / "commands"

    if skills_dir.is_dir():
        for p in sorted(skills_dir.glob("*/SKILL.md")):
            # Skip _shared — consumers of _shared skills (when invocable)
            # still need the contract, but _shared SKILL.md itself is usually a primitive.
            if p.parent.name == "_shared":
                continue
            rel = f"{p.parent.name}/{p.name}"
            if rel in ALLOWLIST:
                continue
            targets.append(p)
        # Walk _shared/* SKILL.md (invocable shared skills) — but these are also
        # often primitives. Apply allowlist by parent/name path.
        for p in sorted(skills_dir.glob("_shared/*/SKILL.md")):
            rel = f"{p.parent.name}/{p.name}"
            if rel in ALLOWLIST:
                continue
            targets.append(p)

    if commands_dir.is_dir():
        for p in sorted(commands_dir.glob("*.md")):
            targets.append(p)

    return targets


def main(plugin_dir_str: str) -> int:
    plugin_dir = Path(plugin_dir_str).resolve()
    if not plugin_dir.is_dir():
        print(f"ERROR:plugin dir not found: {plugin_dir}", file=sys.stderr)
        return 2

    # Repo root = plugin_dir.parent.parent when the layout is plugins/<name>/.
    # Verify by checking for a .git entry (directory for main checkouts, file
    # for worktrees); fall back to plugin_dir if the layout differs.
    repo_root = (plugin_dir / "../..").resolve()
    if not (repo_root / ".git").exists():
        repo_root = plugin_dir

    targets = _collect_targets(plugin_dir)

    if not targets:
        print(f"OK:{plugin_dir.name} — no skill/command files to check")
        return 0

    out: list[str] = []
    for path in targets:
        out.extend(_lint_file(path, repo_root))

    for line in out:
        print(line)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("ERROR:usage: lint_cadence_gates.py <plugin-dir>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
