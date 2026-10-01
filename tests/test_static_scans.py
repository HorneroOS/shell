"""Static scans: no template markers, no chezmoi coupling, licensing intact."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CODE_DIRS = ["modules", "services", "config", "utils", "components",
             "plugin", "extras", "presets", "nix"]
CODE_GLOBS = ("*.qml", "*.js", "*.cpp", "*.hpp", "*.cmake", "*.nix",
              "*.json", "*.txt", "CMakeLists.txt")


def _code_files():
    files = []
    for d in CODE_DIRS:
        base = ROOT / d
        if base.is_dir():
            for pat in CODE_GLOBS:
                files.extend(base.rglob(pat))
    for extra in ("shell.qml", "CMakeLists.txt", "flake.nix"):
        if (ROOT / extra).exists():
            files.append(ROOT / extra)
    return files


def test_no_template_markers():
    hits = [str(p.relative_to(ROOT)) for p in _code_files()
            if "{{" in p.read_text(errors="ignore")]
    assert not hits, f"template markers in: {hits}"


def test_no_chezmoi_in_code():
    hits = [str(p.relative_to(ROOT)) for p in _code_files()
            if "chezmoi" in p.read_text(errors="ignore").lower()]
    assert not hits, f"chezmoi references in: {hits}"


def test_licensing_intact():
    gpl = (ROOT / "LICENSE.GPL-3.0").read_text(errors="ignore")
    assert "caelestia-dots/shell" in gpl, "Caelestia attribution missing"
    assert "GNU GENERAL PUBLIC LICENSE" in gpl, "GPL text missing"
    assert (ROOT / "LICENSE").read_text().startswith("MIT License")
    notice = (ROOT / "NOTICE").read_text()
    assert "caelestia-dots/shell" in notice
    assert "HorneroOS modifications" in notice or "HorneroOS" in notice
    assert (ROOT / "docs" / "MIGRATION.md").exists()


def test_no_undefined_per_area_saveconfig():
    """Config areas expose no saveConfig(); the only writer is Config.save().

    Regression: NotificationsPane called Config.notifs/utilities.saveConfig(),
    which do not exist, so those toggles threw at runtime and never persisted.
    """
    import re
    hits = []
    for p in _code_files():
        if p.suffix != ".qml":
            continue
        for i, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
            if re.search(r"Config\.\w+\.saveConfig\(\)", line):
                hits.append(f"{p.relative_to(ROOT)}:{i}")
    assert not hits, f"calls to undefined per-area saveConfig(): {hits}"


def test_lock_notifdock_hides_content():
    """The lock-screen notification list must be gated on hideNotifs.

    Regression: NotifDock rendered full summary+body pre-auth while
    Config.lock.hideNotifs only changed the empty-state label.
    """
    dock = (ROOT / "modules" / "lock" / "NotifDock.qml").read_text()
    assert "hideNotifs" in dock, "NotifDock must consult Config.lock.hideNotifs"
    assert "visible: !root.contentHidden" in dock, "lock list must hide with the flag"


def test_appearance_sections_disclosure_wired():
    """Every Appearance section restores + persists its disclosure state.

    Regression (baseline 5.6): all 13 sections rendered collapsed with no
    persistence, so first-run discoverability relied on Preview hover.
    Each section must restore from Config.controlCenter and write back
    user toggles; keys must match the pane's canonical _sectionKeys.
    """
    import re
    pane = (ROOT / "modules" / "controlcenter" / "appearance"
            / "AppearancePane.qml").read_text()
    keys = re.findall(r"persistSection\(\"([a-zA-Z]+)\"", pane)
    assert len(keys) == 13, f"expected 13 wired sections, got {len(keys)}: {keys}"
    m = re.search(r"_sectionKeys:\s*\[(.*?)\]", pane, re.S)
    assert m, "pane must declare canonical _sectionKeys"
    canonical = re.findall(r"\"([a-zA-Z]+)\"", m.group(1))
    assert sorted(keys) == sorted(canonical), (
        f"wired keys {sorted(keys)} != canonical {sorted(canonical)}")
    assert "themes" in canonical, "Themes must be a disclosure key"
    for key in keys:
        assert re.search(
            rf'isSectionExpanded\("{key}"\)', pane), (
            f"section {key!r} restores but never reads persisted state")


def test_connections_needs_qtquick_import():
    """Files using Connections must import QtQuick (or QtQml).

    Regression (PR #88): Shortcuts.qml and AreaPicker.qml used Connections
    without importing QtQuick, so the shell failed to load with
    "Connections is not a type". qmllint does not catch this (unqualified
    types are skipped), so the import is asserted here.
    """
    import re
    hits = []
    for p in _code_files():
        if p.suffix != ".qml":
            continue
        text = p.read_text(errors="ignore")
        if re.search(r"(^|\W)Connections\s*\{", text) and not re.search(
                r"^import\s+Qt(Quick|Qml)\b", text, re.M):
            hits.append(str(p.relative_to(ROOT)))
    assert not hits, f"Connections without QtQuick/QtQml import in: {hits}"


def test_notify_roles_documented():
    # §39 roles doc first: OSD/toast/notification each get exactly one
    # voice, with an admission test for new messages.
    doc = (ROOT / "docs" / "NOTIFICATIONS.md").read_text()
    for section in ("## OSD", "## Toast", "## Notification",
                    "## Admission test"):
        assert section in doc, f"roles doc missing {section}"
    for rule in ("Trigger rule", "Caller rule", "Source rule"):
        assert rule in doc, f"roles doc missing {rule}"
    # Baseline §5.1 stays a dated record: the fix note names the real
    # close path instead of silently rewriting the finding.
    base = (ROOT / "docs" / "EXPERIENCE_BASELINE.md").read_text()
    assert "WindowFactory.closeAll" in base
    assert "`function close(): void {}` (empty)" in base
