pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.motion
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Segmented mode switcher for Hornero Welcome: First Flight | Explore Hornero | What's New.
Well {
    id: root

    required property string currentMode
    property bool hasUnseenWhatsNew: false

    signal modeSelected(string modeId)

    readonly property var tabs: [
        { id: "first-flight", label: qsTr("First Flight"), icon: "compass" },
        { id: "explore", label: qsTr("Explore Hornero"), icon: "search" },
        { id: "whats-new", label: qsTr("What's New"), icon: "sparkles" }
    ]

    implicitWidth: tabRow.implicitWidth + 4
    implicitHeight: tabRow.implicitHeight + 4

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Welcome modes")

    RowLayout {
        id: tabRow

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.tabs

            delegate: StyledRect {
                id: tabCell

                required property int index
                required property var modelData

                readonly property bool selected: root.currentMode === modelData.id
                readonly property bool showUnreadDot: modelData.id === "whats-new" && root.hasUnseenWhatsNew && !selected

                implicitWidth: tabInner.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: tabInner.implicitHeight + Appearance.padding.smaller * 2
                radius: Appearance.rounding.small
                color: selected ? Signal.palette.signalWell : "transparent"

                Accessible.role: Accessible.PageTab
                Accessible.name: tabCell.modelData.label
                Accessible.selected: tabCell.selected

                Behavior on color {
                    CAnim {}
                }

                Hairline {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - Appearance.padding.smaller * 2
                    vertical: true
                    visible: tabCell.index > 0
                }

                OnAirBar {
                    edge: "bottom"
                    visible: tabCell.selected
                }

                Interactive {
                    color: tabCell.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                    onClicked: root.modeSelected(tabCell.modelData.id)
                }

                RowLayout {
                    id: tabInner

                    anchors.centerIn: parent
                    spacing: Appearance.spacing.small

                    Glyph {
                        name: tabCell.modelData.icon
                        font.pointSize: Appearance.font.size.small
                        color: tabCell.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                    }

                    StyledText {
                        text: tabCell.modelData.label
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        font.weight: tabCell.selected ? Appearance.font.weight.strong : Appearance.font.weight.medium
                        color: tabCell.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                    }

                    Rectangle {
                        visible: tabCell.showUnreadDot
                        width: 6
                        height: 6
                        radius: width / 2
                        color: Signal.palette.signal
                    }
                }
            }
        }
    }
}
