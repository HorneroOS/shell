import ".."
import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    // Inside a ChannelPanel the row is flat: no frame of its own, a hairline
    // separates it from the previous row.
    readonly property bool flat: {
        for (let p = root.parent; p; p = p.parent) {
            if (p.isChannelPanel === true)
                return true;
        }
        return false;
    }
    readonly property bool isFirst: {
        const siblings = root.parent ? root.parent.children : [];
        for (let i = 0; i < siblings.length; i++) {
            if (siblings[i] === root)
                return true;
            if (siblings[i].visible && siblings[i].implicitHeight > 0)
                return false;
        }
        return true;
    }

    required property string label
    required property bool checked
    property bool enabled: true
    property var onToggled: function (checked) {}

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + (root.flat ? Appearance.padding.small * 2 : Appearance.padding.large * 2)
    radius: Appearance.rounding.small
    color: "transparent"
    border.width: root.flat ? 0 : 1
    border.color: Signal.palette.rule

    Behavior on implicitHeight {
        Anim {}
    }

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.flat && !root.isFirst
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.flat ? Appearance.padding.small : Appearance.padding.large
        anchors.leftMargin: root.flat ? 0 : Appearance.padding.large
        anchors.rightMargin: root.flat ? 0 : Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: root.label
        }

        StyledSwitch {
            Accessible.role: Accessible.CheckBox
            Accessible.name: root.label
            Accessible.checked: root.checked

            checked: root.checked
            enabled: root.enabled
            onToggled: {
                root.onToggled(checked);
            }
        }
    }
}
