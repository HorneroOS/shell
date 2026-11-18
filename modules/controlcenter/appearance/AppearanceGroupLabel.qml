import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Group heading between Appearance sections ("COLOUR", "LOOK & FEEL" …):
// a Signal eyebrow over a hairline rule, so sixteen sections scan as six
// groups. A heading for assistive tech; never interactive.
ColumnLayout {
    id: root

    property string label: ""
    property bool first: false

    Layout.fillWidth: true
    Layout.topMargin: first ? 0 : Appearance.spacing.large
    spacing: Appearance.spacing.smaller

    Accessible.role: Accessible.Heading
    Accessible.name: label

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Eyebrow {
            label: root.label
            color: Signal.palette.signal
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 1
            color: Signal.palette.rule
        }
    }
}
