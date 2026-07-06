#!/usr/bin/env python3
"""Lint .github/workflows/*.yml for supply-chain pinning (BC-16291 / audit plan 004).

Two rules, aimed at the two secret-bearing workflows (behavioral-tests.yml holds
ANTHROPIC_API_KEY; jwt-validity-probe.yml holds the prod Salesforce token +
LINEAR_API_KEY) but enforced repo-wide so the convention can't erode by copy-paste:

  1. Every third-party ``uses: owner/repo@ref`` must pin ``ref`` to a full 40-char
     commit SHA. A moved tag would run arbitrary code next to those secrets on a
     PUBLIC repo. A trailing ``# vN`` comment is allowed and encouraged —
     Dependabot reads it to open bump PRs.
  2. Every ``npm install -g <pkg>`` must pin an EXACT version (``@x.y.z``). A
     dist-tag or range (``@latest``, ``@next``, ``@^5``) still resolves "latest at
     install time", so a poisoned release would run with the same secrets in scope
     — the very thing this guard exists to block. ``--global`` and multiple
     packages on one line are both checked.

Exit 0 = clean, 1 = violations (printed as ``file:line: reason``). Accepts optional
path args (files or dirs) for the self-test; defaults to the repo's workflows dir.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
USES_RE = re.compile(r"""\buses:\s*['"]?([^\s'"#]+)""")
NPM_INSTALL_RE = re.compile(r"\bnpm\s+(?:install|i|add)\b(.*)")
# exact semver x.y.z with an optional -prerelease / +build suffix; rejects dist-tags
# (latest/next/beta), ranges (^~*><=), and partials (@2, @2.1).
EXACT_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$")
_GLOBAL_FLAGS = {"-g", "--global"}
_SHELL_OPS = {"&&", "||", ";", "|", "\\"}


def _is_third_party_action(action: str) -> bool:
    """A tag-pinnable third-party action: owner/repo form, not local (./) or docker."""
    return "/" in action and not action.startswith("./") and not action.startswith("docker://")


def _npm_pin_ok(token: str) -> bool:
    """Pinned iff the package spec carries an EXACT version after its final '@'.

    Handles scoped (``@scope/name@ver``) and unscoped (``name@ver``); a leading
    scope '@' is stripped first so the version separator is the *final* '@'.
    """
    body = token[1:] if token.startswith("@") else token
    if "@" not in body:
        return False
    version = body.rsplit("@", 1)[1]
    return bool(EXACT_VERSION_RE.match(version))


def _strip_inline_comment(line: str) -> str:
    """Drop a YAML inline ``#`` comment (``#`` preceded by whitespace) before matching,
    so a trailing ``# uses: actions/checkout@v4`` doc-comment isn't a false positive.
    The pinned form ``uses: x@<sha> # v4`` is unaffected — the sha precedes the ``#``.
    """
    return re.split(r"\s#", line, maxsplit=1)[0]


def _iter_workflow_files(paths):
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            for f in sorted(p.glob("*.yml")) + sorted(p.glob("*.yaml")):
                yield f
        elif p.is_file():
            yield p


def lint_file(path: Path):
    violations = []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return violations
    for lineno, raw in enumerate(text.splitlines(), 1):
        if raw.lstrip().startswith("#"):
            continue
        scan = _strip_inline_comment(raw)
        # Rule 1 — uses: pins
        m = USES_RE.search(scan)
        if m:
            value = m.group(1)
            if "@" in value:
                action, _, ref = value.rpartition("@")
                if _is_third_party_action(action) and not SHA_RE.match(ref):
                    violations.append(
                        (lineno, f"unpinned action: uses: {value} — pin to a 40-char commit SHA (keep '# vN' as a comment)")
                    )
        # Rule 2 — npm global installs: every package token must be exact-version pinned
        im = NPM_INSTALL_RE.search(scan)
        if im:
            tokens = im.group(1).split()
            if any(t in _GLOBAL_FLAGS for t in tokens):
                for tok in tokens:
                    if tok in _SHELL_OPS:
                        break
                    if tok.startswith("-"):
                        continue
                    if not _npm_pin_ok(tok):
                        violations.append(
                            (lineno, f"unpinned npm global: npm install -g {tok} — pin an exact version (@x.y.z)")
                        )
    return violations


def main(argv):
    args = argv[1:]
    if args:
        paths = args
    else:
        paths = [Path(__file__).resolve().parents[2] / ".github" / "workflows"]
    files = list(_iter_workflow_files(paths))
    all_violations = []
    for f in files:
        for lineno, msg in lint_file(f):
            all_violations.append((f, lineno, msg))
    if all_violations:
        for f, lineno, msg in all_violations:
            print(f"{f}:{lineno}: {msg}")
        print(f"\nFAIL: {len(all_violations)} unpinned reference(s) across {len(files)} workflow file(s)")
        return 1
    print(f"OK: all actions + npm globals pinned across {len(files)} workflow file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
