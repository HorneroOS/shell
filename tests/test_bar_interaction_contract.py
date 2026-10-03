"""Bar affordances stay discoverable and popouts move with their owner edge."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_popout_reveals_from_the_owning_bar_edge():
    src = (ROOT / "modules/bar/popouts/Content.qml").read_text()
    assert "readonly property point anchorPoint" in src
    assert "anchor.mapToItem(popout, anchor.width / 2, anchor.height / 2)" in src
    assert "property real revealScale: 0.94" in src
    assert 'popout.barPosition === "top" ? 0 : popout.height' in src
    assert 'popout.barPosition === "left" ? 0 : popout.width' in src
    assert 'anchors.bottom: !barVertical && barPosition === "top"' in src
    assert 'anchors.top: !barVertical && barPosition === "bottom"' in src


def test_popout_owner_keeps_a_live_trigger_reference():
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    bar = (ROOT / "modules/bar/Bar.qml").read_text()
    assert "property Item currentAnchor" in wrapper
    assert "currentAnchor = null" in wrapper
    assert bar.count("popouts.currentAnchor =") >= 4
    assert "property bool geometryReady" in wrapper
    assert "Qt.callLater" in wrapper
    assert sum(line.strip() == "enabled: root.geometryReady" for line in wrapper.splitlines()) == 2
    assert wrapper.count("enabled: root.geometryReady && root.implicitWidth > 0") == 2


def test_standalone_popouts_use_a_lifted_surface_and_connected_ones_keep_the_bar_surface():
    background = (ROOT / "modules/drawers/Backgrounds.qml").read_text()
    shape = (ROOT / "modules/bar/popouts/Background.qml").read_text()
    assert 'visible: wrapper.visible && !wrapper.usesConnectedBackground' in background
    assert 'Colours.surface(Colours.palette.m3surfaceContainer, "bar")' in background
    assert 'Colours.palette.m3surface, "bar") : "transparent"' in shape


def test_icon_bar_buttons_have_visual_and_accessible_names():
    src = (ROOT / "modules/bar/components/BarButton.qml").read_text()
    assert "Accessible.name: root.label" in src
    assert "readonly property bool hovered: interaction.containsMouse" in src
    assert "Tooltip {" in src
    assert "target: root" in src
    assert "text: root.label" in src


def test_tooltips_flip_to_the_free_edge_and_stay_on_screen():
    src = (ROOT / "components/controls/Tooltip.qml").read_text()
    assert "onLeftEdge" in src and "onRightEdge" in src
    assert "QsWindow.window?.contentItem" in src
    assert "targetPos.y + target.height + gap" in src
    assert "parent.height - tooltipHeight - padding" in src
    assert "Math.min(newX, maxX)" in src
    assert "Math.min(newY, maxY)" in src


def test_inline_bar_sliders_explain_current_value_and_input():
    src = (ROOT / "modules/bar/components/InlineSlider.qml").read_text()
    assert "Accessible.role: Accessible.Slider" in src
    assert 'qsTr("Volume")' in src
    assert 'qsTr("Brightness")' in src
    assert "Scroll or use the arrow keys to adjust." in src
    assert "target: slider" in src
    assert "Audio.incrementVolume()" in src
    assert "monitor.setBrightness" in src


def test_vertical_active_window_stays_compact_and_exposes_the_full_title():
    src = (ROOT / "modules/bar/components/ActiveWindow.qml").read_text()
    assert "Accessible.role: Accessible.StaticText" in src
    assert "Accessible.name: Hypr.activeToplevel?.title" in src
    assert "readonly property bool compactRail: vertical && Config.bar.popouts.activeWindow" in src
    assert "if (root.compactRail)" in src
    assert "return Config.bar.sizes.innerWidth;" in src
    assert "root.compactRail ? parent.verticalCenter" in src
    assert "visible: !root.compactRail" in src


def test_motion_and_bar_affordances_are_documented():
    src = (ROOT / "docs/INTERACTION.md").read_text()
    assert "unfold from" in src
    assert "hover tooltip and an accessible label" in src
