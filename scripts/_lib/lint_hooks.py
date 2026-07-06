#!/usr/bin/env python3
"""Validate a plugin's hooks.json.

Usage: python3 lint_hooks.py <path-to-hooks.json>

Emits one line per finding, in traversal order:
  OK:<event> -> <type> hook
  ERROR:<message>

Rules enforced:
  - Top-level "hooks" key must exist.
  - Event keys limited to PreToolUse/PostToolUse/SessionStart.
  - Each hook.type must be "prompt" or "command".
  - For type="prompt", model must be a concrete ID (not a tier alias
    "haiku"/"sonnet"/"opus" — those are rejected by the hook evaluator).

Exits 0 on normal runs (success or validation errors); callers parse
OK:/ERROR: lines to decide pass/fail. Exits 2 only on bad argv.
"""

import json
import sys

VALID_EVENTS = ("PreToolUse", "PostToolUse", "SessionStart")
TIER_ALIASES = ("haiku", "sonnet", "opus")


def _walk(hooks: object, path: str, out: list[str]) -> None:
    if not isinstance(hooks, dict):
        out.append(f'ERROR:top-level "hooks" must be an object, got {type(hooks).__name__}')
        return

    for event, handlers in hooks.items():
        if event not in VALID_EVENTS:
            out.append(f"ERROR:Unknown event: {event} (expected one of {VALID_EVENTS})")
            continue
        if not isinstance(handlers, list):
            out.append(f"ERROR:{event}: expected a list of handlers, got {type(handlers).__name__}")
            continue
        for i, handler in enumerate(handlers):
            if not isinstance(handler, dict):
                out.append(f"ERROR:{event}[{i}]: handler must be an object")
                continue
            handler_hooks = handler.get("hooks") or []
            if not isinstance(handler_hooks, list):
                out.append(f"ERROR:{event}[{i}]: 'hooks' must be a list, got {type(handler_hooks).__name__}")
                continue
            for hook in handler_hooks:
                if not isinstance(hook, dict):
                    out.append(f"ERROR:{event}[{i}]: hook entry must be an object")
                    continue
                if "type" not in hook:
                    out.append(f"ERROR:{event}[{i}]: hook missing required 'type' field")
                    continue
                htype = hook["type"]
                if htype not in ("prompt", "command"):
                    out.append(f"ERROR:{event}[{i}]: hook type must be prompt or command, got {htype!r}")
                    continue
                if htype == "prompt":
                    model = hook.get("model")
                    if not model:
                        out.append(f"ERROR:{event}[{i}]: prompt hook is missing 'model' field")
                        continue
                    if model in TIER_ALIASES:
                        out.append(
                            f'ERROR:{path}: hook model "{model}" is a tier alias. '
                            "Use a concrete model ID (e.g. claude-haiku-4-5). "
                            "See CLAUDE.md gotcha."
                        )
                        continue
                # Reached only when every prior error branch continued;
                # the hook is well-formed.
                out.append(f"OK:{event} -> {htype} hook")


def main(path: str) -> int:
    out: list[str] = []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        # All ERROR: lines flow through the same `out` buffer so callers see a
        # single emission path for the OK:/ERROR: prefix contract.
        out.append(f"ERROR:not valid JSON: {e}")
        data = None

    if data is not None:
        hooks = data.get("hooks") if isinstance(data, dict) else None
        if hooks is None:
            out.append('ERROR:Missing top-level "hooks" key')
        else:
            _walk(hooks, path, out)

    for line in out:
        print(line)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("ERROR:usage: lint_hooks.py <hooks.json>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
