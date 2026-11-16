pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.config
import QtQuick
import QtQuick.Layouts

// Window list item — flat row inside the window list card.
// No own background (transparent), uses parent's surfaceContainer.
Item {
    id: root

    required property var modelData
    required property bool isActive

    signal focusRequested()

    readonly property bool floating: Compositor.isNiri ? root.modelData.is_floating : root.modelData.lastIpcObject?.floating ?? false
    readonly property bool pinned: !Compositor.isNiri && (root.modelData.lastIpcObject?.pinned ?? false)
    readonly property int fullscreen: Compositor.isNiri ? 0 : root.modelData.lastIpcObject?.fullscreen ?? 0
    readonly property string appId: Compositor.isNiri ? root.modelData.app_id ?? "" : root.modelData.lastIpcObject?.class ?? ""

    implicitWidth: parent ? parent.width : 300
    implicitHeight: row.implicitHeight + Appearance.padding.small

    Accessible.role: Accessible.Button
    Accessible.name: root.modelData.title ?? qsTr("Unknown window")

    // Highlight background for active window
    StyledRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.isActive
            ? Qt.alpha(Signal.palette.signal, 0.12)
            : "transparent"
        visible: root.isActive
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.small

        spacing: Appearance.spacing.small

        // App icon
        Glyph {
            Layout.alignment: Qt.AlignVCenter
            name: Icons.getAppCategoryIcon(root.appId, "terminal")
            color: root.isActive ? Signal.palette.signal : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
        }

        // Title
        StyledText {
            Layout.fillWidth: true
            text: root.modelData.title ?? qsTr("Unknown")
            font.pointSize: Appearance.font.size.small
            font.weight: root.isActive ? 600 : 400
            color: root.isActive ? Signal.palette.signal : Signal.palette.ink
            elide: Text.ElideRight
        }

        // State badges
        Row {
            visible: Config.dashboard.workspaces.showWindowBadges
            spacing: 2

            Glyph {
                visible: root.floating
                name: "picture-in-picture"
                color: Signal.palette.phosphor
                font.pointSize: Appearance.font.size.small
            }

            Glyph {
                visible: Compositor.supports("fullscreenState") && root.fullscreen > 0
                name: "maximize"
                color: Signal.palette.cue
                font.pointSize: Appearance.font.size.small
            }

            Glyph {
                visible: root.pinned
                name: "pin"
                color: Signal.palette.cue
                font.pointSize: Appearance.font.size.small
            }
        }

        // Action buttons
        Row {
            visible: Config.dashboard.workspaces.enableWindowActions && (Compositor.supports("windowFloatingToggle") || Compositor.supports("windowClose"))
            spacing: 2

            IconButton {
                type: IconButton.Text
                visible: Compositor.supports("windowFloatingToggle")
                accessibleName: qsTr("Toggle floating")
                icon: root.floating ? "app-window" : "app-window"
                padding: Appearance.padding.small / 2
                font.pointSize: Appearance.font.size.small

                onClicked: Compositor.toggleWindowFloating(root.modelData)
            }

            IconButton {
                type: IconButton.Text
                icon: "x"
                accessibleName: qsTr("Close window")
                visible: Compositor.supports("windowClose")
                padding: Appearance.padding.small / 2
                font.pointSize: Appearance.font.size.small

                onClicked: Compositor.closeWindowFor(root.modelData)
            }
        }
    }

    // Click to focus
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true
        onClicked: event => {
            root.focusRequested();
            event.accepted = false;
        }
    }
}
