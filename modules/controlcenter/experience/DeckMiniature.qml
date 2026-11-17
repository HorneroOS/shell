pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

// Desktop map of the Signal deck for one mode (Control Center › Experience
// › Desktop widgets). It draws the real solver's answer (services/deck.js)
// for a 1920×1080 reference display: the same placements the desktop layer
// computes, scaled down, so toggling, anchoring, ordering and presets show
// their effect immediately. It never loads an extension, so it holds no
// provider lease and shows no telemetry; each tile is labelled with the
// widget's name only.
Item {
    id: root

    required property var composition
    property int refWidth: 1920
    property int refHeight: 1080
    readonly property real factor: root.width / root.refWidth

    implicitHeight: Math.round(root.width * root.refHeight / root.refWidth)

    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Desktop map")
    Accessible.description: root.composition.placements.length === 0 ? qsTr("No widgets on the desktop.") : qsTr("%n widget(s) on the desktop: %1", "", root.composition.placements.length).arg(root.composition.placements.map(p => p.label).join(", "))

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Signal.palette.sunken
        border.width: 1
        border.color: Signal.palette.rule
    }

    // The open middle the solver keeps free for windows and the wallpaper.
    StyledText {
        anchors.centerIn: parent
        visible: root.composition.placements.length === 0
        text: qsTr("No widgets on the desktop")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
    }

    Repeater {
        model: root.composition.placements

        delegate: Rectangle {
            id: tile

            required property var modelData

            x: Math.round(modelData.x * root.factor)
            y: Math.round(modelData.y * root.factor)
            width: Math.max(8, Math.round(modelData.width * root.factor))
            height: Math.max(8, Math.round(modelData.height * root.factor))
            radius: 0
            color: Signal.palette.panel
            border.width: 1
            border.color: modelData.source === "user" ? Signal.palette.cue : Signal.palette.ruleStrong

            Behavior on x {
                enabled: !Appearance.anim.reduced
                NumberAnimation {
                    duration: Appearance.anim.durations.short
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: !Appearance.anim.reduced
                NumberAnimation {
                    duration: Appearance.anim.durations.short
                    easing.type: Easing.OutCubic
                }
            }

            // Channel tick, the Signal Bezel mark on instrument modules.
            Rectangle {
                x: 0
                y: 0
                width: 2
                height: parent.height
                color: Signal.palette.signal
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 8
                spacing: 2

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: tile.modelData.glyph ?? ""
                    size: Appearance.font.size.larger
                    color: Signal.palette.ink
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    font.capitalization: Font.AllUppercase
                    color: Signal.palette.inkMuted
                    text: tile.modelData.label
                    visible: tile.width >= 56
                }
            }
        }
    }
}
