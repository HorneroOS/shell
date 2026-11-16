#!/usr/bin/env python3
"""Emit a test-only Hornero Signal live scheme for the Welcome VM matrix.

Reads the shell's own built-in role tables (services/Signal.qml) so the
day and contrast schemes are exactly what the product ships. Output goes
to stdout; the scenario writes it to
~/.local/state/hornero/signal/scheme.json in the guest, which Signal
watches (schema v2, RFC 0001).

Usage: welcome-schemes.py --mode day|contrast
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

SHELL_ROOT = Path(__file__).resolve().parent.parent.parent.parent
SIGNAL_QML = SHELL_ROOT / "services" / "Signal.qml"
MODES = {"day": "hornero-signal-day", "contrast": "hornero-signal-contrast"}


def built_in_themes() -> dict:
    text = SIGNAL_QML.read_text(encoding="utf-8")
    try:
        block = text.split("readonly property var builtInThemes: (", 1)[1]
        block = block.split("\n        })", 1)[0] + "\n        }"
    except IndexError as exc:
        raise SystemExit("builtInThemes table not found in services/Signal.qml") from exc
    return json.loads(block)


def scheme(mode: str) -> dict:
    theme = built_in_themes()[MODES[mode]]
    return {
        "schemaVersion": 2,
        "id": theme["id"],
        "mode": theme["mode"],
        "palette": theme["palette"],
        "terminal": theme["terminal"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--mode", choices=sorted(MODES), required=True)
    args = parser.parse_args()
    print(json.dumps(scheme(args.mode), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
