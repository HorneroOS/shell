import ".."
import qs.components.controls
import qs.services
import qs.config
import QtQuick

// Segmented control (Signal Bezel): a row of rectangular channel cells
// split by 1 px `rule` hairlines inside a `sunken` well. The selected
// cell uses the §8 Selected treatment (`signalWell` fill,
// `onSignalWell` content); labels are eyebrow-style Plex Mono uppercase.
// `model` entries are strings or objects with a `label` property.
Well {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool disabled: false
    property string accessibleName: ""

    signal activated(int index)

    function labelFor(entry: var): string {
        return typeof entry === "string" ? entry : (entry?.label ?? "");
    }

    implicitWidth: row.implicitWidth + 2
    implicitHeight: row.implicitHeight + 2

    Accessible.role: Accessible.Grouping
    Accessible.name: root.accessibleName

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.model

            StyledRect {
                id: cell

                required property int index
                required property var modelData

                readonly property bool selected: index === root.currentIndex
                readonly property string label: root.labelFor(modelData)

                implicitWidth: cellLabel.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: cellLabel.implicitHeight + Appearance.padding.smaller * 2
                radius: Appearance.rounding.small
                color: selected ? Signal.palette.signalWell : "transparent"
                opacity: root.disabled ? 0.5 : 1

                Accessible.role: Accessible.RadioButton
                Accessible.name: cell.label
                Accessible.checked: cell.selected

                Hairline {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - Appearance.padding.smaller * 2
                    vertical: true
                    visible: cell.index > 0
                }

                Interactive {
                    color: cell.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                    disabled: root.disabled

                    function onClicked(): void {
                        root.currentIndex = cell.index;
                        root.activated(cell.index);
                    }
                }

                StyledText {
                    id: cellLabel

                    anchors.centerIn: parent
                    text: cell.label
                    mono: true
                    color: cell.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Appearance.font.size.small * 0.08
                }
            }
        }
    }
}
