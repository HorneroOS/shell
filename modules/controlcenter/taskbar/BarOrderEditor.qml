pragma ComponentBehavior: Bound

import "barorder.js" as BarOrder
import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// Bar section order editor for the Bars pane (shell#466). Edits the active
// layout: the bar set
// a preset wrote to bar.bars, or a screen's bar.perScreen override. Entries
// move within and across the start/center/end groups and can be hidden;
// per-entry options and unknown fields are kept, so the result stays a
// valid layout. Applying a preset replaces it, as before.
ColumnLayout {
    id: root

    // "" edits the global bar set; otherwise the override of that screen.
    property string scope: ""
    property int barIndex: 0

    readonly property var screens: BarOrder.overrideScreens(Config.bar.perScreen)
    readonly property var bars: BarOrder.barsForScope(Config.bar.bars, Config.bar.perScreen, root.scope)
    readonly property var bar: root.bars[Math.min(root.barIndex, root.bars.length - 1)] ?? null

    function commit(next: var): void {
        if (root.scope === "")
            Config.bar.bars = next;
        else
            Config.bar.perScreen = BarOrder.withScreenBars(Config.bar.perScreen, root.scope, next);
        Config.save();
    }

    function move(group: string, index: int, delta: int): void {
        root.commit(BarOrder.move(root.bars, root.barIndex, group, index, delta));
    }

    function add(id: string): void {
        root.commit(BarOrder.addEntry(root.bars, root.barIndex, "end", id));
    }

    function setEnabled(group: string, index: int, enabled: bool): void {
        root.commit(BarOrder.setEnabled(root.bars, root.barIndex, group, index, enabled));
    }

    function edgeTitle(edge: string): string {
        return edge === "top" ? qsTr("Top bar") : edge === "bottom" ? qsTr("Bottom bar") : edge === "left" ? qsTr("Left bar") : qsTr("Right bar");
    }

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    onScopeChanged: root.barIndex = 0

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Sections & order")
        font.pointSize: Appearance.font.size.normal
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Reorder or hide what each bar shows. Changes apply to the current layout right away; choosing another layout in Layout replaces them with that layout's order.")
        wrapMode: Text.WordWrap
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
    }

    // Scope: only shown when some screen has its own bar set.
    Flow {
        Layout.fillWidth: true
        visible: root.screens.length > 0
        spacing: Appearance.spacing.small

        TextButton {
            text: qsTr("All screens")
            toggle: true
            checked: root.scope === ""
            type: TextButton.Tonal
            onClicked: root.scope = ""
        }

        Repeater {
            model: root.screens

            TextButton {
                required property string modelData

                text: modelData
                toggle: true
                checked: root.scope === modelData
                type: TextButton.Tonal
                onClicked: root.scope = modelData
            }
        }
    }

    // One tab per bar of the layout.
    Flow {
        Layout.fillWidth: true
        visible: root.bars.length > 1
        spacing: Appearance.spacing.small

        Repeater {
            model: root.bars.length

            TextButton {
                required property int index

                text: root.edgeTitle(root.bars[index].edge)
                toggle: true
                checked: root.barIndex === index
                type: TextButton.Tonal
                onClicked: root.barIndex = index
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.bar === null
        text: qsTr("This layout has no bars.")
        color: Signal.palette.inkMuted
    }

    GridLayout {
        Layout.fillWidth: true
        visible: root.bar !== null
        columns: root.width > 760 ? 3 : 1
        columnSpacing: Appearance.spacing.normal
        rowSpacing: Appearance.spacing.normal

        Repeater {
            model: BarOrder.GROUPS

            StyledRect {
                id: groupCard

                required property string modelData
                readonly property var entries: root.bar ? root.bar.groups[groupCard.modelData] : []

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                implicitHeight: groupColumn.implicitHeight + Appearance.padding.large * 2
                radius: Appearance.rounding.small
                color: Signal.tPalette.raised

                ColumnLayout {
                    id: groupColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr(BarOrder.groupTitle(root.bar?.edge ?? "top", groupCard.modelData))
                        color: Signal.palette.signal
                        font.pointSize: Appearance.font.size.small
                        font.weight: 600
                    }

                    StyledText {
                        visible: groupCard.entries.length === 0
                        text: qsTr("Empty")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.small
                    }

                    Repeater {
                        model: groupCard.entries.length

                        StyledRect {
                            id: entryRow

                            required property int index
                            readonly property var entry: groupCard.entries[index]
                            readonly property var info: BarOrder.entryInfo(entryRow.entry.id)
                            readonly property bool shown: entryRow.entry.enabled !== false

                            Layout.fillWidth: true
                            implicitHeight: entryLayout.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.small
                            color: Signal.tPalette.lifted

                            RowLayout {
                                id: entryLayout

                                anchors.fill: parent
                                anchors.leftMargin: Appearance.padding.normal
                                anchors.rightMargin: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                Glyph {
                                    name: entryRow.info.icon
                                    color: entryRow.shown ? Signal.palette.ink : Signal.palette.ruleStrong
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr(entryRow.info.label)
                                    elide: Text.ElideRight
                                    color: entryRow.shown ? Signal.palette.ink : Signal.palette.ruleStrong
                                    font.strikeout: !entryRow.shown
                                }

                                IconButton {
                                    icon: "arrow-up"
                                    type: IconButton.Text
                                    accessibleName: qsTr("Move %1 earlier").arg(qsTr(entryRow.info.label))
                                    disabled: !BarOrder.canMove(root.bars, root.barIndex, groupCard.modelData, entryRow.index, -1)
                                    onClicked: root.move(groupCard.modelData, entryRow.index, -1)
                                }

                                IconButton {
                                    icon: "arrow-down"
                                    type: IconButton.Text
                                    accessibleName: qsTr("Move %1 later").arg(qsTr(entryRow.info.label))
                                    disabled: !BarOrder.canMove(root.bars, root.barIndex, groupCard.modelData, entryRow.index, 1)
                                    onClicked: root.move(groupCard.modelData, entryRow.index, 1)
                                }

                                StyledSwitch {
                                    checked: entryRow.shown
                                    Accessible.name: qsTr("Show %1").arg(qsTr(entryRow.info.label))
                                    onToggled: root.setEnabled(groupCard.modelData, entryRow.index, checked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Sections this bar does not have yet; added at the end of the bar.
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        visible: root.bar !== null && addRepeater.count > 0
        text: qsTr("Add a section")
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
    }

    Flow {
        Layout.fillWidth: true
        visible: root.bar !== null && addRepeater.count > 0
        spacing: Appearance.spacing.small

        Repeater {
            id: addRepeater

            model: root.bar ? BarOrder.missingIds(root.bars, root.barIndex) : []

            TextButton {
                required property string modelData

                text: "+ " + qsTr(BarOrder.entryInfo(modelData).label)
                type: TextButton.Tonal
                Accessible.name: qsTr("Add %1 to the bar").arg(qsTr(BarOrder.entryInfo(modelData).label))
                onClicked: root.add(modelData)
            }
        }
    }
}
