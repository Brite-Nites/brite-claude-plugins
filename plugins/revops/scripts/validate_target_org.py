#!/usr/bin/env python3
"""Deterministic, side-effect-free `--target-org` shape validator (BC-12639).

The canonical shell-injection shape guard the σ3 SF-write commands
(/revops:create-sf-campaign, /revops:update-sf-campaign-status) delegate their
Phase 0 `--target-org` validation to — the ADR-028 emit-mode seam that makes the
guard BEHAVIORALLY testable instead of prose-the-LLM-follows.

It is a PURE boolean check: exit 0 iff the candidate matches the canonical SF
org-alias / username character set ^[a-zA-Z0-9._@-]+$, non-zero otherwise. It
makes NO shell-out, NO network call, NO filesystem write — so the value it
receives is matched against a regex and never reaches a shell. The command owns
the emit idiom on rejection (σ3 = soft-fail {"error":"invalid_target_org",
"value":"<value>"} exit 0; marketing siblings = hard-fail ERROR: exit non-zero).

Why this matters (the residual vector): `--target-org` is interpolated into a
double-quoted `sf` argument (`sf org display --target-org "<target-org>"`). Bash
expands `$(...)` / backtick command substitution even inside double quotes, so a
value reaches a shell before its guard unless validated first. The regex below
deliberately EXCLUDES `$ ( ) ` backtick, whitespace, `;`, `&`, `|`, `<`, `>`,
quotes — every shell metacharacter — while accepting every character SF aliases
and usernames legitimately use (alphanumerics, dot, underscore, at, hyphen).

Stdlib-only per CLAUDE.md § Conventions; same command+helper pattern as
build_manifest.py / canonicals_bootstrap.py / portfolio_snapshot.py.

Byte-identity discipline: the regex literal below MUST stay byte-identical to the
^[a-zA-Z0-9._@-]+$ guard documented in the σ3 command flag tables and the
marketing siblings (offer-performance / portfolio-snapshot). The consolidating
lint (scripts/_lib/lint_target_org_guard.py, BC-12638) enforces that parity.

Exit codes:
  0  accept — candidate matches the canonical regex
  1  reject — candidate fails the regex (shell-injection shape guard tripped)
  2  usage  — no candidate argument supplied
"""
from __future__ import annotations

import re
import sys

# Canonical SF org-alias / username character set. Byte-identical to the guard
# documented across the σ3 + marketing commands (enforced by the BC-12638 lint).
TARGET_ORG_RE = re.compile(r"^[a-zA-Z0-9._@-]+$")


def is_valid_target_org(value: str) -> bool:
    """Pure predicate: True iff *value* is a safe `--target-org` shape.

    No side effects, no shell-out — *value* is only ever regex-matched, never
    passed to a shell, so injection payloads ($(...), backticks, `x'; DROP`)
    cannot execute here; they simply fail the match.

    Uses ``fullmatch`` (not ``match``) so a value with a single trailing newline
    — which Python's ``$`` would otherwise accept before the final ``\\n`` — is
    correctly rejected; the documented regex literal stays byte-identical.
    """
    return TARGET_ORG_RE.fullmatch(value) is not None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        return 2  # usage: no candidate supplied
    return 0 if is_valid_target_org(argv[1]) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
