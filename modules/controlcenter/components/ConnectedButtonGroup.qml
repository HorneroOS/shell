import ".."
import qs.components
import qs.components.controls
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

    property var options: [] // Array of {label: string, propertyName: string, onToggled: function}
    property var rootItem: null // The root item that contains the properties we want to bind to
    property string title: "" // Optional title text

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + (root.flat ? Appearance.padding.small * 2 : Appearance.padding.large * 2)
    radius: Appearance.rounding.small
    color: "transparent"
    border.width: root.flat ? 0 : 1
    border.color: Signal.palette.rule
    clip: true

    Behavior on implicitHeight {
        Anim {}
    }

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.flat && !root.isFirst
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: root.flat ? Appearance.padding.small : Appearance.padding.large
        anchors.leftMargin: root.flat ? 0 : Appearance.padding.large
        anchors.rightMargin: root.flat ? 0 : Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledText {
            visible: root.title !== ""
            text: root.title
            font.pointSize: Appearance.font.size.normal
        }

        RowLayout {
            id: buttonRow
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.small

            Repeater {
                id: repeater
                model: root.options

                delegate: TextButton {
                    id: button
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    text: modelData.label

                    property bool _checked: false

                    checked: _checked
                    toggle: false
                    type: TextButton.Tonal

                    // Create binding in Component.onCompleted
                    Component.onCompleted: {
                        if (root.rootItem && modelData.propertyName) {
                            const propName = modelData.propertyName;
                            const rootItem = root.rootItem;
                            _checked = Qt.binding(function () {
                                return rootItem[propName] ?? false;
                            });
                        }
                    }

                    // Match utilities Toggles radius styling
                    // Each button has full rounding (not connected) since they have spacing
                    radius: stateLayer.pressed ? Appearance.rounding.small / 2 : internalChecked ? Appearance.rounding.small : Appearance.rounding.small

                    // Match utilities Toggles inactive color
                    inactiveColour: Signal.layer(Signal.palette.lifted, 2)

                    // Adjust width similar to utilities toggles
                    Layout.preferredWidth: implicitWidth + (stateLayer.pressed ? Appearance.padding.large : internalChecked ? Appearance.padding.smaller : 0)

                    onClicked: {
                        if (modelData.onToggled && root.rootItem && modelData.propertyName) {
                            const currentValue = root.rootItem[modelData.propertyName] ?? false;
                            modelData.onToggled(!currentValue);
                        }
                    }

                    Behavior on Layout.preferredWidth {
                        Anim {
                            duration: Appearance.anim.durations.settleFast
                            easing.bezierCurve: Appearance.anim.curves.settleFast
                        }
                    }

                    Behavior on radius {
                        Anim {
                            duration: Appearance.anim.durations.settleFast
                            easing.bezierCurve: Appearance.anim.curves.settleFast
                        }
                    }
                }
            }
        }
    }
}
