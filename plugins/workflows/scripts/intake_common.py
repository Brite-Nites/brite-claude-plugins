#!/usr/bin/env python3
"""Shared deterministic intake primitives for the workflows-plugin S2 evals
(BC-12944, ADR-028 Phase-2 Batch C).

The Rule-of-Three extraction point for `/workflows:raise-a-ticket` and
`/workflows:report-issue`: both commands resolve a CDR-018 severity → Linear
priority + `severity:sevN` label, and both run the SAME existence-aware label
reconcile (apply only the canonical labels actually provisioned in the target
team; never auto-create a workspace label group). Those two pieces are the only
overlap (2 consumers each) — so they live here; the divergent logic (raise's
modal-team tiebreak, report-issue's classification→registry entry) stays in each
builder. Keeping the reconcile single-sourced is the producer↔consumer parity
discipline from BC-12594: a second copy would be a drift hazard.

PURE + stdlib-only (CLAUDE.md § Conventions) — no MCP, no network, no I/O. The
builders that import this run hermetically in the behavioral eval.
"""
from __future__ import annotations

# CDR-018 severity axis → (native Linear priority, severity:sevN label). The two
# axes are distinct (raise-a-ticket Step 4 / report-issue Step 2b): a team may
# provision `severity:*` labels, the native priority, or both — the reconcile
# below drops the label when its group is unprovisioned and the command relies on
# priority to carry the signal.
SEVERITY_TO_PRIORITY = {"critical": 1, "high": 2, "medium": 3, "low": 4}
SEVERITY_TO_SEV_LABEL = {
    "critical": "severity:sev0",
    "high": "severity:sev1",
    "medium": "severity:sev2",
    "low": "severity:sev3",
}


def severity_to_priority(severity: str | None) -> int | None:
    """Critical→1, High→2, Medium→3, Low→4; None for an absent/unknown severity
    (an Idea/Feedback has no severity, so priority is omitted)."""
    return SEVERITY_TO_PRIORITY.get(severity or "")


def severity_to_sev_label(severity: str | None) -> str | None:
    """Critical→severity:sev0 … Low→severity:sev3; None for absent/unknown."""
    return SEVERITY_TO_SEV_LABEL.get(severity or "")


def reconcile_labels(intended, existing) -> tuple[list, list]:
    """Existence-aware label reconcile (raise-a-ticket Step 8 / report-issue 6a).

    `intended` = the ordered canonical labels the command WANTS to apply;
    `existing` = the label names actually provisioned in the target team (the
    injected `list_issue_labels` read). Returns ``(applied, missing)``:
      - ``applied``  = intended labels present in the team, order preserved.
      - ``missing``  = intended labels NOT provisioned — the caller decides the
                       per-label fallback (needs-triage → built-in Triage state;
                       severity:sevN → priority carries it; etc.).
    This function NEVER invents a label and NEVER auto-creates a group — it is
    pure set membership over the team's provisioned names. Order-preserving so
    the applied set is deterministic for the golden.
    """
    have = set(existing or [])
    applied = [lbl for lbl in intended if lbl in have]
    missing = [lbl for lbl in intended if lbl not in have]
    return applied, missing
