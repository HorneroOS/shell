import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Templates

Switch {
    id: root

    property int cLayer: 1

    onActiveFocusChanged: {
        if (activeFocus)
            FocusMode.reportFocus(root.pressed);
    }
    Keys.onTabPressed: event => FocusMode.handleTab(root, event, false)
    Keys.onBacktabPressed: event => FocusMode.handleTab(root, event, true)

    // The hit target is at least 32 px tall even though the rail itself is
    // 24 px (WCAG 2.5.8 plus breathing room).
    implicitWidth: implicitIndicatorWidth
    implicitHeight: Math.max(32, implicitIndicatorHeight)

    // Rocker (signal-visual-language §8): a `sunken` rail with a square cap
    // that rocks between two fixed positions. The state is carried by three
    // independent cues so it survives greyscale: the cap position, the cap
    // mark (hollow `O` ring when off, solid `I` bar when on) and an `ON` /
    // `OFF` mono label on the half of the rail the cap is not covering.
    indicator: Well {
        id: rail

        readonly property real half: (implicitWidth - 2) / 2

        x: root.leftPadding
        y: (root.height - height) / 2
        radius: Appearance.rounding.small
        outline: root.activeFocus ? Signal.palette.focus : Signal.layer(Signal.palette.ruleStrong, root.cLayer)
        color: Signal.layer(Signal.palette.sunken, root.cLayer)
        opacity: root.enabled ? 1 : 0.5

        implicitWidth: Appearance.font.size.normal * 4.6
        implicitHeight: Appearance.font.size.normal + Appearance.padding.smaller * 2 + 2

        // State word on the half the cap is not covering.
        StyledText {
            width: rail.half
            height: rail.height
            x: root.checked ? 1 : rail.half + 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.checked ? qsTr("ON") : qsTr("OFF")
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.small
            font.weight: root.checked ? Font.DemiBold : Font.Normal
            color: root.checked ? Signal.palette.signal : Signal.palette.inkMuted
        }

        StyledRect {
            id: cap

            readonly property real nonAnimWidth: rail.half + (root.pressed ? Appearance.padding.small : 0)

            x: 1 + (root.checked ? rail.width - 2 - nonAnimWidth : 0)
            y: 1
            implicitWidth: nonAnimWidth
            implicitHeight: rail.height - 2
            radius: Appearance.rounding.small - 1
            color: root.checked ? Signal.palette.signal : Signal.layer(Signal.palette.lifted, root.cLayer + 1)
            border.width: 1
            border.color: root.checked ? Signal.palette.signal : Signal.palette.ruleStrong

            // ON: solid bar `I`. OFF: hollow ring `O`.
            Rectangle {
                anchors.centerIn: parent
                width: root.checked ? 2 : parent.height * 0.4
                height: root.checked ? parent.height * 0.5 : width
                radius: root.checked ? 0 : width / 2
                color: root.checked ? Signal.palette.onSignal : "transparent"
                border.width: root.checked ? 0 : 1.5
                border.color: Signal.palette.inkMuted
            }

            StyledRect {
                anchors.fill: parent
                radius: parent.radius
                color: root.checked ? Signal.palette.onSignal : Signal.palette.ink
                opacity: root.pressed ? 0.12 : root.hovered ? 0.08 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            Behavior on x {
                Anim {}
            }

            Behavior on implicitWidth {
                Anim {}
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }

    FocusRing {
        radius: Appearance.rounding.small
    }
}
