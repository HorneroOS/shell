pragma ComponentBehavior: Bound

import ".."
import "../components"
import "../../keybinds"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Keybinds (shell#236, COMPETITIVE gap #5): every
// active bind from `horneroctl hardware keyboard rebind list` (live from
// Hyprland, grouped by purpose), search in English or Spanish, and the
// rebind editor. On the factory Lua config rebinds go to the
// config-owned overlay (~/.config/hypr/hornero-keybinds.lua) through
// `rebind set|reset|undo`; hyprlang configs keep keybindings-user.conf.
// Factory and personal keybinding files are never edited. Conflicts are
// named before saving and can be swapped; every change can be undone.
// The Overlay section holds the keybinding overlay's settings.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property string query: ""
    property var editTarget: null
    property string newCombo: ""
    property bool recording: false

    readonly property var groups: Keybinds.grouped(root.query)
    readonly property var conflict: root.editTarget && root.newCombo.trim() !== "" ? Keybinds.conflictFor(root.newCombo, root.editTarget.combo) : null
    readonly property var summonEntry: {
        for (const e of Keybinds.entries) {
            if (e.submap === "" && e.combo === Keybinds.summonCombo)
                return e;
        }
        return null;
    }
    readonly property bool canEdit: Keybinds.managed

    function editable(entry: var): bool {
        return root.canEdit && entry && entry.submap === "" && entry.source !== "live";
    }

    function startEdit(entry: var): void {
        root.editTarget = entry;
        root.newCombo = "";
    }

    function stopRecording(): void {
        if (root.recording)
            Keybinds.endCapture();
        root.recording = false;
    }

    function apply(swap: bool): void {
        if (!root.editTarget || root.newCombo.trim() === "")
            return;
        root.stopRecording();
        Keybinds.rebind(root.editTarget.combo, root.newCombo.trim(), swap);
        root.editTarget = null;
        root.newCombo = "";
    }

    function setOverlay(key: string, value: bool): void {
        Config.keybinds.overlay[key] = value;
        Config.save();
    }

    Component.onCompleted: Keybinds.refresh()
    Component.onDestruction: root.stopRecording()

    // One apply policy (docs/CONTROL-CENTER-APPLY.md): every rebind,
    // disable and reset applies at once and offers Undo on the shared
    // strip. Undo runs `rebind undo`, which restores the exact previous
    // overlay (swaps included), and it outlives this pane.
    Connections {
        target: Keybinds

        function onWritten(ok: bool, message: string, what: string, undoArgv: var): void {
            if (what === "")
                return;
            if (ok && undoArgv.length > 0)
                Undo.offerCommand("keybind", what, undoArgv, qsTr("Undo restores the previous keybindings."));
            else if (!ok)
                Undo.report("keybind", qsTr("Keybinding was not changed"), message);
        }
    }

    Connections {
        target: Undo

        function onCommandFinished(key: string, ok: bool): void {
            if (key === "keybind")
                Keybinds.refresh();
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
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "keybinds"
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Keybinds.error !== "" ? Keybinds.error : qsTr("%1 keybindings · %2").arg(Keybinds.entries.length).arg(Keybinds.live ? qsTr("live from Hyprland") : qsTr("from config files"))
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                // --- Overlay -------------------------------------------------
                ChannelPanel {
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Glyph {
                                name: "command"
                                color: Signal.palette.signal
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Keybinding overlay")
                                font.weight: Appearance.font.weight.strong
                                color: Signal.palette.ink
                            }

                            TextButton {
                                text: qsTr("Open overlay")
                                type: TextButton.Filled
                                onClicked: Keybinds.openOverlay("")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: root.summonEntry ? qsTr("Summon key") : qsTr("No bind opens the overlay; bind `horneroctl hardware keyboard keys` to a combo.")
                                color: Signal.palette.inkMuted
                                font.pointSize: Appearance.font.size.small
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: root.summonEntry ? root.summonEntry.keys : []

                                Keycap {
                                    required property string modelData

                                    text: modelData
                                    accent: true
                                }
                            }

                            TextButton {
                                visible: root.editable(root.summonEntry)
                                text: qsTr("Change")
                                type: TextButton.Tonal
                                onClicked: root.startEdit(root.summonEntry)
                            }
                        }

                        SwitchRow {
                            label: qsTr("Enter runs the highlighted bind")
                            checked: Keybinds.settings.runOnEnter
                            onToggled: checked => root.setOverlay("runOnEnter", checked)
                        }

                        SwitchRow {
                            label: qsTr("Close the overlay after running a bind")
                            checked: Keybinds.settings.closeAfterRun
                            onToggled: checked => root.setOverlay("closeAfterRun", checked)
                        }

                        SwitchRow {
                            label: qsTr("Show submap binds (resize, gaps, overview)")
                            checked: Keybinds.settings.showSubmaps
                            onToggled: checked => root.setOverlay("showSubmaps", checked)
                        }

                        SwitchRow {
                            label: qsTr("Show mouse binds")
                            checked: Keybinds.settings.showMouse
                            onToggled: checked => root.setOverlay("showMouse", checked)
                        }

                        SwitchRow {
                            label: qsTr("Compact rows")
                            checked: Keybinds.settings.compact
                            onToggled: checked => root.setOverlay("compact", checked)
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }

                            TextButton {
                                text: qsTr("Reset overlay settings")
                                type: TextButton.Tonal
                                onClicked: {
                                    Undo.offerValues("keybinds-overlay", qsTr("Overlay settings reset"), [
                                        {
                                            "obj": Config.keybinds.overlay,
                                            "keys": ["runOnEnter", "closeAfterRun", "showSubmaps", "showMouse", "compact"]
                                        }
                                    ], "");
                                    for (const k of ["runOnEnter", "closeAfterRun", "showSubmaps", "showMouse"])
                                        Config.keybinds.overlay[k] = true;
                                    Config.keybinds.overlay.compact = false;
                                    Config.save();
                                }
                            }
                        }
                    }
                }

                // --- Keybindings ---------------------------------------------
                ChannelPanel {
                    ColumnLayout {
                        id: kbCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
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
                                onClicked: Keybinds.refresh()
                            }
                        }

                        // Editor: record or type the new combo, see the conflict
                        // before saving, swap when the combo is taken.
                        StyledRect {
                            Layout.fillWidth: true
                            visible: root.editTarget !== null
                            implicitHeight: editCol.implicitHeight + Appearance.padding.large * 2
                            radius: Appearance.rounding.normal
                            color: Signal.palette.raised
                            border.width: 1
                            border.color: root.conflict ? Signal.palette.alert : Signal.palette.signal

                            Item {
                                id: recorder

                                focus: root.recording
                                Keys.onPressed: event => {
                                    event.accepted = true;
                                    if (event.key === Qt.Key_Escape) {
                                        root.stopRecording();
                                        return;
                                    }
                                    const combo = Keybinds.comboFromKey(event.key, event.modifiers);
                                    if (combo === "")
                                        return;
                                    root.newCombo = combo;
                                    root.stopRecording();
                                }
                            }

                            ColumnLayout {
                                id: editCol

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.large
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Rebind “%1” (%2) to:").arg(root.editTarget?.label ?? "").arg(root.editTarget?.combo ?? "")
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.ink
                                    wrapMode: Text.Wrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    StyledTextField {
                                        id: newComboField

                                        Layout.fillWidth: true
                                        placeholderText: root.recording ? qsTr("Press the new combo… (Esc stops)") : qsTr("SUPER + F13, then Enter")
                                        text: root.newCombo
                                        onTextChanged: root.newCombo = text
                                        onAccepted: {
                                            if (!root.conflict)
                                                root.apply(false);
                                        }
                                    }

                                    TextButton {
                                        text: root.recording ? qsTr("Recording…") : qsTr("Record")
                                        type: TextButton.Tonal
                                        onClicked: {
                                            root.recording = true;
                                            Keybinds.beginCapture();
                                            recorder.forceActiveFocus();
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.conflict !== null
                                    text: root.conflict ? qsTr("%1 is already “%2” (%3). Swap them, or pick another combo.").arg(root.conflict.combo).arg(root.conflict.label).arg(root.conflict.category) : ""
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.alert
                                    wrapMode: Text.Wrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    TextButton {
                                        visible: !!root.conflict
                                        text: qsTr("Swap")
                                        type: TextButton.Filled
                                        enabled: !Keybinds.busy
                                        onClicked: root.apply(true)
                                    }

                                    TextButton {
                                        visible: Keybinds.isLua
                                        text: qsTr("Disable bind")
                                        type: TextButton.Tonal
                                        enabled: !Keybinds.busy
                                        onClicked: {
                                            root.stopRecording();
                                            Keybinds.disable(root.editTarget.combo);
                                            root.editTarget = null;
                                        }
                                    }

                                    TextButton {
                                        text: qsTr("Cancel")
                                        type: TextButton.Tonal
                                        onClicked: {
                                            root.stopRecording();
                                            root.editTarget = null;
                                            root.newCombo = "";
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.groups

                            delegate: ColumnLayout {
                                id: group

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    Glyph {
                                        name: group.modelData.glyph
                                        color: Signal.palette.signal
                                        font.pointSize: Appearance.font.size.small
                                    }

                                    StyledText {
                                        text: group.modelData.name
                                        font.pointSize: Appearance.font.size.small
                                        font.weight: Appearance.font.weight.strong
                                        color: Signal.palette.ink
                                    }

                                    StyledText {
                                        visible: group.modelData.es !== group.modelData.name
                                        text: "· " + group.modelData.es
                                        font.pointSize: Appearance.font.size.smaller
                                        color: Signal.palette.inkFaint
                                    }

                                    StyledRect {
                                        Layout.preferredHeight: countLabel.implicitHeight + 6
                                        Layout.preferredWidth: countLabel.implicitWidth + 14
                                        color: Signal.palette.signalWell
                                        radius: Appearance.rounding.small

                                        StyledText {
                                            id: countLabel

                                            anchors.centerIn: parent
                                            text: group.modelData.rows.length
                                            font.pointSize: Appearance.font.size.smaller
                                            font.weight: Appearance.font.weight.strong
                                            color: Signal.palette.onSignalWell
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        Layout.alignment: Qt.AlignVCenter
                                        color: Signal.palette.rule
                                    }
                                }

                                Repeater {
                                    model: group.modelData.rows

                                    delegate: RowLayout {
                                        id: bindRow

                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        RowLayout {
                                            Layout.preferredWidth: 250
                                            spacing: 4

                                            Repeater {
                                                model: bindRow.modelData.keys

                                                Keycap {
                                                    required property string modelData

                                                    text: modelData
                                                    accent: bindRow.modelData.remapped
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: bindRow.modelData.label
                                                font.pointSize: Appearance.font.size.small
                                                color: Signal.palette.ink
                                                wrapMode: Text.Wrap
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                visible: bindRow.modelData.remapped || bindRow.modelData.submap !== "" || bindRow.modelData.source === "personal" || bindRow.modelData.shared > 1
                                                text: bindRow.modelData.shared > 1 ? qsTr("%1 binds share this combo; all of them fire").arg(bindRow.modelData.shared) : bindRow.modelData.remapped ? qsTr("moved from %1").arg(bindRow.modelData.original) : bindRow.modelData.submap !== "" ? qsTr("submap: %1").arg(bindRow.modelData.submap) : qsTr("personal (keybindings-user.lua)")
                                                font.pointSize: Appearance.font.size.smaller
                                                color: bindRow.modelData.shared > 1 ? Signal.palette.alert : Signal.palette.inkMuted
                                            }
                                        }

                                        TextButton {
                                            visible: root.editable(bindRow.modelData)
                                            text: qsTr("Rebind")
                                            type: TextButton.Tonal
                                            onClicked: root.startEdit(bindRow.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.groups.length === 0 && Keybinds.loaded
                            text: qsTr("No keybindings match.")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.canEdit
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: Keybinds.overrides > 0 ? qsTr("%1 rebind(s) active").arg(Keybinds.overrides) : qsTr("No rebinds; factory keybindings are active.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            TextButton {
                                visible: Keybinds.isLua && Keybinds.undoDepth > 0
                                enabled: !Keybinds.busy
                                text: qsTr("Undo last change")
                                type: TextButton.Tonal
                                onClicked: Keybinds.undo()
                            }

                            TextButton {
                                visible: Keybinds.overrides > 0
                                enabled: !Keybinds.busy
                                text: qsTr("Reset to defaults")
                                type: TextButton.Tonal
                                onClicked: Keybinds.reset()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: Keybinds.lastMessage !== ""
                            text: Keybinds.lastMessage
                            font.pointSize: Appearance.font.size.small
                            color: Keybinds.lastOk ? Signal.palette.inkMuted : Signal.palette.alert
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.canEdit ? (Keybinds.isLua ? qsTr("Rebinds live in ~/.config/hypr/hornero-keybinds.lua, which the Hornero config applies on top of keybindings.lua and your keybindings-user.lua; neither file is edited. Changes apply live and can be undone.") : qsTr("Rebinds are stored as user overrides in keybindings-user.conf and apply live; factory keybindings are never edited.")) : qsTr("This session's keybindings are read-only here: rebinding needs the Hornero Hyprland config. The list shows what the session actually runs.")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
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
}
