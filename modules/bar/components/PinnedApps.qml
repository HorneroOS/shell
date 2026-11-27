import "dockapps.js" as DockApps
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Pinned application shortcuts & running-window dock (HorneroOS/shell#737).
// options.apps lists desktop-entry ids; entries resolve via DesktopEntries.
// In dock mode (`bar.style === "dock"`), unpinned running windows are merged
// alongside pinned launchers, every tile shows running/active dot indicators,
// left-click focuses/cycles running windows (or launches when idle), and
// middle-click launches a fresh instance.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property bool dock: false
    property string edge: "bottom"
    property var options: ({})

    readonly property var allDesktopEntries: Config.bar.toArray(DesktopEntries.applications.values)
    readonly property var pinnedEntries: {
        // Read .values instead of calling heuristicLookup alone: the entry
        // database populates asynchronously and .values notifies when it
        // lands, so pins resolve after startup instead of staying empty.
        const byId = {};
        for (const e of allDesktopEntries) {
            byId[e.id] = e;
            if (e.id.endsWith(".desktop"))
                byId[e.id.slice(0, -8)] = e;
        }
        const out = [];
        for (const id of Config.bar.toArray(options.apps)) {
            const entry = byId[id] ?? DesktopEntries.heuristicLookup(id);
            if (entry)
                out.push(entry);
        }
        return out;
    }

    readonly property var dockItems: DockApps.buildDockItems(
        root.pinnedEntries,
        root.allDesktopEntries,
        Compositor.allWindowSummaries(),
        root.dock
    )

    // Icon size in logical px (options.iconSize, 16..40). Defaults to the
    // bar icon size; the Console dock ships larger tiles.
    readonly property int pinPx: {
        const v = Number(options.iconSize);
        return v > 0 ? Math.max(16, Math.min(40, Math.round(v))) : Density.iconPx;
    }

    visible: dockItems.length > 0
    implicitWidth: visible ? layout.implicitWidth : 0
    implicitHeight: visible ? layout.implicitHeight : 0

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Appearance.spacing.smaller
        columnSpacing: Appearance.spacing.smaller

        Repeater {
            model: root.dockItems

            Item {
                id: tile

                required property var modelData
                readonly property bool running: modelData.runningCount > 0
                readonly property bool active: modelData.active === true
                readonly property string iconUrl: Quickshell.iconPath(modelData.icon, "application-x-executable")
                readonly property string tipText: modelData.runningCount > 1
                    ? qsTr("%1 (%2 windows)").arg(modelData.name).arg(modelData.runningCount)
                    : modelData.runningCount === 1
                        ? qsTr("%1 (running)").arg(modelData.name)
                        : modelData.name

                implicitWidth: implicitHeight
                implicitHeight: root.pinPx + 8

                Interactive {
                    id: interaction

                    radius: Appearance.rounding.small
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    Accessible.role: Accessible.Button
                    Accessible.name: tile.tipText
                    onClicked: mouse => {
                        if (mouse && mouse.button === Qt.MiddleButton) {
                            if (tile.modelData.entry)
                                tile.modelData.entry.execute();
                            return;
                        }
                        if (tile.running) {
                            const target = DockApps.nextFocusWindow(tile.modelData.windows);
                            if (target) {
                                Compositor.focusWindow(target.id ?? target.address);
                                return;
                            }
                        }
                        if (tile.modelData.entry)
                            tile.modelData.entry.execute();
                    }
                }

                Tooltip {
                    target: tile
                    text: tile.tipText
                }

                Image {
                    anchors.centerIn: parent
                    source: tile.iconUrl
                    sourceSize.width: root.pinPx
                    sourceSize.height: root.pinPx
                    width: root.pinPx
                    height: root.pinPx
                    asynchronous: true
                    smooth: true
                }

                // Running / active indicator dot(s) on the bar's outer edge.
                Row {
                    id: dots

                    visible: tile.running
                    spacing: 2
                    anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
                    anchors.bottom: !root.vertical && root.edge !== "top" ? parent.bottom : undefined
                    anchors.top: !root.vertical && root.edge === "top" ? parent.top : undefined
                    anchors.left: root.vertical && root.edge === "left" ? parent.left : undefined
                    anchors.right: root.vertical && root.edge !== "left" ? parent.right : undefined
                    anchors.margins: 1

                    Repeater {
                        model: Math.min(3, Math.max(0, tile.modelData.runningCount))

                        Rectangle {
                            required property int index

                            width: tile.active && index === 0 ? 6 : 3
                            height: 3
                            radius: 1.5
                            color: tile.active ? root.tone.signal : root.tone.inkMuted
                        }
                    }
                }
            }
        }
    }
}
