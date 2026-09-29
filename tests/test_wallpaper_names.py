"""Wallpaper display names: picker labels must be human-scannable, not raw
machine filenames (baseline §5.5: `wallhaven-…_1920x1080.png` x6,
indistinguishable after truncation).

Contract: `Strings.wallpaperDisplayName` strips the extension and a
trailing _WxH resolution suffix and renders separators as spaces
(`wallhaven-73v179_1920x1080.png` -> `wallhaven 73v179`). Display
only — search/filter keep matching raw filenames. Never blank."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STRINGS = ROOT / "utils" / "Strings.qml"
GRID = ROOT / "modules" / "controlcenter" / "components" / "WallpaperGrid.qml"
ITEM = ROOT / "modules" / "launcher" / "items" / "WallpaperItem.qml"
PREVIEW = ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePreviewPane.qml"


def test_display_name_helper_exists():
    text = STRINGS.read_text()
    assert "function wallpaperDisplayName(name" in text
    for token in (r"\.[A-Za-z0-9]+$", r"[_-]\d+x\d+$", r"[_-]+"):
        assert token in text, f"helper missing transform: {token}"


def test_all_wallpaper_labels_use_display_names():
    for path in (GRID, ITEM):
        text = path.read_text()
        assert "Strings.wallpaperDisplayName(" in text, f"{path.name} label bypasses helper"
    preview = PREVIEW.read_text()
    assert preview.count("Strings.wallpaperDisplayName(") >= 2, "preview chips must use helper"
    assert "root.basename(" not in preview, "dead basename() must not linger"
    assert "modelData.relativePath" not in ITEM.read_text(), "launcher must not show raw paths"


def _display(name):
    """Python mirror of Strings.wallpaperDisplayName (same three regexes)."""
    s = str(name)
    s = s.rsplit("/", 1)[-1]
    s = re.sub(r"\.[A-Za-z0-9]+$", "", s)
    s = re.sub(r"[_-]\d+x\d+$", "", s)
    s = re.sub(r"\s+", " ", re.sub(r"[_-]+", " ", s)).strip()
    return s if s else str(name)


def test_display_names_cover_live_wallpapers():
    assert _display("wallhaven-73v179_1920x1080.png") == "wallhaven 73v179"
    assert _display("flowers-02.jpg") == "flowers 02"
    assert _display("hornero-os-dark.png") == "hornero os dark"
    assert _display("Distance.gif") == "Distance"
    walls = Path.home() / "Pictures" / "Wallpapers"
    seen = 0
    for f in walls.rglob("*"):
        if not f.is_file() or f.suffix.lower() not in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
            continue
        label = _display(f.name)
        assert label, f"blank label for {f.name}"
        assert len(label) <= len(f.stem), f"label longer than stem for {f.name}"
        seen += 1
    assert seen > 0, "expected live wallpapers to check against"
