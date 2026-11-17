import qs.components.controls
import qs.config
import QtQuick
import QtQuick.Layouts

// A pixel/ratio setting row: slider + number field + "Reset" back to the
// factory value. `target[key]` is read live and written on change, then
// persisted with Config.save(). Customisability principle: every size the
// shell ships is also a user setting, with its best default one click away.
RowLayout {
    id: root

    // JsonObject that owns the value (for example Config.launcher.sizes).
    required property var target
    required property string key
    required property string label
    required property real from
    required property real to
    // Factory value; the Reset button writes this back.
    required property real defaultValue
    property real stepSize: 1
    property string suffix: "px"

    readonly property real current: root.target[root.key]
    readonly property bool isDefault: Math.abs(root.current - root.defaultValue) < 1e-9

    function commit(val: real): void {
        const clamped = Math.max(root.from, Math.min(root.to, Math.round(val / root.stepSize) * root.stepSize));
        root.target[root.key] = clamped;
        Config.save();
    }

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    SliderInput {
        Layout.fillWidth: true

        label: root.label
        value: root.current
        from: root.from
        to: root.to
        stepSize: root.stepSize
        suffix: root.suffix
        validator: IntValidator {
            bottom: root.from
            top: root.to
        }
        formatValueFunction: val => Math.round(val).toString()
        parseValueFunction: text => parseInt(text)
        onValueModified: val => root.commit(val)
    }

    TextButton {
        text: qsTr("Reset")
        type: TextButton.Text
        visible: !root.isDefault
        Accessible.name: qsTr("Reset %1 to default").arg(root.label)
        onClicked: root.commit(root.defaultValue)
    }
}
