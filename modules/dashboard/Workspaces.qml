pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import "dash"
import Quickshell
import QtQuick
import QtQuick.Layouts

// Dashboard Workspaces tab (Signal Bezel): framed modules like the rest of
// the dashboard; workspace cells are fixed rectangles, never pills.
//
// Top row: active workspace preview card (left) + window list card (right).
// Bottom row: workspace selector cards in a flow + special workspaces.
Item {
    id: root

    readonly property var nativeWorkspaces: Compositor.workspacesForScreen({ name: Compositor.focusedOutputName })
    // The event stream can briefly be empty while Niri starts. Child controls
    // accept an integer workspace id, so give them a stable, real workspace
    // instead of passing null through the first QML binding pass.
    property int selectedWsId: Compositor.activeWorkspaceIdForScreen({ name: Compositor.focusedOutputName }) ?? nativeWorkspaces[0]?.id ?? 1

    readonly property var regularWorkspaces: {
        if (Compositor.isNiri)
            return nativeWorkspaces;
        return nativeWorkspaces.filter(w => !w.name.startsWith("special:")).sort((a, b) => a.id - b.id);
    }

    readonly property var specialWorkspaces: {
        return Compositor.isNiri ? [] : nativeWorkspaces.filter(w => w.name.startsWith("special:"));
    }

    readonly property var selectedWorkspace: {
        return regularWorkspaces.find(w => w.id === root.selectedWsId) ?? null;
    }

    readonly property string activeSpecialName: Compositor.isSpecialWorkspaceActive({ name: Compositor.focusedOutputName }, true)
        ? Hypr.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? ""
        : ""

    Component.onCompleted: root.selectedWsId = Compositor.activeWorkspaceIdForScreen({ name: Compositor.focusedOutputName }) ?? nativeWorkspaces[0]?.id ?? 1

    implicitWidth: 968
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: Appearance.spacing.normal

        // ── Top row: preview + window list ────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            spacing: Appearance.spacing.normal

            // Left: active/selected workspace preview + actions
            Instruments.Frame {
                Layout.fillWidth: true
                Layout.minimumWidth: 400
                Layout.preferredHeight: headerHeight + previewCol.implicitHeight + 16

                channel: "01"
                title: root.selectedWorkspace ? Compositor.workspaceLabel(root.selectedWorkspace, root.selectedWsId) : qsTr("Workspace %1").arg(root.selectedWsId ?? "\u2014")
                context: {
                    const n = Compositor.windowsForWorkspace(root.selectedWsId).length;
                    return n === 0 ? qsTr("Empty") : (n === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(n));
                }

                ColumnLayout {
                    id: previewCol

                    anchors.left: parent.left
                    anchors.right: parent.right

                    spacing: Appearance.spacing.normal

                    // Live preview
                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: active ? Config.dashboard.workspaces.previewHeight : 0

                        active: Config.dashboard.workspaces.showLivePreview && root.selectedWorkspace !== null && Compositor.supports("nativeWindowThumbnails")

                        sourceComponent: WorkspacePreview {
                            wsId: root.selectedWsId
                        }
                    }

                    // Actions bar
                    WsActionsBar {
                        Layout.fillWidth: true
                        wsId: root.selectedWsId
                    }
                }
            }

            // Right: window list
            Instruments.Frame {
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                Layout.preferredHeight: headerHeight + previewCol.implicitHeight + 16

                channel: "02"
                title: qsTr("Windows")
                context: Compositor.windowsForWorkspace(root.selectedWsId).length > 0 ? String(Compositor.windowsForWorkspace(root.selectedWsId).length) : ""

                WorkspaceDetail {
                    anchors.fill: parent
                    wsId: root.selectedWsId
                    workspace: root.selectedWorkspace
                }
            }
        }

        // ── Bottom: workspace selector cards ──────────────────────────
        Instruments.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: headerHeight + wsFlowCol.implicitHeight + 16

            channel: "03"
            title: qsTr("Workspaces")

            ColumnLayout {
                id: wsFlowCol

                anchors.left: parent.left
                anchors.right: parent.right

                spacing: Appearance.spacing.normal

                // Special workspace chips
                Row {
                    visible: Config.dashboard.workspaces.showSpecialWorkspaces && root.specialWorkspaces.length > 0
                    spacing: Appearance.spacing.small / 2

                    Repeater {
                        model: root.specialWorkspaces

                        delegate: SpecialWsCard {
                            isActive: modelData.name === root.activeSpecialName

                            onClicked: {
                                Hypr.dispatch(`togglespecialworkspace ${modelData.name.slice("special:".length)}`);
                            }
                        }
                    }
                }

                // Workspace cards flow
                Flow {
                    Layout.fillWidth: true

                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.regularWorkspaces

                        delegate: WorkspaceCard {
                            isActive: modelData.id === Compositor.activeWorkspaceIdForScreen({ name: Compositor.focusedOutputName })
                            isSelected: modelData.id === root.selectedWsId

                            onClicked: {
                                root.selectedWsId = modelData.id;
                                Compositor.focusWorkspace(modelData);
                            }
                        }
                    }

                    // Empty state
                    StyledText {
                        visible: root.regularWorkspaces.length === 0
                        text: qsTr("No workspaces open")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.normal
                    }
                }
            }
        }
    }
}
