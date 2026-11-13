import QtQuick

Rectangle {
    id: root

    property int padding: Theme.spacing
    default property alias content: container.data

    color: Theme.surfaceContainer
    radius: Theme.rounding
    implicitWidth: container.implicitWidth + root.padding * 2
    implicitHeight: container.implicitHeight + root.padding * 2

    Item {
        id: container

        anchors.fill: parent
        anchors.margins: root.padding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
