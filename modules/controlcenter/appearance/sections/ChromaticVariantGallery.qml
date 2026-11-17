pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromaticcli.js" as Cli

// Variant chooser (RFC 0002 §6): Auto plus the eight variants, each with
// an honest one-line description. A tile is a radio: arrows move, Space or
// Enter choose. `resolved` marks the variant the engine actually used.
ColumnLayout {
    id: root

    // "auto" or a variant id.
    property string current: "auto"
    property string resolved: ""

    signal chosen(string variant)

    spacing: Appearance.spacing.small
    Accessible.role: Accessible.RadioButton
    Accessible.name: qsTr("Variant")

    readonly property var tiles: [{
            "id": "auto",
            "label": qsTr("Auto"),
            "description": qsTr("Let Hornero pick from the image: Balanced, Vibrant, Expressive or Muted. Never Neon, Faithful, Monochrome or High contrast.")
        }].concat(Cli.VARIANTS)

    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(3, Math.floor(width / 190)))
        columnSpacing: Appearance.spacing.small
        rowSpacing: Appearance.spacing.small

        Repeater {
            model: root.tiles

            StyledRect {
                id: tile

                required property var modelData
                required property int index

                readonly property bool selected: root.current === modelData.id
                readonly property bool inUse: root.resolved === modelData.id

                Layout.fillWidth: true
                Layout.preferredHeight: 124
                Layout.alignment: Qt.AlignTop
                radius: Appearance.rounding.small
                color: selected ? Signal.palette.signalWell : Signal.layer(Signal.palette.raised, 1)
                border.width: 1
                border.color: activeFocus ? Signal.palette.focus : selected ? Signal.palette.signal : Signal.palette.rule

                activeFocusOnTab: index === 0 || selected
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.description: modelData.description
                Accessible.checked: selected
                Accessible.onPressAction: root.chosen(modelData.id)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.chosen(modelData.id);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        const step = (event.key === Qt.Key_Right || event.key === Qt.Key_Down) ? 1 : -1;
                        const next = (index + step + root.tiles.length) % root.tiles.length;
                        root.chosen(root.tiles[next].id);
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: tileCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.normal
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: tile.modelData.label
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 600
                            color: tile.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: tile.inUse && !tile.selected
                            text: qsTr("in use")
                            mono: true
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: tile.modelData.description
                        wrapMode: Text.WordWrap
                        font.pointSize: Appearance.font.size.small
                        color: tile.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tile.forceActiveFocus();
                        root.chosen(tile.modelData.id);
                    }
                }
            }
        }
    }
}
