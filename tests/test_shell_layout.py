"""Layout-preset consistency: every presets/*.json must satisfy the schema
consumed by modules/layoutpicker/PresetGrid.qml and config/BarConfig.qml.

Schema v2 (docs/LAYOUTS.md): bar.bars is the resolved bar set (empty means
the legacy single bar is synthesized). Legacy bar.position/style/entries stay
as the fallback for older horneroctl validators, so they must describe the
primary bar and use v1-only values."""
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PRESETS = sorted((ROOT / "presets").glob("*.json"))

POSITIONS = {"top", "bottom", "left", "right"}
# v1 styles accepted by older horneroctl validators.
STYLES = {"attached", "floating", "dock"}
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
    assert len(PRESETS) == 13, f"expected 13 presets, found {len(PRESETS)}"


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
    assert bar.get("position") in POSITIONS, f"{path.name}: bad bar.position"
    assert bar.get("style") in STYLES, f"{path.name}: bad bar.style"
    entries = bar.get("entries")
    assert isinstance(entries, list) and entries, f"{path.name}: empty entries"
    for entry in entries:
        check_entry(path, entry, "legacy entries", allow_spacer=True)
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
    assert src.count("styleReserves(") >= 5, (
        "normalizeBar/legacyBarFor/reservesSpace* must all use styleReserves()"
    )
    assert '!== "floating"' not in src, "stale `style !== \"floating\"` rule still present"


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_preset_v2_legacy_coherence(path):
    """Multi-bar presets must keep a usable v1 fallback: the legacy fields
    describe the primary bar so older horneroctl renders it."""
    data = json.loads(path.read_text())
    bar = data.get("bar")
    bars = bar.get("bars") or []
    if not bars:
        return
    primary = bars[0]
    assert bar.get("position") == primary["edge"], (
        f"{path.name}: legacy position must match the primary bar edge"
    )
    groups = primary["groups"]
    expected = (
        [e["id"] for e in groups["start"]]
        + ["spacer"]
        + [e["id"] for e in groups["center"]]
        + ["spacer"]
        + [e["id"] for e in groups["end"]]
    )
    actual = [e["id"] for e in bar.get("entries", [])]
    assert actual == expected, f"{path.name}: legacy entries must flatten the primary bar"
