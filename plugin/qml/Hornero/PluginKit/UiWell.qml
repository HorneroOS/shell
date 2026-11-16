import QtQuick

// Sunken readout well (visual language §4.1, §6.3): `sunken` fill, 1 px
// `rule` border, radius 3. Changing numbers and instruments sit in
// wells; static text does not.
Rectangle {
    id: root

    property int padding: Theme.padding.normal
    default property alias content: container.data

    implicitWidth: container.implicitWidth + root.padding * 2
    implicitHeight: container.implicitHeight + root.padding * 2
    radius: Theme.rounding.small
    color: Theme.palette.sunken
    border.width: 1
    border.color: Theme.palette.rule

    Item {
        id: container

        anchors.fill: parent
        anchors.margins: root.padding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
