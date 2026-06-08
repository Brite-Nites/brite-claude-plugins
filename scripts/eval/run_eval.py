#!/usr/bin/env python3
"""M2 — the behavioral-eval runner (BC-12589).

Generic, reusable runner that turns a `(command-id, fixture)` pair into a
pass/fail verdict on the command's produced artifacts (ADR-028 § 5). It owns the
*mechanics* — sandbox creation, running the command's emit mode, collecting the
named artifacts, delegating every check to the M3 assertion library, and gating
the exit code — and knows nothing command-specific itself. Each command plugs in
through a small **emit adapter** registered in `ADAPTERS`.

Per DP2-4 the per-PR eval has no `ANTHROPIC_API_KEY` and never runs `claude -p`:
the plan-campaign adapter invokes `build_manifest.py` (BC-12587) **directly** with
the fixture's values into a sandbox. (The `/marketing:plan-campaign --emit` LLM
entrypoint is the BC-12606 nightly-smoke + dogfood path, not this one.) The runner
strips `ANTHROPIC_API_KEY` from the build subprocess env to *prove* the eval path
is hermetic — if a builder ever reached for it, the eval would fail loudly.

Modes (CLI):
  run_eval.py <cmd> [<fixture>]                 build emit → assert → exit 0/1
  run_eval.py <cmd> [<fixture>] --sandbox DIR   build into DIR (not a mktemp)
  run_eval.py <cmd> [<fixture>] --artifact-dir DIR
                                                assert-only against pre-existing
                                                artifacts (skip build) — the hook
                                                the M2 self-test uses to feed a
                                                deliberately-mutated artifact
                                                (DP2-7). Exit 1 + named diffs.
  run_eval.py <cmd> [<fixture>] --update-golden regenerate the structural golden
                                                FROM emit output (DP2-6) and write
                                                it back — first-class so goldens
                                                are regenerated + PR-reviewed, never
                                                hand-edited into drift.

Exit codes: 0 = all assertions pass; 1 = one or more diffs; 2 = usage / build /
collection error (the emit step itself failed). Stdlib-only.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import assert_lib  # noqa: E402
from assert_lib import Result, combine  # noqa: E402

# scripts/eval/run_eval.py → repo root is two parents up.
REPO_ROOT = Path(__file__).resolve().parents[2]

# Env vars stripped from the build subprocess to keep the eval provably hermetic
# (DP2-4: no API key on the PR path). If a builder ever needed one, the eval fails.
HERMETIC_DENY = ("ANTHROPIC_API_KEY", "OPENAI_API_KEY")


class EvalError(Exception):
    """A build/collection failure (exit 2) — distinct from an assertion diff."""


# ── plan-campaign adapter ────────────────────────────────────────────────────
#
# The ONLY plan-campaign-specific code in the runner. A second command registers
# its own adapter the same way (build argv + collect + check + golden paths); the
# fixture and golden are plugin-local data files. If a 3rd consumer lands, promote
# this dict to a discovered plugin-local descriptor — do NOT build that machinery
# now (ADR-028's "build the thing you don't need yet" anti-pattern).


class PlanCampaignAdapter:
    """Emit adapter for /marketing:plan-campaign: drive build_manifest.py directly."""

    command_id = "plan-campaign"
    artifact_names = ("manifest.json", "issues.json", "brief.md")

    # Plugin-local data files (DP2-9: fixture + golden + schema are plugin-local).
    fixture_path = REPO_ROOT / "plugins/marketing/tests/eval/plan-campaign.fixture.json"
    golden_path = REPO_ROOT / "plugins/marketing/tests/eval/plan-campaign.golden.json"
    manifest_schema_path = (
        REPO_ROOT / "plugins/marketing/tests/eval/plan-campaign.manifest.schema.json"
    )
    issues_schema_path = (
        REPO_ROOT / "plugins/marketing/tests/eval/plan-campaign.issues.schema.json"
    )

    # Builder + its real canonical inputs.
    builder = REPO_ROOT / "plugins/marketing/scripts/build_manifest.py"
    canonicals_dir = REPO_ROOT / "plugins/marketing/data/canonicals"
    templates = REPO_ROOT / "plugins/marketing/references/campaign-sub-issue-templates.md"

    # Every sub-issue description carries these three contract lines (mirrors
    # test_build_manifest.sh run_a). Asserted by presence, never by prose — so a
    # verbatim copy edit to a description never flakes the eval (DP2-6).
    DESC_CONTRACT_LINES = (
        "**Handbook citation**:",
        "**Sub-issue role**:",
        "**Expected plugin command**:",
    )
    # The brief's 8 deterministic section headers (build_manifest INLINE template).
    BRIEF_SECTION_HEADERS = tuple(f"## {n}." for n in range(1, 9))
    # Any surviving template slot is a substitution bug (standard V/P/O fixture
    # fills every inline-template slot). HTML <!-- OPERATOR-FILL --> comments are
    # NOT {{tokens}}, so they legitimately remain.
    SLOT_TOKEN_RE = r"\{\{\s*\w+\s*\}\}"

    # ── build ───────────────────────────────────────────────────────────────

    def build_argv(self, fixture: dict, sandbox: Path) -> list[str]:
        """Map the fixture's emit-mode keys to a build_manifest.py command line.
        NO --brief-template (so the deterministic inline fallback brief is used)."""
        if not fixture.get("created_at"):
            raise EvalError(
                "fixture must pin 'created_at' (eval determinism depends on it; "
                "build_manifest defaults to now() otherwise)"
            )
        argv = [
            sys.executable,
            str(self.builder),
            "--entity", str(fixture["entity"]),
            "--month", str(fixture["month"]),
            "--year", str(fixture["year"]),
            "--launch-date", str(fixture["launch_date"]),
            "--eb-workspace", str(fixture["eb_workspace"]),
            "--created-at", str(fixture["created_at"]),
            "--canonicals-dir", str(self.canonicals_dir),
            "--templates", str(self.templates),
            "--out-dir", str(sandbox),
        ]
        for key, flag in (("vertical", "--vertical"), ("persona", "--persona"),
                          ("offer", "--offer"), ("owner_email", "--owner-email")):
            if fixture.get(key):
                argv += [flag, str(fixture[key])]
        if fixture.get("theme") is not None:
            argv += ["--theme", str(fixture["theme"])]
        if fixture.get("disambiguator") is not None:
            argv += ["--disambiguator", str(fixture["disambiguator"])]
        if fixture.get("situation_mining"):
            argv.append("--situation-mining")
        if fixture.get("creative_angles"):
            argv.append("--creative-angles")
        return argv

    def build(self, fixture: dict, sandbox: Path) -> None:
        """Run the builder into `sandbox`. Raise EvalError (→ exit 2) if it fails —
        a failed emit is an infra error, distinct from an assertion diff."""
        sandbox.mkdir(parents=True, exist_ok=True)
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            self.build_argv(fixture, sandbox),
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_manifest.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    # ── collect ───────────────────────────────────────────────────────────────

    def collect(self, artifact_dir: Path) -> dict:
        """Load the three artifacts from `artifact_dir`. Malformed/missing files
        surface as an EvalError (exit 2), not a traceback."""
        out: dict = {}
        for name in self.artifact_names:
            p = artifact_dir / name
            if not p.exists():
                raise EvalError(f"expected artifact missing: {p}")
            if name.endswith(".json"):
                try:
                    out[name] = json.loads(p.read_text(encoding="utf-8"))
                except json.JSONDecodeError as exc:
                    raise EvalError(f"{name} is not valid JSON: {exc}") from exc
            else:
                out[name] = p.read_text(encoding="utf-8")
        return out

    # ── projection (golden = a STRUCTURAL projection, never the raw artifact) ──

    @staticmethod
    def project_issues(issues: dict) -> dict:
        """Reduce issues.json to the DETERMINISTIC structure the golden pins:
          container → {title, labels}
          each issue → {index, title, dueDate, labels, blockedBy, optional, labs_gated}
        Dropped (asserted elsewhere, or non-golden): every `description` body
        (prose → key-line check), container.description (prose). This is the
        explicit projection the originating-session review asked be made
        first-class; golden_compare (M3) compares its output to the golden file."""
        keep = ("index", "title", "dueDate", "labels", "blockedBy", "optional", "labs_gated")
        return {
            "container": {
                "title": issues["container"]["title"],
                "labels": issues["container"]["labels"],
            },
            "issues": [{k: it[k] for k in keep} for it in issues["issues"]],
        }

    # ── check (compose M3 primitives) ─────────────────────────────────────────

    def check(self, artifacts: dict, fixture: dict) -> Result:
        manifest = artifacts["manifest.json"]
        issues = artifacts["issues.json"]
        brief = artifacts["brief.md"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        manifest_schema = json.loads(self.manifest_schema_path.read_text(encoding="utf-8"))
        issues_schema = json.loads(self.issues_schema_path.read_text(encoding="utf-8"))

        # SHAPE FIRST. The schemas (with additionalProperties:false) guard the
        # full key SET + types of both JSON artifacts. Short-circuit on any schema
        # diff so the value-level checks below (which index raw keys) only ever run
        # on a structurally-valid artifact — a dropped/extra/retyped key surfaces
        # as a named schema diff, never a KeyError traceback.
        schema_diffs = combine(
            assert_lib.schema_validate(manifest, manifest_schema, artifact="manifest.json"),
            assert_lib.schema_validate(issues, issues_schema, artifact="issues.json"),
        )
        if not schema_diffs.ok:
            return schema_diffs

        slug = golden["container"]["title"]  # the golden pins the literal slug
        theme_expected = fixture.get("theme") if fixture.get("entity") == "cross-entity" else None

        # manifest.json — VALUES (every deterministic field, incl. the pinned
        # created_at + the constant Linear project + the must-stay-null IDs).
        manifest_checks = assert_lib.key_fields(manifest, {
            "schema_version": 1,
            "slug": slug,
            "entity": fixture["entity"],
            "vertical": fixture.get("vertical"),
            "persona": fixture.get("persona"),
            "offer": fixture.get("offer"),
            "theme": theme_expected,
            "year": fixture["year"],
            "month": fixture["month"],
            "created_at": fixture["created_at"],
            "email_bison.workspace": fixture["eb_workspace"],
            "linear.project": "Brite GTM",
            "linear.milestone_id": None,
            "linear.milestone_url": None,
            "salesforce.campaign_id": None,
            "email_bison.campaign_id": None,
            "email_bison.launched_at": None,
            "salesforce.campaign_name": slug,
            "email_bison.campaign_name": slug,
        }, artifact="manifest.json")

        # issues.json — STRUCTURE (golden) + container + per-issue contract lines.
        issue_line_diffs: list[str] = []
        for it in issues["issues"]:
            issue_line_diffs += assert_lib.contains(
                it["description"], self.DESC_CONTRACT_LINES,
                label=f"issues.json $.issues[index={it['index']}].description",
            )
        issues_checks = combine(
            assert_lib.golden_compare(self.project_issues(issues), golden, artifact="issues.json"),
            assert_lib.contains(
                issues["container"]["description"], [slug, "Campaign rollup"],
                label="issues.json $.container.description",
            ),
            issue_line_diffs,
        )

        # brief.md — STRUCTURE only (headers + filled slots + key values), never prose.
        brief_checks = combine(
            assert_lib.contains(brief, self.BRIEF_SECTION_HEADERS, label="brief.md (section header)"),
            assert_lib.no_match(brief, self.SLOT_TOKEN_RE, label="brief.md (leftover template slot)"),
            assert_lib.contains(brief, [slug, f"**Entity**: {fixture['entity']}"], label="brief.md"),
        )

        return combine(manifest_checks, issues_checks, brief_checks)

    # ── golden regeneration ───────────────────────────────────────────────────

    def update_golden(self, artifacts: dict) -> str:
        issues = artifacts["issues.json"]
        # Schema-first, same as check(): never project a structurally-broken
        # issues.json (project_issues indexes raw keys) — a malformed build must
        # surface as a clean EvalError, not a KeyError, in the --update-golden flow.
        issues_schema = json.loads(self.issues_schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(issues, issues_schema, artifact="issues.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — issues.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        projection = self.project_issues(issues)
        self.golden_path.write_text(
            json.dumps(projection, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


# ── create-sf-campaign adapter ────────────────────────────────────────────────
#
# The second registered command (BC-12701) — the SIDE-EFFECTING representative:
# its default run MUTATES external state (creates a Salesforce Campaign). Its
# emit-mode builder (`build_campaign_payload.py`) is the deterministic decision
# core the command delegates to (ADR-028 D2); the eval drives a SCENARIO MATRIX
# through it so the hermetic per-PR path exercises EVERY verdict branch —
# would_create + the load-bearing would_skip_duplicate (idempotency) + missing_owner
# + the input-shape guards — not just the happy path. The fixture injects the two
# live SOQL reads as `sf_state` (the plan-campaign inject-to-defeat-now() idiom).


class CreateSfCampaignAdapter:
    """Emit adapter for /revops:create-sf-campaign: drive build_campaign_payload.py."""

    command_id = "create-sf-campaign"
    artifact_names = ("campaign-emit.json",)

    fixture_path = REPO_ROOT / "plugins/revops/tests/eval/create-sf-campaign.fixture.json"
    golden_path = REPO_ROOT / "plugins/revops/tests/eval/create-sf-campaign.golden.json"
    schema_path = REPO_ROOT / "plugins/revops/tests/eval/create-sf-campaign.schema.json"

    builder = REPO_ROOT / "plugins/revops/scripts/build_campaign_payload.py"

    # The scenario `id`s the eval expects, in order — a FLOOR-style guard so a
    # fixture that silently drops a branch (e.g. the idempotency case) is caught
    # by check() with a named diff rather than passing on a thinned matrix.
    EXPECTED_SCENARIO_IDS = (
        "would_create", "duplicate_slug", "near_miss_not_duplicate", "missing_owner",
        "invalid_slug_format", "invalid_target_org", "invalid_owner_email",
        "missing_required_flag",
    )

    # ── build ───────────────────────────────────────────────────────────────

    def build(self, fixture: dict, sandbox: Path) -> None:
        """Run the batch builder over the fixture's scenarios into `sandbox`.

        The runner loads the fixture into a dict (so `run_eval.py <cmd> <alt>` works);
        we write it back to a sandbox file and hand it to the builder's `--scenarios`
        mode — the SAME code path (and the same pure `decide()`) the command calls at
        runtime. API keys are stripped to prove hermeticity (DP2-4)."""
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder),
             "--scenarios", str(fixture_file), "--out-dir", str(sandbox)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_campaign_payload.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    # ── collect ───────────────────────────────────────────────────────────────

    def collect(self, artifact_dir: Path) -> dict:
        out: dict = {}
        for name in self.artifact_names:
            p = artifact_dir / name
            if not p.exists():
                raise EvalError(f"expected artifact missing: {p}")
            try:
                out[name] = json.loads(p.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise EvalError(f"{name} is not valid JSON: {exc}") from exc
        return out

    # ── projection (golden = a structural projection) ─────────────────────────

    @staticmethod
    def project(emit: dict) -> dict:
        """The structure the golden pins: the full verdict matrix. Every field is
        deterministic (no prose, no real IDs — emit makes no write), so the
        projection is the artifact itself, ordered, with no field dropped. The
        explicit method keeps the golden regenerated by `--update-golden`, never
        hand-edited (DP2-6)."""
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    # ── check ─────────────────────────────────────────────────────────────────

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["campaign-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        # SHAPE FIRST — short-circuit so the value/invariant checks below only ever
        # index a structurally-valid matrix (a dropped key surfaces as a named schema
        # diff, never a KeyError). The schema also pins campaign_id: null on every row.
        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="campaign-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []

        # Branch coverage: the matrix must carry every expected scenario id (a
        # thinned fixture that drops the idempotency case is the failure this guards).
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"campaign-emit.json: expected scenario id '{sid}' is absent from the matrix")

        # Per-verdict structural invariants (refinement #4 — assert nullness +
        # payload-presence EXPLICITLY, named, beyond the golden's exact compare).
        for s in emit["scenarios"]:
            tag = f"campaign-emit.json $.scenarios[id={s['id']}]"
            if s["campaign_id"] is not None:
                diffs.append(f"{tag}.campaign_id: expected null (emit makes no SF write), got {s['campaign_id']!r}")
            v = s["verdict"]
            if v == "would_create":
                if not isinstance(s["payload"], dict):
                    diffs.append(f"{tag}: would_create must carry a payload object, got {s['payload']!r}")
                if s["output"] is not None:
                    diffs.append(f"{tag}: would_create output must be null (success envelope needs the post-write id), got {s['output']!r}")
            else:
                if s["payload"] is not None:
                    diffs.append(f"{tag}: {v} must have a null payload (no write), got {s['payload']!r}")
                if not isinstance(s["output"], dict) or "error" not in s["output"]:
                    diffs.append(f"{tag}: {v} must carry an output envelope with an 'error' key, got {s['output']!r}")

        # VALUES — the exact verdict/payload/output per scenario (golden compare).
        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="campaign-emit.json"
        )
        return combine(diffs, golden_diffs)

    # ── golden regeneration ───────────────────────────────────────────────────

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["campaign-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="campaign-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — campaign-emit.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


# ── canonicals command family adapter (new-offer / new-persona / new-vertical) ──
#
# The STRUCTURE-FIRST / LLM-judged representatives (BC-12702 new-offer + BC-12915
# new-persona/new-vertical). Each writes a GTM canonical where the operator/LLM CHOOSES
# the content, but the file has a defined ADR-016 schema. Their shared emit builder
# (build_canonical_emit.py) drives the SAME runtime entrypoint each command delegates to
# (canonicals_bootstrap.py `<subcommand>`, which OWNS every input guard) against a sandbox
# copy of a FROZEN seed, then runs lint_canonicals over the result. The eval asserts the
# artifact's deterministic STRUCTURE — the written canonical passes the full 19-check lint
# contract + the new entry's fields == inputs — and NOT the operator/LLM-chosen content
# (which entry, the handbook-draft prose). That is the ADR-028 D2 structure-first cascade.
#
# Generalized to ONE adapter (3 instances) at the Rule-of-Three point: the per-subcommand
# differences are pure data (subcommand, artifact name, entry-key, projected/passthrough
# fields, expected scenario ids). The `new-offer` instance produces a BYTE-IDENTICAL
# artifact to BC-12702's, so its merged golden is untouched.


class CanonicalEmitAdapter:
    """Generic emit adapter for the canonicals bootstrap command family."""

    builder = REPO_ROOT / "plugins/marketing/scripts/build_canonical_emit.py"
    # FROZEN fixture canonicals seeded into each scenario's sandbox, SHARED across the three
    # subcommands. Deliberately NOT the live plugins/marketing/data/canonicals/ (a divergence
    # from PlanCampaignAdapter, which reads the live dir): these commands WRITE, and their
    # guards need controlled pre-existing state — a live seed would drift the golden + risk
    # hermeticity.
    seed_dir = REPO_ROOT / "plugins/marketing/tests/eval/new-offer-seed"
    _eval_dir = REPO_ROOT / "plugins/marketing/tests/eval"

    def __init__(self, subcommand: str, command_id: str, artifact_name: str,
                 entry_key: str, passthrough_fields: tuple, expected_ids: tuple,
                 *, defaults: dict | None = None, data_stem: str | None = None):
        self.subcommand = subcommand
        self.command_id = command_id
        self.artifact_names = (artifact_name,)
        self.entry_key = entry_key
        # passthrough_fields = entry fields whose value is a DIRECT copy of the operator
        # input (asserted == input via key_fields). A transformed field (e.g. persona's
        # `titles`, a comma-string input → a parsed list) is excluded here and locked by
        # golden_compare instead, which compares the exact value.
        self.passthrough_fields = passthrough_fields
        self.expected_ids = expected_ids
        self.defaults = defaults or {}
        self.action = f"created_{subcommand}"
        stem = data_stem or command_id
        self.fixture_path = self._eval_dir / f"{stem}.fixture.json"
        self.golden_path = self._eval_dir / f"{stem}.golden.json"
        self.schema_path = self._eval_dir / f"{stem}.schema.json"

    # ── build ───────────────────────────────────────────────────────────────

    def build(self, fixture: dict, sandbox: Path) -> None:
        """Run the batch builder over the fixture's scenarios into `sandbox`.

        The runner loads the fixture into a dict; we write it back to a sandbox file and
        hand it to build_canonical_emit.py's `--scenarios` mode, which copies the frozen
        seed into a per-scenario sub-sandbox and shells the SAME canonicals_bootstrap.py +
        lint_canonicals.py the command runs. API keys are stripped to prove hermeticity
        (DP2-4) — build_canonical_emit strips them again for its own children."""
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder), "--subcommand", self.subcommand,
             "--scenarios", str(fixture_file), "--out-dir", str(sandbox),
             "--seed-dir", str(self.seed_dir)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_canonical_emit.py {self.subcommand} exit "
                f"{proc.returncode}):\n{proc.stderr.strip()}"
            )

    # ── collect ───────────────────────────────────────────────────────────────

    def collect(self, artifact_dir: Path) -> dict:
        name = self.artifact_names[0]
        p = artifact_dir / name
        if not p.exists():
            raise EvalError(f"expected artifact missing: {p}")
        try:
            return {name: json.loads(p.read_text(encoding="utf-8"))}
        except json.JSONDecodeError as exc:
            raise EvalError(f"{name} is not valid JSON: {exc}") from exc

    # ── projection (golden = a structural projection) ─────────────────────────

    @staticmethod
    def project(emit: dict) -> dict:
        """The structure the golden pins: the full matrix. Every field is deterministic
        (the new entry's projected fields, the per-guard error string, the baked lint exit
        code) — no prose, no sandbox path — so the projection is the artifact itself,
        ordered, with no field dropped. (yaml_path + handbook_draft are already dropped
        upstream by build_canonical_emit, the structure-first seam.)"""
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    # ── check ─────────────────────────────────────────────────────────────────

    def check(self, artifacts: dict, fixture: dict) -> Result:
        name = self.artifact_names[0]
        emit = artifacts[name]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        # SHAPE FIRST — short-circuit so the value/invariant checks below only ever index
        # a structurally-valid matrix (a dropped/retyped key surfaces as a named schema
        # diff, never a KeyError).
        schema_diffs = combine(assert_lib.schema_validate(emit, schema, artifact=name))
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []

        # Branch coverage: every expected scenario id must be present (a thinned fixture
        # that drops the uniqueness/enum case is the failure this guards).
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.expected_ids:
            if sid not in got_ids:
                diffs.append(f"{name}: expected scenario id '{sid}' is absent from the matrix")

        fixture_by_id = {sc["id"]: sc for sc in fixture.get("scenarios", []) if isinstance(sc, dict)}

        # Per-verdict structural invariants (explicit + named, beyond the golden compare).
        for s in emit["scenarios"]:
            tag = f"{name} $.scenarios[id={s['id']}]"
            entry = s.get(self.entry_key)
            if s["ok"]:
                # A clean write: the new entry exists, no error, and the FULL
                # lint_canonicals contract held over the written canonical (exit 0).
                if s["action"] != self.action:
                    diffs.append(f"{tag}: ok row must have action '{self.action}', got {s['action']!r}")
                if not isinstance(entry, dict):
                    diffs.append(f"{tag}: ok row must carry a {self.entry_key} object, got {entry!r}")
                if s["error"] is not None:
                    diffs.append(f"{tag}: ok row error must be null, got {s['error']!r}")
                if not isinstance(s["lint"], dict) or s["lint"].get("exit_code") != 0:
                    diffs.append(f"{tag}: ok row must carry lint.exit_code 0 (the written canonical passes lint_canonicals), got {s['lint']!r}")
                # Passthrough: the new entry's directly-copied fields == the inputs the
                # operator supplied (the strongest structure-first assertion — proves no
                # field is mangled). A per-subcommand default fills an omitted optional
                # (e.g. offer status → 'draft'). Transformed fields are golden-locked.
                exp = fixture_by_id.get(s["id"], {})
                if exp and isinstance(entry, dict):
                    diffs += assert_lib.key_fields(
                        entry,
                        {f: exp.get(f, self.defaults.get(f)) for f in self.passthrough_fields},
                        artifact=f"{tag}.{self.entry_key}",
                    )
            else:
                # A rejection: no write, no structural claim, a builder-owned error string.
                if s["action"] is not None:
                    diffs.append(f"{tag}: rejection row action must be null, got {s['action']!r}")
                if entry is not None:
                    diffs.append(f"{tag}: rejection row must have a null {self.entry_key} (no write), got {entry!r}")
                if s["lint"] is not None:
                    diffs.append(f"{tag}: rejection row lint must be null (nothing was written to lint), got {s['lint']!r}")
                if not isinstance(s["error"], str) or not s["error"]:
                    diffs.append(f"{tag}: rejection row must carry a non-empty builder error string, got {s['error']!r}")

        # VALUES — the exact matrix (per-scenario verdict + new entry + error string + lint
        # code) via golden compare.
        golden_diffs = assert_lib.golden_compare(self.project(emit), golden, artifact=name)
        return combine(diffs, golden_diffs)

    # ── golden regeneration ───────────────────────────────────────────────────

    def update_golden(self, artifacts: dict) -> str:
        name = self.artifact_names[0]
        emit = artifacts[name]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact=name)
        if diffs:
            raise EvalError(
                f"cannot regenerate golden — {name} failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


# One instance per canonicals subcommand. new-offer's params reproduce BC-12702's adapter
# exactly (entry_key appended_offer, artifact offer-emit.json) → byte-identical artifact.
_NEW_OFFER = CanonicalEmitAdapter(
    "offer", "new-offer", "offer-emit.json", "appended_offer",
    passthrough_fields=("slug", "display", "status", "posture"),
    expected_ids=("valid_add", "near_miss_not_duplicate", "duplicate_slug",
                  "unknown_vertical", "invalid_posture", "invalid_status", "invalid_slug"),
    defaults={"status": "draft"},
)
_NEW_PERSONA = CanonicalEmitAdapter(
    "persona", "new-persona", "persona-emit.json", "appended_persona",
    # titles (comma-string input → parsed list) is transformed, so it's golden-locked, not
    # a key_fields passthrough.
    passthrough_fields=("slug", "display"),
    expected_ids=("valid_add", "near_miss_not_duplicate", "duplicate_slug",
                  "unknown_vertical", "invalid_slug"),
)
_NEW_VERTICAL = CanonicalEmitAdapter(
    "vertical", "new-vertical", "vertical-emit.json", "appended_vertical",
    # aliases/playbook_path are not echoed in the bootstrap result envelope, so the entry
    # projects slug/display only; alias validity is covered by lint + the invalid_alias row.
    passthrough_fields=("slug", "display"),
    expected_ids=("valid_add", "near_miss_not_duplicate", "duplicate_slug",
                  "invalid_slug", "invalid_alias"),
)


ADAPTERS = {
    PlanCampaignAdapter.command_id: PlanCampaignAdapter(),
    CreateSfCampaignAdapter.command_id: CreateSfCampaignAdapter(),
    _NEW_OFFER.command_id: _NEW_OFFER,
    _NEW_PERSONA.command_id: _NEW_PERSONA,
    _NEW_VERTICAL.command_id: _NEW_VERTICAL,
}


# ── runner mechanics ─────────────────────────────────────────────────────────


def _load_fixture(adapter, fixture_arg: str | None) -> dict:
    path = Path(fixture_arg) if fixture_arg else adapter.fixture_path
    if not path.exists():
        raise EvalError(f"fixture not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _report(command_id: str, result: Result) -> int:
    if result.ok:
        print(f"PASS: {command_id} eval — all assertions passed")
        return 0
    print(f"FAIL: {command_id} eval — {len(result.diffs)} diff(s):")
    for d in result.diffs:
        print(f"  - {d}")
    return 1


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="run_eval.py", description="Behavioral-eval runner (BC-12589).")
    p.add_argument("command_id", help=f"one of: {', '.join(sorted(ADAPTERS))}")
    p.add_argument("fixture", nargs="?", default=None,
                   help="fixture JSON (defaults to the adapter's registered fixture)")
    p.add_argument("--sandbox", default=None, help="build into this dir instead of a mktemp")
    p.add_argument("--artifact-dir", default=None, dest="artifact_dir",
                   help="assert-only against pre-existing artifacts (skip build)")
    p.add_argument("--update-golden", action="store_true", dest="update_golden",
                   help="regenerate the structural golden from emit output and write it back")
    p.add_argument("--keep-sandbox", action="store_true", dest="keep_sandbox",
                   help="do not delete a mktemp sandbox (debugging)")
    return p.parse_args(argv)


def main(argv: list[str]) -> int:
    a = parse_args(argv)
    adapter = ADAPTERS.get(a.command_id)
    if adapter is None:
        sys.stderr.write(f"ERROR: unknown command-id '{a.command_id}'. "
                         f"Registered: {', '.join(sorted(ADAPTERS))}\n")
        return 2

    try:
        fixture = _load_fixture(adapter, a.fixture)

        # Assert-only: check pre-existing artifacts (the self-test's mutation hook).
        if a.artifact_dir:
            artifacts = adapter.collect(Path(a.artifact_dir))
            return _report(a.command_id, adapter.check(artifacts, fixture))

        # Build path: into --sandbox or a mktemp we clean up.
        sandbox = Path(a.sandbox) if a.sandbox else Path(tempfile.mkdtemp(prefix="eval-"))
        try:
            adapter.build(fixture, sandbox)
            artifacts = adapter.collect(sandbox)
            if a.update_golden:
                written = adapter.update_golden(artifacts)
                print(f"golden updated: {written}")
                return 0
            return _report(a.command_id, adapter.check(artifacts, fixture))
        finally:
            if not a.sandbox and not a.keep_sandbox and sandbox.exists():
                shutil.rmtree(sandbox, ignore_errors=True)
    except EvalError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
