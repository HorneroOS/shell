pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.config
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    spacing: 0

    property Component leftContent: null
    property Component rightContent: null

    property real leftWidthRatio: 0.4
    property int leftMinimumWidth: 420
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})

    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: console.log(`[SplitPaneLayout] root=${root.width}x${root.height} visible=${root.visible}/${root.opacity} implicit=${root.implicitWidth}x${root.implicitHeight} left=${leftPane.x},${leftPane.y} ${leftPane.width}x${leftPane.height} visible=${leftPane.visible}/${leftPane.opacity} loader=${leftLoader.width}x${leftLoader.height} visible=${leftLoader.visible}/${leftLoader.opacity} item=${leftLoader.item ? `${leftLoader.item.width}x${leftLoader.item.height} visible=${leftLoader.item.visible} opacity=${leftLoader.item.opacity} scale=${leftLoader.item.scale}` : "null"} right=${rightPane.x},${rightPane.y} ${rightPane.width}x${rightPane.height} visible=${rightPane.visible}/${rightPane.opacity} loader=${rightLoader.width}x${rightLoader.height} visible=${rightLoader.visible}/${rightLoader.opacity} item=${rightLoader.item ? `${rightLoader.item.width}x${rightLoader.item.height} visible=${rightLoader.item.visible} opacity=${rightLoader.item.opacity} scale=${rightLoader.item.scale}` : "null"}`)
    }

    Item {
        id: leftPane

        Layout.preferredWidth: Math.floor(parent.width * root.leftWidthRatio)
        // Keep the established minimum on wide windows, but let the list
        // pane follow its share of the available width on compact displays.
        // A fixed 420 px minimum otherwise steals space from device details
        // and settings on laptop-sized windows.
        Layout.minimumWidth: Math.min(root.leftMinimumWidth, parent.width * root.leftWidthRatio)
        Layout.fillHeight: true

        ClippingRectangle {
            id: leftClippingRect

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            anchors.leftMargin: 0
            anchors.rightMargin: Appearance.padding.normal / 2

            radius: leftBorder.innerRadius
            color: "transparent"

            Loader {
                id: leftLoader

                anchors.fill: parent
                anchors.margins: Appearance.padding.large + Appearance.padding.normal
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.large + Appearance.padding.normal / 2

                sourceComponent: root.leftContent

                Component.onCompleted: {
                    for (const key in root.leftLoaderProperties) {
                        leftLoader[key] = root.leftLoaderProperties[key];
                    }
                }
            }
        }

        InnerBorder {
            id: leftBorder

            leftThickness: 0
            rightThickness: Appearance.padding.normal / 2
        }
    }

    Item {
        id: rightPane

        Layout.fillWidth: true
        Layout.fillHeight: true

        ClippingRectangle {
            id: rightClippingRect

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            anchors.leftMargin: 0
            anchors.rightMargin: Appearance.padding.normal / 2

            radius: rightBorder.innerRadius
            color: "transparent"

            Loader {
                id: rightLoader

                anchors.fill: parent
                anchors.margins: Appearance.padding.large * 2

                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }

        InnerBorder {
            id: rightBorder

            leftThickness: Appearance.padding.normal / 2
        }
    }
}
