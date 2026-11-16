pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

// Desktop widget host (PluginKit 3, RFC 0001 §5b): renders every enabled
// extension with an enabled desktop surface on this screen's desktop
// layer, each in its own DesktopWidgetFrame (own Loader, own geometry).
// Bar indicators, dashboard cards and desktop widgets share one widget
// API (PluginKit), one token set and one data-provider layer — there is
// no second widget engine. Plugin QML runs with the logged-in user's
// permissions; it is NOT sandboxed.
//
// Edit mode (Plugins.desktopEditing, `qs ipc call plugins editDesktop`
// or Control Center) shows move/resize affordances and a toolbar; the
// person's geometry persists per screen in Config.plugins.desktopWidgets.
Item {
    id: root

    required property string screenName
    readonly property var widgets: Plugins.desktopPlugins()

    visible: root.widgets.length > 0

    Repeater {
        model: root.widgets

        delegate: DesktopWidgetFrame {
            required property var modelData
            required property int index

            entry: modelData
            screenName: root.screenName
            area: root
            // Channel numbers count from 01 in manifest order.
            channel: index + 1
        }
    }

    // Edit toolbar: a lifted strip centred at the top of the widget area.
    Rectangle {
        id: toolbar

        visible: Plugins.desktopEditing && root.widgets.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: toolbarRow.implicitWidth + Appearance.padding.larger * 2
        height: 36
        radius: Appearance.rounding.small
        color: Signal.palette.lifted
        border.width: 1
        border.color: Signal.palette.ruleStrong
        z: 10

        Row {
            id: toolbarRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 14
                color: Signal.palette.cue
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                mono: true
                font.pointSize: Appearance.font.size.small
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Appearance.font.size.small * 0.08
                color: Signal.palette.ink
                text: qsTr("Edit widgets")
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                text: qsTr("Drag to move · corner to resize · 8 px grid")
            }

            ToolbarButton {
                label: qsTr("Reset layout")
                onActivated: {
                    for (const widget of root.widgets)
                        Config.plugins.resetDesktopWidgetGeometry(widget.id, root.screenName);
                }
            }

            ToolbarButton {
                label: qsTr("Done")
                primary: true
                onActivated: Plugins.setDesktopEditing(false)
            }
        }
    }

    component ToolbarButton: Rectangle {
        id: button

        property string label: ""
        property bool primary: false

        signal activated

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: buttonLabel.implicitWidth + Appearance.padding.larger * 2
        height: 24
        radius: Appearance.rounding.small
        color: button.primary ? Signal.palette.signal : buttonArea.containsMouse ? Signal.palette.raised : Signal.palette.panel
        border.width: button.primary ? 0 : 1
        border.color: Signal.palette.ruleStrong

        Accessible.role: Accessible.Button
        Accessible.name: button.label
        Accessible.onPressAction: button.activated()

        StyledText {
            id: buttonLabel

            anchors.centerIn: parent
            font.pointSize: Appearance.font.size.small
            font.weight: button.primary ? Font.Medium : Font.Normal
            color: button.primary ? Signal.palette.onSignal : Signal.palette.ink
            text: button.label
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
