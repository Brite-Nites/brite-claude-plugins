#!/usr/bin/env python3
"""Deterministic FDA CI audit (BC-12303) — the headless, exit-code runner that
consumer-repo CI calls (via the brite-claude-plugins composite action) to BLOCK
off-canon FDA docs at PR time. This is LAYER-3 / continuous (CI-gated) enforcement
— distinct from layer-2 audit-time `/flow:audit` (an LLM command, not headlessly
runnable) and layer-1 the local verify-docs.sh.

SINGLE SOURCE OF TRUTH: the gate logic is NOT re-implemented here — it imports the
canonical Phase-B predicates from build_audit_report.py (which the audit report and
run-audit-smoke.sh also use) so there is exactly one definition of each gate:

  * story-front-matter-populated / redirect-front-matter-valid / journey-front-matter-populated
                          — _story_frontmatter_populated(text) over story docs (the full
                          ADR-029 canon, unconditional) + the redirect-canon check + the
                          journey frontmatter lint (ADR-033). BC-13915 collapsed the
                          per-repo `frontmatter_schema` flag to this hardcoded full-canon
                          end-state; BC-13956 harmonized the emitted gate-ids to these
                          granular manifest ids (previously a coarse runner-only
                          `frontmatter-schema` umbrella) so red CI names the SAME gate as
                          local `/flow:audit`.
  * story-frame         — _story_frame_present(text) over story docs (the human
                          job-story frame is required everywhere; the legacy
                          constraint-spec frame is rejected — BC-12197 collapsed the
                          per-repo story_frame flag to this hardcoded end-state).
  * link-resolution     — every `](<path>.md[#anchor])` link in any story/journey doc
                          BODY resolves to a file on disk (ALWAYS on, not config-gated;
                          the BC-13710 broken-cross-reference-link class). Frontmatter
                          and `http(s)`/`mailto` links are not checked.

Both the frontmatter-populated gates (full canon) and the story-frame gate (human-only) are
now UNCONDITIONAL — the per-repo `.flow/config.json` `frontmatter_schema` (BC-13915) and
`story_frame` (BC-12197) strangler-fig flags were collapsed once every consumer converged.
Leftover keys in a consumer config are harmless ignored extras.

Usage:  run_fda_ci_audit.py <repo_root>
Exit:   0 = all gates pass · 1 = >=1 hard-fail · 2 = usage / repo not found.
Stdlib only (python3 3.6+); imports the sibling lint modules by path.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_SCRIPTS_DIR))
sys.path.insert(0, str(_SCRIPTS_DIR / "lib"))
import build_audit_report as bar          # canonical Phase-B predicates (single source)
import flow_frontmatter_lint as ffl       # journey lint (+ story, via bar)

# A markdown link whose target is a RELATIVE `<...>.md` file (optionally `#anchor`
# and/or a `"title"` attribute), preceded by `](`. Excluded: any absolute URI
# (`scheme:` — case-insensitively, since the scheme alpha-lead is [a-zA-Z]; covers
# HTTP/HTTPS/Mailto/etc. per RFC-3986 case-insensitive schemes) and protocol-relative
# `//host/...` URLs. The relative target may carry a path prefix (./x.md, ../dom/x.md);
# anchor + title are ignored for on-disk resolution (group 1 is the file path only).
_MD_LINK_RE = re.compile(
    r"\]\("
    r"(?![A-Za-z][\w+.-]*:|//)"   # not an absolute URI scheme, not protocol-relative
    r"([^)\s]+?\.md)"             # group 1: the relative .md target
    r"(?:#[^)\s]*)?"              # optional #anchor
    r'(?:\s+"[^"]*")?'           # optional markdown title attribute: ](path "Title")
    r"\)")


def _body_of(text: str) -> str:
    """The doc body (everything after the closing frontmatter fence); the whole text
    if there is no frontmatter block. Link-resolution only scans the body — a `.md`
    value inside frontmatter (e.g. intent: ../intent.md) is checked by the schema
    lint, not here."""
    # Require the doc to OPEN with a real `---\n` frontmatter fence (not a `----` rule
    # or `---text`) before treating the first block as frontmatter — so a doc that
    # merely starts with a horizontal rule isn't truncated. (CRLF is a non-issue:
    # bar._read → read_text() universal-newline-normalizes \r\n → \n before this runs.)
    if text.startswith("---\n"):
        parts = text.split("\n---\n", 1)
        if len(parts) == 2:
            return parts[1]
    return text


def _check_links(doc: Path) -> list:
    """Return a list of unresolved `](path.md)` body links in `doc` (each as the raw
    relative target). Resolution is relative to the doc's own directory."""
    text = bar._read(doc)
    body = _body_of(text)
    bad = []
    for m in _MD_LINK_RE.finditer(body):
        target = m.group(1)
        resolved = (doc.parent / target).resolve()
        if not resolved.exists():
            bad.append(target)
    return bad


def audit(repo: Path) -> list:
    """Run the three CI gates over `repo` → a list of failure dicts
    {gate, scope, detail}. Empty list ⇒ all pass."""
    failures = []

    # --- story docs: story-front-matter-populated (full canon) / redirect-front-matter-valid
    #     (redirect stubs) + story-frame (human-only) — all unconditional since BC-12197
    #     (story_frame) + BC-13915 (frontmatter_schema); gate-ids harmonized to the Q29
    #     manifest in BC-13956. ---
    for domain in bar._domains(repo):
        for doc in bar._story_docs(repo, domain):
            text = bar._read(doc)
            scope = "flow:" + doc.stem
            if bar._doc_type(text) == "redirect":
                # Redirect stub (BC-12907): an intentional alias to another flow's
                # canonical home — validated AS a redirect (resolvable pointer + valid
                # redirect front-matter); the story-frame + populated gates are skipped.
                # Body link-resolution below still applies (the alias must link a real doc).
                rt = bar._yaml_scalar_text(text, "redirect_to")
                if not bar._redirect_to_resolvable(repo, rt, doc.stem):
                    failures.append({"gate": "redirect-target", "scope": scope,
                                     "detail": "redirect_to=" + (rt.strip() or "∅") + " does not resolve"})
                res = ffl.lint_text(text, "redirect")
                if res["drift"] or res["missing"]:
                    bits = []
                    if res["drift"]:
                        bits.append("drift=" + ",".join(d.split(" ")[0] for d in res["drift"][:4]))
                    if res["missing"]:
                        bits.append("missing=" + ",".join(m.split(" ")[0] for m in res["missing"][:4]))
                    failures.append({"gate": "redirect-front-matter-valid", "scope": scope,
                                     "detail": "; ".join(bits)})
                continue
            if not bar._story_frontmatter_populated(text):
                miss = ffl.lint_text(text, "story")["missing"]
                detail = "missing=" + ",".join(miss[:6]) + ("…" if len(miss) > 6 else "")
                failures.append({"gate": "story-front-matter-populated", "scope": scope, "detail": detail})
            if not bar._story_frame_present(text):
                failures.append({"gate": "story-frame", "scope": scope,
                                 "detail": "no human job-story frame"})

    # --- journey docs: journey-front-matter-populated (ADR-033 canon, unconditional —
    #     BC-13915). bar._journey_docs is the shared journey set (single-sourced into
    #     build_audit_report per BC-13935) — the SAME set bar.evaluate's
    #     journey-front-matter-populated gate lints, keeping this CI runner and
    #     /flow:audit's Phase-B evaluator in lockstep (BC-13148). The runner now emits the
    #     SAME granular gate-id as evaluate() (harmonized in BC-13956); it keeps its own
    #     `journey:<stem>` scope as the unfiltered CI surface. ---
    for doc in bar._journey_docs(repo):
        res = ffl.lint_text(bar._read(doc), "journey")
        if res["drift"] or res["missing"]:
            bits = []
            if res["drift"]:
                bits.append("drift=" + ",".join(d.split(" ")[0] for d in res["drift"][:4]))
            if res["missing"]:
                bits.append("missing=" + ",".join(res["missing"][:4]))
            failures.append({"gate": "journey-front-matter-populated", "scope": "journey:" + doc.stem,
                             "detail": "; ".join(bits)})

    # --- link-resolution: body .md links resolve (ALWAYS on) ---
    link_docs = []
    for domain in bar._domains(repo):
        link_docs.extend(bar._story_docs(repo, domain))
    link_docs.extend(bar._journey_docs(repo))
    for doc in link_docs:
        for target in _check_links(doc):
            scope = ("journey:" if doc.parent.name == "journeys" else "flow:") + doc.stem
            failures.append({"gate": "link-resolution", "scope": scope, "detail": "→ " + target})

    return failures


def main(argv: list) -> int:
    if len(argv) != 1:
        sys.stderr.write("usage: run_fda_ci_audit.py <repo_root>\n")
        return 2
    repo = Path(argv[0])
    if not repo.is_dir():
        sys.stderr.write("error: repo root not found: {}\n".format(repo))
        return 2
    if not (repo / "docs" / "product" / "flows").is_dir():
        sys.stderr.write("error: no docs/product/flows under {} — not an FDA repo?\n".format(repo))
        return 2

    failures = audit(repo)

    print("FDA CI audit — {}".format(repo))
    print("  frontmatter_schema=strict (hardcoded; BC-13915)  story_frame=strict (hardcoded; BC-12197)")
    if not failures:
        print("  ✓ all gates pass")
        return 0
    print("  ✗ {} failure(s):".format(len(failures)))
    for f in failures:
        print("  FAIL  {gate:18s} {scope:24s} {detail}".format(**f))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
