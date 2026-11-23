pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.filedialog
import qs.components.motion
import qs.modules.plugins
// Qualified: unqualified qs.services would shadow this directory's
// Media/Weather page types with its same-named singletons.
import qs.services as Services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker
    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    // Focusable root for S4 keyboard navigation. Escape delivery
    // does NOT depend on Qt item focus: the HyprlandFocusGrab (see
    // Drawers.qml) routes physical keys to this surface on explicit
    // opens, and the central cascade handles them (INTERACTION.md).
    focus: true

    // Tab model (shell#709): native pages first, contributed
    // extension pages (PluginKit 5) next, Extensions last — exactly
    // the pre-contribution order when no extension contributes a tab.
    // Selection resolves by stable key; the legacy integer is only a
    // fallback for state written before keys existed, and a key that
    // names a removed tab falls back to the first tab instead of
    // landing on a neighbour that reused its old index.
    readonly property var extensionTabs: extStable.list
    // Native labels stay untranslated keys here; Tabs.qml renders
    // them through qsTr (its historical translation context), while
    // contributed titles are the extension's own manifest strings.
    readonly property var tabItems: [
        { key: "dash", glyph: "dashboard", label: "Dashboard" },
        { key: "media", glyph: "playlist", label: "Media" },
        { key: "performance", glyph: "gauge", label: "Performance" },
        { key: "weather", glyph: "cloud", label: "Weather" },
        { key: "workspaces", glyph: "layout-grid", label: "Workspaces" }
    ].concat(root.extensionTabs.map(t => ({ key: t.key, glyph: t.glyph, label: t.title }))).concat([
        { key: "extensions", glyph: "puzzle", label: "Extensions" }
    ])
    readonly property int currentIndex: {
        const key = "currentTabKey" in root.state ? root.state.currentTabKey : "";
        if (key !== "") {
            const byKey = root.tabItems.findIndex(t => t.key === key);
            return byKey >= 0 ? byKey : 0;
        }
        return Math.max(0, Math.min(root.state.currentTab, root.tabItems.length - 1));
    }

    function selectTab(index: int): void {
        const clamped = Math.max(0, Math.min(index, root.tabItems.length - 1));
        root.state.currentTab = clamped;
        if ("currentTabKey" in root.state)
            root.state.currentTabKey = root.tabItems[clamped]?.key ?? "";
    }

    // Deep link (`qs ipc call drawers dashboardTab <key>`): the IPC
    // handler records the key and opens the drawer; consume it here
    // once this content (and its tab model) exists.
    function consumePendingTab(): void {
        const key = Services.Plugins.pendingDashboardTabKey;
        if (key === "")
            return;
        const index = root.tabItems.findIndex(t => t.key === key);
        if (index >= 0) {
            root.selectTab(index);
            Services.Plugins.pendingDashboardTabKey = "";
        }
    }

    Component.onCompleted: consumePendingTab()
    onTabItemsChanged: consumePendingTab()

    Connections {
        target: Services.Plugins

        function onPendingDashboardTabKeyChanged(): void {
            root.consumePendingTab();
        }
    }

    StableList {
        id: extStable

        source: Services.Plugins.dashboardTabList()
    }

    AtmosphereTexture {}

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.padding.normal
        anchors.margins: Appearance.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        state: root.state
        tabItems: root.tabItems
        selectedIndex: root.currentIndex
    }

    Item {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        clip: true

        Flickable {
            id: view

            // Real clip (the rounded ClippingRectangle clips by shader and
            // leaves clip false): FocusMode skips off-screen neighbour panes.
            clip: true

            readonly property int currentIndex: root.currentIndex
            readonly property Item currentItem: row.children[Math.min(currentIndex, row.children.length - 1)]

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: currentItem.implicitWidth
            implicitHeight: currentItem.implicitHeight

            contentX: currentItem.x
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.selectTab(Math.min(root.currentIndex + 1, tabs.count - 1));
                else if (x < -currentItem.implicitWidth / 2)
                    root.selectTab(Math.max(root.currentIndex - 1, 0));
            }

            onDragEnded: {
                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.selectTab(Math.min(root.currentIndex + 1, tabs.count - 1));
                else if (x < -currentItem.implicitWidth / 10)
                    root.selectTab(Math.max(root.currentIndex - 1, 0));
                else
                    contentX = Qt.binding(() => currentItem.x);
            }

            RowLayout {
                id: row

                Pane {
                    index: 0
                    sourceComponent: Dash {
                        visibilities: root.visibilities
                        state: root.state
                        facePicker: root.facePicker
                    }
                }

                Pane {
                    index: 1
                    sourceComponent: Media {
                        visibilities: root.visibilities
                    }
                }

                Pane {
                    index: 2
                    sourceComponent: Performance {}
                }

                Pane {
                    index: 3
                    sourceComponent: Weather {}
                }

                Pane {
                    index: 4
                    sourceComponent: Workspaces {}
                }

                Repeater {
                    model: root.extensionTabs

                    ExtPane {}
                }

                Pane {
                    index: 5 + root.extensionTabs.length
                    sourceComponent: Extensions {}
                }
            }

            // Pane slide is position: settle (§11 table, dashboard tabs).
            Behavior on contentX {
                MotionAnim {
                    kind: "settle"
                }
            }
        }
    }

    // Tab content size switch is size: settle (§11 table).
    Behavior on implicitWidth {
        MotionAnim {
            kind: "settle"
        }
    }

    Behavior on implicitHeight {
        MotionAnim {
            kind: "settle"
        }
    }

    component Pane: Loader {
        id: pane

        required property int index

        Layout.alignment: Qt.AlignTop

        Component.onCompleted: active = Qt.binding(() => {
            // Keep the current tab and its neighbours loaded. Deliberately
            // geometry-free: deriving this from visibleArea loops back into
            // the panes' implicit sizes (binding loop).
            return Math.abs(pane.index - view.currentIndex) <= 1;
        })
    }

    // One contributed page (shell#709), hosted exactly like a native
    // Pane: lazy (current ± neighbour) in its own failure-isolated
    // Loader (PluginDashboardTab owns the plugin Loader and errors).
    component ExtPane: Loader {
        id: extPane

        required property var modelData
        required property int index
        readonly property int tabIndex: 5 + index

        Layout.alignment: Qt.AlignTop

        sourceComponent: PluginDashboardTab {
            tab: extPane.modelData
        }

        Component.onCompleted: active = Qt.binding(() => Math.abs(extPane.tabIndex - view.currentIndex) <= 1)
    }

    // Atmosphere: warm lamp, soft inner light, vignette, grain (section 17).
    AtmosphereLayer {
        lampOrigin: "topLeft"
        lampReach: 0.8
        cornerRadius: Appearance.rounding.small
    }
}
