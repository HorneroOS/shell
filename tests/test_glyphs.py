"""Hornero Glyphs contract (RFC 0001 §3.4).

Every glyph name the shell can render must exist in the generated
utils/GlyphMap.js, the map must match the curated names list, and the
subset font must ship with its Tabler MIT licence.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GLYPH_MAP = ROOT / "utils" / "GlyphMap.js"
NAMES = ROOT / "assets" / "fonts" / "hornero-glyphs.names"
FONT = ROOT / "assets" / "fonts" / "hornero-glyphs.ttf"

SCAN_DIRS = ("components", "config", "modules", "plugin/qml", "services",
             "utils", "presets", "examples/plugins")
LITERAL = re.compile(r'''(["'`])([a-z][a-z0-9-]*)\1''')
# Literals that are compared against, not rendered.
COMPARISON = re.compile(r'(===|!==|==|!=|\bcase|includes\(|indexOf\(|startsWith\(|endsWith\(|typeof\s+\w+\s*===)\s*$')
ICON_KEY = re.compile(
    r'''(\b[A-Za-z_]*[Ii]con(?!s)[A-Za-z_]*\b|"_glyph"|"[A-Za-z_]*[Ii]con(?!s)[A-Za-z_]*")\s*(:|=(?!=)|\?\?)''')
# Values that are icon-typed properties but not glyph names
# enum-like roles/colours).
NOT_GLYPHS = {"body", "small", "large", "string", "transparent"}


def glyph_names() -> set:
    return set(re.findall(r'^\s+"([a-z0-9-]+)": 0x[0-9A-F]+', GLYPH_MAP.read_text(), re.M))


def _statement_end(src: str, i: int) -> int:
    depth = 0
    while i < len(src):
        c = src[i]
        if c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
            if depth < 0:
                return i
        elif c == "\n" and depth == 0:
            return i
        i += 1
    return i


def _block_end(src: str, i: int) -> int:
    depth = 0
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return i


def _third_argument(src: str, i: int):
    """Span of the third top-level call argument (the toast icon)."""
    depth, index, start = 0, 0, i
    while i < len(src):
        c = src[i]
        if c in "{([":
            depth += 1
        elif c in "})]":
            if depth == 0:
                return (start, i) if index == 2 else None
            depth -= 1
        elif c == "," and depth == 0:
            if index == 2:
                return (start, i)
            index += 1
            start = i + 1
        i += 1
    return None


def _icon_ranges(path: Path, src: str):
    if path.name == "Icons.qml" and path.parent.name == "utils":
        return [(0, len(src))]
    ranges = []
    for m in ICON_KEY.finditer(src):
        ranges.append((m.start(), _statement_end(src, m.end())))
    if path.suffix == ".json":
        return ranges
    for m in re.finditer(r'\bGlyph\s*\{', src):
        end = _block_end(src, m.end() - 1)
        for n in re.finditer(r'\n\s*name:', src[m.end():end]):
            start = m.end() + n.end()
            ranges.append((start, _statement_end(src, start)))
    for m in re.finditer(r'function\s+(\w*Icon|icon\w*)\s*\([^)]*\)[^{]*\{', src):
        ranges.append((m.end(), _block_end(src, m.end() - 1)))
    for m in re.finditer(r'\b(toast|promote\w*)\s*\(', src):
        arg = _third_argument(src, m.end())
        if arg:
            ranges.append(arg)
    return ranges


def used_glyph_names():
    used = {}
    for d in SCAN_DIRS:
        for path in (ROOT / d).rglob("*"):
            if path.suffix not in (".qml", ".js", ".json") or path.name == "GlyphMap.js":
                continue
            src = path.read_text(errors="ignore")
            ranges = _icon_ranges(path, src)
            if not ranges:
                continue
            for m in LITERAL.finditer(src):
                if not any(a <= m.start() < b for a, b in ranges):
                    continue
                if COMPARISON.search(src[max(0, m.start() - 24):m.start()]):
                    continue
                # Desktop icon-theme lookups (freedesktop names), not glyphs.
                if re.search(r'iconPath\([^)]*$', src[max(0, m.start() - 80):m.start()]):
                    continue
                line_start = src.rfind("\n", 0, m.start()) + 1
                if src[line_start:m.start()].lstrip().startswith("//"):
                    continue
                # Membership tests: ["a", "b"].includes(x).
                if re.match(r'[^\]\n]*\]\.(includes|indexOf)\(', src[m.end():]):
                    continue
                # Object keys ("0": …, WebBrowser: …) are lookups, not glyphs.
                if re.match(r'\s*:', src[m.end():]):
                    continue
                name = m.group(2)
                if name in NOT_GLYPHS:
                    continue
                used.setdefault(name, f"{path.relative_to(ROOT)}:{src.count(chr(10), 0, m.start()) + 1}")
    return used


def test_every_used_glyph_exists():
    known = glyph_names()
    missing = {n: where for n, where in used_glyph_names().items() if n not in known}
    assert not missing, f"glyph names not in Hornero Glyphs: {missing}"


def test_map_matches_curated_names():
    names = {line.strip() for line in NAMES.read_text().splitlines()
             if line.strip() and not line.startswith("#")}
    assert names == glyph_names(), "utils/GlyphMap.js drifted from hornero-glyphs.names; run scripts/build-glyphs.py"


def test_font_and_licence_ship():
    assert FONT.is_file() and FONT.stat().st_size > 10_000
    licence = (ROOT / "assets" / "fonts" / "LICENSE.tabler-icons").read_text()
    assert "MIT License" in licence and "Paweł Kuna" in licence
    notice = (ROOT / "NOTICE").read_text()
    assert "Tabler Icons" in notice and "IBM Plex" in notice


def test_build_script_is_pinned():
    script = (ROOT / "scripts" / "build-glyphs.py").read_text()
    assert re.search(r'TABLER_VERSION = "\d+\.\d+\.\d+"', script)
    assert re.search(r'TABLER_SHA256 = "[0-9a-f]{64}"', script)


def test_font_family_is_hornero_glyphs():
    try:
        out = subprocess.run(["fc-scan", "--format", "%{family}", str(FONT)],
                             capture_output=True, text=True, check=False).stdout
    except FileNotFoundError:
        return
    if out:
        assert "Hornero Glyphs" in out
