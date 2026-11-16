"""Every QML file that reads the Colours singleton must import qs.services.

Without the import the identifier is undefined at runtime: every colour
binding silently evaluates to undefined (black surfaces, invisible text).
It hit PluginKit's Theme (#408) and the Control Center probe cards
(CtlCard, Health & sync, #433). Comments are ignored.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", "build", "tests", "services"}


def _code(text: str) -> str:
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


def test_colours_users_import_qs_services():
    offenders = []
    for path in sorted(ROOT.rglob("*.qml")):
        rel = path.relative_to(ROOT)
        if SKIP_DIRS.intersection(rel.parts):
            continue
        code = _code(path.read_text(encoding="utf-8", errors="ignore"))
        if not re.search(r"\bColours\.", code):
            continue
        imports = set(re.findall(r"^\s*import\s+([A-Za-z0-9_.]+)", code, re.M))
        if "qs.services" not in imports:
            offenders.append(str(rel))
    assert offenders == [], offenders
