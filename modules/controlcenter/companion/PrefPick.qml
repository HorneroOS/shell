import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// A pick-one companion preference: a label, optional help, a row of buttons
// and a Reset that appears only when the value differs from the factory
// default. The caller owns persistence (CompanionStore.patchPref); this row
// only reports the choice.
ColumnLayout {
    id: root

    required property string label
    // [{ id: "left", label: qsTr("Left") }, ...]
    required property var options
    required property string current
    required property string defaultValue
    property string help: ""

    signal picked(string id)

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        TextButton {
            text: qsTr("Reset")
            type: TextButton.Text
            visible: root.current !== root.defaultValue
            Accessible.name: qsTr("Reset %1 to default").arg(root.label)
            onClicked: root.picked(root.defaultValue)
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: root.options

            TextButton {
                required property var modelData

                text: modelData.label
                toggle: true
                checked: root.current === modelData.id
                type: TextButton.Tonal
                Accessible.name: qsTr("%1: %2").arg(root.label).arg(modelData.label)
                onClicked: root.picked(modelData.id)
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.help !== ""
        text: root.help
        wrapMode: Text.Wrap
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.inkFaint
    }
}
