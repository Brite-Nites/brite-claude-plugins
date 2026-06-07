# plan-campaign behavioral eval — fixture, schemas, golden (BC-12589)

Plugin-local data for the first behavioral eval (ADR-028 § 5). The reusable
harness lives at repo level in [`scripts/eval/`](../../../../scripts/eval/); only
the plan-campaign-specific inputs live here (DP2-9).

| File | Role |
|---|---|
| `plan-campaign.fixture.json` | Emit-mode inputs (the keys `/marketing:plan-campaign --emit` reads). `created_at` is **pinned** so the manifest is byte-stable for golden compare. |
| `plan-campaign.manifest.schema.json` | JSON-Schema-**subset** for `manifest.json` — asserts SHAPE (types, required keys, enums, the `schema_version`/`scaffolded_by` consts). |
| `plan-campaign.issues.schema.json` | JSON-Schema-subset for `issues.json` — the `{container, issues[]}` shape + per-issue field types. |
| `plan-campaign.golden.json` | A **structural projection** of `issues.json` (container `{title,labels}` + per-issue `{index,title,dueDate,labels,blockedBy,optional,labs_gated}`). Prose `description` bodies are **dropped** — they're asserted by contract-line presence, not golden, so verbatim copy edits don't flake the eval. |

## Run the eval

```bash
python3 scripts/eval/run_eval.py plan-campaign          # build emit → assert (exit 0/1)
bash    scripts/eval/test_eval_harness.sh               # the full validate.sh-wired self-test
```

Both run automatically in `./scripts/validate.sh` (§15a-bc-12589).

## Regenerating the golden (the discipline)

The golden is generated **from emit output** — never hand-edited. When the
builder's deterministic structure legitimately changes (e.g. a new sub-issue in
`references/campaign-sub-issue-templates.md`, a date-offset change, a label-set
change), the eval will go **red first** (catching the drift), then you regenerate
and **review the golden diff in the PR like any code change**:

```bash
python3 scripts/eval/run_eval.py plan-campaign --update-golden
git diff plugins/marketing/tests/eval/plan-campaign.golden.json   # review it
```

A red eval that you can't explain is a real regression — investigate before
regenerating.
