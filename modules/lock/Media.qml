pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var lock

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight

    Image {
        anchors.fill: parent
        source: Players.active?.trackArtUrl ?? ""

        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: mask
        }

        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.scan
            }
        }
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.5)
            }
            GradientStop {
                position: 0.4
                color: Qt.rgba(0, 0, 0, 0.2)
            }
            GradientStop {
                position: 0.8
                color: Qt.rgba(0, 0, 0, 0)
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.large

        StyledText {
            Layout.topMargin: Appearance.padding.large
            Layout.bottomMargin: Appearance.spacing.larger
            text: qsTr("Now playing")
            color: Signal.palette.inkMuted
            font.family: Appearance.font.family.mono
            font.weight: 500
        }

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: Players.active?.trackArtist ?? qsTr("No media")
            color: Signal.palette.signal
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Appearance.font.size.large
            font.family: Appearance.font.family.mono
            font.weight: 600
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: Players.active?.trackTitle ?? qsTr("No media")
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Appearance.font.size.larger
            font.family: Appearance.font.family.mono
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.spacing.large * 1.2
            Layout.bottomMargin: Appearance.padding.large

            spacing: Appearance.spacing.large

            PlayerControl {
                icon: "player-skip-back"

                function onClicked(): void {
                    if (Players.active?.canGoPrevious)
                        Players.active.previous();
                }
            }

            PlayerControl {
                animate: true
                icon: active ? "player-pause" : "player-play"
                colour: "signal"
                level: active ? 2 : 1
                active: Players.active?.isPlaying ?? false

                function onClicked(): void {
                    if (Players.active?.canTogglePlaying)
                        Players.active.togglePlaying();
                }
            }

            PlayerControl {
                icon: "player-skip-forward"

                function onClicked(): void {
                    if (Players.active?.canGoNext)
                        Players.active.next();
                }
            }
        }
    }

    component PlayerControl: StyledRect {
        id: control

        property alias animate: controlIcon.animate
        property alias icon: controlIcon.name
        property bool active
        // Signal accent role: "signal", "cue" or "phosphor".
        property string colour: "cue"
        readonly property string onColour: `on${colour.charAt(0).toUpperCase()}${colour.slice(1)}`
        property int level: 1

        function onClicked(): void {
        }

        Layout.preferredWidth: implicitWidth + (controlState.pressed ? Appearance.padding.normal * 2 : active ? Appearance.padding.small * 2 : 0)
        implicitWidth: controlIcon.implicitWidth + Appearance.padding.large * 2
        implicitHeight: controlIcon.implicitHeight + Appearance.padding.normal * 2

        color: active ? Signal.palette[colour] : Signal.palette[`${colour}Well`]
        radius: active || controlState.pressed ? Appearance.rounding.normal : Math.min(implicitWidth, implicitHeight) / 2 * Math.min(1, Appearance.rounding.scale)

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: controlState.containsMouse && !controlState.pressed ? control.level + 1 : control.level
        }

        StateLayer {
            id: controlState

            color: control.active ? Signal.palette[control.onColour] : Signal.palette[`${control.onColour}Well`]

            function onClicked(): void {
                control.onClicked();
            }
        }

        Glyph {
            id: controlIcon

            anchors.centerIn: parent
            color: control.active ? Signal.palette[control.onColour] : Signal.palette[`${control.onColour}Well`]
            font.pointSize: Appearance.font.size.large
        }

        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }

        Behavior on radius {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }
    }
}
