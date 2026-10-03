import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick

// Icon button for bar components: one Interactive (Tab stop, Enter/Space,
// focus ring, accessible name) so no bar control is mouse-only.
Item {
    id: root

    property string icon
    property string iconSource
    property color colour: Colours.palette.m3onSurface
    property string label
    property real iconSize: Appearance.font.size.large
    property bool filled
    readonly property bool hovered: interaction.containsMouse

    signal activated

    implicitWidth: implicitHeight
    implicitHeight: Math.max(glyph.implicitHeight, iconSize) + Appearance.padding.small * 2

    Interactive {
        id: interaction

        radius: Appearance.rounding.full
        Accessible.role: Accessible.Button
        Accessible.name: root.label
        onClicked: root.activated()
    }

    Tooltip {
        target: root
        text: root.label
    }

    MaterialIcon {
        id: glyph

        visible: root.iconSource === ""
        anchors.centerIn: parent
        text: root.icon
        color: root.colour
        fill: root.filled ? 1 : 0
        font.pointSize: root.iconSize
    }

    Image {
        visible: root.iconSource !== ""
        anchors.centerIn: parent
        source: root.iconSource
        sourceSize.width: root.iconSize * 1.9
        sourceSize.height: root.iconSize * 1.9
        width: root.iconSize * 1.9
        height: root.iconSize * 1.9
        asynchronous: true
        smooth: true
    }
}
