import ".."
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Row {
    id: root

    enum Type {
        Filled,
        Tonal
    }

    property real horizontalPadding: Appearance.padding.normal
    property real verticalPadding: Appearance.padding.smaller
    property int type: SplitButton.Filled
    property bool disabled
    property bool menuOnTop
    property string fallbackIcon
    property string fallbackText
    property string accessibleName

    property alias menuItems: menu.items
    property alias active: menu.active
    property alias expanded: menu.expanded
    property alias menu: menu
    property alias iconLabel: iconLabel
    property alias label: label
    property alias stateLayer: stateLayer

    property color colour: type == SplitButton.Filled ? Signal.palette.signal : Signal.palette.cueWell
    property color textColour: type == SplitButton.Filled ? Signal.palette.onSignal : Signal.palette.onCueWell
    property color disabledColour: Qt.alpha(Signal.palette.ink, 0.1)
    property color disabledTextColour: Qt.alpha(Signal.palette.ink, 0.38)

    spacing: Math.floor(Appearance.spacing.small / 2)

    StyledRect {
        Accessible.role: Accessible.Button
        Accessible.name: root.accessibleName || label.text

        radius: Appearance.rounding.small
        topRightRadius: Appearance.rounding.small / 2
        bottomRightRadius: Appearance.rounding.small / 2
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: textRow.implicitWidth + root.horizontalPadding * 2
        implicitHeight: expandBtn.implicitHeight

        Interactive {
            id: stateLayer

            rect.topRightRadius: parent.topRightRadius
            rect.bottomRightRadius: parent.bottomRightRadius
            color: root.textColour
            disabled: root.disabled

            function onClicked(): void {
                root.active?.clicked();
            }
        }

        RowLayout {
            id: textRow

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.floor(root.verticalPadding / 4)
            spacing: Appearance.spacing.small

            Glyph {
                id: iconLabel

                Layout.alignment: Qt.AlignVCenter
                animate: true
                name: root.active?.activeIcon ?? root.fallbackIcon
                color: root.disabled ? root.disabledTextColour : root.textColour
            }

            StyledText {
                id: label

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
                animate: true
                text: root.active?.activeText ?? root.fallbackText
                color: root.disabled ? root.disabledTextColour : root.textColour
                clip: true

                Behavior on Layout.preferredWidth {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }
        }
    }

    StyledRect {
        id: expandBtn

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("More options")

        property real rad: Appearance.rounding.small / 2

        radius: Appearance.rounding.small
        topLeftRadius: rad
        bottomLeftRadius: rad
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: implicitHeight
        implicitHeight: expandIcon.implicitHeight + root.verticalPadding * 2

        Interactive {
            id: expandStateLayer

            rect.topLeftRadius: parent.topLeftRadius
            rect.bottomLeftRadius: parent.bottomLeftRadius
            color: root.textColour
            disabled: root.disabled

            function onClicked(): void {
                root.expanded = !root.expanded;
            }
        }

        Glyph {
            id: expandIcon

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.expanded ? 0 : -Math.floor(root.verticalPadding / 4)

            name: "chevron-down"
            color: root.disabled ? root.disabledTextColour : root.textColour
            rotation: root.expanded ? 180 : 0

            Behavior on anchors.horizontalCenterOffset {
                Anim {}
            }

            Behavior on rotation {
                Anim {}
            }
        }

        Behavior on rad {
            Anim {}
        }

        Menu {
            id: menu

            states: State {
                when: root.menuOnTop

                AnchorChanges {
                    target: menu
                    anchors.top: undefined
                    anchors.bottom: expandBtn.top
                }
            }

            anchors.top: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: Appearance.spacing.small
            anchors.bottomMargin: Appearance.spacing.small
        }
    }
}
