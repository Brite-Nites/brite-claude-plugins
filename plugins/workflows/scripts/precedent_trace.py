#!/usr/bin/env python3
"""Shared deterministic decision-trace primitives for the workflows-plugin S3 evals
(BC-12945, ADR-028 Phase-2 Batch D).

The Rule-of-Three extraction point for `/workflows:flywheel-metrics` and
`/workflows:audit-trail`: BOTH parse a precedent file's `## Trace —` sections
(Category / Confidence / Precedent-Referenced / Inputs) AND BOTH run the SAME
`last_refreshed` + `refresh_cadence` staleness ratio + band classification. Those
two pieces are the only overlap (2 consumers each) — so they live here. The
divergent logic stays in each builder: flywheel's 5-metric computation
(confidence trend, CDR-coverage, context-freshness) and audit's per-issue
frequency analysis. `parse_index` (the INDEX.md table) has one consumer today
(flywheel) but lives here by cohesion — it IS a precedent-corpus primitive, the
same call cycle_metrics.py made for its single-consumer helpers (BC-12944).

THE PARSING IS THE LOGIC UNDER TEST (ADR-028 D2): unlike cycle_metrics.py (which
takes pre-parsed Linear JSON), the markdown parsing here is the load-bearing
deterministic work, so the builders that import this READ a frozen
`docs/precedents/` seed and the unit suites drive these functions on raw text.

Format target: the BC-1955 decision-trace `## Trace —` shape the commands
document — `**Category:** v`, `**Confidence:** N/10`, `**Precedent Referenced:** v`,
`**Inputs:**` bullets, with a file-level `**Date:**`. Field extraction tolerates
BOTH colon styles (`**X:** v` and `**X**: v`) since the live corpus mixes them.
Heading category (`## Trace N — <category> — …`, the legacy variant) is NOT parsed —
the `**Category:**` field is the contract.

PURE + stdlib-only (CLAUDE.md § Conventions) — no MCP, no network, NEVER
`date.today()` (the now() equivalent): every wall-clock input is INJECTED as
`as_of` so the builders run hermetically + deterministically. The ONE disk-I/O
exception is `classify_context_file` (the shared file-resolver both builders need
identically); everything else is text/value-in, data-out.

Defensive by contract (the exit-2-or-clean discipline): a malformed trace
(missing Confidence/Category/date, an unparseable date) NEVER raises — the field
resolves to None / [] and the builders decide what that means.
"""
from __future__ import annotations

import re
from datetime import date
from pathlib import Path

# refresh_cadence → days. `on-change` is the documented SKIP value (excluded from
# the freshness denominator, never penalized); anything else is `unknown_cadence`
# (defensive closed-set — a typo'd cadence is surfaced, not silently bucketed).
CADENCE_DAYS = {"quarterly": 90, "monthly": 30, "weekly": 7}
CADENCE_SKIP = "on-change"

# Staleness bands (audit Phase 3 / flywheel M4). Upper-inclusive edges are
# load-bearing: Fresh r<=1.0, Aging 1.0<r<=1.5, Stale 1.5<r<=2.0, Very Stale r>2.0.
BAND_FRESH = "Fresh"
BAND_AGING = "Aging"
BAND_STALE = "Stale"
BAND_VERY_STALE = "Very Stale"
BAND_SKIP = "on-change (skip)"
BAND_NO_METADATA = "No freshness metadata"
BAND_UNKNOWN_CADENCE = "Unknown cadence"
BAND_BAD_DATE = "Unparseable last_refreshed"
BAND_MISSING = "MISSING"  # referenced context file no longer exists (audit Phase 3)

_CDR_RE = re.compile(r"\bCDR-\d+\b")
_TRACE_HEADING_RE = re.compile(r"^## Trace\b.*$", re.MULTILINE)


def _field(text: str, label: str) -> str | None:
    """Extract a `**Label:** value` / `**Label**: value` field's value (first hit).

    Tolerates the colon inside OR outside the bold markers (the live corpus mixes
    them). Returns None when absent. Stripped of surrounding whitespace."""
    m = re.search(
        rf"^\*\*{re.escape(label)}:?\*\*:?[ \t]*(.+?)[ \t]*$", text, re.MULTILINE
    )
    return m.group(1).strip() if m else None


def confidence_value(raw: str | None) -> int | None:
    """`8/10` (or a bare `8`) → 8; None / unparseable → None (never raises)."""
    if not raw:
        return None
    m = re.match(r"\s*(\d+)", raw)
    return int(m.group(1)) if m else None


def has_cdr(precedent_referenced: str | None) -> bool:
    """True iff the Precedent-Referenced field cites a CDR (pattern `CDR-\\d+`).

    An ADR-only reference, `None`, `1st surface (NEW)`, or an empty field → False;
    a field carrying BOTH an ADR and a CDR → True (the CDR presence is what counts)."""
    if not precedent_referenced:
        return False
    return bool(_CDR_RE.search(precedent_referenced))


def _inputs(section: str) -> list[str]:
    """The bullet items under a `**Inputs:**` line (the context_used files), until
    the next blank line / `**Field:**` / `###` subsection. Backticks stripped; a
    section with no Inputs block → []."""
    lines = section.splitlines()
    out: list[str] = []
    collecting = False
    for ln in lines:
        if re.match(r"^\*\*Inputs:?\*\*:?\s*$", ln):
            collecting = True
            continue
        if collecting:
            s = ln.strip()
            if not s:
                # A blank line does NOT end the list — markdown tolerates a blank
                # line between `**Inputs:**` and the first bullet (and "loose" lists
                # with blanks between bullets). Breaking here silently dropped every
                # input for that layout; skip blanks and let a structural boundary
                # (`###` / `**Field`) or non-bullet content end collection instead.
                continue
            if s.startswith("###") or re.match(r"^\*\*\w", s):
                break
            if s.startswith("-"):
                out.append(s.lstrip("- ").strip().strip("`").strip())
            else:
                break
    return out


def parse_traces(text: str) -> list[dict]:
    """Parse a precedent file's `## Trace —` sections → a list of trace dicts.

    Each trace: {summary, category, confidence:int|None, precedent_referenced,
    has_cdr:bool, inputs:[paths], date}. `date` is the file-level `**Date:**`
    (all traces from one issue share its ship date — the flywheel monthly grouping
    key). Defensive: a missing field resolves to None / [] / False, never a raise.
    A file with no `## Trace` heading → []."""
    file_date = _field(text, "Date")

    # Split on the trace headings, keeping each heading with its body.
    headings = list(_TRACE_HEADING_RE.finditer(text))
    traces: list[dict] = []
    for i, h in enumerate(headings):
        start = h.start()
        end = headings[i + 1].start() if i + 1 < len(headings) else len(text)
        section = text[start:end]
        heading_line = h.group(0)
        summary = heading_line[len("## Trace"):].lstrip(" 0123456789—-").strip() or None
        precedent = _field(section, "Precedent Referenced")
        traces.append({
            "summary": summary,
            "category": _field(section, "Category"),
            "confidence": confidence_value(_field(section, "Confidence")),
            "precedent_referenced": precedent,
            "has_cdr": has_cdr(precedent),
            "inputs": _inputs(section),
            "date": file_date,
        })
    return traces


def month_of(iso_date: str | None) -> str | None:
    """`2026-03-15` → `2026-03`; None / unparseable → None (never raises)."""
    if not iso_date:
        return None
    m = re.match(r"\s*(\d{4})-(\d{2})", iso_date)
    return f"{m.group(1)}-{m.group(2)}" if m else None


def staleness(last_refreshed: str | None, refresh_cadence: str | None, as_of: str) -> dict:
    """Classify a context doc's freshness from its frontmatter vs the injected as_of.

    Returns {ratio: float|None, band: str, cadence_days: int|None}. ratio is
    days_since_last_refreshed / cadence_days, rounded to 2 dp; None for the
    non-numeric bands. NEVER raises — every malformed input maps to a named band:
      - both fields absent     → No freshness metadata (excluded from the denominator)
      - cadence == on-change   → on-change (skip)        (excluded; not penalized)
      - cadence unknown        → Unknown cadence         (defensive closed-set)
      - last_refreshed bad ISO → Unparseable last_refreshed
      - a future last_refreshed → ratio clamps at 0.0 → Fresh (negative is not stale)
    """
    if not last_refreshed or not refresh_cadence:
        return {"ratio": None, "band": BAND_NO_METADATA, "cadence_days": None}
    if refresh_cadence == CADENCE_SKIP:
        return {"ratio": None, "band": BAND_SKIP, "cadence_days": None}
    cadence_days = CADENCE_DAYS.get(refresh_cadence)
    if cadence_days is None:
        return {"ratio": None, "band": BAND_UNKNOWN_CADENCE, "cadence_days": None}
    try:
        ref = date.fromisoformat(str(last_refreshed)[:10])
        now = date.fromisoformat(str(as_of)[:10])
    except ValueError:
        return {"ratio": None, "band": BAND_BAD_DATE, "cadence_days": cadence_days}

    days_since = (now - ref).days
    if days_since < 0:
        days_since = 0  # a doc refreshed in the future is not stale (no negative ratio)
    ratio = round(days_since / cadence_days, 2)
    if ratio <= 1.0:
        band = BAND_FRESH
    elif ratio <= 1.5:
        band = BAND_AGING
    elif ratio <= 2.0:
        band = BAND_STALE
    else:
        band = BAND_VERY_STALE
    return {"ratio": ratio, "band": band, "cadence_days": cadence_days}


def is_fresh(band: str) -> bool:
    """A doc counts toward flywheel M4 freshness iff its band is Fresh. The skip /
    no-metadata bands are out of the denominator entirely (decided by the caller)."""
    return band == BAND_FRESH


def counts_for_freshness(band: str) -> bool:
    """True iff a doc is IN the freshness denominator (has usable metadata + a real
    cadence). The skip + no-metadata + unknown-cadence + bad-date bands are excluded
    (not penalized) per the flywheel/audit specs."""
    return band in (BAND_FRESH, BAND_AGING, BAND_STALE, BAND_VERY_STALE)


def parse_imports(text: str) -> list[str]:
    """The `@<relative/path>` import directives from a CLAUDE.md (flywheel M4 /
    audit Phase 2 session context). One per line-leading `@`; de-duplicated,
    order-preserving. A path-less `@` or an inline mid-line `@` is ignored."""
    out: list[str] = []
    seen: set[str] = set()
    for ln in text.splitlines():
        m = re.match(r"^@(\S+)", ln)
        if m and m.group(1) not in seen:
            seen.add(m.group(1))
            out.append(m.group(1))
    return out


def parse_frontmatter_freshness(text: str) -> dict:
    """Extract `last_refreshed` + `refresh_cadence` from a file's leading YAML
    frontmatter (first ~10 lines). Returns {last_refreshed: str|None,
    refresh_cadence: str|None}. Tolerant of a missing `---` fence (scans the head).
    Never raises."""
    out = {"last_refreshed": None, "refresh_cadence": None}
    for ln in text.splitlines()[:10]:
        m = re.match(r"^\s*(last_refreshed|refresh_cadence)\s*:\s*(.+?)\s*$", ln)
        if m:
            out[m.group(1)] = m.group(2).strip().strip("'\"")
    return out


def classify_context_file(base_dir, relpath: str, as_of: str) -> dict:
    """Resolve a referenced context file (a trace Input or a CLAUDE.md @import)
    against `base_dir` → its existence + freshness classification. The ONE I/O
    helper in this otherwise-pure module: BOTH builders (flywheel M4, audit Phase 3)
    need byte-identical missing+freshness classification, so single-sourcing it here
    is the producer↔consumer parity discipline (BC-12594) — a second copy would
    drift. Returns {path, exists, band, ratio, in_denominator, fresh}. NEVER raises:
    a missing file → band MISSING (not in the denominator); an unreadable file is
    treated as no-metadata."""
    base = Path(base_dir).resolve()
    p = (base / relpath).resolve()
    # Confine the resolved path to the corpus root: an ABSOLUTE (`@/etc/shadow`) or
    # TRAVERSAL (`@../../secret`) import — the @import/Input is project-derived content
    # the runtime command reads off disk — must NOT be opened (it would leak an
    # out-of-corpus file's existence + frontmatter). An escaping path is treated as
    # MISSING (surfaces as a warning), never a read. The issue-id guard covers the id;
    # this covers the context-file paths.
    if not p.is_relative_to(base):
        return {"path": relpath, "exists": False, "band": BAND_MISSING,
                "ratio": None, "in_denominator": False, "fresh": False}
    if not p.is_file():
        return {"path": relpath, "exists": False, "band": BAND_MISSING,
                "ratio": None, "in_denominator": False, "fresh": False}
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        text = ""
    fm = parse_frontmatter_freshness(text)
    st = staleness(fm["last_refreshed"], fm["refresh_cadence"], as_of)
    return {
        "path": relpath, "exists": True, "band": st["band"], "ratio": st["ratio"],
        "in_denominator": counts_for_freshness(st["band"]), "fresh": is_fresh(st["band"]),
    }


def parse_index(text: str) -> list[dict]:
    """Parse an INDEX.md markdown table → a list of row dicts
    {issue, decision, category, date, tags}. Skips the header + `|---|` separator
    and the HTML comment block; a malformed row (too few cells) is skipped, never a
    raise. `issue` is de-linked (`[BC-1](BC-1.md)` → `BC-1`)."""
    rows: list[dict] = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) < 5:
            continue
        issue_cell = cells[0]
        if issue_cell.lower() == "issue" or set(issue_cell) <= {"-", ":", " "}:
            continue  # header / separator
        m = re.match(r"\[([^\]]+)\]", issue_cell)
        issue = m.group(1) if m else issue_cell
        rows.append({
            "issue": issue, "decision": cells[1], "category": cells[2],
            "date": cells[3], "tags": cells[4],
        })
    return rows
