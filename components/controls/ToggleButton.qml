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
    // Signal accent role: "signal", "cue" or "phosphor".
    property string accent: "cue"
    readonly property string onAccent: `on${accent.charAt(0).toUpperCase()}${accent.slice(1)}`
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
    color: toggled ? Signal.palette[accent] : Signal.palette[`${accent}Well`]
    opacity: root.disabled ? 0.5 : 1

    Interactive {
        id: toggleStateLayer

        color: root.toggled ? Signal.palette[root.onAccent] : Signal.palette[`${root.onAccent}Well`]
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
            color: root.toggled ? Signal.palette[root.onAccent] : Signal.palette[`${root.onAccent}Well`]
            font.pointSize: root.iconSize
        }

        Loader {
            active: !!root.label
            visible: active

            sourceComponent: StyledText {
                text: root.label
                color: root.toggled ? Signal.palette[root.onAccent] : Signal.palette[`${root.onAccent}Well`]
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
