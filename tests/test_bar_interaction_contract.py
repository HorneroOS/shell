"""Bar affordances stay discoverable and popouts move with their owner edge."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_bar_popouts_are_one_anchored_surface():
    """Every bar popout is a page of one AnchoredSurface placed by the
    shared solver (RFC 0001 §4); no layout positions popouts itself."""
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    content = (ROOT / "modules/bar/popouts/Content.qml").read_text()
    panels = (ROOT / "modules/drawers/Panels.qml").read_text()
    assert "AnchoredSurface {" in wrapper
    assert "component Popout: SurfacePage {" in content
    # No hand-rolled reveal: no scale, no per-edge anchors in the pages.
    assert "revealScale" not in content and "Scale {" not in content
    assert "anchors.bottom" not in content
    # Panels only describe the screen; x/y come from the solver.
    block = panels.split("BarPopouts.Wrapper {", 1)[1].split("Utilities.Wrapper {", 1)[0]
    assert "bounds:" in block and "reserved:" in block
    assert "x:" not in block and "y:" not in block
    assert not (ROOT / "modules/bar/popouts/Background.qml").exists()


def test_popout_owner_keeps_a_live_trigger_reference():
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    bar = (ROOT / "modules/bar/Bar.qml").read_text()
    tracker = (ROOT / "components/placement/AnchorTracker.qml").read_text()
    assert "property Item currentAnchor" in wrapper
    assert "anchorItem: isDetached ? null : currentAnchor" in wrapper
    # The bar publishes itself as the owner; its slab is the live anchor line.
    assert "readonly property var surfaceOwner" in bar
    assert "item: root" in bar
    assert "popouts.openFor(name, anchor, root.surfaceOwner, how)" in bar
    assert "centerBinding" not in bar and "claimPopouts" not in bar
    # Live anchor: every ancestor's geometry is a dependency.
    assert "void p.x;" in tracker and "void p.width;" in tracker


def test_hover_intent_and_close_grace():
    """RFC §4 rule 6: 120 ms open intent, 240 ms close grace bridged across
    the gap; switching between triggers while open morphs immediately."""
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    interactions = (ROOT / "modules/drawers/Interactions.qml").read_text()
    chore = (ROOT / "components/motion/Choreography.qml").read_text()
    assert "readonly property int hoverOpenDelay: 120" in chore
    assert "readonly property int hoverCloseGrace: 240" in chore
    assert "interval: Choreography.hoverOpenDelay" in wrapper
    assert "interval: Choreography.hoverCloseGrace" in wrapper
    assert "if (hover && !root.hasCurrent)" in wrapper
    assert "popouts.hoverLeave()" in interactions
    assert "popouts.holdOpen()" in interactions
    assert "popouts.hasCurrent = false" not in interactions


def test_attached_popouts_omit_the_attached_border_and_draw_the_notch():
    frame = (ROOT / "components/placement/SurfaceFrame.qml").read_text()
    surface = (ROOT / "components/placement/AnchoredSurface.qml").read_text()
    assert "color: Signal.palette.signal" in frame
    assert "clip: root.attached" in frame
    assert "RectangularShadow {" in frame and "layer.enabled" not in frame
    assert "Qt.alpha(Signal.palette.shadow, 0.35)" in frame
    # Popouts are opaque panels, including from Cockpit Clear bars.
    assert "property color fill: Signal.palette.panel" in surface


def test_icon_bar_buttons_have_visual_and_accessible_names():
    src = (ROOT / "modules/bar/components/BarButton.qml").read_text()
    assert "Accessible.name: root.label" in src
    assert "readonly property bool hovered: interaction.containsMouse" in src
    assert "Tooltip {" in src
    assert "target: root" in src
    assert "text: root.label" in src


def test_tooltips_use_the_shared_solver_and_stay_on_screen():
    src = (ROOT / "components/controls/Tooltip.qml").read_text()
    assert "AnchoredSurface {" in src
    assert "target?.Window.contentItem" in src
    assert "p.surfaceOwner !== undefined" in src
    assert "morphs: false" in src and "travelDuration: Choreography.quick" in src
    assert "elevation: 4" in src and "Signal.palette.lifted" in src


def test_inline_bar_sliders_explain_current_value_and_input():
    src = (ROOT / "modules/bar/components/InlineSlider.qml").read_text()
    assert "Accessible.role: Accessible.Slider" in src
    assert 'qsTr("Volume")' in src
    assert 'qsTr("Brightness")' in src
    assert "Scroll or use the arrow keys to adjust." in src
    assert "target: slider" in src
    assert "Audio.incrementVolume()" in src
    assert "monitor.setBrightness" in src


def test_tray_menu_tolerates_transiently_missing_entries():
    src = (ROOT / "modules/bar/popouts/TrayMenu.qml").read_text()
    assert "currentItem?.implicitWidth ?? 0" in src
    assert "currentItem?.implicitHeight ?? 0" in src
    assert "readonly property bool hasEntry: modelData !== null" in src
    assert "readonly property bool isSeparator: modelData?.isSeparator ?? false" in src
    assert "visible: hasEntry" in src
    assert "active: item.hasEntry && !item.isSeparator" in src
    assert "if (!item.hasEntry || !item.isEnabled)" in src
    assert 'text: item.modelData?.text ?? ""' in src


def test_vertical_active_window_stays_compact_and_exposes_the_full_title():
    src = (ROOT / "modules/bar/components/ActiveWindow.qml").read_text()
    assert "Accessible.role: Accessible.StaticText" in src
    assert "Accessible.name: Compositor.activeWindowTitle" in src
    assert "readonly property bool compactRail: vertical && Config.bar.popouts.activeWindow" in src
    assert "if (root.compactRail)" in src
    assert "return Config.bar.sizes.innerWidth;" in src
    assert "root.compactRail ? parent.verticalCenter" in src
    assert "visible: !root.compactRail" in src


def test_motion_and_bar_affordances_are_documented():
    src = " ".join((ROOT / "docs/INTERACTION.md").read_text().split())
    assert "Direction follows the owning bar" in src
    assert "Grows from the trigger notch" in src
    assert "120 ms" in src and "240 ms" in src
    assert "hover tooltip and an accessible label" in src
