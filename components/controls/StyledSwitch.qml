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

    implicitWidth: implicitIndicatorWidth
    implicitHeight: implicitIndicatorHeight

    // Rocker (signal-visual-language §8): a `sunken` rail with a square
    // cap that rocks between two fixed positions. ON is the cap in `signal`
    // with a dark tick; OFF is a `lifted` cap with an `ruleStrong` tick on
    // the opposite half, so the state never relies on colour alone.
    indicator: Well {
        id: rail

        readonly property real half: (implicitWidth - 2) / 2

        radius: Appearance.rounding.small
        outline: root.activeFocus ? Signal.palette.focus : Signal.layer(Signal.palette.ruleStrong, root.cLayer)
        color: Signal.layer(Signal.palette.sunken, root.cLayer)
        opacity: root.enabled ? 1 : 0.5

        implicitWidth: Appearance.font.size.normal * 3.2
        implicitHeight: Appearance.font.size.normal + Appearance.padding.smaller * 2

        // Resting marker on the half the cap is not covering.
        Rectangle {
            width: 1
            height: parent.height * 0.4
            y: (parent.height - height) / 2
            x: root.checked ? rail.half / 2 : rail.half + rail.half / 2
            color: Signal.palette.ruleStrong
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

            Rectangle {
                anchors.centerIn: parent
                width: root.checked ? 2 : 6
                height: parent.height * 0.45
                color: root.checked ? Signal.palette.onSignal : Signal.palette.inkMuted
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
