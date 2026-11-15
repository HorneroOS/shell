import QtQuick
import QtQuick.Controls

ProgressBar {
    id: root

    property bool animated: false
    property string accessibleName: ""

    from: 0
    to: 1
    value: 0
    indeterminate: false

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.ProgressBar

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 6
        radius: height / 2
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.componentBorder
    }

    contentItem: Item {
        Rectangle {
            visible: !root.indeterminate
            width: root.position * parent.width
            height: parent.height
            radius: height / 2
            color: Theme.primary
        }

        Rectangle {
            visible: root.indeterminate
            width: parent.width * 0.4
            height: parent.height
            radius: height / 2
            color: Theme.primary
        }
    }

    SequentialAnimation on opacity {
        // Host reduced motion (shell issue 376) wins over `animated`.
        running: root.indeterminate && root.animated && !Theme.reducedMotion
        loops: Animation.Infinite

        NumberAnimation {
            to: 0.4
            duration: 600
        }
        NumberAnimation {
            to: 1
            duration: 600
        }
    }
}
