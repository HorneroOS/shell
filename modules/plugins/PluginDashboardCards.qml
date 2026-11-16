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
    implicitHeight: hasPlugins ? hint.height + (hint.visible ? Appearance.spacing.small : 0) + scroll.height : empty.implicitHeight

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

        // Keyboard help is noise for pointer users: shown only while the
        // last input was the keyboard (FocusMode), collapsed otherwise.
        visible: root.hasPlugins && FocusMode.keyboard
        height: visible ? implicitHeight : 0
        text: qsTr("Arrows move between cards · Ctrl+arrows reorder · P pins · S resizes")
        font.pointSize: Appearance.font.size.smaller
        color: Colours.palette.m3onSurfaceVariant
    }

    Flickable {
        id: scroll

        visible: root.hasPlugins
        anchors.top: hint.bottom
        anchors.topMargin: hint.visible ? Appearance.spacing.small : 0
        width: root.availableWidth
        height: Math.min(sections.implicitHeight, root.maxViewportHeight)
        contentWidth: width
        contentHeight: sections.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // Sections flow side by side: each section is only as wide as its
        // own cards (up to the viewport), so a section with one or two
        // extensions no longer leaves the rest of the row empty.
        Flow {
            id: sections

            width: scroll.width
            spacing: Appearance.spacing.large

            Repeater {
                model: root.layoutSections

                delegate: ColumnLayout {
                    id: section

                    required property var modelData

                    // Cap by the real width of the viewport too: a section
                    // whose cards would not fit must wrap into fewer
                    // columns, never overflow past the tab edge.
                    // Columns that fit the viewport at a standard card's real
                    // outer width (not the 260 px minimum), so a row never
                    // sums to more than the tab width.
                    readonly property real standardCardWidth: layoutHelper.contentWidth("standard") + Appearance.padding.large * 2
                    readonly property int gridColumns: Math.max(1, Math.min(root.columns, section.modelData.plugins.length, Math.floor((sections.width + Appearance.spacing.normal) / (standardCardWidth + Appearance.spacing.normal))))

                    width: Math.min(sections.width, Math.max(header.implicitWidth, grid.implicitWidth))
                    spacing: Appearance.spacing.small

                    StyledText {
                        id: header

                        text: section.modelData.pinned ? qsTr("Pinned") : section.modelData.category !== "" ? section.modelData.category : qsTr("Other")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 600
                        color: Colours.palette.m3onSurfaceVariant
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }

                    GridLayout {
                        id: grid

                        Layout.fillWidth: true
                        columns: section.gridColumns
                        columnSpacing: Appearance.spacing.normal
                        rowSpacing: Appearance.spacing.normal

                        Repeater {
                            model: section.modelData.plugins

                            delegate: StyledRect {
                                id: card

                                required property var modelData
                                readonly property bool contentReady: card.modelData.state === "loaded" && pluginLoader.status === Loader.Ready
                                readonly property int cardContentWidth: Math.min(layoutHelper.contentWidth(card.modelData.sizeClass), Math.max(160, root.availableWidth - Appearance.padding.large * 2))

                                Layout.alignment: Qt.AlignTop
                                Layout.columnSpan: Math.min(layoutHelper.columnSpan(card.modelData.sizeClass, root.columns), section.gridColumns)
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

                                // Native FocusRing contract: keyboard focus only,
                                // floating 2 px outside the card.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: parent.radius + 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Colours.focusRing
                                    visible: card.activeFocus && FocusMode.keyboard
                                }

                                ColumnLayout {
                                    id: content

                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.small

                                    // A loaded extension owns its card, like a native
                                    // dashboard card: the host name only appears when
                                    // there is no content to identify it (loading, failed).
                                    StyledText {
                                        visible: !card.contentReady
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
                                        // Advertised on the Loader too, so PluginKit
                                        // primitives (UiCard) know they sit inside a
                                        // host card even when the entrypoint does not
                                        // opt in to the host* properties.
                                        readonly property string hostSurface: "dashboard"

                                        Layout.maximumWidth: hostAvailableWidth
                                        clip: true
                                        // Raw Qt Controls an extension uses (TextField,
                                        // ComboBox, ...) take the shell palette instead of
                                        // the Basic style's white fields.
                                        palette.windowText: Colours.palette.m3onSurface
                                        palette.window: Colours.palette.m3surfaceContainer
                                        palette.base: Colours.palette.m3surfaceContainerHigh
                                        palette.alternateBase: Colours.palette.m3surfaceContainerHighest
                                        palette.text: Colours.palette.m3onSurface
                                        palette.placeholderText: Colours.palette.m3onSurfaceVariant
                                        palette.button: Colours.palette.m3surfaceContainerHigh
                                        palette.buttonText: Colours.palette.m3onSurface
                                        palette.highlight: Colours.palette.m3primary
                                        palette.highlightedText: Colours.palette.m3onPrimary
                                        palette.mid: Colours.palette.m3outline
                                        palette.dark: Colours.palette.m3outline
                                        palette.light: Colours.palette.m3surfaceContainerHighest
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

                                    // Status metadata is diagnostic: hidden for a healthy
                                    // extension, shown when it failed/blocked/pending, and
                                    // while the card has keyboard focus (P/S feedback).
                                    RowLayout {
                                        visible: !card.contentReady || (card.activeFocus && FocusMode.keyboard)
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
