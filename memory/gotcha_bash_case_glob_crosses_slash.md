# Bash `case` globs cross `/`

In a `case` statement, `*` matches any characters **including `/`** — unlike
pathname expansion, where `*` stops at slashes. So a guard like:

```sh
case "$path" in
  plugins/*/hooks/*) flag_for_version_bump ;;
esac
```

matches `plugins/marketing/tests/hooks/fixture.py` and
`plugins/marketing/shared/hooks/util.sh`, not just direct
`plugins/<name>/hooks/` children.

Caught as a P2 review finding on PR #317: the pre-commit version-bump guard
over-matched nested `tests/hooks/` and `shared/hooks/` paths, demanding
version bumps for files that don't ship. Regression-locked by scenarios
I/J/K/O in `scripts/test_pre_commit_bump.sh`, which `scripts/validate.sh`
§ 2c runs on every validate.

When a case-glob must mean "direct child only", match the exact segment
count (`plugins/*/hooks/*` → add a guard that the remainder contains no
further `/`), or pre-strip the prefix with parameter expansion and test the
remainder explicitly.
