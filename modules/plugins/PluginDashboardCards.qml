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
Item {
    id: root

    implicitWidth: grid.implicitWidth
    implicitHeight: Plugins.dashboardPlugins().length > 0 ? grid.implicitHeight : empty.implicitHeight

    GridLayout {
        id: grid

        columns: 2
        columnSpacing: Appearance.spacing.normal
        rowSpacing: Appearance.spacing.normal

        Repeater {
            model: Plugins.dashboardPlugins()

            delegate: StyledRect {
                id: card

                required property var modelData

                Layout.alignment: Qt.AlignTop
                Layout.maximumWidth: 440
                implicitWidth: content.implicitWidth + Appearance.padding.large * 2
                implicitHeight: content.implicitHeight + Appearance.padding.large * 2
                radius: Appearance.rounding.large
                color: Colours.palette.m3surfaceContainer

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

                        // Responsive host context (#372): same
                        // injection contract as the bar host. The
                        // dashboard is a horizontal, edge-less surface;
                        // width is capped at the card content width
                        // reported to the plugin, height is uncapped
                        // (0) because the tab scrolls.
                        readonly property int hostAvailableWidth: 380
                        readonly property int hostAvailableHeight: 0

                        Layout.maximumWidth: hostAvailableWidth
                        clip: true
                        // Same contract as the bar host: plugin default
                        // text inherits the card's themed foreground.
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
                            value: false
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
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: empty

        visible: Plugins.dashboardPlugins().length === 0
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
