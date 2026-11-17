pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.containers
import qs.modules.instruments as Instruments
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Props props
    required property var visibilities
    readonly property int notifCount: Notifs.list.reduce((acc, n) => n.closed ? acc : acc + 1, 0)

    anchors.fill: parent
    anchors.margins: Appearance.padding.normal

    Component.onCompleted: Notifs.list.forEach(n => n.popup = false)

    // Header: eyebrow with the live count; the count shows only when there
    // is one.
    Item {
        id: title

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.small

        implicitHeight: Math.max(titleText.implicitHeight, clearBtn.implicitHeight)

        Instruments.Eyebrow {
            id: titleText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: clearBtn.left
            anchors.rightMargin: Appearance.spacing.small

            channel: "04"
            label: root.notifCount > 0 ? `${qsTr("Notifications")} · ${root.notifCount}` : qsTr("Notifications")
        }

        // Clear all: a text segment in the header, not a filled button.
        Item {
            id: clearBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            visible: root.notifCount > 0
            implicitWidth: clearLabel.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: 24

            property string accessibleName: qsTr("Clear all notifications")

            Accessible.role: Accessible.Button
            Accessible.name: accessibleName

            StateLayer {
                radius: Appearance.rounding.small

                function onClicked(): void {
                    clearTimer.start();
                }
            }

            StyledText {
                id: clearLabel

                anchors.centerIn: parent

                mono: true
                text: qsTr("Clear all")
                color: Signal.palette.ink
                font.pointSize: Appearance.font.size.small
                font.capitalization: Font.AllUppercase
                font.underline: true
            }
        }
    }

    Item {
        id: clipRect

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.spacing.smaller

        clip: true

        Loader {
            anchors.centerIn: parent
            active: opacity > 0
            opacity: root.notifCount > 0 ? 0 : 1

            sourceComponent: ColumnLayout {
                spacing: Appearance.spacing.small

                HorneroSprite {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Appearance.spacing.small
                    visible: Atmosphere.mascot
                    pose: "sleep"
                }

                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !Atmosphere.mascot
                    name: "bell-off"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Microcopy.line("notifications.empty")
                    color: Signal.palette.inkMuted
                    mono: true
                    font.pointSize: Appearance.font.size.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.scan
                }
            }
        }

        StyledFlickable {
            id: view

            anchors.fill: parent

            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: notifList.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: view
            }

            NotifDockList {
                id: notifList

                props: root.props
                visibilities: root.visibilities
                container: view
            }
        }
    }

    Timer {
        id: clearTimer

        repeat: true
        interval: 50
        onTriggered: {
            let next = null;
            for (let i = 0; i < notifList.repeater.count; i++) {
                next = notifList.repeater.itemAt(i);
                if (!next?.closed)
                    break;
            }
            if (next)
                next.closeAll();
            else
                stop();
        }
    }
}
