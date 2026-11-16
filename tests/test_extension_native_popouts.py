"""Extension popovers use the native bar popout panel (shell#449): the bar
host Loader advertises a native popout; UiPopover hands its content to it in
bars (toggle/dismiss delegate); Content.qml shows it with the native Popout;
Bar.qml opens it on hover in every island and on click/keyboard requests;
tooltips stay off indicators that own a popout.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_host_loader_advertises_a_native_popout():
    src = read("modules/plugins/PluginBarWidgets.qml")
    for needle in ('readonly property string name: "plugin:" + modelData.id', "property Item hostPopoutContent",
                   "function hostRegisterPopout", "function hostTogglePopout", "Plugins.requestPopout"):
        assert needle in src, needle
    assert "signal popoutRequested(Item loader, bool open)" in read("services/Plugins.qml")


def test_native_panel_shows_extension_content():
    content = read("modules/bar/popouts/Content.qml")
    assert "PluginPopoutHost {" in content and "hostPopoutContent" in content
    host = read("modules/bar/popouts/PluginPopoutHost.qml")
    assert "Component.onDestruction: release()" in host and "root._held.parent = root._home" in host


def test_bar_opens_extension_popouts_like_native_ones():
    bar = read("modules/bar/Bar.qml")
    for needle in ("function pluginLoaderAt", "function openPluginPopout", "function onPopoutRequested",
                   'pluginHit !== null || extIsland !== null', "function closeExtensionIslands", "const item = ch.item ?? ch", '"hostRegisterPopout" in icon',
                   "hostPopoutOpen = true"):
        assert needle in bar, needle


def test_pluginkit_hands_popovers_to_the_host():
    pop = read("plugin/qml/Hornero/PluginKit/UiPopover.qml")
    assert "host.hostRegisterPopout(container)" in pop
    assert "root.hostPopout.hostTogglePopout()" in pop and "root.hostPopout.hostClosePopout()" in pop
    tip = read("plugin/qml/Hornero/PluginKit/UiTooltip.qml")
    assert "_popoutOwned" in tip and "!root._popoutOwned &&" in tip


def test_indicators_in_tray_like_islands_have_no_hover_background():
    button = read("plugin/qml/Hornero/PluginKit/UiButton.qml")
    assert 'root.hostStyle.hostSection === "status" || root.hostStyle.hostSection === "end"' in button
    assert "hovered: hover.hovered && !root.quietHover" in button


def test_popover_content_fits_the_native_popout():
    state = read("plugin/qml/Hornero/PluginKit/UiState.qml")
    assert "Math.min(implicitWidth, root.parent.width)" in state
    bar = read("modules/plugins/PluginBarWidgets.qml")
    assert "palette.base: Signal.palette.raised" in bar
    assert "palette.placeholderText: Signal.palette.inkMuted" in bar
