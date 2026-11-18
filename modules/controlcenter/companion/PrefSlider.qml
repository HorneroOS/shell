import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// A numeric companion preference: slider plus number field, with a Reset
// that appears only when the value differs from the factory default.
RowLayout {
    id: root

    required property string label
    required property real value
    required property real from
    required property real to
    required property real defaultValue
    property real stepSize: 1
    property string suffix: ""
    property int decimals: 0

    signal changed(real value)

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    SliderInput {
        Layout.fillWidth: true

        label: root.label
        value: root.value
        from: root.from
        to: root.to
        stepSize: root.stepSize
        suffix: root.suffix
        decimals: root.decimals
        onValueModified: newValue => root.changed(Number(newValue.toFixed(root.decimals)))
    }

    TextButton {
        text: qsTr("Reset")
        type: TextButton.Text
        visible: Math.abs(root.value - root.defaultValue) > 1e-9
        Accessible.name: qsTr("Reset %1 to default").arg(root.label)
        onClicked: root.changed(root.defaultValue)
    }
}
