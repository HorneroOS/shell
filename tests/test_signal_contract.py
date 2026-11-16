"""Hornero Signal static scan (RFC 0001 §7).

No Material-era names may remain in first-party code, packaging or docs:
Material 3 colour roles, the Material icon component and font, the M3
palette type, or the wallpaper colour-synthesis library. Only
docs/PROVENANCE.md and NOTICE may mention them, as history.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THIS = Path(__file__).resolve()

# Built from fragments so this file does not match itself.
FORBIDDEN = {
    "m3 colour role": re.compile(r"\bm3[A-Z]"),
    "Material icon component": re.compile("Material" + "Icon"),
    "Material Symbols font": re.compile("Material" + r"\s+Symbols"),
    "wallpaper colour synthesis": re.compile("material" + "youcolor", re.I),
    "M3 palette type": re.compile("M3" + "Palette"),
}
ALLOWED = {"docs/PROVENANCE.md", "NOTICE"}
TEXT_SUFFIXES = {".qml", ".js", ".py", ".sh", ".md", ".json", ".yml", ".yaml", ".nix",
                 ".txt", ".cpp", ".hpp", ".cmake", ".desktop", ".service", ".frag", ""}


def _tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True,
                         text=True, check=True).stdout
    for rel in filter(None, out.split("\0")):
        path = ROOT / rel
        if path.resolve() == THIS or rel in ALLOWED:
            continue
        if path.suffix not in TEXT_SUFFIXES and path.name not in ("PKGBUILD", "CMakeLists.txt"):
            continue
        if not path.is_file():
            continue
        yield rel, path


def test_no_material_era_names():
    hits = []
    for rel, path in _tracked_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for label, pattern in FORBIDDEN.items():
            for m in pattern.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                hits.append(f"{rel}:{line}: {label}")
    assert not hits, "Material-era names remain:\n" + "\n".join(hits)


def test_retired_files_are_gone():
    for rel in ("services/Colours.qml", "components/" + "Material" + "Icon.qml",
                "scripts/gen-flagship-m3.py", "modules/launcher/services/M3Variants.qml",
                "modules/launcher/services/Schemes.qml",
                "modules/controlcenter/appearance/sections/ColorVariantSection.qml",
                "modules/controlcenter/appearance/sections/ColorSchemeSection.qml",
                "services/WallpaperAnalysis.qml"):
        assert not (ROOT / rel).exists(), rel


def test_packaging_depends_on_ibm_plex_not_material_fonts():
    pkgbuild = (ROOT / "packaging" / "PKGBUILD").read_text()
    depends = re.search(r"^depends=\((.*?)\)", pkgbuild, re.M | re.S).group(1)
    assert "'ttf-ibm-plex'" in depends
    for retired in ("ttf-material-symbols", "ttf-rubik", "caskaydia"):
        assert retired not in pkgbuild.lower(), retired
    nix = (ROOT / "nix" / "default.nix").read_text()
    assert "ibm-plex" in nix and "rubik" not in nix and "material-symbols" not in nix
    flake = (ROOT / "flake.nix").read_text()
    assert "ibm-plex" in flake and "material-symbols" not in flake
