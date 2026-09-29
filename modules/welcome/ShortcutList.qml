import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.welcome
import QtQuick
import QtQuick.Layouts

// Filterable keybinding cheatsheet shared by the Welcome Shortcuts
// page. Lives outside pages/*Page.qml on purpose: the welcome page
// contract bans Layout.* attached properties in page files, so all
// layout lives here next to ActionCard. Data comes from the
// ShortcutHints singleton (same manifest as the Welcome badges).
ColumnLayout {
    id: root

    property string query: ""
    property string selectedGroup: ""

    spacing: Appearance.spacing.small

    function focusSearch(): void {
        search.forceActiveFocus();
    }

    readonly property bool loaded: ShortcutHints.ready

    readonly property var groups: {
        const byName = {};
        const order = [];
        for (const e of ShortcutHints.entries) {
            const keys = root.badge(e);
            if (keys === "")
                continue;
            const g = root.groupFor(e);
            if (byName[g] === undefined) {
                byName[g] = [];
                order.push(g);
            }
            const label = root.describe(e);
            if (!byName[g].some(r => r.keys === keys && r.label === label))
                byName[g].push({ keys, parts: root.chips(e), label });
        }
        return order.map(name => ({ name, rows: byName[name] }));
    }

    readonly property var groupNames: {
        const names = [];
        for (const g of root.groups)
            names.push(g.name);
        return names;
    }

    readonly property int totalCount: {
        let n = 0;
        for (const g of root.groups)
            n += g.rows.length;
        return n;
    }

    function filteredCount(): int {
        let n = 0;
        for (const g of root.groups)
            for (const r of g.rows)
                if (root.matches(r))
                    n++;
        return n;
    }

    // Dispatcher/id prefixes mapped to cheatsheet groups. First match
    // wins; anything unknown lands in System rather than vanishing.
    function groupFor(entry: var): string {
        const id = String(entry.id || "");
        const disp = String(entry.dispatcher || "");
        if (/^(exec|app)-/.test(id) || disp === "exec" && /launch|terminal|kitty|foot/.test(id))
            return qsTr("Launch & apps");
        if (/^ipc-/.test(id))
            return qsTr("Shell");
        if (/workspace|specialworkspace|overview|changegroupactive/.test(id + disp))
            return qsTr("Workspaces");
        if (/movefocus|movewindow|resizeactive|fullscreen|floating|pin|killactive|centerwindow|layout|split/.test(id + disp))
            return qsTr("Windows");
        return qsTr("System");
    }

    function iconFor(group: string): string {
        if (group === qsTr("Launch & apps"))
            return "apps";
        if (group === qsTr("Shell"))
            return "terminal";
        if (group === qsTr("Workspaces"))
            return "workspaces";
        if (group === qsTr("Windows"))
            return "select_window";
        return "settings";
    }

    function humanize(id: string): string {
        return String(id).replace(/^(exec|ipc|app)-/, "").replace(/[-_:]+/g, " ").replace(/^./, c => c.toUpperCase());
    }

    // Keycap glyphs: the manifest carries raw XKB key names, so the
    // cheatsheet translates symbolic ones here into what is printed on
    // the key. Unknown names pass through untouched (never blank).
    function keyGlyph(key: string): string {
        const glyphs = {
            "apostrophe": "'",
            "comma": ",",
            "period": ".",
            "minus": "-",
            "equal": "=",
            "slash": "/",
            "question": "?",
            "Return": "Enter",
            "return": "Enter",
            "escape": "Esc",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "mouse:272": "Left click",
            "mouse:273": "Right click",
            "mouse_down": "Scroll down",
            "mouse_up": "Scroll up"
        };
        if (glyphs[key] !== undefined)
            return glyphs[key];
        if (key.indexOf("XF86") === 0)
            return key.substring(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        return key;
    }

    // Human-readable action labels. The manifest only carries machine ids
    // (dispatcher + args), so the cheatsheet translates them here using the
    // exact wording of the HorneroOS/config keybindings.conf comments.
    // Unknown pairs fall back to a prettified dispatcher + args and are
    // never hidden or left as raw machine ids.
    function describe(entry: var): string {
        const disp = String(entry.dispatcher || "");
        const args = String(entry.args || "").trim();
        const exact = {
            "killactive|": "Close active window",
            "centerwindow|": "Move window to center",
            "togglefloating|": "Toggle floating",
            "fullscreen|0": "Toggle fullscreen",
            "fullscreen|1": "Toggle maximize",
            "pin|": "Pin window (all workspaces)",
            "exit|": "Exit Hyprland",
            "focuscurrentorlast|": "Focus current or last window",
            "togglegroup|": "Toggle group",
            "lockactivegroup|toggle": "Toggle group lock",
            "changegroupactive|f": "Focus next window in group",
            "changegroupactive|b": "Focus previous window in group",
            "togglespecialworkspace|magic": "Toggle scratchpad",
            "movewindow|": "Drag to move window",
            "resizewindow|": "Drag to resize window",
            "submap|resize": "Window-resize keys",
            "submap|reset": "Reset keys",
            "scrolloverview:overview|toggle": "Toggle overview",
            "scrolloverview:overview|select": "Select in overview",
            "scrolloverview:overview|off": "Hide overview",
            "layoutmsg|promote": "Promote focused window into its own column",
            "layoutmsg|togglefit": "Toggle focus fit behavior (center/fit)",
            "layoutmsg|move -col": "Move viewport left one column",
            "layoutmsg|move +col": "Move viewport right one column",
            "layoutmsg|swapcol l": "Swap column with left neighbor",
            "layoutmsg|swapcol r": "Swap column with right neighbor",
            "layoutmsg|colresize +conf": "Widen column",
            "layoutmsg|colresize -conf": "Narrow column",
            "layoutmsg|colresize +0.05": "Widen column (fine)",
            "layoutmsg|colresize -0.05": "Narrow column (fine)",
            "layoutmsg|fit active": "Fit active window to column",
            "layoutmsg|fit visible": "Fit all visible columns"
        };
        if (exact[disp + "|" + args] !== undefined)
            return exact[disp + "|" + args];

        const dir = {
            "l": "left",
            "r": "right",
            "u": "up",
            "d": "down"
        };
        if (disp === "workspace") {
            if (args === "e+1")
                return "Next workspace";
            if (args === "e-1")
                return "Previous workspace";
            return "Go to workspace " + args;
        }
        if (disp === "movetoworkspace") {
            if (args === "special:magic")
                return "Move window to scratchpad";
            return "Move window to workspace " + args;
        }
        if (disp === "movetoworkspacesilent")
            return "Move window to workspace " + args + " (silent)";
        if ((disp === "movefocus" || disp === "movewindow") && dir[args] !== undefined)
            return (disp === "movefocus" ? "Focus window " : "Move window ") + dir[args];
        if (disp === "resizeactive")
            return "Resize active window (" + args.split(/\s+/).join(", ") + ")";
        if (disp === "scrolloverview:navigate")
            return "Navigate overview " + args;
        if (/^(exec|ipc|app)-/.test(String(entry.id || "")))
            return root.humanize(String(entry.id));

        // Generic fallback: prettified dispatcher plus raw args.
        const pretty = disp.replace(/[-_:]+/g, " ").replace(/^./, c => c.toUpperCase());
        return args === "" ? pretty : pretty + ": " + args;
    }

    function chips(entry: var): var {
        const parts = [];
        for (const m of (entry.mods || [])) {
            if (typeof m === "string" && m !== "")
                parts.push(m);
        }
        if (typeof entry.key === "string" && entry.key !== "")
            parts.push(root.keyGlyph(entry.key));
        return parts;
    }

    function badge(entry: var): string {
        return root.chips(entry).join(" + ");
    }

    function matches(row: var): bool {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return true;
        return row.keys.toLowerCase().indexOf(q) !== -1 || row.label.toLowerCase().indexOf(q) !== -1;
    }

    SearchBar {
        id: search

        Layout.fillWidth: true
        placeholderText: qsTr("Search shortcuts…")
        onTextChanged: root.query = text
    }

    RowLayout {
        id: chipRow

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        FilterChip {
            label: qsTr("All")
            selected: root.selectedGroup === ""
            onClicked: root.selectedGroup = ""
        }

        Repeater {
            model: root.groupNames

            FilterChip {
                required property var modelData

                label: modelData
                selected: root.selectedGroup === modelData
                onClicked: root.selectedGroup = root.selectedGroup === modelData ? "" : modelData
            }
        }
    }

    StyledText {
        visible: root.loaded && root.totalCount > 0
        text: root.query.trim() === "" && root.selectedGroup === "" ? qsTr("%1 shortcuts").arg(root.totalCount) : qsTr("%1 of %2").arg(root.filteredCount()).arg(root.totalCount)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.smaller
        Layout.alignment: Qt.AlignHCenter
    }

    ColumnLayout {
        visible: root.loaded && root.groups.length === 0
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "keyboard"
            font.pointSize: Appearance.font.size.large * 2
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No keybindings found. Regenerate the shortcuts manifest.")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
        }
    }

    Repeater {
        model: root.groups

        StyledRect {
            id: groupCard

            required property var modelData

            Layout.fillWidth: true
            visible: (root.selectedGroup === "" || groupCard.modelData.name === root.selectedGroup) && groupCard.filteredRows.length > 0

            readonly property var filteredRows: groupCard.modelData.rows.filter(r => root.matches(r))

            color: Colours.palette.m3surfaceContainer
            radius: Appearance.rounding.large
            implicitHeight: cardColumn.implicitHeight + Appearance.padding.normal * 2

            ColumnLayout {
                id: cardColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: root.iconFor(groupCard.modelData.name)
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.small
                    }

                    StyledText {
                        text: groupCard.modelData.name
                        font.pointSize: Appearance.font.size.small
                        font.weight: 600
                        color: Colours.palette.m3onSurface
                        clip: true
                    }

                    StyledRect {
                        Layout.preferredHeight: countLabel.implicitHeight + 6
                        Layout.preferredWidth: countLabel.implicitWidth + 14
                        color: Colours.palette.m3primaryContainer
                        radius: Appearance.rounding.full

                        StyledText {
                            id: countLabel

                            anchors.centerIn: parent
                            text: groupCard.filteredRows.length
                            font.pointSize: Appearance.font.size.smaller
                            font.weight: 600
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.alignment: Qt.AlignVCenter
                        color: Colours.palette.m3outlineVariant
                    }
                }

                Repeater {
                    model: groupCard.filteredRows

                    RowLayout {
                        id: shortcutRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.preferredWidth: 230
                            spacing: 4

                            Repeater {
                                model: shortcutRow.modelData.parts

                                Keycap {
                                    required property var modelData

                                    text: modelData
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: shortcutRow.modelData.label
                            font.pointSize: Appearance.font.size.smaller
                            color: Colours.palette.m3onSurface
                            clip: true
                        }
                    }
                }
            }
        }
    }

    // One physical-looking key: the signature of this reference.
    component Keycap: StyledRect {
        required property string text

        implicitWidth: capLabel.implicitWidth + 16
        implicitHeight: capLabel.implicitHeight + 8

        color: Colours.palette.m3surfaceContainerHighest
        radius: Appearance.rounding.small
        border.width: 1
        border.color: Colours.palette.m3outlineVariant

        StyledText {
            id: capLabel

            anchors.centerIn: parent
            text: parent.text
            mono: true
            font.pointSize: Appearance.font.size.smaller
            font.weight: 600
            color: Colours.palette.m3onSurface
        }
    }

    // Single-select pill for the group filter row.
    component FilterChip: StyledRect {
        id: chip

        required property string label
        required property bool selected
        signal clicked

        Layout.preferredHeight: chipLabel.implicitHeight + 10
        Layout.preferredWidth: chipLabel.implicitWidth + 24

        color: chip.selected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
        radius: Appearance.rounding.full
        border.width: 1
        border.color: chip.selected ? "transparent" : Colours.palette.m3outlineVariant

        StyledText {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.label
            font.pointSize: Appearance.font.size.smaller
            font.weight: chip.selected ? 600 : 400
            color: chip.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
