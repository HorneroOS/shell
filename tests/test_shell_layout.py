"""Layout-preset consistency: every presets/*.json must satisfy the schema
consumed by modules/layoutpicker/PresetGrid.qml and config/BarConfig.qml.

Schema v2 (docs/LAYOUTS.md): every bar is declared explicitly as an edge,
style, reservation policy, and start/center/end component groups."""
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PRESETS = sorted((ROOT / "presets").glob("*.json"))

POSITIONS = {"top", "bottom", "left", "right"}
# v2 styles accepted by BarConfig.barStyles.
BAR_STYLES = {"attached", "inset", "floating", "islands", "dock"}
GROUPS = ("start", "center", "end")

# Entry ids must exist as delegates in modules/bar/Bar.qml (roleValue), so
# presets and code cannot drift apart.
KNOWN_ENTRIES = set(
    re.findall(r'roleValue:\s*"([A-Za-z]+)"', (ROOT / "modules/bar/Bar.qml").read_text())
)
# Action ids must exist in services/ShellActions.qml run().
KNOWN_ACTIONS = set(
    re.findall(r'case\s*"([A-Za-z]+)"\s*:', (ROOT / "services/ShellActions.qml").read_text())
)


def test_preset_count():
    assert len(PRESETS) == 15, f"expected 15 presets, found {len(PRESETS)}"


def check_entry(path, entry, where, allow_spacer):
    assert isinstance(entry, dict), f"{path.name}: {where} entry must be an object"
    eid = entry.get("id")
    assert eid, f"{path.name}: {where} entry without id"
    if eid == "spacer":
        assert allow_spacer, f"{path.name}: {where} must not use spacer"
    else:
        assert eid in KNOWN_ENTRIES, f"{path.name}: {where} unknown entry id {eid!r}"
    assert isinstance(entry.get("enabled"), bool), (
        f"{path.name}: {where} entry {eid} needs bool enabled"
    )
    options = entry.get("options", {})
    assert isinstance(options, dict), f"{path.name}: {where} entry {eid} options must be an object"
    if eid == "quickActions" and "actions" in options:
        actions = options["actions"]
        assert isinstance(actions, list) and actions, (
            f"{path.name}: {where} quickActions.actions must be a non-empty list"
        )
        for a in actions:
            assert a in KNOWN_ACTIONS, f"{path.name}: {where} unknown action {a!r}"
    if eid == "pinnedApps" and "apps" in options:
        apps = options["apps"]
        assert isinstance(apps, list) and apps, (
            f"{path.name}: {where} pinnedApps.apps must be a non-empty list"
        )
        for a in apps:
            assert isinstance(a, str) and a, f"{path.name}: {where} pinnedApps.apps needs app ids"


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_preset_layout(path):
    data = json.loads(path.read_text())
    assert data.get("_name"), f"{path.name}: missing _name"
    bar = data.get("bar")
    assert isinstance(bar, dict), f"{path.name}: missing bar object"
    assert "position" not in bar and "style" not in bar and "entries" not in bar, (
        f"{path.name}: bar must use only the multi-bar schema"
    )
    sizes = bar.get("sizes", {})
    assert isinstance(sizes.get("innerWidth"), (int, float)), (
        f"{path.name}: sizes.innerWidth must be numeric"
    )
    assert isinstance(bar.get("status", {}), dict), f"{path.name}: bad status"
    scroll = bar.get("scrollActions", {})
    assert isinstance(scroll, dict), f"{path.name}: bad scrollActions"


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_preset_bars_v2(path):
    data = json.loads(path.read_text())
    bar = data.get("bar")
    assert isinstance(bar, dict), f"{path.name}: missing bar object"
    bars = bar.get("bars")
    assert isinstance(bars, list), f"{path.name}: bar.bars must be a list (v2 schema)"
    seen = set()
    for spec in bars:
        assert isinstance(spec, dict), f"{path.name}: bar spec must be an object"
        edge = spec.get("edge")
        assert edge in POSITIONS, f"{path.name}: bad bar edge {edge!r}"
        assert edge not in seen, f"{path.name}: duplicated bar edge {edge!r}"
        seen.add(edge)
        assert spec.get("style") in BAR_STYLES, f"{path.name}: bad bar style {spec.get('style')!r}"
        if "margin" in spec:
            assert isinstance(spec["margin"], (int, float)) and 0 <= spec["margin"] <= 256, (
                f"{path.name}: bar margin out of range"
            )
        if "thickness" in spec:
            assert isinstance(spec["thickness"], (int, float)) and 16 <= spec["thickness"] <= 256, (
                f"{path.name}: bar thickness out of range"
            )
        if "reserve" in spec:
            assert isinstance(spec["reserve"], bool), f"{path.name}: bar reserve must be bool"
        if "density" in spec:
            assert spec["density"] in {"values", "glyphs"}, f"{path.name}: bad bar density"
        groups = spec.get("groups")
        assert isinstance(groups, dict), f"{path.name}: bar groups must be an object"
        assert set(groups) == set(GROUPS), f"{path.name}: bar groups must be start/center/end"
        for name in GROUPS:
            assert isinstance(groups[name], list), f"{path.name}: group {name} must be a list"
            for entry in groups[name]:
                check_entry(path, entry, f"bar {edge} group {name}", allow_spacer=False)


def test_reserve_default_rule():
    """BarConfig's reserve default must match docs/LAYOUTS.md: strips
    (attached, inset) and dock reserve; floating/islands overlay.

    Single source of truth is styleReserves(); every default site must use
    it so no divergent inline rule (e.g. `style !== "floating"`, which
    wrongly reserved for islands) can reappear."""
    src = (ROOT / "config/BarConfig.qml").read_text()
    m = re.search(
        r"function styleReserves\(s: string\): bool \{\s*return ([^;]+);", src
    )
    assert m, "styleReserves() helper missing from BarConfig.qml"
    rule = m.group(1)
    for s in ("attached", "inset", "dock"):
        assert f'"{s}"' in rule, f"styleReserves must reserve {s}"
    assert "floating" not in rule and "islands" not in rule, (
        "styleReserves must not reserve floating/islands"
    )
    assert src.count("styleReserves(") >= 2, (
        "normalizeBar must use the shared styleReserves() rule"
    )
    assert '!== "floating"' not in src, "stale `style !== \"floating\"` rule still present"


def test_backdrop_contract():
    """Clear backdrops (docs/LAYOUTS.md): enum + solid default in BarConfig,
    the frame opens on clear edges (openOn, not floatingOn), and a clear
    owner never gets a frame-connected popout."""
    cfg = (ROOT / "config/BarConfig.qml").read_text()
    assert 'barBackdrops: ["solid", "clear"]' in cfg
    assert 'backdrop: barBackdrops.includes(b.backdrop) ? b.backdrop : "solid"' in cfg
    assert 'backdrop: "solid"' in cfg, "default bars must stay solid"
    for f in ("modules/drawers/Border.qml", "modules/drawers/Panels.qml"):
        src = (ROOT / f).read_text()
        assert "openOn(" in src and "floatingOn(" not in src, f"{f} must use BarSet.openOn"
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    assert 'ownerBackdrop !== "clear"' in wrapper
    for path in PRESETS:
        for b in json.loads(path.read_text())["bar"].get("bars") or []:
            assert b.get("backdrop", "solid") in ("solid", "clear"), f"{path.name}: bad backdrop"


ENTRY_OPTIONS = {
    "clock": {"showDate": bool},
    "audioSlider": {"showValue": bool},
    "brightnessSlider": {"showValue": bool},
    "workspaces": {"style": ("pills", "labels")},
}


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_preset_entry_options(path):
    """Typed per-entry options must use documented keys and values."""
    for b in json.loads(path.read_text())["bar"].get("bars") or []:
        for group in b["groups"].values():
            for e in group:
                spec = ENTRY_OPTIONS.get(e["id"])
                if not spec or not e.get("options"):
                    continue
                for k, v in e["options"].items():
                    assert k in spec, f"{path.name}: {e['id']} has undocumented option {k}"
                    want = spec[k]
                    ok = isinstance(v, want) if isinstance(want, type) else v in want
                    assert ok, f"{path.name}: {e['id']}.{k}={v!r}"


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_preset_has_no_single_bar_schema(path):
    bar = json.loads(path.read_text())["bar"]
    assert bar["bars"], f"{path.name}: needs an explicit v2 bar set"
    assert not {"position", "style", "entries", "floatingMargin"}.intersection(bar), (
        f"{path.name}: single-bar schema fields must not ship"
    )


def test_layout_picker_topology_contract():
    """Layout Picker previews canonical bar topology and owns keyboard focus."""
    preview = (ROOT / "modules/layoutpicker/LayoutPreview.qml").read_text()
    for needle in ("property var bars", '"islands"', '"dock"', '"clear"', "Array.from(bars ?? [])"):
        assert needle in preview, f"LayoutPreview lacks {needle}"
    grid = (ROOT / "modules/layoutpicker/PresetGrid.qml").read_text()
    assert "bars: card.modelData.bars" in grid
    assert "p.position" not in grid and "p.style" not in grid
    assert "availableWidth" in grid and "Accessible.role: Accessible.Button" in grid
    assert "function focusCurrentPreset(): void" in grid
    assert "onCurrentNameChanged: focusCurrentPreset()" in grid
    assert "onKeyboardNavChanged: focusCurrentPreset()" in grid
    assert "root.forceActiveFocus()" in grid
    assert "onEntered: root.focusIndex = card.index" not in grid
    content = (ROOT / "modules/layoutpicker/Content.qml").read_text()
    assert "activeFocusOnTab: true" in content and "forceActiveFocus" in content


def test_wallpaper_empty_state_fits_available_width():
    """The first-run wallpaper card stays visible on narrower displays."""
    wallpaper = (ROOT / "modules/background/Wallpaper.qml").read_text()
    assert "width: Math.max(0, Math.min(420, parent.width - Appearance.padding.large * 2))" in wallpaper
    assert "width: parent.width - Appearance.padding.large * 2" in wallpaper


def test_bar_workspaces_are_accessible_controls():
    """Every visible workspace can be activated by pointer or keyboard and
    exposes its identity/state to accessibility clients."""
    workspace = (ROOT / "modules/bar/components/workspaces/Workspace.qml").read_text()
    assert "\nItem {\n    id: root" in workspace, "the interaction target must not be managed by the visual GridLayout"
    assert "GridLayout {\n        id: content" in workspace
    assert "import qs.components.controls" in workspace
    assert "Interactive {" in workspace
    assert "    Interactive {\n        anchors.fill: parent" in workspace
    assert "Accessible.role: Accessible.Button" in workspace
    assert 'Accessible.name: qsTr("Workspace %1, %2")' in workspace
    assert "root.activeWsId !== root.ws" in workspace
    assert "Compositor.toggleSpecialWorkspace()" in workspace

    group = (ROOT / "modules/bar/components/workspaces/Workspaces.qml").read_text()
    assert "MouseArea {" not in group, "per-workspace controls own the hit target and focus"
