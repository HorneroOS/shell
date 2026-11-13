pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Desktop placement for community plugins (M2): renders every
// enabled plugin whose manifest declares `placement: "desktop"` in
// one of nine stable slots per display. Slot choices live in the
// user-owned Shell config; resolution changes preserve them, and a
// disconnected display keeps its saved entry for a later reconnect.
// Each plugin gets its own Loader, so one failing entrypoint cannot
// take the desktop or its neighbours down. Plugin QML runs with the
// logged-in user's permissions; it is NOT sandboxed.
Item {
    id: root

    required property string screenName
    visible: Plugins.desktopPlugins().length > 0
    readonly property var slotNames: [
        "top-left", "top-center", "top-right",
        "middle-left", "middle-center", "middle-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    GridLayout {
        anchors.fill: parent
        columns: 3
        rows: 3
        columnSpacing: Appearance.spacing.normal
        rowSpacing: Appearance.spacing.normal

        Repeater {
            model: root.slotNames.length

            delegate: Item {
                id: slotCell

                required property int index
                readonly property string slotName: root.slotNames[index]
                readonly property int row: Math.floor(index / 3)
                readonly property int column: index % 3

                Layout.row: row
                Layout.column: column
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Appearance.spacing.normal

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: slotCell.row > 0
                    }

                    Repeater {
                        model: Plugins.desktopPlugins().filter(plugin => Config.plugins.desktopWidgetSlot(plugin.id, root.screenName) === slotCell.slotName)

                        delegate: StyledRect {
                            id: card

                            required property var modelData

                            Layout.alignment: slotCell.column === 0 ? Qt.AlignLeft : slotCell.column === 1 ? Qt.AlignHCenter : Qt.AlignRight
                            Layout.maximumWidth: 360
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

                                    // Responsive host context (#372):
                                    // same injection contract as the bar
                                    // host. Desktop cards are horizontal
                                    // and edge-less; width is capped at
                                    // the reported value, height is
                                    // uncapped (0). screenName identifies
                                    // which display this instance is on.
                                    readonly property int hostAvailableWidth: 300
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
                                            Plugins.markFailed(card.modelData.id, pluginLoader.errorString || "desktop entrypoint failed to load (see shell log)");
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
                                        value: "desktop"
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
                                        value: root.screenName
                                        when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
                                        restoreMode: Binding.RestoreNone
                                    }
                                }

                                StyledText {
                                    visible: pluginLoader.status === Loader.Error
                                    text: qsTr("This plugin failed to load.")
                                    color: Colours.palette.m3error
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: slotCell.row < 2
                    }
                }
            }
        }
    }
}
