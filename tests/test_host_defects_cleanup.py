"""Defects found on the real desktop: stale Appearance disclosure state and
log noise."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_appearance_themes_open_by_default_and_legacy_key_ignored():
    cfg = (ROOT / "config/ControlCenterConfig.qml").read_text(encoding="utf-8")
    assert 'property var appearanceOpenSections: ["themes"]' in cfg
    for p in ROOT.rglob("*"):
        if p.suffix in (".qml", ".json", ".py") and ".git" not in p.parts and p.name != Path(__file__).name:
            assert "appearanceExpandedSections" not in p.read_text(encoding="utf-8"), p


def test_log_noise_guards():
    osd = (ROOT / "modules/osd/Wrapper.qml").read_text(encoding="utf-8")
    assert "Qt.binding(() => root.shouldBeActive || root.visible)" not in osd
    tray = (ROOT / "modules/bar/popouts/Content.qml").read_text(encoding="utf-8")
    assert "trayMenu.modelData?.menu ?? null" in tray
    assert "trayMenu.modelData.menu" not in tray
