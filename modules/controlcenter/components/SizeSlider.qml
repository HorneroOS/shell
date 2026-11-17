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
    // Fraction digits; > 0 for ratios and multipliers.
    property int decimals: 0

    readonly property real current: root.target[root.key]
    readonly property bool isDefault: Math.abs(root.current - root.defaultValue) < 1e-9

    function commit(val: real): void {
        const stepped = Math.round(val / root.stepSize) * root.stepSize;
        const clamped = Math.max(root.from, Math.min(root.to, stepped));
        root.target[root.key] = Number(clamped.toFixed(root.decimals));
        Config.save();
    }

    // Reset writes the exact factory value (not a stepped one).
    function reset(): void {
        root.target[root.key] = root.defaultValue;
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
        decimals: root.decimals
        validator: DoubleValidator {
            bottom: root.from
            top: root.to
            decimals: root.decimals
        }
        formatValueFunction: val => root.decimals > 0 ? val.toFixed(root.decimals) : Math.round(val).toString()
        parseValueFunction: text => parseFloat(text)
        onValueModified: val => root.commit(val)
    }

    TextButton {
        text: qsTr("Reset")
        type: TextButton.Text
        visible: !root.isDefault
        Accessible.name: qsTr("Reset %1 to default").arg(root.label)
        onClicked: root.reset()
    }
}
