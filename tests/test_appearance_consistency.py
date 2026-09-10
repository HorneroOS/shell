"""Appearance consistency: QML may drive theming only through the canonical
dots-gtk-theme / dots-m3-colors CLIs — never gtk-theme-manager.sh directly,
never bare `python3 generate-m3-colors`."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = [ROOT / d for d in ("modules", "services", "config", "utils", "components")]


def _qml_files():
    for d in QML_DIRS:
        yield from d.rglob("*.qml")


def _hits(needle):
    return [p for p in _qml_files() if needle in p.read_text()]


def test_no_direct_gtk_theme_manager():
    hits = _hits("gtk-theme-manager.sh")
    assert not hits, f"direct gtk-theme-manager.sh calls in: {hits}"


def test_no_bare_generate_m3_colors():
    hits = _hits("generate-m3-colors")
    assert not hits, f"bare generate-m3-colors calls in: {hits}"


def test_canonical_cli_calls_present():
    gtk = _hits("dots-gtk-theme")
    m3 = _hits("dots-m3-colors")
    assert gtk, "expected dots-gtk-theme CLI calls in QML"
    assert m3, "expected dots-m3-colors CLI calls in QML"
