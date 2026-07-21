from __future__ import annotations

from tests.datacloud_test_utils import ROOT, load_registry

# Registry is a deliberate SUPERSET of the on-disk skills (ADR-007 §3.5, amended
# 2026-07-07 / BC-16683): every absent `sf-*` entry is intentional and MUST declare
# why via an `absent_reason` marker — "runtime-installable" (the Data Cloud family,
# installable on demand via tools/install.py) or "not-ported" (Agentforce / Industry
# / Vlocity / flex-estimator / etc., skipped per ADR-007 §3.5). Requiring a valid
# marker means genuine silent drift — a renamed or deleted on-disk skill whose
# registry entry lingers unmarked, or an entry marked with a bogus value to mute
# this test — still fails.
VALID_ABSENT_REASONS = {"runtime-installable", "not-ported"}


def test_registry_contains_every_sf_skill_directory() -> None:
    registry_skills = load_registry()["skills"]
    skill_dirs = sorted(path.name for path in (ROOT / "skills").glob("sf-*") if path.is_dir())

    missing = [skill for skill in skill_dirs if skill not in registry_skills]
    assert not missing, f"skills-registry.json is missing entries for: {', '.join(missing)}"



def test_registry_does_not_reference_missing_sf_skill_directories() -> None:
    registry_skills = load_registry()["skills"]
    skill_dirs = {path.name for path in (ROOT / "skills").glob("sf-*") if path.is_dir()}

    unmarked = sorted(
        skill
        for skill, entry in registry_skills.items()
        if skill.startswith("sf-")
        and skill not in skill_dirs
        and entry.get("absent_reason") not in VALID_ABSENT_REASONS
    )
    assert not unmarked, (
        "skills-registry.json references missing skill directories without a valid "
        f"absent_reason marker ({sorted(VALID_ABSENT_REASONS)}): {', '.join(unmarked)}"
    )

    # Symmetric guard: an on-disk skill must NOT carry a marker. `absent_reason`
    # means "intentionally has no SKILL.md dir"; a marked *present* entry whose
    # dir is later removed would be silently excluded by the `unmarked` check
    # above (marked ⇒ skipped), re-opening the drift hole this test closes.
    marked_present = sorted(
        skill for skill in skill_dirs if registry_skills.get(skill, {}).get("absent_reason")
    )
    assert not marked_present, (
        "on-disk skills must not carry an absent_reason marker (it is for absent "
        f"entries only): {', '.join(marked_present)}"
    )
