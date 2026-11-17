"""Palette audit of the bars (shell#530): which foreground roles each preset can paint.

A bar's foreground is ink, inkMuted and one accent (signal); alert only marks
urgent states. The audit reads every component a preset's entries load and
enumerates the colour roles their sources use, so a component that starts
painting phosphor, cue or any other palette role fails here before it ships a
rainbow strip.
"""
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules/bar/components"
ENTRY_FILES = {
    "logo": ["OsIcon.qml"], "quickActions": ["QuickActions.qml", "BarButton.qml"],
    "audioSlider": ["InlineSlider.qml"], "brightnessSlider": ["InlineSlider.qml"],
    "clock": ["Clock.qml"], "weather": ["WeatherChip.qml"], "modeIndicator": ["ModeIndicator.qml"],
    "statusIcons": ["StatusIcons.qml"], "tray": ["Tray.qml", "TrayItem.qml"],
    "extensions": ["ExtensionsIsland.qml"], "power": ["Power.qml"], "battery": ["Battery.qml"],
    "resources": ["Resources.qml"], "kbLayout": ["KbLayout.qml"], "media": ["Media.qml"],
    "workspaces": ["workspaces/Workspaces.qml", "workspaces/Workspace.qml", "workspaces/ActiveIndicator.qml"],
    "activeWindow": ["ActiveWindow.qml"], "pinnedApps": ["PinnedApps.qml"],
}
# Surfaces, rules and fills are not foreground; these are the ink roles.
FOREGROUND = {"ink", "inkMuted", "signal", "alert", "phosphor", "cue", "glow", "onPhosphor", "onSignal"}
ALLOWED = {"ink", "inkMuted", "signal", "alert"}
MAX_NON_URGENT = 3


def roles(rel: str) -> set[str]:
    src = (COMP / rel).read_text()
    found = set(re.findall(r"(?:tone|palette)\.([A-Za-z]+)", src))
    return found & FOREGROUND


def entries(preset: Path) -> set[str]:
    data = json.loads(preset.read_text())
    ids = set()
    for bar in data.get("bar", {}).get("bars", []):
        for group in bar.get("groups", {}).values():
            ids.update(e["id"] for e in group if e.get("enabled", True))
    return ids


PRESETS = sorted((ROOT / "presets").glob("*.json"))


@pytest.mark.parametrize("preset", PRESETS, ids=lambda p: p.stem)
def test_preset_foreground_is_ink_muted_and_one_accent(preset):
    used: dict[str, set[str]] = {}
    for entry in entries(preset):
        for rel in ENTRY_FILES.get(entry, []):
            for role in roles(rel):
                used.setdefault(role, set()).add(entry)
    stray = set(used) - ALLOWED - {"onSignal"}
    assert not stray, {r: sorted(used[r]) for r in stray}
    non_urgent = set(used) - {"alert"}
    assert len(non_urgent) <= MAX_NON_URGENT, sorted(non_urgent)


def test_every_preset_entry_is_audited():
    missing = {e for p in PRESETS for e in entries(p)} - set(ENTRY_FILES) - {"spacer"}
    assert not missing, f"add these entries to ENTRY_FILES: {sorted(missing)}"
