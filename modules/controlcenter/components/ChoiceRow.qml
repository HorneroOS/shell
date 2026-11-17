import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// A pick-one setting: a label and a row of buttons. `target[key]` holds the
// option id; Reset returns to the factory id.
ColumnLayout {
    id: root

    required property var target
    required property string key
    required property string label
    // [{ id: "left", label: qsTr("Left") }, ...]
    required property var options
    required property string defaultValue

    readonly property string current: String(root.target[root.key])

    function pick(id: string): void {
        root.target[root.key] = id;
        Config.save();
    }

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pointSize: Appearance.font.size.normal
        }

        TextButton {
            text: qsTr("Reset")
            type: TextButton.Text
            visible: root.current !== root.defaultValue
            Accessible.name: qsTr("Reset %1 to default").arg(root.label)
            onClicked: root.pick(root.defaultValue)
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
                onClicked: root.pick(modelData.id)
            }
        }
    }
}
