pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// The keybinding overlay's sheet: header, search, grouped list, the
// in-place rebind panel and the footer. KeybindsOverlay.qml owns the
// layer window, IPC and the run-after-close timer.
StyledRect {
    id: sheet

    property string initialQuery: ""

    signal closeRequested
    signal runRequested(var entry)

    property string query: sheet.initialQuery
    property int selected: 0
    // idle | capture | confirm
    property string mode: "idle"
    property var target: null
    property string captured: ""
    readonly property var conflict: sheet.captured !== "" && sheet.target ? Keybinds.conflictFor(sheet.captured, sheet.target.combo) : null
    readonly property bool compact: Keybinds.settings.compact

    readonly property var groups: Keybinds.grouped(sheet.query)
    readonly property var rows: Keybinds.flatten(sheet.groups)
    readonly property var current: sheet.rows.length > 0 ? sheet.rows[Math.max(0, Math.min(sheet.selected, sheet.rows.length - 1))] : null
    // Flat list for the view: group headers interleaved with rows.
    readonly property var items: {
        const out = [];
        let index = 0;
        for (const g of sheet.groups) {
            out.push({ header: true, group: g });
            for (const r of g.rows)
                out.push({ header: false, entry: r, index: index++ });
        }
        return out;
    }

    color: Signal.palette.panel
    radius: Appearance.rounding.large
    border.width: 1
    border.color: Signal.palette.ruleStrong

    opacity: 0
    scale: Appearance.anim.spatial ? 0.97 : 1
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
        search.forceActiveFocus();
    }
    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.short
        }
    }
    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.short
            easing.bezierCurve: Appearance.anim.curves.settleFast
        }
    }

    // Swallow clicks so the scrim behind does not close the sheet.
    MouseArea {
        anchors.fill: parent
    }

    onQueryChanged: sheet.selected = 0
    onSelectedChanged: sheet.reveal()

    function reveal(): void {
        for (let i = 0; i < sheet.items.length; i++) {
            if (!sheet.items[i].header && sheet.items[i].index === sheet.selected) {
                list.positionViewAtIndex(i, ListView.Contain);
                if (i > 0 && sheet.items[i - 1].header && sheet.selected === sheet.items[i].index)
                    list.positionViewAtIndex(i - 1, ListView.Contain);
                return;
            }
        }
    }

    function move(delta: int): void {
        if (sheet.rows.length === 0)
            return;
        sheet.selected = (sheet.selected + delta + sheet.rows.length) % sheet.rows.length;
    }

    function runCurrent(): void {
        const e = sheet.current;
        if (!e || !Keybinds.settings.runOnEnter)
            return;
        if (Keybinds.settings.closeAfterRun) {
            runLater.entry = e;
            sheet.closeRequested();
            runLater.restart();
        } else {
            Keybinds.run(e);
        }
    }

    function startCapture(): void {
        const e = sheet.current;
        if (!e || e.submap !== "" || e.source === "live" || !Keybinds.managed)
            return;
        sheet.target = e;
        sheet.captured = "";
        sheet.mode = "capture";
        Keybinds.beginCapture();
        catcher.forceActiveFocus();
        captureTimeout.restart();
    }

    function endCapture(): void {
        captureTimeout.stop();
        Keybinds.endCapture();
    }

    function cancelCapture(): void {
        sheet.endCapture();
        sheet.mode = "idle";
        sheet.target = null;
        sheet.captured = "";
        search.forceActiveFocus();
    }

    function save(swap: bool): void {
        if (!sheet.target || sheet.captured === "")
            return;
        Keybinds.rebind(sheet.target.combo, sheet.captured, swap);
        sheet.query = sheet.captured;
        search.text = sheet.captured;
        sheet.cancelCapture();
    }

    // A stuck capture must never strand the session in the empty submap.
    Timer {
        id: captureTimeout

        interval: 15000
        onTriggered: sheet.cancelCapture()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large + Appearance.padding.normal
        spacing: Appearance.spacing.normal

        // --- header ----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                implicitWidth: 40
                implicitHeight: 40
                radius: Appearance.rounding.normal
                color: Signal.palette.signalWell

                Glyph {
                    anchors.centerIn: parent
                    name: "keyboard"
                    color: Signal.palette.onSignalWell
                    size: Appearance.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Plate {
                    text: qsTr("Keybindings")
                    color: Signal.palette.signal
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Keybinds.loading && !Keybinds.loaded ? qsTr("Reading the compositor…") : Keybinds.error !== "" ? Keybinds.error : qsTr("%1 binds · %2").arg(sheet.rows.length).arg(Keybinds.live ? qsTr("live from Hyprland") : qsTr("from config files"))
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                visible: Keybinds.summonCombo !== ""
                spacing: 4

                StyledText {
                    text: qsTr("Summon")
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.smaller
                }

                Repeater {
                    model: Keybinds.summonCombo.split("+").map(p => p.trim()).filter(p => p !== "")

                    Keycap {
                        required property string modelData

                        text: modelData
                        compact: true
                    }
                }
            }
        }

        // --- search ----------------------------------------------------
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: search.implicitHeight + Appearance.padding.normal
            radius: Appearance.rounding.normal
            color: Signal.palette.sunken
            border.width: 1
            border.color: search.activeFocus ? Signal.palette.focus : Signal.palette.rule

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.normal
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.small

                Glyph {
                    name: "search"
                    color: Signal.palette.inkMuted
                    size: Appearance.font.size.normal
                }

                StyledTextField {
                    id: search

                    Layout.fillWidth: true
                    text: sheet.initialQuery
                    placeholderText: qsTr("Search binds, actions or groups · buscar atajos…")
                    font.pointSize: Appearance.font.size.normal
                    trapTab: false
                    onTextChanged: sheet.query = text

                    Keys.onPressed: event => {
                        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        if (event.key === Qt.Key_Escape) {
                            if (search.text !== "")
                                search.text = "";
                            else
                                sheet.closeRequested();
                        } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N) || event.key === Qt.Key_Tab) {
                            sheet.move(1);
                        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P) || event.key === Qt.Key_Backtab) {
                            sheet.move(-1);
                        } else if (event.key === Qt.Key_PageDown) {
                            sheet.move(8);
                        } else if (event.key === Qt.Key_PageUp) {
                            sheet.move(-8);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sheet.runCurrent();
                        } else if (ctrl && event.key === Qt.Key_E) {
                            sheet.startCapture();
                        } else if (ctrl && event.key === Qt.Key_D) {
                            if (sheet.current && sheet.current.submap === "" && sheet.current.source !== "live" && Keybinds.isLua)
                                Keybinds.disable(sheet.current.combo);
                        } else if (ctrl && event.key === Qt.Key_Z) {
                            if (Keybinds.undoDepth > 0)
                                Keybinds.undo();
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        // --- list ------------------------------------------------------
        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: sheet.items
            spacing: sheet.compact ? 0 : 2
            boundsBehavior: Flickable.StopAtBounds

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: Loader {
                id: itemLoader

                required property var modelData

                width: list.width
                sourceComponent: modelData.header ? headerItem : rowItem

                Component {
                    id: headerItem

                    RowLayout {
                        spacing: Appearance.spacing.small

                        Item {
                            implicitHeight: sheet.compact ? 6 : 10
                        }

                        Glyph {
                            name: itemLoader.modelData.group.glyph
                            color: Signal.palette.signal
                            size: Appearance.font.size.normal
                        }

                        StyledText {
                            text: itemLoader.modelData.group.name
                            color: Signal.palette.ink
                            font.pointSize: Appearance.font.size.small
                            font.weight: Appearance.font.weight.strong
                        }

                        StyledText {
                            visible: itemLoader.modelData.group.es !== itemLoader.modelData.group.name
                            text: "· " + itemLoader.modelData.group.es
                            color: Signal.palette.inkFaint
                            font.pointSize: Appearance.font.size.smaller
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Signal.palette.rule
                        }

                        StyledText {
                            text: itemLoader.modelData.group.rows.length
                            color: Signal.palette.inkMuted
                            font.pointSize: Appearance.font.size.smaller
                            tabular: true
                        }
                    }
                }

                Component {
                    id: rowItem

                    StyledRect {
                        id: row

                        readonly property var entry: itemLoader.modelData.entry
                        readonly property bool isSelected: itemLoader.modelData.index === sheet.selected
                        readonly property bool isTarget: sheet.mode !== "idle" && sheet.target && sheet.target.combo === row.entry.combo && row.entry.submap === ""

                        implicitHeight: rowLayout.implicitHeight + (sheet.compact ? 4 : 10)
                        radius: Appearance.rounding.normal
                        color: row.isSelected ? Signal.palette.signalWell : rowMouse.containsMouse ? Signal.palette.raised : "transparent"
                        border.width: row.isTarget ? 1 : 0
                        border.color: Signal.palette.signal

                        Accessible.role: Accessible.ListItem
                        Accessible.name: qsTr("%1: %2").arg(row.entry.combo).arg(row.entry.label)
                        Accessible.selected: row.isSelected

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                sheet.selected = itemLoader.modelData.index;
                                search.forceActiveFocus();
                            }
                            onDoubleClicked: sheet.runCurrent()
                        }

                        RowLayout {
                            id: rowLayout

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.rightMargin: Appearance.padding.normal
                            spacing: Appearance.spacing.normal

                            RowLayout {
                                Layout.preferredWidth: 270
                                spacing: 4

                                Repeater {
                                    model: row.entry.keys

                                    Keycap {
                                        required property string modelData

                                        text: modelData
                                        accent: row.entry.remapped
                                        compact: sheet.compact
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
                                    text: row.entry.label
                                    color: row.isSelected ? Signal.palette.onSignalWell : Signal.palette.ink
                                    font.pointSize: Appearance.font.size.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: row.entry.remapped
                                    text: qsTr("moved from %1").arg(row.entry.original)
                                    color: Signal.palette.inkMuted
                                    font.pointSize: Appearance.font.size.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            Chip {
                                visible: row.entry.shared > 1
                                text: qsTr("shared ×%1").arg(row.entry.shared)
                                alert: true
                            }

                            Chip {
                                visible: row.entry.source === "personal"
                                text: qsTr("personal")
                            }

                            Chip {
                                visible: row.entry.submap !== ""
                                text: row.entry.submap
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: sheet.rows.length === 0 && Keybinds.loaded
                text: qsTr("No keybindings match “%1”.").arg(sheet.query)
                color: Signal.palette.inkMuted
            }
        }

        // --- rebind panel ------------------------------------------------
        StyledRect {
            Layout.fillWidth: true
            visible: sheet.mode !== "idle"
            implicitHeight: capCol.implicitHeight + Appearance.padding.large * 2
            radius: Appearance.rounding.normal
            color: Signal.palette.raised
            border.width: 1
            border.color: sheet.conflict ? Signal.palette.alert : Signal.palette.signal

            // Receives every key while capturing (Hyprland sits in the
            // empty hornero_capture submap, so bound combos land here).
            Item {
                id: catcher

                focus: sheet.mode !== "idle"
                Keys.onPressed: event => {
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape) {
                        sheet.cancelCapture();
                        return;
                    }
                    if (sheet.mode === "confirm") {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (!sheet.conflict)
                                sheet.save(false);
                        } else if (event.key === Qt.Key_S && sheet.conflict) {
                            sheet.save(true);
                        } else if (event.key === Qt.Key_R || event.key === Qt.Key_Backspace) {
                            sheet.captured = "";
                            sheet.mode = "capture";
                            Keybinds.beginCapture();
                            captureTimeout.restart();
                        }
                        return;
                    }
                    const combo = Keybinds.comboFromKey(event.key, event.modifiers);
                    if (combo === "")
                        return;
                    sheet.captured = combo;
                    sheet.mode = "confirm";
                    // Release Hyprland as soon as the combo is known.
                    sheet.endCapture();
                }
            }

            ColumnLayout {
                id: capCol

                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: sheet.mode === "capture" ? qsTr("Press the new combo for “%1”… (Esc cancels)").arg(sheet.target?.label ?? "") : sheet.conflict ? qsTr("%1 is already “%2” (%3).").arg(sheet.captured).arg(sheet.conflict.label).arg(sheet.conflict.category) : qsTr("Move “%1” from %2 to %3?").arg(sheet.target?.label ?? "").arg(sheet.target?.combo ?? "").arg(sheet.captured)
                    color: sheet.conflict ? Signal.palette.alert : Signal.palette.ink
                    font.pointSize: Appearance.font.size.small
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    visible: sheet.mode === "confirm"
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: sheet.captured.split("+").map(p => p.trim()).filter(p => p !== "")

                        Keycap {
                            required property string modelData

                            text: modelData
                            accent: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        visible: !sheet.conflict
                        text: qsTr("Save (Enter)")
                        type: TextButton.Filled
                        onClicked: sheet.save(false)
                    }

                    TextButton {
                        visible: !!sheet.conflict
                        text: qsTr("Swap them (S)")
                        type: TextButton.Filled
                        onClicked: sheet.save(true)
                    }

                    TextButton {
                        text: qsTr("Try another (R)")
                        type: TextButton.Tonal
                        onClicked: {
                            sheet.captured = "";
                            sheet.mode = "capture";
                            Keybinds.beginCapture();
                            catcher.forceActiveFocus();
                        }
                    }

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Tonal
                        onClicked: sheet.cancelCapture()
                    }
                }
            }
        }

        // --- footer ------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: Keybinds.lastMessage !== "" ? Keybinds.lastMessage : Keybinds.managed ? qsTr("↑↓ select · Enter run · Ctrl+E rebind · Ctrl+D disable · Ctrl+Z undo · Esc close") : qsTr("↑↓ select · Enter run · Esc close · rebinding needs the Hornero config")
                color: Keybinds.lastOk ? Signal.palette.inkMuted : Signal.palette.alert
                font.pointSize: Appearance.font.size.smaller
                elide: Text.ElideRight
            }

            TextButton {
                visible: sheet.current && sheet.current.submap === "" && sheet.current.source !== "live" && Keybinds.managed && sheet.mode === "idle"
                text: qsTr("Rebind")
                type: TextButton.Tonal
                onClicked: sheet.startCapture()
            }

            TextButton {
                visible: Keybinds.isLua && Keybinds.undoDepth > 0
                enabled: !Keybinds.busy
                text: qsTr("Undo")
                type: TextButton.Tonal
                onClicked: Keybinds.undo()
            }
        }
    }

    component Chip: StyledRect {
        property alias text: chipLabel.text
        property bool alert: false

        implicitWidth: chipLabel.implicitWidth + 12
        implicitHeight: chipLabel.implicitHeight + 4
        radius: Appearance.rounding.full
        color: alert ? Signal.palette.alertWell : Signal.palette.cueWell

        StyledText {
            id: chipLabel

            anchors.centerIn: parent
            color: parent.alert ? Signal.palette.onAlertWell : Signal.palette.onCueWell
            font.pointSize: Appearance.font.size.smaller
        }
    }
}
