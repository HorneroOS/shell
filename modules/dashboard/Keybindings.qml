import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Keys tab: live keybinding cheatsheet rendered from the generated
// manifest `$XDG_DATA_HOME/hornero/shortcuts.json` (same source as the
// Welcome badges). Global bindings only; unknown structure resolves to
// the empty state, never invented rows.
//
// Focus: the dashboard surface only takes keyboard focus while a
// text-taking panel is open (see Drawers keyboardFocus); this tab
// autofocuses its search whenever it becomes current so typing just
// works, launcher-style.
Item {
    id: root

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight

    property var groups: []
    property bool loaded: false
    property string query: ""
    property bool isCurrent: false

    onIsCurrentChanged: {
        if (isCurrent)
            search.forceActiveFocus();
    }

    readonly property string manifestPath: `${Paths.data}/shortcuts.json`

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

    function chips(entry: var): var {
        const parts = [];
        for (const m of (entry.mods || [])) {
            if (typeof m === "string" && m !== "")
                parts.push(m);
        }
        if (typeof entry.key === "string" && entry.key !== "")
            parts.push(entry.key);
        return parts;
    }

    function badge(entry: var): string {
        return root.chips(entry).join(" + ");
    }

    function parse(text: string): void {
        const groups = {};
        const order = [];
        try {
            const o = JSON.parse(text);
            if (o !== null && typeof o === "object" && !Array.isArray(o) && o.schemaVersion === 1 && Array.isArray(o.entries)) {
                for (const e of o.entries) {
                    if (e === null || typeof e !== "object" || Array.isArray(e))
                        continue;
                    if (typeof e.id !== "string" || e.id === "" || e.submap !== "")
                        continue;
                    const keys = root.badge(e);
                    if (keys === "")
                        continue;
                    const g = root.groupFor(e);
                    if (groups[g] === undefined) {
                        groups[g] = [];
                        order.push(g);
                    }
                    const label = root.humanize(e.id);
                    if (!groups[g].some(r => r.keys === keys && r.label === label))
                        groups[g].push({ keys, parts: root.chips(e), label });
                }
            }
        } catch (e) {
            // Malformed manifest: groups stay empty, empty state shows.
        }
        root.groups = order.map(name => ({ name, rows: groups[name] }));
        root.loaded = true;
    }

    function matches(row: var): bool {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return true;
        return row.keys.toLowerCase().indexOf(q) !== -1 || row.label.toLowerCase().indexOf(q) !== -1;
    }

    FileView {
        path: root.manifestPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: {
            root.groups = [];
            root.loaded = true;
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.small

        SearchBar {
            id: search

            Layout.fillWidth: true
            placeholderText: qsTr("Search shortcuts…")
            onTextChanged: root.query = text
        }

        StyledText {
            visible: root.loaded && root.totalCount > 0
            text: root.query.trim() === "" ? qsTr("%1 shortcuts").arg(root.totalCount) : qsTr("%1 of %2").arg(root.filteredCount()).arg(root.totalCount)
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
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
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
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
                visible: groupCard.filteredRows.length > 0

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
                            Layout.fillWidth: true
                            text: groupCard.modelData.name
                            font.pointSize: Appearance.font.size.small
                            font.weight: 600
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
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
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // One physical-looking key: the signature of this tab.
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
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            font.weight: 600
            color: Colours.palette.m3onSurface
        }
    }
}
