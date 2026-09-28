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
Item {
    id: root

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight

    property var groups: []
    property bool loaded: false
    property string query: ""

    readonly property string manifestPath: `${Paths.data}/shortcuts.json`

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

    function humanize(id: string): string {
        return String(id).replace(/^(exec|ipc|app)-/, "").replace(/[-_:]+/g, " ").replace(/^./, c => c.toUpperCase());
    }

    function badge(entry: var): string {
        const parts = [];
        for (const m of (entry.mods || [])) {
            if (typeof m === "string" && m !== "")
                parts.push(m);
        }
        if (typeof entry.key === "string" && entry.key !== "")
            parts.push(entry.key);
        return parts.join(" + ");
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
                        groups[g].push({ keys, label });
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
            onTextChanged: root.query = text
        }

        StyledText {
            visible: root.loaded && root.groups.length === 0
            text: qsTr("No keybindings found. Regenerate the shortcuts manifest.")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.groups

            ColumnLayout {
                id: groupBox

                required property var modelData

                Layout.fillWidth: true
                spacing: 2
                visible: groupBox.filteredRows.length > 0

                readonly property var filteredRows: groupBox.modelData.rows.filter(r => root.matches(r))

                StyledText {
                    text: modelData.name
                    font.pointSize: Appearance.font.size.small
                    font.weight: 600
                    color: Colours.palette.m3primary
                }

                Repeater {
                    model: groupBox.filteredRows

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.preferredWidth: 220
                            text: modelData.keys
                            font.pointSize: Appearance.font.size.smaller
                            font.family: Appearance.font.family.mono
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.pointSize: Appearance.font.size.smaller
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
