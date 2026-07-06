#!/usr/bin/env python3
"""Lint .github/workflows/*.yml for supply-chain pinning (BC-16291 / audit plan 004).

Two rules, aimed at the two secret-bearing workflows (behavioral-tests.yml holds
ANTHROPIC_API_KEY; jwt-validity-probe.yml holds the prod Salesforce token +
LINEAR_API_KEY) but enforced repo-wide so the convention can't erode by copy-paste:

  1. Every third-party ``uses: owner/repo@ref`` must pin ``ref`` to a full 40-char
     commit SHA. A moved tag would run arbitrary code next to those secrets on a
     PUBLIC repo. A trailing ``# vN`` comment is allowed and encouraged —
     Dependabot reads it to open bump PRs.
  2. Every ``npm install -g <pkg>`` must pin an exact version (``@x.y.z``); a
     poisoned "latest" npm release would run with the same secrets in scope.

Exit 0 = clean, 1 = violations (printed as ``file:line: reason``). Accepts optional
path args (files or dirs) for the self-test; defaults to the repo's workflows dir.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
USES_RE = re.compile(r"""\buses:\s*['"]?([^\s'"#]+)""")
NPM_G_RE = re.compile(r"\bnpm\s+(?:install|i)\s+-g\b(.*)")
_SHELL_OPS = {"&&", "||", ";", "|", "\\"}


def _is_third_party_action(action: str) -> bool:
    """A tag-pinnable third-party action: owner/repo form, not local (./) or docker."""
    return "/" in action and not action.startswith("./") and not action.startswith("docker://")


def _pkg_is_pinned(token: str) -> bool:
    """Scoped ``@scope/name@ver`` carries a 2nd '@'; unscoped ``name@ver`` carries one."""
    if token.startswith("@"):
        return "@" in token[1:]
    return "@" in token


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
        # Rule 1 — uses: pins
        m = USES_RE.search(raw)
        if m:
            value = m.group(1)
            if "@" in value:
                action, _, ref = value.rpartition("@")
                if _is_third_party_action(action) and not SHA_RE.match(ref):
                    violations.append(
                        (lineno, f"unpinned action: uses: {value} — pin to a 40-char commit SHA (keep '# vN' as a comment)")
                    )
        # Rule 2 — npm install -g pins (check the first real package token after -g)
        nm = NPM_G_RE.search(raw)
        if nm:
            for tok in nm.group(1).split():
                if tok in _SHELL_OPS:
                    break
                if tok.startswith("-"):
                    continue
                if not _pkg_is_pinned(tok):
                    violations.append(
                        (lineno, f"unpinned npm global: npm install -g {tok} — pin an exact version (@x.y.z)")
                    )
                break
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
