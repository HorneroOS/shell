pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Dashboard placement for community plugins (M2): renders every
// enabled plugin whose manifest declares `placement: "dashboard"` as
// a card in the dashboard Extensions tab. Each plugin gets its own
// Loader, so a failing entrypoint is marked failed through the
// Plugins service and never takes the dashboard (or other plugins)
// down. Plugin QML runs with the logged-in user's permissions; it is
// NOT sandboxed.
//
// Composable layout (shell#378): cards are grouped into sections —
// user-pinned first, then manifest categories alphabetically, then
// uncategorized ("Other") — inside a vertically scrolling viewport
// with a responsive column count, replacing the old fixed 2-column
// grid. Card size classes (compact/standard/wide), order and pins
// come from the persisted user layout
// (Config.plugins.dashboardLayout), which overrides the manifest's
// size/category hints. The whole arrangement is computed once per
// model/layout change by layoutHelper.sectionsFor(), never per
// card, and every plugin Loader stays asynchronous, so dozens of
// cards do not multiply layout work. Focused cards take keyboard
// configuration: Ctrl+arrows reorder, P pins/unpins, S cycles the
// size class; plain arrows move focus between cards and
// PageUp/PageDown scroll.
Item {
    id: root

    // Scroll viewport cap: the tab never grows the dashboard past
    // this height; extra cards scroll instead.
    property int maxViewportHeight: 600
    property string focusedId: ""
    // Live delegate registry for keyboard focus moves (plain map,
    // mutated on delegate create/destroy).
    property var cardItems: ({})

    readonly property var layoutSections: layoutHelper.sectionsFor(Plugins.dashboardPlugins(), Config.plugins.dashboardLayout)
    readonly property var visibleIds: root.layoutSections.reduce((ids, section) => ids.concat(section.plugins.map(p => p.id)), [])
    readonly property bool hasPlugins: root.visibleIds.length > 0
    readonly property real availableWidth: width > 0 ? width : 840
    readonly property int columns: layoutHelper.columnsForWidth(root.availableWidth, Appearance.spacing.normal)

    implicitWidth: 840
    implicitHeight: hasPlugins ? hint.implicitHeight + Appearance.spacing.small + scroll.height : empty.implicitHeight

    function focusCard(id: string): void {
        root.focusedId = id;
        const item = root.cardItems[id];
        if (item)
            item.forceActiveFocus();
    }

    function scrollBy(delta: real): void {
        const maxY = Math.max(0, scroll.contentHeight - scroll.height);
        scroll.contentY = Math.max(0, Math.min(maxY, scroll.contentY + delta));
    }

    // One keyboard contract for every card; returns true when the key
    // was consumed. Reorder/pin/size write through Config.plugins, so
    // they persist in shell.json like every other user plugin value.
    function handleCardKey(plugin: var, event: var): bool {
        const id = plugin.id;
        if (event.key === Qt.Key_PageDown) {
            root.scrollBy(scroll.height);
        } else if (event.key === Qt.Key_PageUp) {
            root.scrollBy(-scroll.height);
        } else if (event.modifiers & Qt.ControlModifier
                && (event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Down || event.key === Qt.Key_Right)) {
            const delta = event.key === Qt.Key_Up || event.key === Qt.Key_Left ? -1 : 1;
            const layout = Config.plugins.dashboardLayout;
            const order = layoutHelper.movedOrder(layout && layout.order ? layout.order : [], root.visibleIds, id, delta);
            Config.plugins.setDashboardOrder(order);
            root.focusedId = id;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
            const step = event.key === Qt.Key_Up ? -root.columns : event.key === Qt.Key_Down ? root.columns : event.key === Qt.Key_Left ? -1 : 1;
            const index = root.visibleIds.indexOf(id);
            const target = root.visibleIds[Math.max(0, Math.min(root.visibleIds.length - 1, index + step))];
            if (target)
                root.focusCard(target);
        } else if (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier)) {
            Config.plugins.setDashboardPinned(id, !plugin.pinned);
            root.focusedId = id;
        } else if (event.key === Qt.Key_S && !(event.modifiers & Qt.ControlModifier)) {
            Config.plugins.setDashboardCardSize(id, layoutHelper.nextSize(plugin.sizeClass));
            root.focusedId = id;
        } else {
            return false;
        }
        event.accepted = true;
        return true;
    }

    DashboardLayout {
        id: layoutHelper
    }

    StyledText {
        id: hint

        visible: root.hasPlugins
        text: qsTr("Arrows move between cards · Ctrl+arrows reorder · P pins · S resizes")
        font.pointSize: Appearance.font.size.smaller
        color: Colours.palette.m3onSurfaceVariant
    }

    Flickable {
        id: scroll

        visible: root.hasPlugins
        anchors.top: hint.bottom
        anchors.topMargin: Appearance.spacing.small
        width: root.availableWidth
        height: Math.min(sections.implicitHeight, root.maxViewportHeight)
        contentWidth: width
        contentHeight: sections.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: sections

            width: scroll.width
            spacing: Appearance.spacing.large

            Repeater {
                model: root.layoutSections

                delegate: ColumnLayout {
                    id: section

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: section.modelData.pinned ? qsTr("Pinned") : section.modelData.category !== "" ? section.modelData.category : qsTr("Other")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 600
                        color: Colours.palette.m3onSurfaceVariant
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.columns
                        columnSpacing: Appearance.spacing.normal
                        rowSpacing: Appearance.spacing.normal

                        Repeater {
                            model: section.modelData.plugins

                            delegate: StyledRect {
                                id: card

                                required property var modelData
                                readonly property int cardContentWidth: Math.min(layoutHelper.contentWidth(card.modelData.sizeClass), Math.max(160, root.availableWidth - Appearance.padding.large * 2))

                                Layout.alignment: Qt.AlignTop
                                Layout.columnSpan: layoutHelper.columnSpan(card.modelData.sizeClass, root.columns)
                                Layout.maximumWidth: cardContentWidth + Appearance.padding.large * 2
                                implicitWidth: content.implicitWidth + Appearance.padding.large * 2
                                implicitHeight: content.implicitHeight + Appearance.padding.large * 2
                                radius: Appearance.rounding.large
                                color: Colours.palette.m3surfaceContainer

                                activeFocusOnTab: true
                                Accessible.role: Accessible.Pane
                                Accessible.name: card.modelData.name || card.modelData.id
                                Accessible.description: qsTr("Dashboard extension card. Ctrl+arrows reorder, P pins, S resizes.")

                                Component.onCompleted: {
                                    root.cardItems[card.modelData.id] = card;
                                    if (root.focusedId === card.modelData.id)
                                        card.forceActiveFocus();
                                }
                                Component.onDestruction: {
                                    if (root.cardItems[card.modelData.id] === card)
                                        delete root.cardItems[card.modelData.id];
                                }
                                onActiveFocusChanged: {
                                    if (activeFocus)
                                        root.focusedId = card.modelData.id;
                                }
                                Keys.onPressed: event => root.handleCardKey(card.modelData, event)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Colours.palette.m3primary
                                    visible: card.activeFocus
                                }

                                ColumnLayout {
                                    id: content

                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.small

                                    StyledText {
                                        text: card.modelData.name || card.modelData.id
                                        font.pointSize: Appearance.font.size.normal
                                        color: Colours.palette.m3onSurface
                                    }

                                    Loader {
                                        id: pluginLoader

                                        // Responsive host context (#372):
                                        // same injection contract as the
                                        // bar host; #378 size classes set
                                        // the offered width (standard
                                        // keeps the historic 380) and a
                                        // compact card reports hostCompact.
                                        readonly property int hostAvailableWidth: card.cardContentWidth
                                        readonly property int hostAvailableHeight: 0

                                        Layout.maximumWidth: hostAvailableWidth
                                        clip: true
                                        palette.windowText: Colours.palette.m3onSurface
                                        source: card.modelData.entrypoint ? `file://${Plugins.pluginsDir}/${card.modelData.id}/${card.modelData.entrypoint}` : ""
                                        asynchronous: true

                                        onStatusChanged: {
                                            if (status === Loader.Ready)
                                                Plugins.markLoaded(card.modelData.id);
                                            else if (status === Loader.Error)
                                                Plugins.markFailed(card.modelData.id, pluginLoader.errorString || "dashboard entrypoint failed to load (see shell log)");
                                        }

                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostOrientation"
                                            value: "horizontal"
                                            when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostEdge"
                                            value: "none"
                                            when: pluginLoader.item !== null && "hostEdge" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostSurface"
                                            value: "dashboard"
                                            when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostAvailableWidth"
                                            value: pluginLoader.hostAvailableWidth
                                            when: pluginLoader.item !== null && "hostAvailableWidth" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostAvailableHeight"
                                            value: pluginLoader.hostAvailableHeight
                                            when: pluginLoader.item !== null && "hostAvailableHeight" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostCompact"
                                            value: card.modelData.sizeClass === "compact"
                                            when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                        Binding {
                                            target: pluginLoader.item
                                            property: "hostScreenName"
                                            value: ""
                                            when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
                                            restoreMode: Binding.RestoreNone
                                        }
                                    }

                                    StyledText {
                                        visible: pluginLoader.status === Loader.Error
                                        text: qsTr("This plugin failed to load.")
                                        color: Colours.palette.m3error
                                    }

                                    RowLayout {
                                        spacing: Appearance.spacing.small

                                        StyledRect {
                                            Layout.preferredHeight: stateLabel.implicitHeight + 6
                                            Layout.preferredWidth: stateLabel.implicitWidth + 14
                                            radius: Appearance.rounding.full
                                            color: card.modelData.state === "failed" || card.modelData.state === "blocked" ? Colours.palette.m3errorContainer : card.modelData.state === "loaded" ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

                                            StyledText {
                                                id: stateLabel

                                                anchors.centerIn: parent
                                                text: card.modelData.state === "loaded" ? qsTr("Loaded") : card.modelData.state === "failed" ? qsTr("Failed") : card.modelData.state === "blocked" ? qsTr("Blocked") : qsTr("Pending")
                                                font.pointSize: Appearance.font.size.smaller
                                                font.weight: 600
                                                color: card.modelData.state === "failed" || card.modelData.state === "blocked" ? Colours.palette.m3onErrorContainer : card.modelData.state === "loaded" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                            }
                                        }

                                        StyledText {
                                            visible: !!card.modelData.version
                                            text: "v" + (card.modelData.version || "")
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            visible: !!card.modelData.trust
                                            text: card.modelData.trust || ""
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            visible: !!card.modelData.pinned
                                            text: qsTr("Pinned")
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3primary
                                        }

                                        StyledText {
                                            text: card.modelData.sizeClass || "standard"
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: empty

        visible: !root.hasPlugins
        spacing: Appearance.spacing.small

        StyledText {
            text: qsTr("No dashboard plugins")
            font.pointSize: Appearance.font.size.large
        }

        StyledText {
            text: qsTr("Enabled plugins that declare dashboard placement show up here as cards.")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
