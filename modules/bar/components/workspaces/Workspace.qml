import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root

    required property ShellScreen screen

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Labels style: always the workspace number, plus an underline (accent
    // when active, faint when occupied). Set by Workspaces.
    property bool labels: false
    readonly property bool isActive: activeWsId === ws
    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property string accessibleState: root.isActive ? qsTr("current") : root.isOccupied ? qsTr("occupied") : qsTr("empty")
    // Unanimated prop for others to use as reference (main-axis size)
    readonly property int size: (vertical ? implicitHeight : implicitWidth) + (hasWindows ? Appearance.padding.small : 0)

    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.preferredHeight: vertical ? size : implicitHeight
    Layout.preferredWidth: vertical ? implicitWidth : size

    flow: vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: vertical ? -1 : 1
    columns: vertical ? 1 : -1
    rowSpacing: 0
    columnSpacing: 0

    Interactive {
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Workspace %1, %2").arg(root.ws).arg(root.accessibleState)
        Accessible.description: root.isActive ? qsTr("Activating the current workspace opens the special workspace") : qsTr("Switch to workspace %1").arg(root.ws)

        onClicked: {
            if (root.activeWsId !== root.ws)
                Hypr.dispatch(`workspace ${root.ws}`);
            else
                Hypr.dispatch("togglespecialworkspace special");
        }
    }

    StyledText {
        id: indicator

        Layout.alignment: root.vertical ? Qt.AlignHCenter | Qt.AlignTop : Qt.AlignVCenter | Qt.AlignLeft
        Layout.preferredHeight: root.vertical ? Config.bar.sizes.innerWidth - Appearance.padding.small * 2 : implicitHeight
        Layout.preferredWidth: root.vertical ? implicitWidth : Config.bar.sizes.innerWidth - Appearance.padding.small * 2

        animate: true
        text: {
            const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
            const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
            let displayName = wsName.toString();
            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                displayName = displayName.toUpperCase();
            } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                displayName = displayName.toLowerCase();
            }
            if (root.labels)
                return displayName;
            const label = Config.bar.workspaces.label || displayName;
            const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
            const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
            return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
        }
        color: {
            if (root.labels)
                return root.isActive ? Colours.palette.m3primary : root.isOccupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant;
            return Config.bar.workspaces.occupiedBg || root.isOccupied || root.isActive ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2);
        }
        verticalAlignment: Qt.AlignVCenter
        horizontalAlignment: Qt.AlignHCenter
    }

    Loader {
        id: windows

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.fillHeight: root.vertical
        Layout.fillWidth: !root.vertical
        Layout.topMargin: root.vertical ? -Config.bar.sizes.innerWidth / 10 : 0
        Layout.leftMargin: root.vertical ? 0 : -Config.bar.sizes.innerWidth / 10

        visible: active
        active: root.hasWindows

        sourceComponent: root.vertical ? vIconsComp : hIconsComp
    }

    Component {
        id: vIconsComp

        Column {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Hypr.toplevels.values.filter(c => c.workspace?.id === root.ws).slice(0, Config.bar.workspaces.maxWindowIcons)
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Component {
        id: hIconsComp

        Row {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Hypr.toplevels.values.filter(c => c.workspace?.id === root.ws).slice(0, Config.bar.workspaces.maxWindowIcons)
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Behavior on Layout.preferredHeight {
        Anim {}
    }

    Behavior on Layout.preferredWidth {
        Anim {}
    }
}
