#!/usr/bin/env python3
"""Print the last JSON object in CLI output that may contain text warnings."""

import json
import sys


def main() -> int:
    for line in reversed(sys.stdin.read().splitlines()):
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            print(json.dumps(value, separators=(",", ":")))
            return 0

    print("no JSON object found in command output", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
