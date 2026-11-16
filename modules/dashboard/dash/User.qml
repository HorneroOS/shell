import qs.components
import qs.components.effects
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Row {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    padding: Appearance.padding.large
    spacing: Appearance.spacing.normal

    StyledClippingRect {
        implicitWidth: info.implicitHeight
        implicitHeight: info.implicitHeight

        radius: Appearance.rounding.large
        color: Signal.layer(Signal.palette.raised, 2)

        Glyph {
            anchors.centerIn: parent

            name: "user"
            font.pointSize: Math.floor(info.implicitHeight / 2) || 1
        }

        CachingImage {
            id: pfp

            anchors.fill: parent
            path: `${Paths.home}/.face`
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            StyledRect {
                anchors.fill: parent

                color: Qt.alpha(Signal.palette.scrim, 0.5)
                opacity: parent.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.settleFast
                    }
                }
            }

            StyledRect {
                anchors.centerIn: parent

                implicitWidth: selectIcon.implicitHeight + Appearance.padding.small * 2
                implicitHeight: selectIcon.implicitHeight + Appearance.padding.small * 2

                radius: Appearance.rounding.normal
                color: Signal.palette.signal
                scale: parent.containsMouse ? 1 : 0.5
                opacity: parent.containsMouse ? 1 : 0

                StateLayer {
                    color: Signal.palette.onSignal

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Change profile picture")

                    function onClicked(): void {
                        root.visibilities.launcher = false;
                        root.facePicker.open();
                    }
                }

                Glyph {
                    id: selectIcon

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -font.pointSize * 0.02

                    name: "user-square"
                    color: Signal.palette.onSignal
                    font.pointSize: Appearance.font.size.extraLarge
                }

                Behavior on scale {
                    Anim {
                        duration: Appearance.anim.durations.settleFast
                        easing.bezierCurve: Appearance.anim.curves.settleFast
                    }
                }

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.settleFast
                    }
                }
            }
        }
    }

    Column {
        id: info

        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.normal

        Item {
            id: line

            implicitWidth: icon.implicitWidth + text.width + text.anchors.leftMargin
            implicitHeight: Math.max(icon.implicitHeight, text.implicitHeight)

            ColouredIcon {
                id: icon

                anchors.left: parent.left
                anchors.leftMargin: (Config.dashboard.sizes.infoIconSize - implicitWidth) / 2

                source: SysInfo.osLogo
                implicitSize: Math.floor(Appearance.font.size.normal * 1.34)
                colour: Signal.palette.signal
            }

            StyledText {
                id: text

                anchors.verticalCenter: icon.verticalCenter
                anchors.left: icon.right
                anchors.leftMargin: icon.anchors.leftMargin
                text: `:  ${SysInfo.osPrettyName || SysInfo.osName}`
                font.pointSize: Appearance.font.size.normal

                width: Config.dashboard.sizes.infoWidth
                elide: Text.ElideRight
            }
        }

        InfoLine {
            icon: "app-window"
            text: SysInfo.wm
            colour: Signal.palette.cue
        }

        InfoLine {
            id: uptime

            icon: "clock-hour-4"
            text: qsTr("up %1").arg(SysInfo.uptime)
            colour: Signal.palette.phosphor
        }
    }

    component InfoLine: Item {
        id: line

        required property string icon
        required property string text
        required property color colour

        implicitWidth: icon.implicitWidth + text.width + text.anchors.leftMargin
        implicitHeight: Math.max(icon.implicitHeight, text.implicitHeight)

        Glyph {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: (Config.dashboard.sizes.infoIconSize - implicitWidth) / 2

            name: line.icon
            color: line.colour
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            id: text

            anchors.verticalCenter: icon.verticalCenter
            anchors.left: icon.right
            anchors.leftMargin: icon.anchors.leftMargin
            text: `:  ${line.text}`
            font.pointSize: Appearance.font.size.normal

            width: Config.dashboard.sizes.infoWidth
            elide: Text.ElideRight
        }
    }
}
