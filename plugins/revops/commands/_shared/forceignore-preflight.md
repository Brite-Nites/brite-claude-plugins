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

Set `SCOPE_MODE` and, for a diff-scoped caller, `RANGE`, then run the block.

| Caller | `SCOPE_MODE` | `RANGE` |
|---|---|---|
| `/revops:preview-changes` (branch diff) | `diff` | merge-base of `origin/integration` with `HEAD`, or `integration~1..integration` when run from `integration`; `main` is refused |
| `/revops:preview-changes --reconcile` | `reconcile` | same reviewed branch range as branch-diff mode; the deploy is full-tree, but F1 asks which changed paths would be silently dropped |
| `/revops:push-to-production` | `diff` | `main~1..main` (the squash commit that just landed) |
| `/revops:emergency-deploy-to-production` | `diff` | `main~1..main` (the command accepts no arbitrary ref) |

Reconcile never skips F1. It still checks the reviewed change range, because
BC-12347's contract is **changed path + ignored = block**. Enumerating the whole
tree would make reconcile impossible: `.forceignore` intentionally excludes
nondeployable `jsconfig`, tests, and org-issued state that already exist in the
repo. Permanent exclusions outside the change range remain repository policy;
any changed path that the full-tree deploy would silently drop is a hard block.

```bash
set -u

if [ ! -f .forceignore ]; then
  echo "ERROR: .forceignore is missing — F1 cannot prove the deploy scope."
  echo "FORCEIGNORE_PREFLIGHT_ERROR=1"
  exit 2
fi
if ! FORCEIGNORE_CONTENT=$(cat .forceignore 2>&1); then
  echo "ERROR: .forceignore is unreadable — F1 cannot prove the deploy scope."
  printf '%s\n' "$FORCEIGNORE_CONTENT"
  echo "FORCEIGNORE_PREFLIGHT_ERROR=1"
  exit 2
fi

# SCOPE_MODE and (for diff mode) RANGE are set by the caller — see the table above.
case "${SCOPE_MODE:-}" in
  diff|reconcile)
    if [ -z "${RANGE:-}" ]; then
      echo "ERROR: F1 diff mode requires a non-empty RANGE."
      echo "FORCEIGNORE_PREFLIGHT_ERROR=1"
      exit 2
    fi
    if ! RAW_CHANGED=$(git diff "$RANGE" --name-only --diff-filter=ACMRT 2>&1); then
      echo "ERROR: git diff failed — F1 cannot prove the deploy scope."
      printf '%s\n' "$RAW_CHANGED"
      echo "FORCEIGNORE_PREFLIGHT_ERROR=1"
      exit 2
    fi
    ;;
  *)
    echo "ERROR: F1 requires SCOPE_MODE=diff or SCOPE_MODE=reconcile."
    echo "FORCEIGNORE_PREFLIGHT_ERROR=1"
    exit 2
    ;;
esac
CHANGED=$(printf '%s\n' "$RAW_CHANGED" | grep '^force-app/' || true)

if [ -z "$CHANGED" ]; then
  echo "INFO: no force-app/** paths in the selected deploy scope — .forceignore pre-flight: nothing to check."
  exit 0
fi

NC_EXCLUDED=""
OTHER_EXCLUDED=""

while IFS= read -r fpath; do
  [ -z "$fpath" ] && continue
  fpath_rel="${fpath#force-app/main/default/}"
  matched_pattern=""
  excluded=0
  while IFS= read -r pattern; do
    case "$pattern" in ''|\#*) continue ;; esac
    negated=0
    case "$pattern" in
      \!*) negated=1; pat="${pattern#!}" ;;
      *) pat="$pattern" ;;
    esac
    pat="${pat#/}"
    [ -z "$pat" ] && continue
    hit=0
    case "$fpath" in *$pat*) hit=1 ;; esac
    if [ "$hit" = "0" ]; then
      case "$fpath_rel" in *$pat*) hit=1 ;; esac
    fi
    if [ "$hit" = "1" ]; then
      matched_pattern="$pattern"
      if [ "$negated" = "1" ]; then
        excluded=0
      else
        excluded=1
      fi
    fi
  done <<< "$FORCEIGNORE_CONTENT"
  # .forceignore follows ordered gitignore-style rules: a later !pattern
  # re-includes a path. Never break on the first positive match.
  if [ "$excluded" = "1" ]; then
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
  printf '\nNamed Credential exclusions detected (PLACEHOLDER protects runtime URLs, but an ignored source change still cannot ride this deploy):\n'
  printf '%b' "$NC_EXCLUDED"
fi

if [ -n "$OTHER_EXCLUDED" ]; then
  printf '\n⚠️  .forceignore exclusions detected — these paths will be silently dropped by sf project deploy:\n'
  printf '%b' "$OTHER_EXCLUDED"
fi

printf '\nF1 BLOCKED: a deploy path is excluded. Resolve the policy in source, commit the reviewed .forceignore change, and promote it through the same lane. A local edit cannot change the remote CI checkout.\n'
echo "FORCEIGNORE_BLOCKED=1"
exit 2
```

## Acting on the result

- `FORCEIGNORE_PREFLIGHT_ERROR=1` — **halt**. The scope could not be measured, so no deploy decision is possible.
- `FORCEIGNORE_BLOCKED=1` — **halt**. Resolve the exclusion as a reviewed repository change and re-run from the resulting commit. Never continue from an uncommitted `.forceignore` edit.
- `FORCEIGNORE_BLOCKED=0`, or no exclusions at all — continue.
