# Python test quarantine

Tracks `test_*.py` files/tests skipped by `scripts/test-python-units.sh` (wired
into `validate.sh` §2j and the CI `python-units` job, BC-16289). **The goal of
this document is to empty itself** — every row here is either a real
production bug awaiting a fix (after which the test un-skips) or dead test
code awaiting deletion (once the corresponding skill/asset is confirmed gone
for good). Nothing here should be permanent.

| File | Test(s) | Reason | Suspected cause | Date |
| --- | --- | --- | --- | --- |
| `plugins/revops/tests/test_flex_estimator_contracts.py` | whole module | Module-level fixture load (`skills/sf-flex-estimator/assets/calculators/flex_calculator.py`) fails at collection time — the file doesn't exist. | `sf-flex-estimator` is not one of the 14 SF skills Brite retained from the upstream `Jaganpro/sf-skills` subtree (ADR-007 §3.5) — this test came in with the BC-5789 scaffold (commit `1488256a`) and was never pruned alongside the skill filter. Orphaned test for a skill that was never carried over. | 2026-07-06 |
| `plugins/revops/tests/hooks/test_agentscript_validator.py` | whole module | Every assertion targets `sf-ai-agentscript/hooks/scripts/agentscript-syntax-validator.py`, which doesn't exist in this repo. | Same class as above: `sf-ai-agentscript` is not one of the 14 retained skills; test survived the upstream subtree filter uncleaned. | 2026-07-06 |
| `plugins/revops/tests/test_datacloud_skill_contracts.py` | whole module (all 8 tests) | Every assertion reads `skills/sf-datacloud*/SKILL.md`; none of the `sf-datacloud*` skill directories exist in this repo. | Same class: `sf-datacloud`, `sf-datacloud-connect`, etc. are not among the 14 retained skills. | 2026-07-06 |
| `plugins/revops/tests/test_skill_registry_contracts.py` | `test_registry_does_not_reference_missing_sf_skill_directories` | `shared/hooks/skills-registry.json` (v5.0.0) lists all 36 upstream skills, but this repo only ships 14 (ADR-007 §3.5). The registry was never pruned when the skill filter landed at the BC-5789 scaffold. **Production bug, not test rot** — the registry itself is stale; a real consumer using it for skill-discovery routing would recommend 22 skills that don't exist on disk. | `shared/hooks/skills-registry.json` needs a filter pass to match the 14 retained skills (or the 22 orphaned entries need explicit "not yet ported" documentation instead of silent staleness). Fix is separate — filed as a follow-up, not done in BC-16289. | 2026-07-06 |

## Emptying this list

- The 3 "missing skill directory" rows (flex-estimator, agentscript, datacloud) resolve by either building the missing skill (moving it into the 14-skill roster) or deleting the orphaned test file — whichever a future ticket decides.
- The skill-registry row resolves once `shared/hooks/skills-registry.json` is pruned to the 14 retained skills (or the extra entries are otherwise justified).
- The apex-validator row resolves once `post-tool-validate.py`'s score merge incorporates `llm_pattern_validator` (and Live Query Plan) findings, or the test's expectation is revised to explicitly test only the advisory issues list rather than the numeric score.
