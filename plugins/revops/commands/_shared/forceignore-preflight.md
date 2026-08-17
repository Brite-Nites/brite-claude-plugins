<!-- eval-waiver: Shared PROCEDURE include, not a command — it has no frontmatter and is never invoked as /revops:forceignore-preflight. Its body is the F1 .forceignore pattern-match block (BC-12347) lifted verbatim from the three deploy commands that previously each carried a copy; extracting it changed no behaviour and added no decision. It is exercised through its callers, whose own eval-waivers cover the live-deploy sequence it sits in. Same fnmatch-vs-Path.glob asymmetry as its sibling: visible to the diff-gate, invisible to --check's surface, so it cannot take a debt row. -->

# Shared procedure — `.forceignore` pre-flight (F1, BC-12347)

Not a command. Included by reference from `/revops:preview-changes`,
`/revops:push-to-production`, and `/revops:emergency-deploy-to-production`.

## Why it exists

`sf project deploy start` **silently skips** any path matched by `.forceignore`.
A changed component that is ignored just does not deploy, and nothing says so.
sfdx-hardis does not cover this: its overwrite protection answers a different
question ("don't clobber what's there"), and the underlying `sf project deploy`
still drops ignored paths without a word ([ADR-025](../../../../docs/decisions/025-sfdx-hardis-adoption.md)).
So this stays a revops-side pre-flight — caught at the cheapest correct layer.

Per [ADR-026](../../../../docs/decisions/026-revops-promotion-topology.md)
section 4, F1 runs in **every** revops deploy command, the emergency path
included. The emergency path is never unguarded. It also mirrors as a CI step,
so the same drop is caught whichever lane the change travels.

## Procedure

Set `RANGE` to the diff range this command uses, then run the block.

| Caller | `RANGE` |
|---|---|
| `/revops:preview-changes` | merge-base of `origin/main` with `HEAD`, or `main~1..main` when run from `main` |
| `/revops:push-to-production` | `main~1..main` (the squash commit that just landed) |
| `/revops:emergency-deploy-to-production` | `main~1..main`, or the explicit `--ref` range |

Skip the whole block when the caller is in `reconcile` (full-tree) mode: the
operator opted into deploying everything, so a per-path diff check has nothing to
say. Print `NOTE: reconcile mode — skipping .forceignore pre-flight.` and move on.

```bash
set +e  # individual checks may return non-zero legitimately

if [ ! -f .forceignore ]; then
  echo "NOTE: no .forceignore found — pre-flight skipped."
  exit 0
fi

# RANGE is set by the caller — see the table above.
RAW_CHANGED=$(git diff "$RANGE" --name-only --diff-filter=ACMRT 2>&1)
if [ $? -ne 0 ]; then
  echo "WARN: git diff failed — skipping .forceignore pre-flight (not blocking)."
  printf '%s\n' "$RAW_CHANGED"
  exit 0
fi
CHANGED=$(printf '%s\n' "$RAW_CHANGED" | grep '^force-app/' || true)

if [ -z "$CHANGED" ]; then
  echo "INFO: no force-app/** paths in the diff — .forceignore pre-flight: nothing to check."
  exit 0
fi

NC_EXCLUDED=""
OTHER_EXCLUDED=""

while IFS= read -r fpath; do
  [ -z "$fpath" ] && continue
  fpath_rel="${fpath#force-app/main/default/}"
  matched_pattern=""
  while IFS= read -r pattern; do
    case "$pattern" in ''|\#*) continue ;; esac
    pat="${pattern#/}"
    [ -z "$pat" ] && continue
    hit=0
    case "$fpath" in *$pat*) hit=1 ;; esac
    if [ "$hit" = "0" ]; then
      case "$fpath_rel" in *$pat*) hit=1 ;; esac
    fi
    if [ "$hit" = "1" ]; then
      matched_pattern="$pattern"
      break
    fi
  done < .forceignore
  if [ -n "$matched_pattern" ]; then
    case "$matched_pattern" in
      *namedCredential*)
        NC_EXCLUDED="${NC_EXCLUDED}  ${fpath} (pattern: ${matched_pattern})\n"
        ;;
      *)
        OTHER_EXCLUDED="${OTHER_EXCLUDED}  ${fpath} (pattern: ${matched_pattern})\n"
        ;;
    esac
  fi
done <<< "$CHANGED"

if [ -z "$NC_EXCLUDED" ] && [ -z "$OTHER_EXCLUDED" ]; then
  echo "✓ .forceignore pre-flight: no deploy paths excluded."
  exit 0
fi

if [ -n "$NC_EXCLUDED" ]; then
  printf '\nNamed Credential exclusions (expected — placeholder URLs; handled by /revops:run-manual-post-deploy-steps Phase 5):\n'
  printf '%b' "$NC_EXCLUDED"
fi

if [ -n "$OTHER_EXCLUDED" ]; then
  printf '\n⚠️  .forceignore exclusions detected — these paths will be silently dropped by sf project deploy:\n'
  printf '%b' "$OTHER_EXCLUDED"
  printf '\nRemediation: temporarily comment out the matching .forceignore line(s), run the deploy, then restore.\n'
  echo "FORCEIGNORE_BLOCKED=1"
else
  echo "FORCEIGNORE_BLOCKED=0"
fi
```

## Acting on the result

- `FORCEIGNORE_BLOCKED=1` — ask via `AskUserQuestion`:
  - Question: `⚠️ .forceignore will silently drop the paths listed above. How do you want to proceed?`
  - Options:
    - `I've resolved the .forceignore conflict — continue` → continue the caller's phase sequence.
    - `Halt — fix .forceignore first` → **halt** cleanly. Print: *"Stopped at .forceignore pre-flight. Comment out the relevant .forceignore lines, verify the fix, then re-run."* Exit.
- `FORCEIGNORE_BLOCKED=0`, or no exclusions at all — continue silently. Named Credential exclusions are expected and were already printed.
