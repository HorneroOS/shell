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


def test_pane_stack_layout_has_geometry_for_translated_pages():
    panes = (CC / "Panes.qml").read_text()
    layout = panes.split("Item {\n        id: layout", 1)[1].split("\n    }", 1)[0]
    assert "width: root.width" in layout
    assert "height: root.height * PaneRegistry.count" in layout
    assert "y: -root.session.activeIndex * root.height" in layout
    pane = layout.split("Pane {", 1)[1].split("\n            }", 1)[0]
    assert "y: index * root.height" in pane
    assert "height: root.height" in pane
    assert "width: root.width" in pane


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


def test_terminal_settings_loading_is_bounded_and_reports_empty_process_output():
    pane = (CC / "terminal" / "TerminalPane.qml").read_text()
    assert "property bool listTimedOut: false" in pane
    assert "interval: 15000" in pane
    assert "interval: 2000" in pane
    assert 'qsTr("Terminal settings request timed out.")' in pane
    assert 'qsTr("Terminal settings returned no data.")' in pane
    assert "if (root.listTimedOut)\n                    return;" in pane
    assert "root.installedTerminals = [];" in pane.split("id: listTimeout", 1)[1].split("Process {", 1)[0]
    timeout = pane.split("id: listTimeout", 1)[1].split("Timer {", 1)[0]
    assert "running: root.loading || listProc.running" in timeout
    assert "if (root.loading && !root.listAnswered)" in timeout
    assert "root.statusMessage = qsTr(\"Terminal settings request timed out.\");" in timeout
    assert "if (!listProc.running)" not in timeout
    assert "if (listProc.running)" in timeout
    assert "listKillTimeout.start();" in timeout
    refresh = pane.split("function refresh", 1)[1].split("function applyTerminal", 1)[0]
    assert "listTimeout.restart()" not in refresh
    kill_timeout = pane.split("id: listKillTimeout", 1)[1].split("Process {", 1)[0]
    assert "listProc.signal(9)" in kill_timeout
    stream_finished = pane.split("onStreamFinished:", 1)[1].split("onExited:", 1)[0]
    assert "listTimeout.stop()" not in stream_finished
    list_exit = pane.split("onExited:", 1)[1].split("\n        }", 1)[0]
    assert "root.loading = false;" in list_exit
    assert "listKillTimeout.stop();" in list_exit
    assert "root.listTimedOut = false;" not in list_exit


def test_terminal_settings_keeps_supported_choices_visible_and_marks_missing_apps():
    pane = (CC / "terminal" / "TerminalPane.qml").read_text()
    assert "Repeater {" not in pane, "fixed terminal options should share one full-width layout"
    assert "property var installedTerminals: []" in pane
    assert "function availableTerminalIds(value: var): var" in pane
    assert 'Array.isArray(value) ? value : String(value || "").split(",")' in pane
    assert 'supported.indexOf(id) >= 0 && ids.indexOf(id) < 0' in pane
    assert "root.installedTerminals = root.availableTerminalIds(data.terminals_available)" in pane
    assert "readonly property bool installed: root.installedTerminals.indexOf(terminalId) >= 0" in pane
    assert 'qsTr("Not installed")' in pane
    assert 'qsTr("Install first")' in pane
    assert 'qsTr("Selected")' in pane
    assert 'qsTr("Use this")' in pane
    assert "Layout.fillWidth: true" in pane
    assert "ActionCell {" in pane
    card = pane.split("component TerminalCard:", 1)[1].split("Component.onCompleted", 1)[0]
    assert "anchors.right: parent.right" in card
    assert "width: action.actionColumnWidth" in card
    assert "anchors.right: action.left" in card
    assert "width: Appearance.font.size.extraLarge * 1.5" in card
    assert "controlEnabled: terminalCard.installed && terminalCard.terminalId !== root.selectedTerminal && !root.busy" in pane
    assert 'accessibilityName: terminalCard.terminalId === root.selectedTerminal ? qsTr("%1 is the default terminal").arg(terminalCard.terminalId)' in pane
    terminal_rows = re.findall(r'TerminalCard\s*\{([^{}]*)\}', pane, re.DOTALL)
    assert len(terminal_rows) == 3
    assert all("Layout.fillWidth: true" in row for row in terminal_rows), (
        "each terminal row must fill its SectionContainer so action cells share the same trailing edge"
    )


def test_control_center_action_cells_share_a_trailing_edge():
    action_cell = (CC / "components" / "ActionCell.qml").read_text()

    assert "readonly property real actionColumnWidth: Math.max(" in action_cell
    assert "Config.controlCenter.actionColumnWidth * Appearance.font.size.scale" in action_cell
    assert "Layout.minimumWidth: actionColumnWidth" in action_cell
    assert "Layout.preferredWidth: actionColumnWidth" in action_cell
    assert "Layout.maximumWidth: actionColumnWidth" in action_cell
    assert "anchors.right: parent.right" in action_cell
    assert "anchors.verticalCenter: parent.verticalCenter" in action_cell
    assert "anchors.centerIn: parent" not in action_cell
    assert "width: implicitWidth" in action_cell
    assert "disabled: root.disabled || !root.controlEnabled" in action_cell

    # These panes contain repeatable setting rows with trailing actions; keep
    # them on the shared cell so label changes cannot shift the action center.
    for pane in ("terminal/TerminalPane.qml", "system/SystemPane.qml", "power/PowerPane.qml"):
        assert "ActionCell {" in (CC / pane).read_text(), f"{pane} must use the shared action cell"


def test_control_center_split_keeps_details_space_on_compact_windows():
    split_layout = (CC / "components" / "SplitPaneLayout.qml").read_text()

    assert "property real leftWidthRatio: 0.4" in split_layout
    assert "property int leftMinimumWidth: 420" in split_layout
    assert "Layout.minimumWidth: Math.min(root.leftMinimumWidth, parent.width * root.leftWidthRatio)" in split_layout


def test_flickable_column_content_uses_its_implicit_height():
    for relative in (
        "components/DeviceList.qml",
        "components/DeviceDetails.qml",
        "bluetooth/Settings.qml",
        "launcher/Settings.qml",
        "network/NetworkSettings.qml",
        "network/EthernetSettings.qml",
        "network/WirelessSettings.qml",
        "network/VpnSettings.qml",
    ):
        source = (CC / relative).read_text()
        assert "height: implicitHeight" in source, f"{relative} must expose its Flickable content height"

    for relative, layout_id in (
        ("network/NetworkingPane.qml", "leftContent"),
        ("dashboard/DashboardPane.qml", "dashboardLayout"),
        ("taskbar/TaskbarPane.qml", "sidebarLayout"),
        ("appearance/AppearancePane.qml", "sidebarLayout"),
        ("audio/AudioPane.qml", "leftContent"),
        ("audio/AudioPane.qml", "contentLayout"),
        ("launcher/LauncherPane.qml", "debugLayout"),
    ):
        source = (CC / relative).read_text()
        layout = source.split(f"id: {layout_id}", 1)[1].split("\n                }", 1)[0]
        assert "height: implicitHeight" in layout, f"{relative} {layout_id} must expose its Flickable content height"

    section = (ROOT / "components" / "SectionContainer.qml").read_text()
    assert "id: contentColumn" in section
    assert "height: implicitHeight" in section
    header = (CC / "components" / "SettingsHeader.qml").read_text()
    assert "id: column" in header
    assert "height: implicitHeight" in header


def test_repeated_control_center_action_columns_share_a_stable_width():
    terminal = (CC / "terminal" / "TerminalPane.qml").read_text()
    power = (CC / "power" / "PowerPane.qml").read_text()
    system = (CC / "system" / "SystemPane.qml").read_text()

    action_cell = (CC / "components" / "ActionCell.qml").read_text()
    for pane in (terminal, power, system):
        assert "ActionCell {" in pane

    assert "Layout.minimumWidth: actionColumnWidth" in action_cell
    assert "Layout.preferredWidth: actionColumnWidth" in action_cell
    assert "Layout.maximumWidth: actionColumnWidth" in action_cell
    assert "anchors.right: parent.right" in action_cell
    assert "anchors.verticalCenter: parent.verticalCenter" in action_cell
    assert "width: implicitWidth" in action_cell
    assert "height: implicitHeight" in action_cell
    assert "Layout.alignment: Qt.AlignVCenter" in action_cell

    config = (ROOT / "config" / "ControlCenterConfig.qml").read_text()
    assert "readonly property real actionColumnWidth: 136" in config


def test_system_action_tiles_keep_one_trailing_action_edge():
    pane = (CC / "system" / "SystemPane.qml").read_text()
    action_tile = pane.split("component ActionTile:", 1)[1].split("// ── Stat row", 1)[0]
    assert "Layout.fillWidth: true" in action_tile
    assert action_tile.count("Layout.minimumWidth: Appearance.font.size.extraLarge * 1.5") == 1
    assert action_tile.count("Layout.preferredWidth: Appearance.font.size.extraLarge * 1.5") == 1
    assert action_tile.count("Layout.maximumWidth: Appearance.font.size.extraLarge * 1.5") == 1
    assert 'text: qsTr("Run")' in action_tile
    assert "ActionCell {" in action_tile
    assert all("Layout.fillWidth: true" in block for block in re.findall(r"ActionTile\s*\{([^{}]*)\}", pane, re.DOTALL)), (
        "every System action row must fill its ColumnLayout so the shared action rail is stable"
    )


def test_power_tiles_fill_the_settings_column_before_aligning_actions():
    pane = (CC / "power" / "PowerPane.qml").read_text()
    power_tiles = re.findall(r"PowerTile\s*\{([^{}]*)\}", pane, re.DOTALL)
    assert len(power_tiles) == 5
    assert all("Layout.fillWidth: true" in block for block in power_tiles), (
        "each Power row must fill its settings column so the action rail remains stable"
    )


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
    action = pane.split("ActionCell {", 1)[1].split("\n            }", 1)[0]
    assert "text: tile.armed ? qsTr(\"Confirm\") : qsTr(\"Run\")" in action
    assert "controlEnabled: !root.busy" in action


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
    create_body = factory.split("function create(parent: Item, props: var): bool {", 1)[1].split("function closeAll()", 1)[0]
    reuse_path = create_body.split("if (windows.length > 0) {", 1)[1].split("\n        }\n        const win", 1)[0]
    new_window_path = create_body.split("const win = controlCenter.createObject", 1)[1].split("\n        root.syncCompanion();", 1)[0]
    assert "root.focusSettingsWindow(existing)" in reuse_path
    assert "root.focusSettingsWindow(win)" in new_window_path
    assert "parent ?? null" in create_body
    assert "could not create Settings window" in create_body
    assert "id: dummy" not in factory
    assert "requestActivate()" not in factory


def test_welcome_settings_actions_keep_the_overlay_if_window_creation_fails():
    actions = (ROOT / "modules" / "welcome" / "Actions.qml").read_text()
    open_settings = actions.split("function openControlCenter", 1)[1].split(
        "function shellQuote", 1
    )[0]
    assert "WelcomeModule.Welcome.close();" in open_settings
    assert "if (opened)" in open_settings
    assert open_settings.index("WindowFactory.create") < open_settings.index(
        "WelcomeModule.Welcome.close();"
    )


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


def test_extensions_pane_lifecycle_goes_through_horneroctl_with_consent():
    pane = (CC / "extensions" / "ExtensionsPane.qml").read_text()
    assert "Plugins.entries" in pane and "Plugins.reload()" in pane
    # horneroctl stays the single writer: the pane never writes receipts
    # or payloads; enable/disable go through the exact CLI argv (with
    # --json first), and enable requires an inline confirmation step
    # mirroring the CLI --yes gate. Install/remove stay CLI-only.
    assert '["horneroctl", "--json", "plugin", action, pluginId,' in pane
    assert 'if (action === "install" || action === "update")' in pane
    assert 'command.push("--revision", root.catalogRevision)' in pane
    assert "pendingEnable" in pane and "Confirm enable" in pane
    assert "runLifecycle(\"enable\"" in pane and "runLifecycle(\"disable\"" in pane
    for banned in ('"plugin", "install', '"plugin", "remove',
                   "plugins-receipts"):
        assert banned not in pane, f"extensions pane must not do this itself: {banned}"
    assert "without a sandbox" in pane


def test_extensions_marketplace_section():
    pane = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
    assert "Official catalogue" in pane
    assert '"plugin", "catalog"' in pane
    assert 'runCatalogAction("install", catRow.modelData.id)' in pane
    assert "Payload SHA-256" in pane
    assert "declaredCapabilities" in pane
    assert "Confirm install" in pane
    assert "rollback_available" in pane
    assert 'Settings: %4' in pane
    # Marketplace never writes receipts itself and never enables silently.
    assert "pendingInstall" in pane
    assert 'runLifecycle("enable"' in pane  # existing consent path untouched


def test_extensions_community_registry_is_verified_read_only_cli_output():
    pane = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
    section = (ROOT / "modules/controlcenter/extensions/CommunityRegistrySection.qml").read_text()
    assert "CommunityRegistrySection" in pane
    assert '["horneroctl", "--json", "plugin", "community", "list"]' in section
    assert "root.entries = entries" in section and "env.ok !== true" in section
    assert 'typeof data.plugins !== "string"' in section
    assert "entries.some(entry => !entry" in section
    assert '(env.data && env.data.plugins) || "[]"' not in section
    assert "index signature identifies who published the list" in section
    assert "does not mean HorneroOS reviewed the code or that the code is safe" in section
    assert "has no sandbox" in section
    assert "Pinned revision" in section and "Payload SHA-256" in section
    assert "Community install, update, and rollback are unavailable until horneroctl preserves the verified revision and payload hash through those actions." in section
    # Community discovery is read-only until it has a provenance-preserving lifecycle.
    assert '"plugin", "community", "install"' not in pane + section
    assert '"plugin", "community", "enable"' not in pane + section


def test_studio_pane_is_registered_and_uses_only_horneroctl_studio():
    registry = REGISTRY.read_text(encoding="utf-8")
    assert 'readonly property string id: "studio"' in registry
    assert '"studio/StudioPane.qml"' in registry

    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert 'required property Session session' in pane
    # Fixed horneroctl argv only: no shell, no package manager, no AUR.
    assert '"horneroctl", "--json", "studio", "selection", "show"' in pane
    assert '"horneroctl", "--json", "studio", "doctor"' in pane
    assert '"horneroctl", "--json", "studio", "selection", "set"' in pane
    for forbidden in ("pacman", "paru", "yay", "sh -c", "bash -c", "pkexec"):
        assert forbidden not in pane, forbidden
    # Truthful product state: planned, no support claim, data preservation.
    assert "Studio is Planned" in pane
    assert "never deletes your files, settings, or projects" in pane
    assert "Penpot" in pane and "reference-only" in pane.lower()
    assert "REAPER" in pane and "Proprietary" in pane


def test_studio_pane_models_match_canonical_catalogue_ids():
    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    specializations = [
        "audio-music-production",
        "video-editing-post-production",
        "streaming-content-creation",
        "graphic-design-illustration",
        "photography-raw-processing",
        "3d-animation-vfx",
        "game-development",
        "maker-cad",
        "complete-creative-workstation",
        "custom-selection",
    ]
    applications = [
        "ardour", "guitarix", "carla", "audacity", "reaper", "yabridge",
        "obs-studio", "kdenlive", "blender", "krita", "gimp", "inkscape",
        "darktable", "rawtherapee", "graphite", "penpot", "scribus",
        "freecad", "godot",
    ]
    for stable_id in specializations + applications:
        assert f'"{stable_id}"' in pane, stable_id
    # Interactive rows are accessible switches with names.
    assert "SwitchRow" in pane
    assert 'Accessible.name: qsTr("Refresh Studio selection and health")' in pane


def test_studio_pane_audio_section_reuses_audio_service_without_inventing_metrics():
    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert 'qsTr("Audio routing & health")' in pane
    # Shared backend state only: no second graph service, no capture.
    assert "Audio.sink" in pane and "Audio.source" in pane and "Audio.streams" in pane
    assert "Audio.getStreamName" in pane
    assert "not exposed by this backend" in pane
    assert "no audio is recorded" in pane.lower()
    for forbidden in ("pw-dump", "pw-top", "wpctl", "pactl", "arecord", "parecord"):
        assert forbidden not in pane, forbidden
    # Empty/unsupported states are explicit accessible text.
    assert "No output device detected" in pane
    assert "No active application streams" in pane


def test_studio_pane_readiness_checklist_never_fakes_external_gates():
    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert 'qsTr("Readiness")' in pane
    assert "Selection recorded" in pane
    assert "pending evidence, not passed" in pane
    # Checklist state derives from recorded selection + doctor data only.
    assert "root.selectionState" in pane
    assert "root.doctorChecks" in pane


def test_studio_pane_performance_controls_use_only_horneroctl_mode():
    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert 'qsTr("Performance")' in pane
    # Fixed horneroctl mode argv only (HorneroOS/hornero#286/#287).
    assert '"horneroctl", "--json", "studio", "mode"' in pane
    assert '"studio", "mode", "audio", "balanced"' in pane
    assert '"studio", "mode", "audio", "low-latency", "--yes"' in pane
    assert '"studio", "mode", "audio", "advanced", "--yes"' in pane
    assert '"studio", "mode", "performance", "--yes"' in pane
    assert '"studio", "mode", "restore"' in pane
    # No privileged or tuning call may be implemented in QML.
    for forbidden in ("powerprofilesctl", "cpupower", "governor", "pkexec",
                      "systemctl", "wpctl", "pactl"):
        assert forbidden not in pane, forbidden
    # Honest UI: opt-in labels, restore of exact previous state, and no
    # performance guarantee or invented metric.
    assert "explicit opt-in" in pane
    assert "Restore previous mode" in pane
    assert "No performance improvement is guaranteed" in pane
    assert "Mode state unavailable" in pane
    assert 'Accessible.name: qsTr("Restore previous Studio mode and power profile")' in pane


def test_studio_pane_render_jobs_surface_is_typed_and_approval_gated():
    pane = (CC / "studio" / "StudioPane.qml").read_text(encoding="utf-8")
    assert 'qsTr("Render jobs (experimental)")' in pane
    # Typed horneroctl job state only (HorneroOS/hornero#289): list/log
    # reads and explicit per-job cancel; no submission or inference.
    assert '"horneroctl", "--json", "studio", "jobs", "list"' in pane
    assert '"studio", "jobs", "log", id' in pane
    assert '"studio", "jobs", "cancel", modelData.id' in pane
    assert '"studio", "jobs", "submit"' not in pane
    assert '"studio", "jobs", "run"' not in pane
    # Cancel is only offered for queued jobs and never deletes files.
    assert 'modelData.state === "queued"' in pane
    assert "never deletes source or output files" in pane
    # No agent/Companion runtime, no process inference, no shell.
    for forbidden in ("ps aux", "pgrep", "pkill", "sh -c", "bash -c",
                      "hermes", "Hermes", "companion", "Companion"):
        assert forbidden not in pane, forbidden
    # Logs come from horneroctl (redacted on read), shown as text only.
    assert "redacted log" in pane.lower()
    assert "No Studio jobs recorded yet" in pane
    assert 'Accessible.name: qsTr("Cancel queued job %1")' in pane
