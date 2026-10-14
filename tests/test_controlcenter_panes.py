"""Control-center pane contract: PaneRegistry entries must resolve to real
pane files, every registered pane must accept the shared Session, and no
pane may invoke a retired dots-* wrapper (all of them are retired now —
appearance included — every call goes through horneroctl)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"
REGISTRY = CC / "PaneRegistry.qml"
WINDOW_FACTORY = CC / "WindowFactory.qml"

# Every dots-* wrapper the shell ever invoked, all superseded by horneroctl
# verbs (see docs/PROVENANCE.md). None may appear in pane QML.
DEAD_WRAPPERS = [
    "dots-quickshell",
    "dots-launcher",
    "dots-power-menu",
    "dots-clipboard",
    "dots-snappy-switcher",
    "dots-hypr-layout",
    "dots-hyprland-plugins",
    "dots-battery-monitor",
    "dots-keyboard-help",
    "dots-keyboard-layout",
    "dots-lockscreen",
    "dots-screenshooter",
    "dots-sysupdate",
    "dots-theme-selector",
    "dots-gtk-theme",
    "dots-m3-colors",
    "dots-color-scheme",
    "dots-appearance",
    "dots-accent-override",
    "dots-night-mode",
    "dots-wallpaper-current",
    "dots-wallpaper-set",
    "dots-recorder",
    "dots-settings-gui",
    "dots-hyprlock-theme",
]


def _registry_entries():
    text = REGISTRY.read_text()
    entries = []
    for block in re.findall(r"QtObject\s*\{([^{}]*)\}", text, re.DOTALL):
        if 'readonly property string component:' not in block:
            continue
        values = {}
        for key in ("id", "label", "icon", "component", "title", "category", "description"):
            match = re.search(rf'readonly property string {key}:\s*(?:qsTr\()?"([^"]+)"\)?', block)
            if match:
                values[key] = match.group(1)
        values["keywords"] = re.search(r"readonly property list<string> keywords:\s*\[([^]]*)\]", block, re.DOTALL)
        entries.append(values)
    return entries


def test_registry_components_exist():
    entries = _registry_entries()
    assert entries, "no panes parsed from PaneRegistry.qml"
    for entry in entries:
        assert (CC / entry["component"]).is_file(), f"pane {entry['id']}: missing {entry['component']}"


def test_registry_ids_unique_and_labels_sane():
    entries = _registry_entries()
    ids = [e["id"] for e in entries]
    assert len(ids) == len(set(ids)), f"duplicate pane ids: {ids}"
    for entry in entries:
        label = entry["label"]
        assert re.fullmatch(r"[a-z]+", label), f"bad pane label: {label}"


def test_registry_discovery_metadata_is_complete_and_categories_resolve():
    text = REGISTRY.read_text()
    categories = set(re.findall(r'property string id:\s*"([^"]+)";\s*readonly property string title:', text))
    for entry in _registry_entries():
        assert entry.get("title"), f"pane {entry['id']}: missing title"
        assert entry.get("description"), f"pane {entry['id']}: missing description"
        assert entry.get("keywords") and entry["keywords"].group(1).strip(), f"pane {entry['id']}: missing search keywords"
        assert entry.get("category") in categories, f"pane {entry['id']}: unknown category {entry.get('category')}"


def test_registry_categories_are_unique_nonempty_and_grouped():
    text = REGISTRY.read_text()
    category_block = text.split("readonly property list<QtObject> categories:", 1)[1].split(
        "readonly property list<QtObject> panes:", 1
    )[0]
    categories = re.findall(
        r'property string id:\s*"([^"]+)";\s*readonly property string title:',
        category_block,
    )
    entries = _registry_entries()
    pane_categories = [entry["category"] for entry in entries]

    assert len(categories) == len(set(categories)), f"duplicate categories: {categories}"
    assert set(categories) == set(pane_categories), "every category must have panes and every pane must have a category"
    assert all(pane_categories.count(category) > 0 for category in categories)

    seen = set()
    previous = None
    for category in pane_categories:
        if category != previous:
            assert category not in seen, f"category {category} is split across navigation groups"
            seen.add(category)
            previous = category


def test_search_targets_resolve_to_registered_panes_and_appearance_sections():
    text = REGISTRY.read_text()
    target_block = text.split("readonly property list<QtObject> searchTargets:", 1)[1].split("]", 1)[0]
    targets = re.findall(r"QtObject\s*\{([^{}]*)\}", target_block, re.DOTALL)
    ids = set()
    panes = {entry["id"] for entry in _registry_entries()}
    appearance = (CC / "appearance" / "AppearancePane.qml").read_text()
    for block in targets:
        values = {}
        for key in ("id", "title", "pane", "section", "keywords"):
            match = re.search(rf'readonly property string {key}:\s*(?:qsTr\()?"([^"]*)"', block)
            assert match, f"search target missing {key}: {block}"
            values[key] = match.group(1)
        assert values["id"] not in ids, f"duplicate search target id: {values['id']}"
        ids.add(values["id"])
        assert values["title"], f"search target {values['id']}: missing title"
        assert values["keywords"], f"search target {values['id']}: missing keywords"
        assert values["pane"] in panes, f"search target {values['id']}: unknown pane"
        if values["pane"] == "appearance":
            assert re.search(rf'"{re.escape(values["section"])}"', appearance), (
                f"search target {values['id']}: unknown Appearance section"
            )


def test_settings_search_has_keyboard_entry_and_layered_escape():
    search = (CC / "SettingsSearch.qml").read_text()
    assert 'replace(/\\s+/g, " ").trim()' in search
    factory = WINDOW_FACTORY.read_text()
    assert 'sequences: ["Ctrl+,"]' in factory
    assert "Qt.Key_Down" in search and "Qt.Key_Up" in search
    assert "Qt.Key_Return" in search and "Qt.Key_Escape" in search
    assert "searchQuery.length > 0" in factory


def test_compact_settings_rail_shortens_osd_label_and_keeps_full_accessible_name():
    nav = (CC / "NavRail.qml").read_text()
    assert 'paneId === "osd" ? qsTr("OSD") : title' in nav
    assert "compactTitle: root.compactTitle(pane.id, pane.title)" in nav
    assert "text: item.compactTitle" in nav
    assert 'Accessible.name: item.active ? qsTr("%1, current Settings page").arg(item.title) : item.title' in nav


def test_appearance_section_routes_use_the_sidebar_component_scope():
    appearance = (CC / "appearance" / "AppearancePane.qml").read_text()
    keys = re.search(r"readonly property var _sectionKeys:\s*\[([^]]*)\]", appearance)
    assert keys, "Appearance section ids must remain explicit"
    section_ids = re.findall(r'"([A-Za-z]+)"', keys.group(1))
    sidebar_map = re.search(r"readonly property var sections:\s*\(\{(.*?)\}\)", appearance, re.DOTALL)
    assert sidebar_map, "sidebar component must expose its scoped section items"
    for section_id in section_ids:
        assert re.search(rf"\b{re.escape(section_id)}:\s*{re.escape(section_id)}Section\b", sidebar_map.group(1)), (
            f"sidebar section map is missing {section_id}"
        )
    assert "root.sectionItems[key]" in appearance
    assert "root.sectionScroll = sidebarFlickable" in appearance
    assert "flickable.contentY = Math.max" in appearance

def test_registered_panes_take_shared_session():
    for entry in _registry_entries():
        text = (CC / entry["component"]).read_text()
        assert ("required property Session session" in text
                or "required property CC.Session session" in text), (
            f"pane {entry['id']}: must declare `required property [CC.]Session session`"
        )


def test_session_type_never_shadowed():
    # `import qs.modules.welcome` brings a second `Session` name (its
    # singleton) into scope. A pane that imports it must qualify the
    # session property (`CC.Session`); unqualified, the loader's session
    # value fails assignment and the pane renders blank (system pane).
    for entry in _registry_entries():
        text = (CC / entry["component"]).read_text()
        if "import qs.modules.welcome" in text:
            assert "required property CC.Session session" in text, (
                f"pane {entry['id']}: imports qs.modules.welcome, so the session "
                "property must be qualified as `CC.Session`"
            )


def test_terminal_settings_uses_cli_report_and_change_contract():
    pane = (CC / "terminal" / "TerminalPane.qml").read_text()
    assert '["horneroctl", "--json", "config", "default-apps", "list"]' in pane
    assert 'data.terminals_available' in pane
    assert 'data.terminal_shell_id' in pane
    assert '"default-apps", "set", "terminal", id, "--yes"' in pane
    assert 'Install Kitty, Alacritty, or Ghostty' in pane


def test_terminal_settings_keeps_supported_choices_visible_and_marks_missing_apps():
    pane = (CC / "terminal" / "TerminalPane.qml").read_text()
    assert 'TerminalCard { terminalId: "kitty" }' in pane
    assert 'TerminalCard { terminalId: "alacritty" }' in pane
    assert 'TerminalCard { terminalId: "ghostty" }' in pane
    assert "Repeater {" not in pane, "fixed terminal options should share one full-width layout"
    assert "property var installedTerminals: []" in pane
    assert "function availableTerminalIds(value: var): var" in pane
    assert 'Array.isArray(value) ? value : String(value || "").split(",")' in pane
    assert 'supported.indexOf(id) >= 0 && ids.indexOf(id) < 0' in pane
    assert "root.installedTerminals = root.availableTerminalIds(data.terminals_available)" in pane
    assert "readonly property bool installed: root.installedTerminals.indexOf(terminalId) >= 0" in pane
    assert 'qsTr("Not installed")' in pane
    assert 'qsTr("Unavailable")' in pane
    assert 'qsTr("Selected")' in pane
    assert 'qsTr("Use")' in pane
    assert "Layout.fillWidth: true" in pane
    assert "Layout.minimumWidth: root.actionColumnWidth" in pane
    assert "Layout.preferredWidth: root.actionColumnWidth" in pane
    assert "Layout.maximumWidth: root.actionColumnWidth" in pane
    assert "Layout.minimumWidth: Appearance.font.size.extraLarge * 1.5" in pane
    assert "Layout.preferredWidth: Appearance.font.size.extraLarge * 1.5" in pane
    assert "Layout.maximumWidth: Appearance.font.size.extraLarge * 1.5" in pane
    assert "enabled: terminalCard.installed && terminalCard.terminalId !== root.selectedTerminal && !root.busy" in pane
    assert 'Accessible.name: terminalCard.terminalId === root.selectedTerminal ? qsTr("%1 is the default terminal").arg(terminalCard.terminalId)' in pane


def test_repeated_control_center_action_columns_share_a_stable_width():
    terminal = (CC / "terminal" / "TerminalPane.qml").read_text()
    power = (CC / "power" / "PowerPane.qml").read_text()
    system = (CC / "system" / "SystemPane.qml").read_text()

    for pane in (terminal, power, system):
        assert "readonly property real actionColumnWidth: Config.controlCenter.actionColumnWidth" in pane
        assert "Layout.minimumWidth: root.actionColumnWidth" in pane
        assert "Layout.preferredWidth: root.actionColumnWidth" in pane
        assert "Layout.maximumWidth: root.actionColumnWidth" in pane

    config = (ROOT / "config" / "ControlCenterConfig.qml").read_text()
    assert "readonly property real actionColumnWidth: 136" in config


def test_system_action_tiles_keep_one_right_aligned_action_rail():
    pane = (CC / "system" / "SystemPane.qml").read_text()
    action_tile = pane.split("component ActionTile:", 1)[1].split("// ── Stat row", 1)[0]
    assert "Layout.fillWidth: true" in action_tile
    assert 'text: qsTr("Run")' in action_tile
    assert "Layout.minimumWidth: root.actionColumnWidth" in action_tile
    assert "Layout.maximumWidth: root.actionColumnWidth" in action_tile


def test_audio_stream_controls_listen_to_pipewire_volume_notifications():
    pane = (CC / "audio" / "AudioPane.qml").read_text()
    assert "function onAudioChanged()" not in pane
    assert pane.count("target: modelData?.audio") == 2
    assert pane.count("function onVolumesChanged()") == 2


def test_terminal_settings_uses_available_rounded_clipping_component():
    pane = (CC / "terminal" / "TerminalPane.qml").read_text()
    assert "import qs.modules.controlcenter" in pane
    assert "required property Session session" in pane
    assert "StyledClippingRect {" in pane
    assert "ClippingRectangle {" not in pane
    assert "radius: Appearance.rounding.normal" in pane
    assert "radius: border.innerRadius" not in pane


def test_power_actions_keep_a_stable_confirmation_column():
    pane = (CC / "power" / "PowerPane.qml").read_text()
    action = pane.split("TextButton {", 1)[1].split("\n            }", 1)[0]
    assert "text: tile.armed ? qsTr(\"Confirm\") : qsTr(\"Run\")" in action
    assert "Layout.minimumWidth: root.actionColumnWidth" in action
    assert "Layout.preferredWidth: root.actionColumnWidth" in action
    assert "Layout.maximumWidth: root.actionColumnWidth" in action


def test_system_lock_action_description_is_compositor_neutral():
    pane = (CC / "system" / "SystemPane.qml").read_text()
    assert 'description: qsTr("Activate the configured lock screen immediately")' in pane
    assert 'description: qsTr("Activate hyprlock immediately")' not in pane


def test_power_tiles_keep_variable_icons_from_shifting_the_label_column():
    pane = (CC / "power" / "PowerPane.qml").read_text()
    tile = pane.split("component PowerTile:", 1)[1].split("ClippingRectangle {", 1)[0]
    icon = tile.split("MaterialIcon {", 1)[1].split("StyledText {", 1)[0]
    slot_width = "Appearance.font.size.extraLarge * 1.5"

    assert icon.count(f"Layout.minimumWidth: {slot_width}") == 1
    assert icon.count(f"Layout.preferredWidth: {slot_width}") == 1
    assert icon.count(f"Layout.maximumWidth: {slot_width}") == 1
    assert "horizontalAlignment: Text.AlignHCenter" in icon


def test_audio_device_labels_keep_a_stable_icon_column():
    pane = (CC / "audio" / "AudioPane.qml").read_text()
    slot_width = "Appearance.font.size.extraLarge * 1.5"

    for section in ("outputRowLayout", "inputRowLayout"):
        row = pane.split(f"id: {section}", 1)[1].split("StyledText {", 1)[0]
        icon = row.split("MaterialIcon {", 1)[1]
        for constraint in ("minimumWidth", "preferredWidth", "maximumWidth"):
            assert f"Layout.{constraint}: {slot_width}" in icon
        assert "horizontalAlignment: Text.AlignHCenter" in icon


def test_control_center_navigation_uses_keyboard_accessible_interactive_controls():
    nav = (CC / "NavRail.qml").read_text()
    nav_items = nav.split("component NavItem:", 1)[1]
    assert "Interactive {" in nav_items
    assert "Accessible.role: Accessible.Button" in nav_items
    assert "Accessible.name: item.active ? qsTr(\"%1, current Settings page\").arg(item.title) : item.title" in nav_items
    assert 'Accessible.description: qsTr("Open the %1 Settings page").arg(item.title)' in nav_items
    assert "Keys.onReturnPressed" not in nav_items, "use the shared Interactive keyboard contract"

    float_action = nav.split("sourceComponent: StyledRect {", 1)[1].split("MaterialIcon {", 1)[0]
    assert "Interactive {" in float_action
    assert 'Accessible.name: qsTr("Float Settings window")' in float_action


def test_control_center_window_factory_activates_new_and_reused_settings_windows():
    factory = (CC / "WindowFactory.qml").read_text()
    create_body = factory.split("function create(parent: Item, props: var): void {", 1)[1].split("function closeAll()", 1)[0]
    reuse_path = create_body.split("if (windows.length > 0) {", 1)[1].split("\n        }\n        const win", 1)[0]
    new_window_path = create_body.split("const win = controlCenter.createObject", 1)[1].split("\n        root.syncCompanion();", 1)[0]
    assert "root.focusSettingsWindow(existing)" in reuse_path
    assert "root.focusSettingsWindow(win)" in new_window_path
    assert "requestActivate()" not in factory


def test_control_center_retries_focus_while_compositor_registers_settings_toplevel():
    factory = (CC / "WindowFactory.qml").read_text()
    assert "property var pendingFocusWindow: null" in factory
    assert "property int focusAttemptsRemaining: 0" in factory
    assert "root.focusAttemptsRemaining = 10" in factory
    assert "interval: 120" in factory
    assert "repeat: true" in factory
    assert "onTriggered: root.tryFocusSettingsWindow()" in factory
    assert "Compositor.activeWindowAppId === \"org.quickshell\"" in factory
    assert "root.pendingFocusWindow === win" in factory
    assert "did not become focused after retries" in factory


def test_compositor_can_focus_a_shell_window_on_supported_backends():
    compositor = (ROOT / "services" / "Compositor.qml").read_text()
    assert "function focusWindowByAppIdAndTitlePrefix(appId: string, titlePrefix: string): bool" in compositor
    assert "Niri.windows.find" in compositor
    assert "focusMatchingHyprlandClient" in compositor
    assert "hyprlandAddress(client.address)" in compositor
    assert "return window === null ? false : focusWindowFor(window);" in compositor


def test_control_center_focus_uses_live_hyprland_identity_before_dispatch():
    compositor = (ROOT / "services" / "Compositor.qml").read_text()
    focus = compositor.split("function focusWindowByAppIdAndTitlePrefix", 1)[1].split(
        "function closeWindowFor", 1
    )[0]
    assert 'command: ["hyprctl", "-j", "clients"]' in compositor
    assert "item.class === appId" in compositor
    assert 'String(item.title ?? "").startsWith(titlePrefix)' in compositor
    assert "focuswindow address:${hyprlandAddress(client.address)}" in compositor
    assert focus.index("hyprlandClientsProcess.running = true") < focus.index("return true;"), (
        "Hyprland focus must query a fresh client snapshot before dispatching"
    )
    assert "focuswindow title:" not in compositor, "title-only selectors can focus another app"


def test_hyprland_window_actions_normalize_addresses_before_dispatch():
    compositor = (ROOT / "services" / "Compositor.qml").read_text()
    assert 'function hyprlandAddress(windowId: var): string' in compositor
    assert 'address.startsWith("0x") ? address : `0x${address}`' in compositor

    focus = compositor.split("function focusWindow(windowId: var): bool", 1)[1].split(
        "function closeWindow(windowId: var): bool", 1
    )[0]
    close = compositor.split("function closeWindow(windowId: var): bool", 1)[1].split(
        "function hyprlandAddress", 1
    )[0]
    floating = compositor.split("function toggleWindowFloating(window: var): bool", 1)[1].split(
        "function toggleFullscreen()", 1
    )[0]

    assert "const address = hyprlandAddress(windowId);" in focus
    assert "focuswindow address:${address}" in focus
    assert "const address = hyprlandAddress(windowId);" in close
    assert "closewindow address:${address}" in close
    assert "const address = hyprlandAddress(windowIdFor(window));" in floating
    assert "togglefloating address:${address}" in floating
    assert "address:0x${windowId}" not in compositor


def test_no_dead_wrappers_in_panes():
    hits = []
    for path in CC.rglob("*.qml"):
        text = path.read_text()
        for dead in DEAD_WRAPPERS:
            if dead in text:
                hits.append(f"{path.relative_to(ROOT)}: {dead}")
    assert not hits, f"retired wrappers invoked by panes:\n" + "\n".join(hits)


def test_dynamic_settings_window_is_visible_on_creation():
    text = WINDOW_FACTORY.read_text()
    window = text[text.index("FloatingWindow {"):]
    assert "visible: true" in window, (
        "QWindow starts hidden by default; without visible: true the close "
        "handler immediately destroys Settings after creation"
    )


def test_settings_close_releases_window_and_uses_registered_titles():
    factory = WINDOW_FACTORY.read_text()
    close = factory.split("function closeWindow(win: var): void", 1)[1].split("function prune()", 1)[0]
    assert close.index("root.forget(win)") < close.index("win.destroy()"), (
        "unregister a floating Settings window before deferred destruction so an immediate reopen can create it"
    )
    assert "property int registryToken: 0" in factory
    assert "w.registryToken !== token" in factory, "window cleanup must not depend on QML wrapper identity"
    assert "function forget(win: var)" in factory, "FloatingWindow is not a QQuickItem"
    assert "return w && w.visible" in factory, "prune windows that were hidden before destruction completed"
    assert factory.count("root.closeWindow(win)") >= 3, "Escape, WM close, and ControlCenter close must share cleanup"
    assert "cc.session.activeTitle" in factory, "window titles should use canonical pane names (for example, VPN)"

    title = (CC / "WindowTitle.qml").read_text()
    session = (CC / "Session.qml").read_text()
    assert "readonly property string activeTitle: PaneRegistry.getById(active)?.title ?? active" in session
    assert "root.session.activeTitle" in title
    assert "WindowFactory.closeWindow(QsWindow.window)" in title
