pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 06 — Extensions ("Extend Your Hornero"):
// Reads real ExtensionStore.catalogue, shows curated highlights with
// publisher/trust disclosure, explicit user-privilege warning banner,
// opt-in two-step install/enable, and link to Control Center > Extensions.
Item {
    id: root

    property bool windowActive: true

    property string armedPluginId: ""
    readonly property var visibleCatalogue: (Actions.extensionCatalogue || []).slice(0, 6)

    Component.onCompleted: Actions.ensureExtensionsLoaded()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: qsTr("OPTIONAL EXTENSIONS")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("Extend your Hornero")
                    font.pointSize: Appearance.font.size.extraLarge * 0.78
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("PluginKit 3 lets community extensions add bar modules, dashboard tabs, and launcher providers.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("Refresh")
                disabled: Actions.extensionCatalogueLoading
                onClicked: Actions.refreshExtensions()
            }

            TextButton {
                type: TextButton.Filled
                text: qsTr("Open Marketplace")
                onClicked: Actions.openControlCenter("extensions", false)
            }
        }

        // Explicit Trust & Safety Boundary Banner
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: trustRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Signal.palette.alertWell
            border.width: 1
            border.color: Signal.palette.alert

            RowLayout {
                id: trustRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph {
                    name: "shield-lock"
                    color: Signal.palette.onAlertWell
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Plugins run inside Quickshell with your user privileges and are not sandboxed. Safe Mode (HORNERO_SAFE_MODE=1) disables all plugins for recovery.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.onAlertWell
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Offline / loading / catalogue state
        StyledRect {
            visible: Actions.extensionCatalogueLoading || Actions.extensionCatalogueError !== "" || root.visibleCatalogue.length === 0
            Layout.fillWidth: true
            implicitHeight: stateRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Signal.palette.panel
            border.width: 1
            border.color: Signal.palette.rule

            RowLayout {
                id: stateRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph {
                    name: Actions.extensionCatalogueLoading ? "hourglass" : "puzzle"
                    color: Signal.palette.signal
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Actions.extensionCatalogueLoading
                        ? qsTr("Loading extension catalogue…")
                        : (Actions.extensionCatalogueError !== "" ? Actions.extensionCatalogueError : qsTr("No extensions in catalogue right now. Open Marketplace anytime to manage local plugins."))
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Curated catalogue grid
        StyledFlickable {
            id: extFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            contentHeight: extFlow.implicitHeight
            visible: root.visibleCatalogue.length > 0

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: extFlick
            }

            Flow {
                id: extFlow

                width: parent.width - Appearance.padding.small
                spacing: Appearance.spacing.normal

                Repeater {
                    model: root.visibleCatalogue

                    delegate: StyledRect {
                        id: extCard

                        required property var modelData

                        readonly property bool installed: modelData.installed === true
                        readonly property bool armed: root.armedPluginId === modelData.id

                        width: Math.max(260, (extFlow.width - Appearance.spacing.normal) / 2)
                        implicitHeight: cardCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.panel
                        border.width: 1
                        border.color: armed ? Signal.palette.signal : Signal.palette.rule

                        ColumnLayout {
                            id: cardCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Glyph {
                                    name: "puzzle"
                                    color: Signal.palette.signal
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: extCard.modelData.name || extCard.modelData.id
                                    font.weight: Appearance.font.weight.strong
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: extCard.modelData.trust ? String(extCard.modelData.trust) : qsTr("community")
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: extCard.modelData.description || qsTr("Community shell extension")
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: extCard.modelData.author ? qsTr("By %1").arg(extCard.modelData.author) : qsTr("Publisher unverified")
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    elide: Text.ElideRight
                                }

                                TextButton {
                                    visible: !extCard.installed
                                    type: extCard.armed ? TextButton.Filled : TextButton.Tonal
                                    text: extCard.armed ? qsTr("Confirm Install") : qsTr("Install")
                                    disabled: Actions.extensionBusy
                                    horizontalPadding: Appearance.padding.normal
                                    verticalPadding: Appearance.padding.small
                                    onClicked: {
                                        if (!extCard.armed) {
                                            root.armedPluginId = extCard.modelData.id;
                                        } else {
                                            root.armedPluginId = "";
                                            Actions.installExtension(extCard.modelData.id, extCard.modelData.name || extCard.modelData.id);
                                        }
                                    }
                                }

                                TextButton {
                                    visible: extCard.installed
                                    type: TextButton.Tonal
                                    text: qsTr("Manage")
                                    horizontalPadding: Appearance.padding.normal
                                    verticalPadding: Appearance.padding.small
                                    onClicked: Actions.openControlCenter("extensions", false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
