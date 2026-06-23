#!/usr/bin/env python3
"""Deterministic /flow:audit Phase-B gate-report builder (BC-12946, ADR-028
Phase-2 Batch E — flow-architecture's first behavioral-eval builder).

The hermetic, side-effect-free EMIT harness the behavioral eval (BC-12589 runner)
drives for /flow:audit. It is an **eval-only re-implementation of the DOCUMENTED
Phase-B gate semantics** — `commands/audit.md` § Phase B + the Q29 gate manifest
(`skills/_shared/artifact-gate-pattern.md`) — NOT the command's runtime path. The
runtime "Phase B" is prose an LLM evaluates; `tests/run-audit-smoke.sh`'s
`run_phase_b_gates()` is a separate bash impl of the same gates; this is a third
(Python) impl. The three are kept honest by a shared ORACLE: all evaluate the same
two on-disk fixtures (`audit-{clean,broken}-shape`), and the eval harness
cross-asserts this builder's broken-fixture verdict against the smoke's documented
expectation (exactly 3 named hard-fails). The long-term consolidation (a single
declarative `gates.json` both consume) is a v1.1 follow-up, not Batch E.

Scope = Phase B's deterministic FILESYSTEM gates only (per Q38 sub-decision 6 exit
codes 0/1/64). **Phase A** (`verify-docs.sh` deep-parse) and **Phase C** (Linear-MCP
state + the four Linear-side cross-cutting gates) are OUT — the same skip-with-reason
scoping `run-audit-smoke.sh` already uses. `exit 2` (Phase-A-gated) is therefore out
of scope; the emitted `summary.exit_code` ranges over {0, 1, 64}.

emit artifact (`--scenarios <fixture> --out-dir <dir> [--fixtures-dir <dir>]`):
    audit-report-emit.json = {
      "schema_version": 1,
      "command": "/flow:audit",
      "scenarios": [ {id, gates:[{id,type,status,scope,message}], summary:{...}, error}, … ]
    }
Each scenario names an on-disk fixture repo (`repo`) under --fixtures-dir; the builder
evaluates the Phase-B gates over that repo_root (explicit, the analytics HOME-override
analog — it NEVER runs against $CWD / the worktree). A scenario carrying an unrecognized
`gate` id yields an exit_code:64 / error row (the os.EX_USAGE arg-guard). `gates[]` is
sorted by a total (id, scope) key; every `message` is fixture-static (counts + frozen
timestamps) — no wall-clock, no absolute path leaks into the golden.

Stdlib-only per CLAUDE.md § Conventions. Same builder+harness shape as
build_analytics_emit.py / build_promotion_candidates.py.

Exit codes (PROCESS, distinct from the emitted summary.exit_code DATA field):
    0 = emitted OK; 2 = usage / unreadable-or-malformed fixture / missing fixture repo.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_VERSION = 1
COMMAND = "/flow:audit"

_HERE = Path(__file__).resolve().parent
# repo root = .../plugins/flow-architecture/scripts → up 3.
REPO_ROOT = _HERE.parent.parent.parent
DEFAULT_FIXTURES_DIR = _HERE.parent / "tests" / "fixtures"

# Single-source the canonical story key set: the strict `story-front-matter-populated`
# widening (BC-12572) delegates to the WS-A frontmatter lint rather than re-listing
# the 20-key canon a third time. lib/ is a sibling of this file.
sys.path.insert(0, str(_HERE / "lib"))
import flow_frontmatter_lint as _ffl  # noqa: E402

# os.EX_USAGE arg-guard universe: the canonical `--gate=<id>` valid-ID set from
# audit.md § Phase B `--gate=<id>` table (the full Q29 manifest). An unrecognized
# --gate value exits 64. This is the SUPERSET; the Phase-B subset this builder
# actually EMITS is whatever evaluate() emits (the Phase A/C ids + env-ready +
# scaffold-complete are valid-but-not-emitted here).
VALID_GATE_IDS = frozenset({
    # phase-transition (Q29.1)
    "env-ready", "preflight-complete", "intent-exists", "inventory-complete",
    "scaffold-complete", "story-docs-complete", "journey-complete", "index-complete",
    # per-flow [Story]
    "story-doc-exists", "story-front-matter-populated", "story-job-story-regex",
    "story-ac-gherkin-count", "story-verify-docs-pass",
    # per-flow [Eng]
    "eng-linear-completed", "eng-build-lint-test-pass", "eng-sandbox-http-200",
    "eng-children-engineering-populated",
    # per-flow [Design]
    "design-linear-completed", "design-figma-node-id", "design-children-design-populated",
    # per-flow [QA]
    "qa-status-signed-off", "qa-last-signed-off-iso8601", "qa-history-row-signed-off",
    "qa-comment-signature-match", "qa-children-qa-populated",
    # per-flow [Docs]
    "docs-customer-doc-exists", "docs-customer-frontmatter-q28",
    "docs-user-docs-url-non-tbd", "docs-customer-verify-docs-pass",
    "docs-children-docs-populated",
    # cross-cutting (Q29.3 + amendment 2)
    "inventory-story-doc-id-match", "index-story-doc-status-match",
    "linear-children-match", "parent-l3-summary-populated",
    "milestone-subflows-table-match", "cross-domain-deps-bidirectional",
})

# gate-id → type, for the `type` field of every emitted gate (Q29 categories).
# This lists only the phase-transition gates this builder EMITS — the other two of
# the 8 (env-ready, scaffold-complete) are intentionally absent because neither is
# reachable from the filesystem alone in Phase B (env-ready needs Linear MCP/gh auth;
# scaffold-complete needs the scaffold-log integration), mirroring run-audit-smoke.sh's
# RECOGNIZED_GATES. _gate_type() only ever classifies an emitted gate id.
_PHASE_TRANSITION = frozenset({
    "preflight-complete", "intent-exists", "inventory-complete",
    "story-docs-complete", "journey-complete", "index-complete",
})
_CROSS_CUTTING = frozenset({
    "inventory-story-doc-id-match", "index-story-doc-status-match",
})


def _gate_type(gate_id: str) -> str:
    if gate_id in _PHASE_TRANSITION:
        return "phase-transition"
    if gate_id in _CROSS_CUTTING:
        return "cross-cutting"
    return "per-flow"


class BuildError(Exception):
    """Unreadable/malformed/missing fixture (→ process exit 2). Distinct from a
    per-scenario hard-fail or a 64 row (both are SUCCESSFUL emits)."""


# ── gate-predicate helpers (faithful ports of run-audit-smoke.sh) ─────────────


def _read(p: Path) -> str:
    # errors="replace" so a malformed-encoding on-disk artifact degrades to a FAILED
    # gate (its predicates just don't match), never an uncaught UnicodeDecodeError that
    # aborts the emit — honoring evaluate()'s gate-fail-not-crash contract.
    return p.read_text(encoding="utf-8", errors="replace")


def _config_story_frame_mode(repo: Path) -> str:
    """`.flow/config.json` story_frame → 'strict' iff the string 'strict'
    (case-insensitive); every other state (absent file/field, bad value, parse
    error) resolves fail-safe to 'lenient'. Mirrors smoke story_frame_mode()."""
    cfg = repo / ".flow" / "config.json"
    if not cfg.is_file():
        return "lenient"
    try:
        v = json.loads(_read(cfg)).get("story_frame")
    except (ValueError, OSError, AttributeError):
        # AttributeError: valid-but-non-dict JSON (e.g. a top-level list) → .get fails.
        # Fail-safe to lenient on ANY unusable config, matching the smoke twin's broad
        # catch — the gate can only ever STAY permissive, never accidentally narrow.
        return "lenient"
    return "strict" if isinstance(v, str) and v.lower() == "strict" else "lenient"


def _config_frontmatter_schema_mode(repo: Path) -> str:
    """`.flow/config.json` frontmatter_schema → 'strict' iff the string 'strict'
    (case-insensitive); every other state (absent file/field, bad value, parse
    error) resolves fail-safe to 'lenient'. Mirrors _config_story_frame_mode and
    the smoke's frontmatter_schema_mode() — same per-repo strangler-fig as
    story_frame (BC-12572 / mirrors Q29 amendment 3)."""
    cfg = repo / ".flow" / "config.json"
    if not cfg.is_file():
        return "lenient"
    try:
        v = json.loads(_read(cfg)).get("frontmatter_schema")
    except (ValueError, OSError, AttributeError):
        # AttributeError: valid-but-non-dict JSON (e.g. a top-level list) → .get fails.
        # Fail-safe to lenient on ANY unusable config (parity with the smoke twin's
        # broad catch + _config_story_frame_mode above).
        return "lenient"
    return "strict" if isinstance(v, str) and v.lower() == "strict" else "lenient"


def _story_frontmatter_populated(doc_text: str, mode: str) -> bool:
    """The story-front-matter-populated predicate (BC-12572 config-gated widening).

    LENIENT (default): the 4-key presence floor (flow_id/status/figma/user_docs_url)
    — today's behavior, unchanged. STRICT: the FULL 20-key story canon must be
    present (presence, never non-emptiness — honest-empty `personas: []` passes),
    delegated to the WS-A lint (over the already-read doc_text, no re-read) so the
    canon is single-sourced. Drift keys fail here only via the canonical key they
    displace going MISSING — naming the drift itself is the standalone lint's job,
    not this completeness gate."""
    if mode == "strict":
        return not _ffl.lint_text(doc_text, "story")["missing"]
    return all(re.search(rf"^{k}:", doc_text, re.MULTILINE) for k in
               ("flow_id", "status", "figma", "user_docs_url"))


def _story_frame_present(doc_text: str, mode: str) -> bool:
    """The story-job-story-regex predicate. Region-scoped (title → first
    `## Acceptance`); the human frame (When/I want to/so I can) always passes; the
    legacy constraint-spec frame (Given/MUST/so that) passes only under lenient.
    Mirrors smoke story_frame_present() — case-insensitive, line-form-agnostic."""
    region_lines = []
    for ln in doc_text.splitlines():
        if ln.startswith("## Acceptance"):
            break
        region_lines.append(ln)
    region = "\n".join(region_lines)

    # Extract the CONTENT of each bold span (`**…**`) left-to-right, non-overlapping —
    # `[^*\n]+` can't cross an asterisk or a newline, so each match is one real
    # single-line bold run and the plain text BETWEEN two spans is never captured.
    # (Guards a false-positive where `**A** … keyword … **B**` would read as one span:
    # a `**Doc type:**` blockquote followed much later by a bolded persona link, with
    # unbolded `Given … MUST … so that` prose in between — observed in brite-labs.)
    # A marker is present if its word-boundaried keyword sits inside one of those spans
    # (BC-13751): recognizes phrase-bolded `**the system MUST**` / "to"-less `**I want**`
    # while the bold REQUIREMENT stays intact (unbolded prose has no qualifying span);
    # keywords are word-boundaried so "must" in "mustard" / "I want" in "I wanted" do
    # not leak. `so I can` keeps its full phrase (bare `**so**` is deferred to the
    # brite-base epic). Line-scoped (`[^*\n]`) to mirror the bash twin's `grep -o`.
    bold_spans = re.findall(r"\*\*([^*\n]+)\*\*", region)

    def marker(kw: str) -> bool:
        return any(re.search(r"\b" + kw + r"\b", s, re.IGNORECASE) for s in bold_spans)

    if marker("When") and marker("I want") and marker("so I can"):
        return True
    if mode != "strict":
        if marker("Given") and marker("MUST") and marker("so that"):
            return True
    return False


def _children_field_present(doc_text: str, field: str) -> bool:
    """`field` appears as `  <field>: ` inside the front-matter `children:` block
    (resets on the next top-level `^[a-z]` key or the closing `---`). Mirrors the
    smoke's awk children_field_present()."""
    in_children = False
    for ln in doc_text.splitlines():
        if ln.startswith("children:"):
            in_children = True
            continue
        if in_children and (re.match(r"^[a-z]", ln) or ln.strip() == "---"):
            in_children = False
        if in_children and re.match(rf"^  {re.escape(field)}: ", ln):
            return True
    return False


def _domains(repo: Path) -> list:
    """The flow domains = sorted subdirs of docs/product/flows/ (deterministic;
    more general than the smoke's hardcoded `TEAM SHIP` — same set for the
    fixtures, sorted)."""
    flows = repo / "docs" / "product" / "flows"
    if not flows.is_dir():
        return []
    return sorted(d.name for d in flows.iterdir() if d.is_dir())


def _story_docs(repo: Path, domain: str) -> list:
    """Sorted *.md story docs in a domain dir (deterministic glob order)."""
    d = repo / "docs" / "product" / "flows" / domain
    if not d.is_dir():
        return []
    return sorted(p for p in d.glob("*.md") if p.is_file())


# ── the Phase-B gate evaluator (pure; the load-bearing logic under test) ──────


def evaluate(repo: Path) -> list:
    """Run the Phase-B filesystem gates over one repo_root → an UNSORTED list of
    {id, type, status, scope, message} dicts. Faithful port of
    run-audit-smoke.sh's run_phase_b_gates(). Hard gates only (Phase B emits no
    soft-warns); status ∈ {pass, hard-fail}. A malformed/absent artifact FAILs its
    gate — it never raises (the gate-fail-not-crash contract)."""
    gates: list = []

    def emit(status: str, gate_id: str, scope: str, message: str = "") -> None:
        gates.append({
            "id": gate_id, "type": _gate_type(gate_id),
            "status": status, "scope": scope, "message": message,
        })

    frame_mode = _config_story_frame_mode(repo)
    fm_schema_mode = _config_frontmatter_schema_mode(repo)

    # --- preflight-complete (Q29.1) ---
    cfg = repo / ".flow" / "config.json"
    required = ("version", "linear_project_id", "linear_project_name",
                "linear_team_key", "fda_first_setup_at", "fda_plugin_version")
    ok = False
    if cfg.is_file():
        try:
            d = json.loads(_read(cfg))
            ok = all(k in d for k in required)
        except (ValueError, OSError):
            ok = False
    emit("pass" if ok else "hard-fail", "preflight-complete", "project")

    # --- intent-exists (Q29.1) ---
    intent = repo / "docs" / "product" / "intent.md"
    ok = False
    if intent.is_file():
        t = _read(intent)
        ok = any(l.startswith("## Mission") for l in t.splitlines()) and \
            any(l.startswith("## L1 review summary") for l in t.splitlines())
    emit("pass" if ok else "hard-fail", "intent-exists", "project")

    # --- inventory-complete (Q29.1; section-count half — verify-docs orphan half is Phase A) ---
    inv = repo / "docs" / "product" / "master-flow-inventory.md"
    inv_text = _read(inv) if inv.is_file() else ""
    inv_domains = sum(1 for l in inv_text.splitlines() if l.startswith("## Domain:"))
    if inv_domains >= 1:
        emit("pass", "inventory-complete", "project")
    else:
        emit("hard-fail", "inventory-complete", "project", f"domains={inv_domains}")

    # --- per-domain + per-flow gates ---
    for domain in _domains(repo):
        scope_dom = f"domain:{domain}"

        # journey-complete (Q29.1)
        journey = repo / "docs" / "product" / "journeys" / f"{domain}.md"
        emit("pass" if journey.is_file() else "hard-fail", "journey-complete", scope_dom)

        # story-docs-complete (Q29.1): inventory rows for the domain == story-doc files
        inv_count = _inventory_row_count(inv_text, domain)
        docs = _story_docs(repo, domain)
        doc_count = len(docs)
        if inv_count > 0 and inv_count == doc_count:
            emit("pass", "story-docs-complete", scope_dom,
                 f"inventory={inv_count} docs={doc_count}")
        else:
            emit("hard-fail", "story-docs-complete", scope_dom,
                 f"inventory={inv_count} docs={doc_count}")

        # per-flow gates against the story docs that exist
        for doc in docs:
            fid = doc.stem
            scope = f"flow:{fid}"
            t = _read(doc)

            emit("pass", "story-doc-exists", scope)

            emit("pass" if _story_frontmatter_populated(t, fm_schema_mode)
                 else "hard-fail", "story-front-matter-populated", scope)

            emit("pass" if _story_frame_present(t, frame_mode) else "hard-fail",
                 "story-job-story-regex", scope)

            scn = sum(1 for l in t.splitlines() if l.startswith("Scenario:"))
            if 3 <= scn <= 5:
                emit("pass", "story-ac-gherkin-count", scope, f"count={scn}")
            else:
                emit("hard-fail", "story-ac-gherkin-count", scope, f"count={scn}")

            # children.<discipline> populated (gate prefix eng for engineering)
            for field in ("engineering", "design", "docs", "qa"):
                prefix = "eng" if field == "engineering" else field
                gate_id = f"{prefix}-children-{field}-populated"
                emit("pass" if _children_field_present(t, field) else "hard-fail",
                     gate_id, scope)

            # [QA] front-matter half
            emit("pass" if re.search(r"^qa_status: signed-off", t, re.MULTILINE)
                 else "hard-fail", "qa-status-signed-off", scope)
            emit("pass" if re.search(
                r"^qa_last_signed_off: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",
                t, re.MULTILINE) else "hard-fail", "qa-last-signed-off-iso8601", scope)
            emit("pass" if "| signed-off |" in t else "hard-fail",
                 "qa-history-row-signed-off", scope)

    # --- index-complete (Q29.1): INDEX generated_at >= breadcrumb run_started_at ---
    index_at = _yaml_scalar(repo / "docs" / "product" / "flows" / "INDEX.md", "generated_at")
    brk_at = _json_field(repo / "docs" / "plans" / ".flow-phase-state.json", "run_started_at")
    # Lexicographic compare is correct for ISO-8601 YYYY-MM-DDTHH:MM:SSZ.
    if index_at and brk_at and index_at >= brk_at:
        emit("pass", "index-complete", "project",
             f"index={index_at} breadcrumb={brk_at}")
    else:
        emit("hard-fail", "index-complete", "project",
             f"index={index_at} breadcrumb={brk_at}")

    # --- cross-cutting (Q29.3 filesystem halves) ---
    # NOTE: fid/stat are re.escape()d here where the bash oracle interpolates them raw
    # into `grep -qE`; on the fixtures both are regex-inert single tokens (TEAM-01 /
    # shipped) so the two agree. A future fixture with a regex metachar in a flow_id/
    # status would be malformed anyway — the escape is the safer port, intentionally.
    id_mismatch = False
    status_mismatch = False
    index_text = ""
    idx = repo / "docs" / "product" / "flows" / "INDEX.md"
    if idx.is_file():
        index_text = _read(idx)
    for domain in _domains(repo):
        for doc in _story_docs(repo, domain):
            t = _read(doc)
            fid = _yaml_scalar_text(t, "flow_id")
            stat = _yaml_scalar_text(t, "status")
            if fid and not re.search(rf"^\| {re.escape(fid)} \|", inv_text, re.MULTILINE):
                id_mismatch = True
            if fid and stat and not re.search(
                    rf"^\| {re.escape(fid)} \| {re.escape(stat)} ", index_text, re.MULTILINE):
                status_mismatch = True
    emit("pass" if not id_mismatch else "hard-fail",
         "inventory-story-doc-id-match", "project")
    emit("pass" if not status_mismatch else "hard-fail",
         "index-story-doc-status-match", "project")

    return gates


def _inventory_row_count(inv_text: str, domain: str) -> int:
    """Count `| FLOW-NN |` rows under the `## Domain: <domain>` section."""
    in_section = False
    count = 0
    for ln in inv_text.splitlines():
        if ln.startswith("## Domain:"):
            in_section = ln.split(":", 1)[1].strip() == domain
            continue
        if in_section and re.match(r"^\| [A-Z]+-[0-9]+ \|", ln):
            count += 1
    return count


def _yaml_scalar(path: Path, key: str) -> str:
    """First `key: value` scalar from a file's leading front-matter (or '')."""
    if not path.is_file():
        return ""
    return _yaml_scalar_text(_read(path), key)


def _yaml_scalar_text(text: str, key: str) -> str:
    m = re.search(rf"^{re.escape(key)}:[ \t]*(.*)$", text, re.MULTILINE)
    return m.group(1).strip() if m else ""


def _json_field(path: Path, key: str) -> str:
    if not path.is_file():
        return ""
    try:
        return str(json.loads(_read(path)).get(key, "") or "")
    except (ValueError, OSError):
        return ""


# ── per-scenario decision + summary ───────────────────────────────────────────


def decide(scenario: dict, fixtures_dir: Path) -> dict:
    """One scenario → one emit row: {id, gates[sorted], summary, error}. A scenario
    with an unrecognized `gate` id yields the exit_code:64 arg-guard row (no gate
    run). Otherwise evaluate Phase-B gates over the named fixture repo."""
    sid = scenario.get("id", "scenario")
    gate = scenario.get("gate")
    # `isinstance(gate, str)` SHORT-CIRCUITS before the frozenset membership test — a
    # non-string degenerate value (a list/dict is unhashable; an int won't match) routes
    # to the same 64 arg-guard row instead of raising on the hash (the recurring
    # malformed-injected-state P1 — VALID_GATE_IDS is a frozenset, not a tuple).
    if gate is not None and (not isinstance(gate, str) or gate not in VALID_GATE_IDS):
        return {
            "id": sid, "gates": [],
            "summary": {"hard_pass": 0, "hard_fail": 0, "soft_warn": 0,
                        "overrides": 0, "exit_code": 64},
            "error": (f"invalid --gate '{gate}': not a recognized gate id "
                      "(os.EX_USAGE)"),
        }

    repo_rel = scenario.get("repo")
    if not isinstance(repo_rel, str) or not repo_rel:
        raise BuildError(f"scenario {sid!r} missing string 'repo'")
    # Path-confinement: the resolved repo MUST stay under fixtures_dir — a `../` repo
    # value can't escape to evaluate an arbitrary tree (the Batch-D is_relative_to fix).
    base = fixtures_dir.resolve()
    repo = (base / repo_rel).resolve()
    if base != repo and base not in repo.parents:
        raise BuildError(f"scenario {sid!r} repo {repo_rel!r} escapes the fixtures dir")
    if not repo.is_dir():
        raise BuildError(f"scenario {sid!r} fixture repo not found: {repo}")

    gates = evaluate(repo)
    # Determinism: total (id, scope) sort — no FS / dict-order leakage.
    gates.sort(key=lambda g: (g["id"], g["scope"]))
    hard_fail = sum(1 for g in gates if g["status"] == "hard-fail")
    hard_pass = sum(1 for g in gates if g["status"] == "pass")
    return {
        "id": sid,
        "gates": gates,
        "summary": {
            "hard_pass": hard_pass, "hard_fail": hard_fail,
            "soft_warn": 0, "overrides": 0,
            "exit_code": 1 if hard_fail else 0,
        },
        "error": None,
    }


def run_scenarios(scenarios: list, fixtures_dir: Path) -> dict:
    rows = []
    for i, sc in enumerate(scenarios):
        if not isinstance(sc, dict):
            raise BuildError(f"scenario[{i}] is not an object")
        rows.append(decide(sc, fixtures_dir))
    return {"schema_version": SCHEMA_VERSION, "command": COMMAND, "scenarios": rows}


def _load_scenarios(path: Path) -> list:
    if not path.exists():
        raise BuildError(f"fixture not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise BuildError(f"fixture is not valid JSON: {exc}") from exc
    scenarios = data.get("scenarios") if isinstance(data, dict) else data
    if not isinstance(scenarios, list):
        raise BuildError("fixture must be a list of scenarios or {'scenarios': [...]}")
    return scenarios


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(
        prog="build_audit_report.py",
        description="Deterministic /flow:audit Phase-B gate-report builder (BC-12946).",
    )
    ap.add_argument("--scenarios", help="fixture JSON (scenario list) — emit batch mode")
    ap.add_argument("--out-dir", help="write audit-report-emit.json into this dir (with --scenarios)")
    ap.add_argument("--fixtures-dir", default=str(DEFAULT_FIXTURES_DIR),
                    help=f"dir holding the named fixture repos (default: {DEFAULT_FIXTURES_DIR})")
    ap.add_argument("--repo-root", metavar="DIR",
                    help="single-repo mode: evaluate one repo_root, print its row to stdout")
    args = ap.parse_args(argv)

    try:
        if args.repo_root:
            repo = Path(args.repo_root)
            if not repo.is_dir():
                raise BuildError(f"--repo-root not a directory: {repo}")
            gates = evaluate(repo)
            gates.sort(key=lambda g: (g["id"], g["scope"]))
            hard_fail = sum(1 for g in gates if g["status"] == "hard-fail")
            row = {
                "id": repo.name, "gates": gates,
                "summary": {
                    "hard_pass": sum(1 for g in gates if g["status"] == "pass"),
                    "hard_fail": hard_fail, "soft_warn": 0, "overrides": 0,
                    "exit_code": 1 if hard_fail else 0,
                },
                "error": None,
            }
            print(json.dumps(row, ensure_ascii=False))
            return 0

        if args.scenarios:
            if not args.out_dir:
                sys.stderr.write("ERROR: --scenarios requires --out-dir\n")
                return 2
            fixtures_dir = Path(args.fixtures_dir)
            scenarios = _load_scenarios(Path(args.scenarios))
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            artifact = run_scenarios(scenarios, fixtures_dir)
            (out_dir / "audit-report-emit.json").write_text(
                json.dumps(artifact, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            return 0

        ap.error("one of --scenarios (with --out-dir) or --repo-root is required")
    except BuildError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
