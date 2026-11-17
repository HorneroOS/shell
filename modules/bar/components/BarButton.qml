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
    property color colour: Signal.palette.ink
    property string label
    property real iconSize: Density.iconPt
    property bool filled
    readonly property bool hovered: interaction.containsMouse

    signal activated

    implicitWidth: implicitHeight
    implicitHeight: Math.max(glyph.implicitHeight, iconSize) + Appearance.padding.small * 2

    Interactive {
        id: interaction

        radius: Appearance.rounding.small
        Accessible.role: Accessible.Button
        Accessible.name: root.label
        onClicked: root.activated()
    }

    Tooltip {
        target: root
        text: root.label
    }

    Glyph {
        id: glyph

        visible: root.iconSource === ""
        anchors.centerIn: parent
        name: root.icon
        color: root.colour
        font.pointSize: root.iconSize
    }

    Image {
        visible: root.iconSource !== ""
        anchors.centerIn: parent
        source: root.iconSource
        sourceSize.width: root.iconSize * 1.33
        sourceSize.height: root.iconSize * 1.33
        width: root.iconSize * 1.33
        height: root.iconSize * 1.33
        asynchronous: true
        smooth: true
    }
}
