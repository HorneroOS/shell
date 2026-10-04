pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import QtQuick
import QtQuick.Layouts

// Workspace selector card — compact card for the bottom flow.
// Matches the visual style of forecast cards in Weather.qml.
Item {
    id: root

    required property var modelData
    required property bool isSelected
    required property bool isActive

    signal clicked()

    readonly property int windowCount: Compositor.windowsForWorkspace(root.modelData.id).length
    readonly property var wsToplevels: Compositor.windowsForWorkspace(root.modelData.id)

    implicitWidth: 150
    // Flow sizes delegates from their implicit dimensions; StyledRect is a
    // Rectangle and does not infer height from its anchored children.
    implicitHeight: 72

    StyledRect {
        id: card

        anchors.fill: parent

        radius: Appearance.rounding.normal
        color: root.isActive
            ? Colours.tPalette.m3primaryContainer
            : root.isSelected
                ? Colours.tPalette.m3secondaryContainer
                : Colours.tPalette.m3surfaceContainerHigh

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
            }
        }

        StateLayer {
            color: root.isActive
                ? Colours.palette.m3onPrimaryContainer
                : root.isSelected
                    ? Colours.palette.m3onSecondaryContainer
                    : Colours.palette.m3onSurface

            function onClicked(): void {
                root.clicked();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.normal

            spacing: Appearance.spacing.small / 2

            // Header: WS number + name
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    text: Compositor.workspaceLabel(root.modelData, root.modelData.id)
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 700
                    color: root.isActive
                        ? Colours.palette.m3onPrimaryContainer
                        : root.isSelected
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData.name === String(root.modelData.id) ? "" : root.modelData.name
                    visible: !Compositor.isNiri && text !== ""
                    font.pointSize: Appearance.font.size.small
                    color: root.isActive
                        ? Colours.palette.m3onPrimaryContainer
                        : root.isSelected
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                // Window count
                StyledText {
                    text: root.windowCount > 0 ? String(root.windowCount) : ""
                    font.pointSize: Appearance.font.size.smaller
                    color: root.isActive
                        ? Colours.palette.m3onPrimaryContainer
                        : Colours.palette.m3onSurfaceVariant
                    visible: root.windowCount > 0
                }
            }

            // App icons
            Row {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: Math.min(root.wsToplevels.length, Config.dashboard.workspaces.maxAppIcons)

                    MaterialIcon {
                        required property int index

                        text: Icons.getAppCategoryIcon(Compositor.isNiri ? root.wsToplevels[index]?.app_id ?? "" : root.wsToplevels[index]?.lastIpcObject?.class ?? "", "terminal")
                        color: root.isActive
                            ? Colours.palette.m3onPrimaryContainer
                            : root.isSelected
                                ? Colours.palette.m3onSecondaryContainer
                                : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.normal
                        opacity: 0.85
                    }
                }

                StyledText {
                    visible: root.wsToplevels.length > Config.dashboard.workspaces.maxAppIcons
                    text: qsTr("+%1").arg(root.wsToplevels.length - Config.dashboard.workspaces.maxAppIcons)
                    font.pointSize: Appearance.font.size.smaller
                    color: root.isActive
                        ? Colours.palette.m3onPrimaryContainer
                        : Colours.palette.m3onSurfaceVariant
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
