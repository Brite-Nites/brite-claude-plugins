#!/usr/bin/env python3
"""Unwired-test meta-lint for validate.sh §2b-unwired (BC-16381).

A test that no runner executes is worse than no test — it rots silently while
looking like coverage. This fails when a `test_*.sh` / `test-*.sh` / `test_*.py`
file exists under `scripts/` or `plugins/*/{tests,scripts}/` that no runner
(`scripts/validate.sh` or a `.github/workflows/*.yml`) would execute.

A test counts as WIRED if ANY of these hold (the repo runs tests four ways):
  - **literal** — its basename or repo-relative path appears in the runner corpus
    on a non-comment line (a `bash …/test_foo.sh` or `run: …` invocation);
  - **glob-loop** (.sh) — validate.sh iterates the file's directory, e.g.
    `for t in "$REPO_ROOT"/plugins/workflows/tests/test-*.sh; do bash "$t"; done`;
  - **stem-interpolation** (.sh) — the file's stem is a member of a `for VAR in …`
    list whose variable feeds a `test_$VAR.sh` / `test-$VAR.sh` path (the actual
    loop lists are extracted, not merely scanned for the token — so a common-word
    stem like `data` or `report` is NOT treated as wired unless it is really in
    such a loop);
  - **pytest discovery** (.py) — it lives under `plugins/<p>/tests/` (recursively)
    where `<p>` is in `scripts/test-python-units.sh`'s explicit `plugins=` list,
    which runs `pytest tests/` per listed plugin.

Full-line comments are stripped from the corpus before matching, so a test merely
*mentioned* in a comment (not invoked) does not count as wired.

Prints `OK` (exit 0) or `UNWIRED:<comma-separated repo-relative paths>` (exit 1).
Args: <repo_root>
"""
import glob
import os
import re
import sys


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (FileNotFoundError, OSError):
        return ""


def strip_comments(text):
    """Drop full-line comments (bash + YAML: first non-space char is #)."""
    return "\n".join(ln for ln in text.splitlines() if not re.match(r"\s*#", ln))


def pytest_plugins(path):
    """Parse the explicit `plugins="a b c"` list from test-python-units.sh."""
    m = re.search(r'^\s*plugins=(["\']?)([A-Za-z0-9 _-]+)\1\s*$', read(path), re.MULTILINE)
    return set(m.group(2).split()) if m else set()


def stem_loop_stems(validate_code):
    """Stems that a `for VAR in <list>; … test_$VAR.sh` loop actually executes.

    Precise: only stems in the `in <list>` of a for-loop whose variable feeds a
    `test_$VAR` / `test-$VAR` path count — not any token that happens to appear.
    """
    interp_vars = set(re.findall(r"test[_-]\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", validate_code))
    stems = set()
    for var in interp_vars:
        for m in re.finditer(
            r"\bfor\s+" + re.escape(var) + r"\s+in\s+([^\n;]+?)(?:\s*;|\s+do\b)",
            validate_code,
        ):
            for tok in m.group(1).split():
                if re.fullmatch(r"[A-Za-z0-9_.\-]+", tok):  # bareword, not $expansion/glob
                    stems.add(tok)
    return stems


def enumerate_tests(root):
    """test_*.sh / test-*.sh / test_*.py under scripts/ or plugins/*/{tests,scripts}/."""
    seen = set()
    roots = [os.path.join(root, "scripts")]
    roots += glob.glob(os.path.join(root, "plugins", "*", "tests"))
    roots += glob.glob(os.path.join(root, "plugins", "*", "scripts"))
    for base in roots:
        for dirpath, _dirs, files in os.walk(base):
            for fn in files:
                if re.match(r"^test[_-].*\.(sh|py)$", fn):
                    seen.add(os.path.relpath(os.path.join(dirpath, fn), root))
    return seen


def is_wired(rel, code_corpus, code_validate, stems, py_plugins):
    base = os.path.basename(rel)
    dirp = os.path.dirname(rel)
    is_py = base.endswith(".py")
    stem = re.sub(r"\.(sh|py)$", "", re.sub(r"^test[_-]", "", base))

    # literal path or basename on a non-comment line of validate.sh or a workflow
    if base in code_corpus or rel in code_corpus:
        return "literal"

    if is_py:
        m = re.match(r"plugins/([^/]+)/tests(?:/|$)", rel)
        if m and m.group(1) in py_plugins:
            return "pytest"
        return None

    # .sh glob-loop over the file's directory (test-*.sh / test_*.sh)
    if (dirp + "/test-*.") in code_validate or (dirp + "/test_*.") in code_validate:
        return "glob-loop"
    # .sh stem-interpolation — stem must be in an actual test_$VAR loop list
    if stem in stems:
        return "stem"
    return None


def main(argv):
    root = argv[1] if len(argv) > 1 else "."
    validate = read(os.path.join(root, "scripts", "validate.sh"))
    workflows = "".join(
        read(p) for p in glob.glob(os.path.join(root, ".github", "workflows", "*.yml"))
    )
    code_validate = strip_comments(validate)
    code_corpus = code_validate + "\n" + strip_comments(workflows)
    stems = stem_loop_stems(code_validate)
    py_plugins = pytest_plugins(os.path.join(root, "scripts", "test-python-units.sh"))

    unwired = [
        rel for rel in enumerate_tests(root)
        if not is_wired(rel, code_corpus, code_validate, stems, py_plugins)
    ]
    if unwired:
        print("UNWIRED:" + ", ".join(sorted(unwired)))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
