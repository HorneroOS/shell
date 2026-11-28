import ".."
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property bool toggled
    property string icon
    property string label
    // Signal accent role: "signal", "cue", "phosphor", or "alert".
    property string accent: "cue"
    readonly property string onAccent: `on${accent.charAt(0).toUpperCase()}${accent.slice(1)}`

    readonly property color resolvedBg: {
        if (root.accent === "signal" || root.accent === "caution")
            return root.toggled ? Signal.palette.signal : Signal.palette.signalWell;
        if (root.accent === "phosphor")
            return root.toggled ? Signal.palette.phosphor : Signal.palette.phosphorWell;
        if (root.accent === "alert" || root.accent === "fault")
            return root.toggled ? Signal.palette.alert : Signal.palette.alertWell;
        return root.toggled ? Signal.palette.cue : Signal.palette.cueWell;
    }

    readonly property color resolvedFg: {
        if (root.accent === "signal" || root.accent === "caution")
            return root.toggled ? Signal.palette.onSignal : Signal.palette.onSignalWell;
        if (root.accent === "phosphor")
            return root.toggled ? Signal.palette.onPhosphor : Signal.palette.onPhosphorWell;
        if (root.accent === "alert" || root.accent === "fault")
            return root.toggled ? Signal.palette.onAlert : Signal.palette.onAlertWell;
        return root.toggled ? Signal.palette.onCue : Signal.palette.onCueWell;
    }
    property real iconSize: Appearance.font.size.large
    property real horizontalPadding: Appearance.padding.large
    property real verticalPadding: Appearance.padding.normal
    property string tooltip: ""

    property bool hovered: false
    property bool disabled: false
    signal clicked

    Component.onCompleted: {
        hovered = toggleStateLayer.containsMouse;
    }

    Connections {
        target: toggleStateLayer
        function onContainsMouseChanged() {
            const newHovered = toggleStateLayer.containsMouse;
            if (hovered !== newHovered) {
                hovered = newHovered;
            }
        }
    }

    Layout.preferredWidth: implicitWidth + (toggleStateLayer.pressed ? Appearance.padding.normal * 2 : toggled ? Appearance.padding.small * 2 : 0)
    implicitWidth: toggleBtnInner.implicitWidth + horizontalPadding * 2
    implicitHeight: toggleBtnIcon.implicitHeight + verticalPadding * 2

    // QAccessible has no ToggleButton role: a checkable Button is the toggle.
    Accessible.role: Accessible.Button
    Accessible.checkable: true
    Accessible.name: root.label !== "" ? root.label : root.tooltip
    Accessible.checked: root.toggled

    // Signal Bezel: rectangular channel cells, radius `small` in every state.
    radius: Appearance.rounding.small
    color: root.resolvedBg
    opacity: root.disabled ? 0.5 : 1

    Interactive {
        id: toggleStateLayer

        color: root.resolvedFg
        disabled: root.disabled

        function onClicked(): void {
            root.clicked();
        }
    }

    RowLayout {
        id: toggleBtnInner

        anchors.centerIn: parent
        spacing: Appearance.spacing.normal

        Glyph {
            id: toggleBtnIcon

            visible: !!text
            name: root.icon
            color: root.resolvedFg
            font.pointSize: root.iconSize
        }

        Loader {
            active: !!root.label
            visible: active

            sourceComponent: StyledText {
                text: root.label
                color: root.resolvedFg
            }
        }
    }

    Behavior on radius {
        Anim {
            duration: Appearance.anim.durations.settleFast
            easing.bezierCurve: Appearance.anim.curves.settleFast
        }
    }

    Behavior on Layout.preferredWidth {
        Anim {
            duration: Appearance.anim.durations.settleFast
            easing.bezierCurve: Appearance.anim.curves.settleFast
        }
    }

    // Tooltip - positioned absolutely, doesn't affect layout
    Loader {
        id: tooltipLoader
        active: root.tooltip !== ""
        z: 10000
        width: 0
        height: 0
        sourceComponent: Component {
            Tooltip {
                target: root
                text: root.tooltip
            }
        }
        // Completely remove from layout
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        Layout.maximumWidth: 0
        Layout.maximumHeight: 0
        Layout.minimumWidth: 0
        Layout.minimumHeight: 0
    }
}
