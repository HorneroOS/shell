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

    // No left content: a single-column pane (shell#454). The left column is
    // dropped entirely instead of showing an empty or decorative panel.
    readonly property bool singleColumn: root.leftContent === null

    Item {
        id: leftPane

        visible: !root.singleColumn
        Layout.preferredWidth: root.singleColumn ? 0 : Math.floor(parent.width * root.leftWidthRatio)
        // Keep the established minimum on wide windows, but let the list
        // pane follow its share of the available width on compact displays.
        // A fixed 420 px minimum otherwise steals space from device details
        // and settings on laptop-sized windows.
        Layout.minimumWidth: root.singleColumn ? 0 : Math.min(root.leftMinimumWidth, parent.width * root.leftWidthRatio)
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
