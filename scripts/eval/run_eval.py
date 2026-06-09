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


# ── update-sf-campaign-status adapter ─────────────────────────────────────────
#
# The σ3 SIBLING of create-sf-campaign (BC-12942, ADR-028 Phase-2 Batch A) — also
# side-effecting (its default run MUTATES external state: `sf data update record`
# on a Salesforce Campaign). Its emit-mode builder (`build_status_update_payload.py`)
# is the deterministic decision core the command delegates to (ADR-028 D2); the eval
# drives a SCENARIO MATRIX through it so the hermetic per-PR path exercises EVERY
# verdict branch — would_update (incl. the load-bearing (active,paused)→(active,null)
# overlay-clear) + the behaviorally-load-bearing would_noop (idempotency, null≡empty
# Substatus__c) + dry_run + the two precedence edges (dry_run>noop; not_found>dry_run)
# + campaign_not_found + the input-shape guards — not just the happy path. The fixture
# injects the ONE live SOQL read as `sf_state.campaign` (NO owner lookup — the
# cheaper-than-create delta). Mirrors CreateSfCampaignAdapter; the per-verdict
# invariants differ (campaign_id is a PRE-write read, present for existing-campaign
# rows; the post-write-null invariants are would_update.output==null +
# would_noop.output.campaign_url==null).


class UpdateSfCampaignStatusAdapter:
    """Emit adapter for /revops:update-sf-campaign-status: drive build_status_update_payload.py."""

    command_id = "update-sf-campaign-status"
    artifact_names = ("status-update-emit.json",)

    fixture_path = REPO_ROOT / "plugins/revops/tests/eval/update-sf-campaign-status.fixture.json"
    golden_path = REPO_ROOT / "plugins/revops/tests/eval/update-sf-campaign-status.golden.json"
    schema_path = REPO_ROOT / "plugins/revops/tests/eval/update-sf-campaign-status.schema.json"

    builder = REPO_ROOT / "plugins/revops/scripts/build_status_update_payload.py"

    # The scenario `id`s the eval expects, in order — a FLOOR-style guard so a fixture
    # that silently drops a branch (e.g. the overlay-clear or a precedence edge) is
    # caught by check() with a named diff rather than passing on a thinned matrix.
    EXPECTED_SCENARIO_IDS = (
        "would_update", "would_update_clears_overlay", "would_noop",
        "would_noop_empty_substatus", "dry_run", "dry_run_wins_over_noop",
        "dry_run_against_missing", "campaign_not_found", "invalid_slug_format",
        "invalid_linear_status", "invalid_linear_substatus", "invalid_target_org",
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
                f"emit failed (build_status_update_payload.py exit {proc.returncode}):\n"
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
        deterministic (no prose, no POST-write IDs — emit makes no write; campaign_id
        is the injected pre-write read), so the projection is the artifact itself,
        ordered, with no field dropped. The explicit method keeps the golden
        regenerated by `--update-golden`, never hand-edited (DP2-6)."""
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    # ── check ─────────────────────────────────────────────────────────────────

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["status-update-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        # SHAPE FIRST — short-circuit so the value/invariant checks below only ever
        # index a structurally-valid matrix (a dropped key surfaces as a named schema
        # diff, never a KeyError).
        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="status-update-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []

        # Branch coverage: the matrix must carry every expected scenario id (a thinned
        # fixture that drops the overlay-clear or a precedence edge is the failure this
        # guards).
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"status-update-emit.json: expected scenario id '{sid}' is absent from the matrix")

        # Per-verdict structural invariants (refinement #4 — assert the no-write +
        # post-write-null invariants EXPLICITLY, named, beyond the golden's exact compare).
        for s in emit["scenarios"]:
            tag = f"status-update-emit.json $.scenarios[id={s['id']}]"
            v = s["verdict"]
            if v == "would_update":
                # The Phase-6 UPDATE: a payload to send + the pre-write record-id; the
                # success envelope is IO-assembled post-write, so output stays null.
                if not isinstance(s["payload"], dict):
                    diffs.append(f"{tag}: would_update must carry a payload object, got {s['payload']!r}")
                if s["campaign_id"] is None:
                    diffs.append(f"{tag}: would_update must carry the injected pre-write campaign_id, got null")
                if s["output"] is not None:
                    diffs.append(f"{tag}: would_update output must be null (the success envelope needs the post-write LastModifiedDate + URL), got {s['output']!r}")
            elif v == "would_noop":
                # No write (payload null), but the success envelope IS emitted directly
                # — decide() owns all of it EXCEPT the Phase-7 campaign_url (pinned null,
                # the out-of-scope invariant). The pre-write record-id is present.
                if s["payload"] is not None:
                    diffs.append(f"{tag}: would_noop must have a null payload (no write), got {s['payload']!r}")
                if s["campaign_id"] is None:
                    diffs.append(f"{tag}: would_noop must carry the injected pre-write campaign_id, got null")
                if not isinstance(s["output"], dict):
                    diffs.append(f"{tag}: would_noop must carry a success-envelope output object, got {s['output']!r}")
                elif s["output"].get("campaign_url") is not None:
                    diffs.append(f"{tag}: would_noop output.campaign_url must be null (Phase-7 URL is out of the emit scope), got {s['output']['campaign_url']!r}")
            elif v == "dry_run":
                # The preview: a payload + the pre-write record-id + the preview envelope
                # the command emits verbatim (NO write — dry_run never mutates).
                if not isinstance(s["payload"], dict):
                    diffs.append(f"{tag}: dry_run must carry a payload object, got {s['payload']!r}")
                if s["campaign_id"] is None:
                    diffs.append(f"{tag}: dry_run must carry the injected pre-write campaign_id, got null")
                if not isinstance(s["output"], dict) or s["output"].get("dry_run") is not True:
                    diffs.append(f"{tag}: dry_run must carry a preview output with dry_run:true, got {s['output']!r}")
            elif v == "campaign_not_found":
                # 0 rows — no campaign, no payload, a WARNING envelope.
                if s["payload"] is not None:
                    diffs.append(f"{tag}: campaign_not_found must have a null payload, got {s['payload']!r}")
                if s["campaign_id"] is not None:
                    diffs.append(f"{tag}: campaign_not_found campaign_id must be null (no row), got {s['campaign_id']!r}")
                if not isinstance(s["output"], dict) or "warning" not in s["output"]:
                    diffs.append(f"{tag}: campaign_not_found must carry an output with a 'warning' key, got {s['output']!r}")
            else:  # error
                if s["payload"] is not None:
                    diffs.append(f"{tag}: {v} must have a null payload (no write), got {s['payload']!r}")
                if s["campaign_id"] is not None:
                    diffs.append(f"{tag}: {v} campaign_id must be null (no row read), got {s['campaign_id']!r}")
                if not isinstance(s["output"], dict) or "error" not in s["output"]:
                    diffs.append(f"{tag}: {v} must carry an output envelope with an 'error' key, got {s['output']!r}")

        # VALUES — the exact verdict/payload/campaign_id/output per scenario (golden compare).
        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="status-update-emit.json"
        )
        return combine(diffs, golden_diffs)

    # ── golden regeneration ───────────────────────────────────────────────────

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["status-update-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="status-update-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — status-update-emit.json failed schema validation:\n  - "
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


# ── offer-performance adapter (BC-12943 — structure-first report-builder) ──────
#
# /marketing:offer-performance writes a per-offer-version performance.md report. Its
# emit builder (build_offer_perf_emit.py) drives the SAME runtime entrypoint the
# command shells (offer_performance.py) over a sandbox copy of a FROZEN campaigns +
# canonicals seed, with EB/SF stats INJECTED per scenario (the --eb-json/--sf-json
# seam the command's Phase-3/4 reads write to) and --generated-at pinned (the lone
# clock call defeated). The eval asserts the WRITTEN report's deterministic STRUCTURE
# — frontmatter, the ordered section headers, the degraded banners, the retirement
# signal, and the fully-parsed per-version metrics table (every injected stat rendered
# through the builder's formatters) — NOT prose (ADR-028 D2 structure-first).


class OfferPerformanceAdapter:
    """Emit adapter for /marketing:offer-performance (structure-first report)."""

    command_id = "offer-performance"
    artifact_names = ("offer-perf-emit.json",)
    builder = REPO_ROOT / "plugins/marketing/scripts/build_offer_perf_emit.py"
    seed_dir = REPO_ROOT / "plugins/marketing/tests/eval/offer-performance-seed"
    _eval_dir = REPO_ROOT / "plugins/marketing/tests/eval"
    fixture_path = _eval_dir / "offer-performance.fixture.json"
    golden_path = _eval_dir / "offer-performance.golden.json"
    schema_path = _eval_dir / "offer-performance.schema.json"

    # Mirrors build_offer_perf_emit.GENERATED_AT — locking it in every OK row proves
    # --generated-at is honored (the determinism control that defeats datetime.now()).
    GENERATED_AT = "2026-05-26T12:00:00Z"
    SECTION_1 = "1. Per-version metrics"
    SECTION_CROSS = "2. Cross-version comparison"
    EXPECTED_SCENARIO_IDS = (
        "multi_version_ok", "single_version_ok", "eb_degraded",
        "sf_degraded", "retirement_candidate", "invalid_slug",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder), "--scenarios", str(fixture_file),
             "--out-dir", str(sandbox), "--seed-dir", str(self.seed_dir)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_offer_perf_emit.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    def collect(self, artifact_dir: Path) -> dict:
        name = self.artifact_names[0]
        p = artifact_dir / name
        if not p.exists():
            raise EvalError(f"expected artifact missing: {p}")
        try:
            return {name: json.loads(p.read_text(encoding="utf-8"))}
        except json.JSONDecodeError as exc:
            raise EvalError(f"{name} is not valid JSON: {exc}") from exc

    @staticmethod
    def project(emit: dict) -> dict:
        """The structure the golden pins: the full matrix (every field deterministic —
        the parsed frontmatter, ordered section headers, banner bools, retirement bool,
        and the rendered metrics table; no prose, no sandbox path)."""
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        name = self.artifact_names[0]
        emit = artifacts[name]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        # SHAPE FIRST — short-circuit so value/invariant checks index a valid matrix.
        schema_diffs = combine(assert_lib.schema_validate(emit, schema, artifact=name))
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []

        # Branch coverage: a thinned fixture that drops a load-bearing branch is caught.
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"{name}: expected scenario id '{sid}' is absent from the matrix")

        fixture_by_id = {sc["id"]: sc for sc in fixture.get("scenarios", []) if isinstance(sc, dict)}

        # Per-verdict structural invariants (explicit + named, beyond the golden compare).
        for s in emit["scenarios"]:
            tag = f"{name} $.scenarios[id={s['id']}]"
            if s["ok"]:
                if not isinstance(s["frontmatter"], dict):
                    diffs.append(f"{tag}: ok row must carry a frontmatter object, got {s['frontmatter']!r}")
                    continue
                if not isinstance(s["sections"], list) or not s["sections"]:
                    diffs.append(f"{tag}: ok row must carry a non-empty sections list, got {s['sections']!r}")
                if not isinstance(s["versions"], list):
                    diffs.append(f"{tag}: ok row must carry a versions list, got {s['versions']!r}")
                if s["error"] is not None:
                    diffs.append(f"{tag}: ok row error must be null, got {s['error']!r}")
                fm = s["frontmatter"]
                # Determinism: the pinned --generated-at is honored (clock call defeated).
                if fm.get("generated_at") != self.GENERATED_AT:
                    diffs.append(f"{tag}: frontmatter.generated_at must be the pinned {self.GENERATED_AT!r}, got {fm.get('generated_at')!r}")
                sections = s["sections"] if isinstance(s["sections"], list) else []
                if not sections or sections[0] != self.SECTION_1:
                    diffs.append(f"{tag}: sections[0] must be {self.SECTION_1!r}, got {(sections or [None])[0]!r}")
                # The single-vs-multi branch: the metrics table has one row per analyzed
                # version, and the Cross-version comparison renders IFF >= 2 versions.
                n = fm.get("versions_analyzed")
                versions = s["versions"] if isinstance(s["versions"], list) else []
                if isinstance(n, int) and len(versions) != n:
                    diffs.append(f"{tag}: versions_analyzed ({n}) != rendered table rows ({len(versions)})")
                cross = self.SECTION_CROSS in sections
                if isinstance(n, int):
                    if n >= 2 and not cross:
                        diffs.append(f"{tag}: {n} versions but the Cross-version comparison section is absent")
                    if n < 2 and cross:
                        diffs.append(f"{tag}: single version but a Cross-version comparison section is present")
                # Passthrough: the report is for the offer/entity the scenario named.
                exp = fixture_by_id.get(s["id"], {})
                if exp:
                    diffs += assert_lib.key_fields(
                        fm,
                        {"offer_slug": exp.get("offer_slug"), "entity": exp.get("entity")},
                        artifact=f"{tag}.frontmatter",
                    )
            else:
                # A rejection (invalid offer slug → the canonicals guard): no report.
                for field in ("frontmatter", "sections", "banners", "retirement_signal", "versions"):
                    if s[field] is not None:
                        diffs.append(f"{tag}: rejection row must have null {field} (no report written), got {s[field]!r}")
                if not isinstance(s["error"], str) or not s["error"]:
                    diffs.append(f"{tag}: rejection row must carry a non-empty builder error string, got {s['error']!r}")

        # VALUES — the exact matrix (frontmatter + sections + banners + retirement +
        # rendered metrics table per scenario) via golden compare.
        golden_diffs = assert_lib.golden_compare(self.project(emit), golden, artifact=name)
        return combine(diffs, golden_diffs)

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


# ── portfolio-snapshot adapter (BC-12943 — structure-first report-builder) ─────
#
# /marketing:portfolio-snapshot writes a monthly/quarterly review packet. Its emit
# builder (build_portfolio_emit.py) drives the SAME runtime entrypoint the command
# shells (portfolio_snapshot.py) over a sandbox copy of a FROZEN campaigns+canonicals
# seed with --generated-at pinned. The eval asserts the WRITTEN packet's deterministic
# STRUCTURE — frontmatter (window + sources), the window label, the ordered section
# headers (the monthly-5-vs-quarterly-9 branch), the degraded banners, the verdict
# distribution, and the in-window campaign count — and the anti-creep --out guard
# rejection (a load-bearing security branch) — NOT prose (ADR-028 D2 structure-first).


class PortfolioSnapshotAdapter:
    """Emit adapter for /marketing:portfolio-snapshot (structure-first report)."""

    command_id = "portfolio-snapshot"
    artifact_names = ("portfolio-emit.json",)
    builder = REPO_ROOT / "plugins/marketing/scripts/build_portfolio_emit.py"
    seed_dir = REPO_ROOT / "plugins/marketing/tests/eval/portfolio-snapshot-seed"
    _eval_dir = REPO_ROOT / "plugins/marketing/tests/eval"
    fixture_path = _eval_dir / "portfolio-snapshot.fixture.json"
    golden_path = _eval_dir / "portfolio-snapshot.golden.json"
    schema_path = _eval_dir / "portfolio-snapshot.schema.json"

    GENERATED_AT = "2026-05-26T15:00:00Z"  # mirrors build_portfolio_emit.GENERATED_AT
    SECTION_1 = "1. Portfolio shape"
    SECTION_QUARTERLY = "6. Cross-quarter MSPA transitions"
    MONTHLY_SECTIONS = 5
    QUARTERLY_SECTIONS = 9
    EXPECTED_SCENARIO_IDS = (
        "monthly_ok", "quarterly_ok", "sf_degraded_auth",
        "linear_degraded", "out_of_window_excluded", "out_anticreep_rejected",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder), "--scenarios", str(fixture_file),
             "--out-dir", str(sandbox), "--seed-dir", str(self.seed_dir)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_portfolio_emit.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    def collect(self, artifact_dir: Path) -> dict:
        name = self.artifact_names[0]
        p = artifact_dir / name
        if not p.exists():
            raise EvalError(f"expected artifact missing: {p}")
        try:
            return {name: json.loads(p.read_text(encoding="utf-8"))}
        except json.JSONDecodeError as exc:
            raise EvalError(f"{name} is not valid JSON: {exc}") from exc

    @staticmethod
    def project(emit: dict) -> dict:
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        name = self.artifact_names[0]
        emit = artifacts[name]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(assert_lib.schema_validate(emit, schema, artifact=name))
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"{name}: expected scenario id '{sid}' is absent from the matrix")

        fixture_by_id = {sc["id"]: sc for sc in fixture.get("scenarios", []) if isinstance(sc, dict)}

        for s in emit["scenarios"]:
            tag = f"{name} $.scenarios[id={s['id']}]"
            exp = fixture_by_id.get(s["id"], {})
            if s["ok"]:
                if not isinstance(s["frontmatter"], dict):
                    diffs.append(f"{tag}: ok row must carry a frontmatter object, got {s['frontmatter']!r}")
                    continue
                if not isinstance(s["sections"], list) or not s["sections"]:
                    diffs.append(f"{tag}: ok row must carry a non-empty sections list, got {s['sections']!r}")
                if not isinstance(s["banners"], dict):
                    diffs.append(f"{tag}: ok row must carry a banners object, got {s['banners']!r}")
                if not isinstance(s["campaigns_in_window"], int):
                    diffs.append(f"{tag}: ok row must carry an integer campaigns_in_window, got {s['campaigns_in_window']!r}")
                if s["error"] is not None:
                    diffs.append(f"{tag}: ok row error must be null, got {s['error']!r}")
                fm = s["frontmatter"]
                if fm.get("generated_at") != self.GENERATED_AT:
                    diffs.append(f"{tag}: frontmatter.generated_at must be the pinned {self.GENERATED_AT!r}, got {fm.get('generated_at')!r}")
                sections = s["sections"] if isinstance(s["sections"], list) else []
                if not sections or sections[0] != self.SECTION_1:
                    diffs.append(f"{tag}: sections[0] must be {self.SECTION_1!r}, got {(sections or [None])[0]!r}")
                # The monthly-vs-quarterly branch: quarterly adds sections 6-9.
                span = exp.get("span")
                quarterly_present = self.SECTION_QUARTERLY in sections
                if span == "monthly":
                    if len(sections) != self.MONTHLY_SECTIONS:
                        diffs.append(f"{tag}: monthly span must render {self.MONTHLY_SECTIONS} sections, got {len(sections)}")
                    if quarterly_present:
                        diffs.append(f"{tag}: monthly span must NOT carry the quarterly section {self.SECTION_QUARTERLY!r}")
                elif span == "quarterly":
                    if len(sections) != self.QUARTERLY_SECTIONS:
                        diffs.append(f"{tag}: quarterly span must render {self.QUARTERLY_SECTIONS} sections, got {len(sections)}")
                    if not quarterly_present:
                        diffs.append(f"{tag}: quarterly span must carry the quarterly section {self.SECTION_QUARTERLY!r}")
                # Passthrough: the packet echoes the window + the upstream-source statuses.
                if exp:
                    diffs += assert_lib.key_fields(
                        fm,
                        {
                            "window.span": exp.get("span"),
                            "window.start": exp.get("window_start"),
                            "window.end": exp.get("window_end"),
                            "sources.sf": exp.get("sf_status", "ok"),
                            "sources.linear": exp.get("linear_status", "ok"),
                        },
                        artifact=f"{tag}.frontmatter",
                    )
            else:
                for field in ("frontmatter", "title_label", "sections", "banners", "verdicts", "campaigns_in_window"):
                    if s[field] is not None:
                        diffs.append(f"{tag}: rejection row must have null {field} (no packet written), got {s[field]!r}")
                if not isinstance(s["error"], str) or not s["error"]:
                    diffs.append(f"{tag}: rejection row must carry a non-empty builder error string, got {s['error']!r}")

        golden_diffs = assert_lib.golden_compare(self.project(emit), golden, artifact=name)
        return combine(diffs, golden_diffs)

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


# ── import-campaign adapter (BC-12943 — structure-first manifest composer) ─────
#
# /marketing:import-campaign's `compose` step is a PURE stdin→stdout v2-manifest
# composer (no clock — created_at is an input). Its emit builder (build_import_emit.py)
# pipes each scenario's payload to the SAME `import_campaign.py compose` the command
# shells, against a FROZEN copy of the canonicals audience-tier taxonomy. The eval
# asserts the COMPOSED manifest's deterministic STRUCTURE — the 13-key top level,
# schema_version 2, the scaffolded_by literal, the input passthroughs, and the
# email_bison.campaigns[] records with their auto-classified audience_tier objects +
# the derived pending_classification flag — and NOT prose (ADR-028 D2 structure-first).


class ImportCampaignAdapter:
    """Emit adapter for /marketing:import-campaign (structure-first manifest composer)."""

    command_id = "import-campaign"
    artifact_names = ("import-campaign-emit.json",)
    builder = REPO_ROOT / "plugins/marketing/scripts/build_import_emit.py"
    seed_manifest = REPO_ROOT / "plugins/marketing/tests/eval/import-campaign-seed/_manifest.yaml"
    _eval_dir = REPO_ROOT / "plugins/marketing/tests/eval"
    fixture_path = _eval_dir / "import-campaign.fixture.json"
    golden_path = _eval_dir / "import-campaign.golden.json"
    schema_path = _eval_dir / "import-campaign.schema.json"

    # The v2 campaign_manifest top-level contract (data/canonicals/schema.json
    # #/definitions/campaign_manifest `required`). The canonical schema is
    # additionalProperties:true, so the 13-key set + the v1-anti-regression are
    # asserted here as NAMED invariants rather than via schema_validate.
    MANIFEST_KEYS = frozenset({
        "schema_version", "slug", "entity", "vertical", "persona", "offer",
        "year", "month", "linear", "salesforce", "email_bison", "created_at",
        "scaffolded_by",
    })
    SCAFFOLDED_BY = "/marketing:import-campaign"
    PASSTHROUGH = ("slug", "entity", "vertical", "persona", "offer", "year", "month")
    EXPECTED_SCENARIO_IDS = (
        "happy_empty_records", "single_launched_auto_classified",
        "multi_workspace_multi_tier", "pending_classification_set",
        "operator_tier_override", "reject_bad_slug",
        "reject_bad_eb_record_workspace", "reject_non_dict_eb_record",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder), "--scenarios", str(fixture_file),
             "--out-dir", str(sandbox), "--seed-manifest", str(self.seed_manifest)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_import_emit.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    def collect(self, artifact_dir: Path) -> dict:
        name = self.artifact_names[0]
        p = artifact_dir / name
        if not p.exists():
            raise EvalError(f"expected artifact missing: {p}")
        try:
            return {name: json.loads(p.read_text(encoding="utf-8"))}
        except json.JSONDecodeError as exc:
            raise EvalError(f"{name} is not valid JSON: {exc}") from exc

    @staticmethod
    def project(emit: dict) -> dict:
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        name = self.artifact_names[0]
        emit = artifacts[name]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(assert_lib.schema_validate(emit, schema, artifact=name))
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"{name}: expected scenario id '{sid}' is absent from the matrix")

        fixture_by_id = {sc["id"]: sc for sc in fixture.get("scenarios", []) if isinstance(sc, dict)}

        for s in emit["scenarios"]:
            tag = f"{name} $.scenarios[id={s['id']}]"
            if s["ok"]:
                m = s["manifest"]
                if not isinstance(m, dict):
                    diffs.append(f"{tag}: ok row must carry a manifest object, got {m!r}")
                    continue
                if s["error"] is not None:
                    diffs.append(f"{tag}: ok row error must be null, got {s['error']!r}")
                # v2 contract: exact 13-key top level + schema_version 2 + scaffolded_by.
                if set(m) != self.MANIFEST_KEYS:
                    extra = sorted(set(m) - self.MANIFEST_KEYS)
                    missing = sorted(self.MANIFEST_KEYS - set(m))
                    diffs.append(f"{tag}: manifest top-level keys != the v2 contract (extra={extra}, missing={missing})")
                if m.get("schema_version") != 2:
                    diffs.append(f"{tag}: manifest.schema_version must be 2, got {m.get('schema_version')!r}")
                if m.get("scaffolded_by") != self.SCAFFOLDED_BY:
                    diffs.append(f"{tag}: manifest.scaffolded_by must be {self.SCAFFOLDED_BY!r}, got {m.get('scaffolded_by')!r}")
                # v1 anti-regression: the singular email_bison.campaign_id must NOT return
                # (schema is additionalProperties:true, so only a named check catches it).
                eb = m.get("email_bison")
                if isinstance(eb, dict):
                    if "campaign_id" in eb:
                        diffs.append(f"{tag}: email_bison must NOT carry the v1 singular 'campaign_id' (v2 uses campaigns[])")
                    if "campaigns" not in eb:
                        diffs.append(f"{tag}: email_bison must carry the v2 'campaigns' array")
                else:
                    diffs.append(f"{tag}: manifest.email_bison must be an object, got {eb!r}")
                # Passthrough: the deterministic input fields are copied verbatim.
                exp = fixture_by_id.get(s["id"], {})
                payload = exp.get("payload", {}) if isinstance(exp, dict) else {}
                if payload:
                    diffs += assert_lib.key_fields(
                        m, {f: payload.get(f) for f in self.PASSTHROUGH},
                        artifact=f"{tag}.manifest",
                    )
            else:
                if s["manifest"] is not None:
                    diffs.append(f"{tag}: rejection row must have a null manifest (no compose), got {s['manifest']!r}")
                if not isinstance(s["error"], str) or not s["error"]:
                    diffs.append(f"{tag}: rejection row must carry a non-empty builder error string, got {s['error']!r}")

        golden_diffs = assert_lib.golden_compare(self.project(emit), golden, artifact=name)
        return combine(diffs, golden_diffs)

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


# ── icp-refinement-review adapter (BC-12943 — structure-first review loop) ─────
#
# /marketing:icp-refinement-review is a pure-disk review loop (scan → apply → emit-
# handbook). Its emit builder (build_icp_review_emit.py) drives the SAME runtime
# entrypoints the command shells over a sandbox copy of a FROZEN discoveries-tree seed,
# then runs the SAME lint_discoveries.py the command's Validation § runs over the
# MUTATED file. The eval asserts: the mutated discoveries.json STILL lints (lint_exit_code
# 0 — the structure-first anchor), the apply count summary, the per-signal promotion_status
# flips (incl. the defer-noop + one-way skip-terminal invariants), the scan filter count,
# and the emit-handbook promoted-blob set — NOT prose (ADR-028 D2 structure-first).


class IcpRefinementReviewAdapter:
    """Emit adapter for /marketing:icp-refinement-review (structure-first review loop)."""

    command_id = "icp-refinement-review"
    artifact_names = ("icp-review-emit.json",)
    builder = REPO_ROOT / "plugins/marketing/scripts/build_icp_review_emit.py"
    seed_dir = REPO_ROOT / "plugins/marketing/tests/eval/icp-refinement-review-seed"
    _eval_dir = REPO_ROOT / "plugins/marketing/tests/eval"
    fixture_path = _eval_dir / "icp-refinement-review.fixture.json"
    golden_path = _eval_dir / "icp-refinement-review.golden.json"
    schema_path = _eval_dir / "icp-refinement-review.schema.json"

    # The frozen seed has exactly two PENDING icp-refinement signals (hotels[0] +
    # installers[0]); the terminal-promoted [1] + the title-discovery [2] are filtered
    # out by scan. A constant across all rows → locks scan's category+pending filter.
    SCAN_TOTAL_PENDING = 2
    EXPECTED_SCENARIO_IDS = (
        "apply_promote", "apply_mixed", "apply_defer_noop",
        "apply_skip_terminal", "reject_bad_decision", "reject_out_of_range",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
        sandbox.mkdir(parents=True, exist_ok=True)
        fixture_file = sandbox / "_fixture.json"
        fixture_file.write_text(json.dumps(fixture), encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if k not in HERMETIC_DENY}
        proc = subprocess.run(
            [sys.executable, str(self.builder), "--scenarios", str(fixture_file),
             "--out-dir", str(sandbox), "--seed-dir", str(self.seed_dir)],
            capture_output=True, text=True, env=env,
        )
        if proc.returncode != 0:
            raise EvalError(
                f"emit failed (build_icp_review_emit.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

    def collect(self, artifact_dir: Path) -> dict:
        name = self.artifact_names[0]
        p = artifact_dir / name
        if not p.exists():
            raise EvalError(f"expected artifact missing: {p}")
        try:
            return {name: json.loads(p.read_text(encoding="utf-8"))}
        except json.JSONDecodeError as exc:
            raise EvalError(f"{name} is not valid JSON: {exc}") from exc

    @staticmethod
    def project(emit: dict) -> dict:
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        name = self.artifact_names[0]
        emit = artifacts[name]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(assert_lib.schema_validate(emit, schema, artifact=name))
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"{name}: expected scenario id '{sid}' is absent from the matrix")

        for s in emit["scenarios"]:
            tag = f"{name} $.scenarios[id={s['id']}]"
            # scan runs on EVERY row (before apply) → the filter count is invariant.
            if s["scan_total_pending"] != self.SCAN_TOTAL_PENDING:
                diffs.append(f"{tag}: scan_total_pending must be {self.SCAN_TOTAL_PENDING} (the seed's pending icp signals), got {s['scan_total_pending']!r}")
            if s["ok"]:
                if not isinstance(s["counts"], dict):
                    diffs.append(f"{tag}: ok row must carry a counts object, got {s['counts']!r}")
                if not isinstance(s["mutated_statuses"], dict):
                    diffs.append(f"{tag}: ok row must carry a mutated_statuses object, got {s['mutated_statuses']!r}")
                if not isinstance(s["emit_verticals"], list):
                    diffs.append(f"{tag}: ok row must carry an emit_verticals list, got {s['emit_verticals']!r}")
                if s["error"] is not None:
                    diffs.append(f"{tag}: ok row error must be null, got {s['error']!r}")
                # THE structure-first anchor: the MUTATED discoveries.json still lints.
                if s["lint_exit_code"] != 0:
                    diffs.append(f"{tag}: the mutated discoveries.json must still pass lint_discoveries (lint_exit_code 0), got {s['lint_exit_code']!r}")
            else:
                for field in ("counts", "mutated_statuses", "lint_exit_code", "emit_blob_count", "emit_verticals"):
                    if s[field] is not None:
                        diffs.append(f"{tag}: rejection row must have null {field} (no apply), got {s[field]!r}")
                if not isinstance(s["error"], str) or not s["error"]:
                    diffs.append(f"{tag}: rejection row must carry a non-empty builder error string, got {s['error']!r}")

        golden_diffs = assert_lib.golden_compare(self.project(emit), golden, artifact=name)
        return combine(diffs, golden_diffs)

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


# ── workflows intake adapters (BC-12944, ADR-028 Phase-2 Batch C) ─────────────
#
# The workflows plugin's FIRST behavioral evals. raise-a-ticket + report-issue are
# the S2 intake pair: their builders are NEW seam extractions (no prior build_*),
# pure decide(inputs, injected_state) cores delegating the conversational parts to
# the LLM. Each emit asserts the deterministic label/priority/team projection (+
# report-issue's registry-entry artifact) — NOT the title/body/classification/dup
# search (those are LLM-narrated / out of the deterministic scope). Both mirror the
# UpdateSfCampaignStatusAdapter shape: build → collect → project → check → golden.


class RaiseTicketAdapter:
    """Emit adapter for /workflows:raise-a-ticket: drive build_raise_ticket_payload.py."""

    command_id = "raise-a-ticket"
    artifact_names = ("raise-ticket-emit.json",)

    fixture_path = REPO_ROOT / "plugins/workflows/tests/eval/raise-a-ticket.fixture.json"
    golden_path = REPO_ROOT / "plugins/workflows/tests/eval/raise-a-ticket.golden.json"
    schema_path = REPO_ROOT / "plugins/workflows/tests/eval/raise-a-ticket.schema.json"

    builder = REPO_ROOT / "plugins/workflows/scripts/build_raise_ticket_payload.py"

    # The scenario ids the eval expects, in order — a FLOOR-style guard so a fixture
    # that silently drops a branch (a modal-team edge, the severity/triage fallback)
    # is caught by check() with a named diff rather than passing on a thinned matrix.
    EXPECTED_SCENARIO_IDS = (
        "bug_full_labels", "idea_no_severity", "bug_severity_not_provisioned",
        "needs_triage_absent", "multi_team_modal", "multi_team_tie",
        "multi_team_no_team_field", "bug_with_domain", "error_invalid_kind",
        "error_bug_missing_severity",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
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
                f"emit failed (build_raise_ticket_payload.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

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

    @staticmethod
    def project(emit: dict) -> dict:
        """Every field is deterministic (no prose, no live IDs — emit makes no
        write), so the projection is the artifact itself, ordered."""
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["raise-ticket-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="raise-ticket-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"raise-ticket-emit.json: expected scenario id '{sid}' is absent from the matrix")

        for s in emit["scenarios"]:
            tag = f"raise-ticket-emit.json $.scenarios[id={s['id']}]"
            if s["error"] is not None:
                # A reject row produces no payload projection.
                for k in ("type_label", "severity_label", "priority", "team", "team_tiebreak", "footer"):
                    if s[k] is not None:
                        diffs.append(f"{tag}: {k} must be null on an error row, got {s[k]!r}")
                if s["applied_labels"]:
                    diffs.append(f"{tag}: applied_labels must be empty on an error row, got {s['applied_labels']!r}")
                continue
            # Success row invariants.
            if s["team"] is None:
                diffs.append(f"{tag}: a filed ticket must resolve a team, got null")
            if s["footer"] is None:
                diffs.append(f"{tag}: a filed ticket must carry a provenance footer, got null")
            if s["kind"] == "idea":
                if s["severity_label"] is not None:
                    diffs.append(f"{tag}: an Idea/Feedback carries no severity_label, got {s['severity_label']!r}")
                if s["priority"] is not None:
                    diffs.append(f"{tag}: an Idea/Feedback carries no priority, got {s['priority']!r}")
            if s["severity_carried_by_priority"]:
                if s["severity_label"] not in s["missing_labels"]:
                    diffs.append(f"{tag}: severity_carried_by_priority is true but {s['severity_label']!r} is not in missing_labels")
                if s["severity_label"] in s["applied_labels"]:
                    diffs.append(f"{tag}: severity_carried_by_priority is true but {s['severity_label']!r} is in applied_labels")
            if s["triage_state_fallback"] == "Triage" and "needs-triage" not in s["missing_labels"]:
                diffs.append(f"{tag}: triage_state_fallback is set but needs-triage is not in missing_labels")

        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="raise-ticket-emit.json"
        )
        return combine(diffs, golden_diffs)

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["raise-ticket-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="raise-ticket-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — raise-ticket-emit.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


class ReportIssueAdapter:
    """Emit adapter for /workflows:report-issue: drive build_report_issue_payload.py."""

    command_id = "report-issue"
    artifact_names = ("report-issue-emit.json",)

    fixture_path = REPO_ROOT / "plugins/workflows/tests/eval/report-issue.fixture.json"
    golden_path = REPO_ROOT / "plugins/workflows/tests/eval/report-issue.golden.json"
    schema_path = REPO_ROOT / "plugins/workflows/tests/eval/report-issue.schema.json"

    builder = REPO_ROOT / "plugins/workflows/scripts/build_report_issue_payload.py"

    TRIGGER_CLASSES = ("wrong-skill", "skill-not-fired", "skill-over-fired")
    LINEAR_ONLY_CLASSES = ("hook-issue", "subagent-issue", "command-flow")
    RUBRIC_KEYS = ("clarity", "completeness", "actionability")

    EXPECTED_SCENARIO_IDS = (
        "wrong_skill", "skill_not_fired", "skill_over_fired", "bad_output_b11",
        "bad_output_noncontiguous", "hook_issue_linear_only", "command_flow_linear_only",
        "severity_provisioned", "needs_triage_absent", "error_invalid_classification",
        "error_missing_severity",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
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
                f"emit failed (build_report_issue_payload.py exit {proc.returncode}):\n"
                f"{proc.stderr.strip()}"
            )

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

    @staticmethod
    def project(emit: dict) -> dict:
        """The golden pins the full composite matrix, with ONE transform: a
        behavioral entry's `judge_rubric` (a dev-tuned, under-specified judgment —
        the command's "4/5 standard, 3/5 minimum" gives no severity→threshold rule)
        is projected to its sorted KEY SET as `judge_rubric_keys`, so the golden
        asserts the rubric is PRESENT + well-shaped without pinning the judgment
        VALUES. check() validates the values' keys + 1-5 range on the raw emit (the
        schema leaves the polymorphic registry `entry` an unconstrained object, so
        check() is the sole enforcer — not a schema backstop). ADR-028 D2: assert the
        shape the builder owns, not the LLM/dev judgment. Everything else is
        deterministic and pinned verbatim."""
        scenarios = []
        for s in emit["scenarios"]:
            row = json.loads(json.dumps(s))  # deep copy (stdlib, no `copy` import)
            reg = row.get("registry")
            if isinstance(reg, dict) and isinstance(reg.get("entry"), dict):
                entry = reg["entry"]
                jr = entry.get("judge_rubric")
                if isinstance(jr, dict):
                    entry.pop("judge_rubric")
                    entry["judge_rubric_keys"] = sorted(jr.keys())
            scenarios.append(row)
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": scenarios,
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["report-issue-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="report-issue-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"report-issue-emit.json: expected scenario id '{sid}' is absent from the matrix")

        for s in emit["scenarios"]:
            tag = f"report-issue-emit.json $.scenarios[id={s['id']}]"
            err, ip, reg, cls = s["error"], s["issue_payload"], s["registry"], s["classification"]

            if err is not None:
                if ip is not None:
                    diffs.append(f"{tag}: error row must have a null issue_payload, got {ip!r}")
                if reg is not None:
                    diffs.append(f"{tag}: error row must have a null registry, got {reg!r}")
                continue

            if not isinstance(ip, dict):
                diffs.append(f"{tag}: a successful row must carry an issue_payload object, got {ip!r}")
            else:
                if ip.get("severity_carried_by_priority"):
                    sev_missing = [l for l in ip.get("missing_labels", []) if l.startswith("severity:")]
                    if not sev_missing:
                        diffs.append(f"{tag}: severity_carried_by_priority is true but no severity:* label is in missing_labels")
                if ip.get("triage_state_fallback") == "Triage" and "needs-triage" not in ip.get("missing_labels", []):
                    diffs.append(f"{tag}: triage_state_fallback is set but needs-triage is not in missing_labels")

            if not isinstance(reg, dict):
                diffs.append(f"{tag}: a successful row must carry a registry object, got {reg!r}")
                continue
            target, entry = reg.get("target"), reg.get("entry")

            if cls in self.TRIGGER_CLASSES:
                if target != "trigger-registry.json":
                    diffs.append(f"{tag}: {cls} must route to trigger-registry.json, got {target!r}")
                if not isinstance(entry, dict):
                    diffs.append(f"{tag}: {cls} must carry a trigger-registry entry, got {entry!r}")
                else:
                    for k in ("phrase", "expected", "not_expected", "description"):
                        if k not in entry:
                            diffs.append(f"{tag}: trigger entry missing key '{k}'")
                    if cls == "skill-over-fired" and entry.get("expected") != []:
                        diffs.append(f"{tag}: skill-over-fired expected must be [], got {entry.get('expected')!r}")
            elif cls == "bad-output":
                if target != "behavioral-registry.json":
                    diffs.append(f"{tag}: bad-output must route to behavioral-registry.json, got {target!r}")
                if not isinstance(entry, dict):
                    diffs.append(f"{tag}: bad-output must carry a behavioral-registry entry, got {entry!r}")
                else:
                    rid = entry.get("id")
                    if not (isinstance(rid, str) and rid[:1] == "B" and rid[1:].isdigit()):
                        diffs.append(f"{tag}: behavioral id must match B##, got {rid!r}")
                    if entry.get("tier") != 2:
                        diffs.append(f"{tag}: behavioral entry tier must be 2, got {entry.get('tier')!r}")
                    # judge_rubric SHAPE only (Option 1): keys present + integer 1-5.
                    jr = entry.get("judge_rubric")
                    if not isinstance(jr, dict):
                        diffs.append(f"{tag}: behavioral entry judge_rubric must be an object, got {jr!r}")
                    else:
                        for rk in self.RUBRIC_KEYS:
                            v = jr.get(rk)
                            if rk not in jr:
                                diffs.append(f"{tag}: judge_rubric missing key '{rk}'")
                            elif not (isinstance(v, int) and not isinstance(v, bool) and 1 <= v <= 5):
                                diffs.append(f"{tag}: judge_rubric.{rk} must be an integer in 1-5, got {v!r}")
            else:  # Linear-only classifications
                if target is not None:
                    diffs.append(f"{tag}: {cls} must route Linear-only (target null), got {target!r}")
                if entry is not None:
                    diffs.append(f"{tag}: {cls} must have a null registry entry, got {entry!r}")

        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="report-issue-emit.json"
        )
        return combine(diffs, golden_diffs)

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["report-issue-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="report-issue-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — report-issue-emit.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


# ── workflows cycle-metrics adapters (BC-12944, ADR-028 Phase-2 Batch C) ──────
#
# retrospective + sprint-planning are the S3 pair: their builders share cycle_metrics.py
# (cycle_snapshot has 2 consumers; velocity is sprint-only). Each emit asserts the
# deterministic snapshot / velocity / backlog projection over INJECTED list_issues +
# list_cycles + as_of — NOT the LLM retro synthesis / suggestion rationale, nor the
# mutating save_status_update / save_issue (out of the deterministic scope).


class RetrospectiveAdapter:
    """Emit adapter for /workflows:retrospective: drive build_retro_snapshot.py."""

    command_id = "retrospective"
    artifact_names = ("retro-snapshot-emit.json",)

    fixture_path = REPO_ROOT / "plugins/workflows/tests/eval/retrospective.fixture.json"
    golden_path = REPO_ROOT / "plugins/workflows/tests/eval/retrospective.golden.json"
    schema_path = REPO_ROOT / "plugins/workflows/tests/eval/retrospective.schema.json"

    builder = REPO_ROOT / "plugins/workflows/scripts/build_retro_snapshot.py"

    EXPECTED_SCENARIO_IDS = (
        "onTrack_80_boundary", "atRisk_75", "atRisk_50_boundary",
        "offTrack_40_with_canceled", "empty_cycle", "error_no_cycle",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
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
                f"emit failed (build_retro_snapshot.py exit {proc.returncode}):\n{proc.stderr.strip()}"
            )

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

    @staticmethod
    def project(emit: dict) -> dict:
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["retro-snapshot-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="retro-snapshot-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"retro-snapshot-emit.json: expected scenario id '{sid}' is absent from the matrix")

        for s in emit["scenarios"]:
            tag = f"retro-snapshot-emit.json $.scenarios[id={s['id']}]"
            if s["error"] is not None:
                for k in ("cycle_number", "total", "completed", "carried_over", "canceled", "completion_rate", "health"):
                    if s[k] is not None:
                        diffs.append(f"{tag}: {k} must be null on an error row, got {s[k]!r}")
                continue
            # Partition invariant: every issue is delivered, carried, or canceled.
            if s["total"] != s["completed"] + s["carried_over"] + s["canceled"]:
                diffs.append(f"{tag}: total ({s['total']}) != completed+carried_over+canceled ({s['completed']}+{s['carried_over']}+{s['canceled']})")
            # Count↔id-list consistency.
            if s["completed"] != len(s["delivered_ids"]):
                diffs.append(f"{tag}: completed ({s['completed']}) != len(delivered_ids) ({len(s['delivered_ids'])})")
            if s["carried_over"] != len(s["carried_ids"]):
                diffs.append(f"{tag}: carried_over ({s['carried_over']}) != len(carried_ids) ({len(s['carried_ids'])})")
            if s["canceled"] != len(s["canceled_ids"]):
                diffs.append(f"{tag}: canceled ({s['canceled']}) != len(canceled_ids) ({len(s['canceled_ids'])})")
            # Health↔rate band consistency (binds the health() thresholds to the rate).
            rate, h = s["completion_rate"], s["health"]
            expected_health = "onTrack" if rate >= 80 else "atRisk" if rate >= 50 else "offTrack"
            if h != expected_health:
                diffs.append(f"{tag}: health '{h}' inconsistent with completion_rate {rate}% (expected '{expected_health}')")

        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="retro-snapshot-emit.json"
        )
        return combine(diffs, golden_diffs)

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["retro-snapshot-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="retro-snapshot-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — retro-snapshot-emit.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


class SprintPlanningAdapter:
    """Emit adapter for /workflows:sprint-planning: drive build_sprint_plan.py."""

    command_id = "sprint-planning"
    artifact_names = ("sprint-plan-emit.json",)

    fixture_path = REPO_ROOT / "plugins/workflows/tests/eval/sprint-planning.fixture.json"
    golden_path = REPO_ROOT / "plugins/workflows/tests/eval/sprint-planning.golden.json"
    schema_path = REPO_ROOT / "plugins/workflows/tests/eval/sprint-planning.schema.json"

    builder = REPO_ROOT / "plugins/workflows/scripts/build_sprint_plan.py"
    BACKLOG_CAP = 20

    EXPECTED_SCENARIO_IDS = (
        "plan_partial_velocity", "velocity_three_full", "prioritization_only",
        "large_backlog_truncated",
    )

    def build(self, fixture: dict, sandbox: Path) -> None:
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
                f"emit failed (build_sprint_plan.py exit {proc.returncode}):\n{proc.stderr.strip()}"
            )

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

    @staticmethod
    def project(emit: dict) -> dict:
        return {
            "schema_version": emit["schema_version"],
            "command": emit["command"],
            "scenarios": emit["scenarios"],
        }

    def check(self, artifacts: dict, fixture: dict) -> Result:
        emit = artifacts["sprint-plan-emit.json"]
        golden = json.loads(self.golden_path.read_text(encoding="utf-8"))
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))

        schema_diffs = combine(
            assert_lib.schema_validate(emit, schema, artifact="sprint-plan-emit.json")
        )
        if not schema_diffs.ok:
            return schema_diffs

        diffs: list[str] = []
        got_ids = [s["id"] for s in emit["scenarios"]]
        for sid in self.EXPECTED_SCENARIO_IDS:
            if sid not in got_ids:
                diffs.append(f"sprint-plan-emit.json: expected scenario id '{sid}' is absent from the matrix")

        for s in emit["scenarios"]:
            tag = f"sprint-plan-emit.json $.scenarios[id={s['id']}]"
            mode = s["mode"]
            if mode == "prioritization-only":
                if s["current_snapshot"] is not None:
                    diffs.append(f"{tag}: prioritization-only must have a null current_snapshot")
                if s["days_elapsed"] is not None:
                    diffs.append(f"{tag}: prioritization-only must have a null days_elapsed")
            elif mode == "plan":
                if not isinstance(s["current_snapshot"], dict):
                    diffs.append(f"{tag}: plan mode must carry a current_snapshot object, got {s['current_snapshot']!r}")
                if s["current_cycle_number"] is None:
                    diffs.append(f"{tag}: plan mode must carry a current_cycle_number")
            else:
                diffs.append(f"{tag}: unexpected mode {mode!r}")

            vel = s["velocity"]
            # contributing must equal the number of velocity rows (skips excluded).
            if vel["contributing"] != len(vel["rows"]):
                diffs.append(f"{tag}: velocity.contributing ({vel['contributing']}) != len(rows) ({len(vel['rows'])})")
            # The limited-data note is present IFF fewer than 3 cycles contributed
            # (binds the note rule — the non-vacuous twin of the 3-cycle row).
            note_present = vel["note"] is not None
            if note_present != (vel["contributing"] < 3):
                diffs.append(f"{tag}: velocity.note presence ({note_present}) inconsistent with contributing {vel['contributing']} (note iff <3)")

            bk = s["backlog"]
            if bk["shown"] != len(bk["ordered_ids"]):
                diffs.append(f"{tag}: backlog.shown ({bk['shown']}) != len(ordered_ids) ({len(bk['ordered_ids'])})")
            if bk["truncated"] != (bk["total"] > self.BACKLOG_CAP):
                diffs.append(f"{tag}: backlog.truncated ({bk['truncated']}) inconsistent with total {bk['total']} vs cap {self.BACKLOG_CAP}")
            if bk["remaining"] != max(0, bk["total"] - self.BACKLOG_CAP):
                diffs.append(f"{tag}: backlog.remaining ({bk['remaining']}) != max(0, total-{self.BACKLOG_CAP})")
            if bk["large"] != (bk["total"] >= 50):
                diffs.append(f"{tag}: backlog.large ({bk['large']}) inconsistent with total {bk['total']} (>=50)")

        golden_diffs = assert_lib.golden_compare(
            self.project(emit), golden, artifact="sprint-plan-emit.json"
        )
        return combine(diffs, golden_diffs)

    def update_golden(self, artifacts: dict) -> str:
        emit = artifacts["sprint-plan-emit.json"]
        schema = json.loads(self.schema_path.read_text(encoding="utf-8"))
        diffs = assert_lib.schema_validate(emit, schema, artifact="sprint-plan-emit.json")
        if diffs:
            raise EvalError(
                "cannot regenerate golden — sprint-plan-emit.json failed schema validation:\n  - "
                + "\n  - ".join(diffs)
            )
        self.golden_path.write_text(
            json.dumps(self.project(emit), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        return str(self.golden_path)


ADAPTERS = {
    PlanCampaignAdapter.command_id: PlanCampaignAdapter(),
    CreateSfCampaignAdapter.command_id: CreateSfCampaignAdapter(),
    UpdateSfCampaignStatusAdapter.command_id: UpdateSfCampaignStatusAdapter(),
    _NEW_OFFER.command_id: _NEW_OFFER,
    _NEW_PERSONA.command_id: _NEW_PERSONA,
    _NEW_VERTICAL.command_id: _NEW_VERTICAL,
    OfferPerformanceAdapter.command_id: OfferPerformanceAdapter(),
    PortfolioSnapshotAdapter.command_id: PortfolioSnapshotAdapter(),
    ImportCampaignAdapter.command_id: ImportCampaignAdapter(),
    IcpRefinementReviewAdapter.command_id: IcpRefinementReviewAdapter(),
    RaiseTicketAdapter.command_id: RaiseTicketAdapter(),
    ReportIssueAdapter.command_id: ReportIssueAdapter(),
    RetrospectiveAdapter.command_id: RetrospectiveAdapter(),
    SprintPlanningAdapter.command_id: SprintPlanningAdapter(),
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
