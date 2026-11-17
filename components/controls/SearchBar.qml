import QtQuick
import qs.components
import qs.components.controls
import qs.services
import qs.config

StyledTextField {
    id: root

    readonly property alias bg: bg
    readonly property alias searchIcon: searchIcon

    leftPadding: searchIcon.width + searchIcon.anchors.leftMargin + Appearance.spacing.normal
    rightPadding: clearIcon.width + clearIcon.anchors.rightMargin + Appearance.spacing.normal
    topPadding: Appearance.padding.large
    bottomPadding: Appearance.padding.large

    background: StyledRect {
        id: bg

        anchors.fill: parent
        color: Signal.tPalette.panel
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: root.activeFocus ? Signal.palette.signal : "transparent"
        opacity: root.enabled ? 1 : 0.5

        Behavior on border.color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            disabled: !root.enabled
        }

        Glyph {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Appearance.spacing.normal
            name: "search"
            color: Signal.palette.inkMuted
        }
    }

    Glyph {
        id: clearIcon

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Appearance.spacing.normal
        visible: root.text.length > 0
        color: Signal.palette.inkMuted
        name: "x"

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Clear search")

        Interactive {
            radius: Appearance.rounding.normal

            onClicked: root.clear()
        }
    }
}
