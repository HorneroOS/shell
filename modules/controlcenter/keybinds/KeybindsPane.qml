pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Keybinds (shell#236): the session's keybindings
// through `horneroctl hardware keyboard keys` (hyprlang or Lua
// provider, hornero#176), with local search, plus the rebind editor
// (slice 2) through `horneroctl hardware keyboard rebind`. Overrides
// live in the user's keybindings-user.conf; factory binds are never
// edited. Lua sessions stay read-only and say so. The keys call sets
// HORNERO_BYPASS_QUICKSHELL=1 so its open-Settings shortcut cannot
// recurse into this very pane.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property var binds: []
    property string query: ""
    property string statusText: qsTr("Reading keybindings…")
    property bool managed: false
    property int overrides: 0
    property string editOld: ""
    property string newCombo: ""
    property string actionText: ""
    property bool resetArmed: false

    function comboOf(line: string): string {
        let s = line;
        if (s.startsWith("[")) {
            const i = s.indexOf("] ");
            if (i >= 0)
                s = s.slice(i + 2);
        }
        const a = s.indexOf(" -> ");
        if (a < 0)
            return "";
        let c = s.slice(0, a).trim();
        if (c.startsWith("+ "))
            c = c.slice(2);
        return c;
    }

    function categoryOf(line: string): string {
        if (!line.startsWith("["))
            return qsTr("General");
        const i = line.indexOf("] ");
        return i > 1 ? line.slice(1, i) : qsTr("General");
    }

    // Friendly action label: Lua binds arrive as hl.dsp.* expressions,
    // hyprlang binds as dispatcher text; show the command for exec_cmd
    // and the bare dispatcher otherwise.
    function actionOf(line: string): string {
        const a = line.indexOf(" -> ");
        if (a < 0)
            return line;
        let action = line.slice(a + 4).trim();
        const exec = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\)$/.exec(action);
        if (exec)
            return exec[1];
        if (action.startsWith("hl.dsp."))
            action = action.slice(7);
        return action;
    }

    function chipsOf(line: string): var {
        return comboOf(line).split("+").map(p => p.trim()).filter(p => p !== "");
    }

    // Shown binds grouped by their [Category] prefix, first-seen order.
    readonly property var grouped: {
        const byName = {};
        const order = [];
        for (const line of shown) {
            const cat = categoryOf(line);
            if (byName[cat] === undefined) {
                byName[cat] = [];
                order.push(cat);
            }
            byName[cat].push(line);
        }
        return order.map(name => ({ name, rows: byName[name] }));
    }

    function applyRebind(): void {
        if (root.editOld === "" || root.newCombo.trim() === "")
            return;
        root.actionText = qsTr("Applying…");
        actionProc.out = "";
        actionProc.command = ["horneroctl", "hardware", "keyboard", "rebind", "set", "--old", root.editOld, "--new", root.newCombo, "--yes", "--json"];
        actionProc.running = true;
    }

    function applyReset(): void {
        root.actionText = qsTr("Resetting…");
        actionProc.out = "";
        actionProc.command = ["horneroctl", "hardware", "keyboard", "rebind", "reset", "--yes", "--json"];
        actionProc.running = true;
    }

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return binds;
        return binds.filter(l => l.toLowerCase().includes(q));
    }

    function refresh(): void {
        keysProc.out = "";
        keysProc.command = ["env", "HORNERO_BYPASS_QUICKSHELL=1", "horneroctl", "hardware", "keyboard", "keys", "--json"];
        keysProc.running = true;
        rebindProc.out = "";
        rebindProc.command = ["horneroctl", "hardware", "keyboard", "rebind", "status", "--json"];
        rebindProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: keysProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                keysProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(keysProc.out.trim());
                root.binds = payload.ok ? (payload.message ?? "").toString().split("\n").filter(l => l.trim() !== "") : [];
                root.statusText = payload.ok ? qsTr("%1 keybindings · from %2").arg(root.binds.length).arg((payload.data ?? {}).file ?? "") : payload.message.toString();
            } catch (e) {
                root.binds = [];
                root.statusText = qsTr("horneroctl keyboard keys unavailable on this system.");
            }
        }
    }

    Process {
        id: rebindProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                rebindProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(rebindProc.out.trim());
                const d = payload.data ?? {};
                root.managed = (d.managed ?? "false") === "true";
                root.overrides = parseInt(d.overrides ?? "0") || 0;
            } catch (e) {
                root.managed = false;
                root.overrides = 0;
            }
        }
    }

    Process {
        id: actionProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                actionProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(actionProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
                if (payload.ok) {
                    root.editOld = "";
                    root.newCombo = "";
                    root.resetArmed = false;
                }
            } catch (e) {
                root.actionText = qsTr("horneroctl rebind unavailable on this system.");
            }
            root.refresh();
        }
    }

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Keybinds")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: kbCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: kbCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledTextField {
                                Layout.fillWidth: true
                                placeholderText: qsTr("Search keybindings…")
                                onTextChanged: root.query = text
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        Repeater {
                            model: root.grouped

                            delegate: ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    MaterialIcon {
                                        text: "keyboard"
                                        color: Colours.palette.m3primary
                                        font.pointSize: Appearance.font.size.small
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pointSize: Appearance.font.size.small
                                        font.weight: 600
                                        color: Colours.palette.m3onSurface
                                    }

                                    StyledRect {
                                        Layout.preferredHeight: countLabel.implicitHeight + 6
                                        Layout.preferredWidth: countLabel.implicitWidth + 14
                                        color: Colours.palette.m3primaryContainer
                                        radius: Appearance.rounding.full

                                        StyledText {
                                            id: countLabel

                                            anchors.centerIn: parent
                                            text: modelData.rows.length
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
                                    model: modelData.rows

                                    delegate: RowLayout {
                                        required property string modelData

                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        RowLayout {
                                            Layout.preferredWidth: 250
                                            spacing: 4

                                            Repeater {
                                                model: root.chipsOf(modelData)

                                                Keycap {
                                                    required property string modelData

                                                    text: modelData
                                                }
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.actionOf(modelData)
                                            font.pointSize: Appearance.font.size.small
                                            color: Colours.palette.m3onSurface
                                            wrapMode: Text.Wrap
                                        }

                                        TextButton {
                                            visible: root.managed && root.comboOf(modelData) !== ""
                                            text: qsTr("Rebind")
                                            type: TextButton.Tonal
                                            onClicked: {
                                                root.editOld = root.comboOf(modelData);
                                                root.newCombo = "";
                                                root.resetArmed = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.managed && root.editOld !== ""
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Rebind %1 to:").arg(root.editOld)
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledTextField {
                                    id: newComboField

                                    Layout.fillWidth: true
                                    placeholderText: qsTr("SUPER + F13")
                                    text: root.newCombo
                                    onTextChanged: root.newCombo = text
                                    onAccepted: root.applyRebind()
                                }

                                TextButton {
                                    text: qsTr("Apply")
                                    type: TextButton.Filled
                                    enabled: root.newCombo.trim() !== ""
                                    onClicked: root.applyRebind()
                                }

                                TextButton {
                                    text: qsTr("Cancel")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.editOld = "";
                                        root.newCombo = "";
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.managed
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: root.overrides > 0 ? qsTr("%1 user override(s) active").arg(root.overrides) : qsTr("No user overrides; factory keybindings are active.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }

                            TextButton {
                                visible: root.overrides > 0
                                text: root.resetArmed ? qsTr("Confirm reset") : qsTr("Reset to defaults")
                                type: TextButton.Tonal
                                onClicked: {
                                    if (root.resetArmed)
                                        root.applyReset();
                                    else
                                        root.resetArmed = true;
                                }
                            }

                            TextButton {
                                visible: root.resetArmed
                                text: qsTr("Keep overrides")
                                type: TextButton.Tonal
                                onClicked: root.resetArmed = false
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionText !== ""
                            text: root.actionText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.shown.length === 0
                            text: qsTr("No keybindings match.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.managed
                            text: qsTr("Rebinds are stored as user overrides and apply live; factory keybindings are never edited. This list always shows what the session actually runs.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.managed
                            text: qsTr("This session's keybindings are read-only here (Lua configuration); the list shows what the session actually runs.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }

    // One physical-looking key, same treatment as the Welcome cheatsheet.
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
}
