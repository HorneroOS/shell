import qs.components
import qs.components.atmosphere
import qs.components.effects
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

// Station module: who and what is running this session. Square portrait
// (radius `small`), three labelled facts from SysInfo, then the quick
// toggles. Facts that the system cannot report are left out, not faked.
Column {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    spacing: Appearance.spacing.normal

    // Greeting: time-of-day line in the active microcopy voice, with the
    // hornero beside it when the mascot is on.
    Row {
        spacing: Appearance.spacing.smaller

        HorneroSprite {
            anchors.verticalCenter: parent.verticalCenter
            pixel: 2
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - (Atmosphere.mascot ? 40 : 0))
            text: Microcopy.greeting
            elide: Text.ElideRight
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }
    }

    Row {
        spacing: Appearance.spacing.normal

        Rectangle {
            id: portrait

            implicitWidth: 64
            implicitHeight: 64

            radius: Appearance.rounding.small
            color: Signal.palette.sunken
            border.width: 1
            border.color: Signal.palette.rule
            clip: true

            Glyph {
                anchors.centerIn: parent

                name: "user"
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.extraLarge
            }

            CachingImage {
                anchors.fill: parent
                anchors.margins: 1

                path: `${Paths.home}/.face`
            }

            // Hover scrim names the action; the keyboard path is the
            // button role on the MouseArea itself.
            MouseArea {
                id: change

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Change profile picture")
                Accessible.onPressAction: change.clicked(null)
                Keys.onReturnPressed: change.clicked(null)
                Keys.onSpacePressed: change.clicked(null)

                onClicked: {
                    root.visibilities.launcher = false;
                    root.facePicker.open();
                }

                Rectangle {
                    anchors.fill: parent

                    color: Qt.alpha(Signal.palette.scrim, 0.6)
                    opacity: change.containsMouse || change.activeFocus ? 1 : 0

                    StyledText {
                        anchors.centerIn: parent

                        text: qsTr("Change")
                        color: Signal.palette.ink
                        font.pointSize: Appearance.font.size.small
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2

                    visible: change.activeFocus
                    color: "transparent"
                    radius: Appearance.rounding.small + 2
                    border.width: 2
                    border.color: Signal.palette.focus
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.small

            Row {
                spacing: Appearance.spacing.small

                ColouredIcon {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: SysInfo.osLogo !== ""

                    source: SysInfo.osLogo
                    implicitSize: Math.floor(Appearance.font.size.normal * 1.34)
                    colour: Signal.palette.signal
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter

                    text: SysInfo.osPrettyName || SysInfo.osName
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 176)
                    font.pointSize: Appearance.font.size.smaller
                }
            }

            Fact {
                glyph: "app-window"
                text: SysInfo.wm
            }

            Fact {
                glyph: "clock-hour-4"
                text: qsTr("up %1").arg(SysInfo.uptime)
            }
        }
    }

    QuickToggles {
        width: parent.width
    }

    component Fact: Row {
        id: fact

        required property string glyph
        required property string text
        property color tint: Signal.palette.inkMuted

        visible: text !== ""
        spacing: Appearance.spacing.small

        Glyph {
            anchors.verticalCenter: parent.verticalCenter

            name: fact.glyph
            color: fact.tint
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            text: fact.text
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 156)
            font.pointSize: Appearance.font.size.smaller
        }
    }
}
