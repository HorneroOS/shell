pragma ComponentBehavior: Bound

import ".."
import "../components"
import "../../../services/customisation.js" as Customisation
import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center > Customisation: everything you changed from the HorneroOS
// defaults, in one searchable list, each with Edit (jump to its pane) and
// Reset. "Reset all" returns every look, size and behaviour setting to the
// factory value and never touches your data (apps, paths, favourites,
// layouts, plugins). The factory values come from config/shell.default.json.
Item {
    id: root

    required property Session session

    property var factory: ({})
    property var ranges: ({})
    property int revision: 0
    property string query: ""
    property bool confirmAll: false
    // Re-read on every save so the list follows live edits.
    readonly property var items: {
        const _r = root.revision;
        return Customisation.changed(Config.serializeConfig(), root.factory);
    }
    readonly property var shown: Customisation.filter(root.items, root.query)

    function resetPath(path: string): void {
        const parts = path.split(".");
        let obj = Config;
        for (let i = 0; i < parts.length - 1; i++)
            obj = obj[parts[i]];
        let fac = root.factory;
        for (const p of parts)
            fac = fac[p];
        obj[parts[parts.length - 1]] = fac;
    }

    property string packText: ""
    property string packMessage: ""

    function exportPack(): void {
        root.packText = JSON.stringify(Customisation.exportPack(Config.serializeConfig(), root.factory, qsTr("My look")), null, 2);
        root.packMessage = qsTr("Copy this text to share your look.");
    }

    function importPack(): void {
        let pack = null;
        try {
            pack = JSON.parse(root.packText);
        } catch (e) {
            root.packMessage = qsTr("That is not valid JSON.");
            return;
        }
        const r = Customisation.validatePack(pack, root.factory, root.ranges);
        for (const a of r.accepted) {
            const parts = a.path.split(".");
            let obj = Config;
            for (let i = 0; i < parts.length - 1; i++)
                obj = obj[parts[i]];
            obj[parts[parts.length - 1]] = a.value;
        }
        if (r.accepted.length > 0)
            Config.save();
        root.revision++;
        root.packMessage = r.rejected.length > 0 ? qsTr("Applied %1 setting(s); skipped %2 (%3).").arg(r.accepted.length).arg(r.rejected.length).arg(r.rejected[0].reason) : qsTr("Applied %1 setting(s).").arg(r.accepted.length);
    }

    function resetItems(list: var): void {
        for (const it of list)
            root.resetPath(it.path);
        Config.save();
        root.confirmAll = false;
        root.revision++;
    }

    anchors.fill: parent

    FileView {
        path: Quickshell.shellPath("config/shell.default.json")
        blockLoading: true
        onLoaded: {
            try {
                root.factory = JSON.parse(text());
            } catch (e) {
                root.factory = {};
            }
        }
    }

    FileView {
        path: Quickshell.shellPath("config/ranges.json")
        blockLoading: true
        onLoaded: {
            try {
                root.ranges = JSON.parse(text()).ranges ?? {};
            } catch (e) {
                root.ranges = {};
            }
        }
    }

    Connections {
        target: Config

        function onRecentlySavedChanged(): void {
            root.revision++;
        }
    }

    StyledFlickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        flickableDirection: Flickable.VerticalFlick
        contentHeight: content.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flick
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Appearance.spacing.normal

            PaneHeader {
                paneId: "customisation"
                intro: qsTr("HorneroOS ships its best defaults, and every value here is yours to change. This page lists what you have changed, so you can find it, edit it or put it back.")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                SearchBar {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search your changes")
                    Accessible.name: qsTr("Search changed settings")
                    onTextChanged: root.query = text
                }

                TextButton {
                    text: qsTr("Search all settings")
                    type: TextButton.Tonal
                    onClicked: root.session.searchOpen = true
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.items.length === 0 ? qsTr("Everything is at the HorneroOS default.") : qsTr("%n setting(s) differ from the default.", "", root.items.length)
                font.pointSize: Appearance.font.size.normal
                color: Signal.palette.inkMuted
            }

            RowLayout {
                visible: root.items.length > 0
                spacing: Appearance.spacing.small

                TextButton {
                    visible: !root.confirmAll
                    text: qsTr("Reset all")
                    type: TextButton.Tonal
                    Accessible.name: qsTr("Reset all customised settings to the HorneroOS defaults")
                    onClicked: root.confirmAll = true
                }

                StyledText {
                    visible: root.confirmAll
                    text: qsTr("Reset %n setting(s)? Your apps, files and layouts are not touched.", "", root.items.length)
                    color: Signal.palette.alert
                    font.pointSize: Appearance.font.size.small
                }

                TextButton {
                    visible: root.confirmAll
                    text: qsTr("Yes, reset all")
                    type: TextButton.Tonal
                    onClicked: root.resetItems(root.items)
                }

                TextButton {
                    visible: root.confirmAll
                    text: qsTr("Cancel")
                    type: TextButton.Text
                    onClicked: root.confirmAll = false
                }
            }

            StyledText {
                text: qsTr("Share a look")
                font.pointSize: Appearance.font.size.normal
                font.weight: Appearance.font.weight.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Export turns your changes into text you can send to a friend. Paste someone else's text and press Import to try their look; only known look and size settings are accepted.")
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 120
                radius: Appearance.rounding.normal
                color: Signal.layer(Signal.palette.panel, 1)

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    clip: true
                    contentHeight: packEdit.implicitHeight

                    TextEdit {
                        id: packEdit

                        width: parent.width
                        text: root.packText
                        onTextChanged: root.packText = text
                        color: Signal.palette.ink
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.small
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        Accessible.name: qsTr("Look pack text")
                    }
                }
            }

            RowLayout {
                spacing: Appearance.spacing.small

                TextButton {
                    text: qsTr("Export")
                    type: TextButton.Tonal
                    onClicked: root.exportPack()
                }

                TextButton {
                    text: qsTr("Import")
                    type: TextButton.Tonal
                    onClicked: root.importPack()
                }

                StyledText {
                    text: root.packMessage
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }

            Repeater {
                model: root.shown

                StyledRect {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Signal.layer(Signal.palette.panel, 1)
                    implicitHeight: rowLayout.implicitHeight + Appearance.padding.normal * 2

                    RowLayout {
                        id: rowLayout

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                font.pointSize: Appearance.font.size.normal
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("%1  (default %2)").arg(Customisation.display(row.modelData.current)).arg(Customisation.display(row.modelData.factory))
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                mono: true
                                elide: Text.ElideRight
                            }
                        }

                        TextButton {
                            text: qsTr("Edit")
                            type: TextButton.Text
                            Accessible.name: qsTr("Edit %1").arg(row.modelData.label)
                            onClicked: root.session.navigateTo(row.modelData.pane, row.modelData.section)
                        }

                        TextButton {
                            text: qsTr("Reset")
                            type: TextButton.Tonal
                            Accessible.name: qsTr("Reset %1 to default").arg(row.modelData.label)
                            onClicked: root.resetItems([row.modelData])
                        }
                    }
                }
            }
        }
    }
}
