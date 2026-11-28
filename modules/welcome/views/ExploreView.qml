pragma ComponentBehavior: Bound

import "../../../services/welcome_model.js" as WelcomeModel
import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.companion
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.modules.welcome.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Mode B — Explore Hornero: permanent discovery hub with unified search
// across Features, Shortcuts, Hornero Apps, and Extensions, plus an
// optional unfinished-setup strip and strict typed deep links.
Item {
    id: root

    property bool windowActive: true

    property string query: ""
    property string selectedCategory: Welcome.exploreCategory || ""
    property string kindFilter: "all"
    property var featuresData: []

    readonly property var categoryFilters: [
        { id: "", label: qsTr("All") },
        { id: "Appearance", label: qsTr("Appearance") },
        { id: "Desktop & Bars", label: qsTr("Desktop & Bars") },
        { id: "Apps & Packages", label: qsTr("Apps") },
        { id: "Profiles & Snapshots", label: qsTr("Profiles") },
        { id: "Create, Build & Play", label: qsTr("Workloads") },
        { id: "Javi & Companion", label: qsTr("Javi") },
        { id: "Extensions", label: qsTr("Extensions") },
        { id: "Keybinds & Navigation", label: qsTr("Keybinds") },
        { id: "Updates & Recovery", label: qsTr("Recovery") },
        { id: "Accessibility", label: qsTr("Accessibility") }
    ]

    readonly property var capabilitiesSnapshot: ({
            hyprland: Compositor.isHyprland,
            studioAudio: Experience.studioAudioAvailable,
            companion: WelcomeModule.State.mascotEnabled && CompanionStore.enabled,
            assistantGateway: AssistantRun.gateway && AssistantRun.gateway.enabled === true,
            btrfsSnapshots: TrustDiagnostics.btrfsReady
        })

    readonly property var shortcutSearchItems: {
        const list = ShortcutHints.entries || [];
        return list.slice(0, 60).map(e => ({
            id: e.id,
            label: String(e.dispatcher || "") + (e.args ? " " + String(e.args) : ""),
            keys: (e.mods || []).concat([e.key]).join(" + "),
            group: "Shortcuts"
        }));
    }

    readonly property var unifiedResults: {
        const all = WelcomeModel.searchDiscovery(
            root.query,
            root.featuresData,
            root.shortcutSearchItems,
            Actions.catalogApps || [],
            Actions.extensionCatalogue || [],
            root.capabilitiesSnapshot
        );
        return all.filter(item => {
            if (root.kindFilter !== "all" && item.kind !== root.kindFilter)
                return false;
            if (root.selectedCategory !== "" && item.kind === "feature" && item.category !== root.selectedCategory)
                return false;
            return true;
        });
    }

    Component.onCompleted: {
        Actions.ensureCatalogApps();
        Actions.ensureExtensionsLoaded();
        if (Welcome.exploreSubView === "shortcuts")
            root.kindFilter = "shortcut";
    }

    FileView {
        path: Qt.resolvedUrl("../data/features.json")
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.featuresData = Array.isArray(parsed.features) ? parsed.features : [];
            } catch (e) {
                root.featuresData = [];
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        // Header + Search + Shortcuts quick button
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: qsTr("EXPLORE HORNERO")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("Every capability, shortcut, and setting in one place")
                    font.pointSize: Appearance.font.size.large
                    font.weight: Appearance.font.weight.strong
                }
            }

            TextButton {
                type: Welcome.exploreSubView === "shortcuts" ? TextButton.Filled : TextButton.Tonal
                text: Welcome.exploreSubView === "shortcuts" ? qsTr("Back to Hub") : qsTr("Full Shortcuts Sheet")
                onClicked: Welcome.exploreSubView = Welcome.exploreSubView === "shortcuts" ? "features" : "shortcuts"
            }
        }

        // Unfinished First Flight banner (never pushes, quietly invites)
        StyledRect {
            visible: !WelcomeModule.State.firstRunCompleted && Welcome.exploreSubView !== "shortcuts"
            Layout.fillWidth: true
            implicitHeight: resumeRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Signal.palette.cueWell
            border.width: 1
            border.color: Signal.palette.cue

            RowLayout {
                id: resumeRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph { name: "compass"; color: Signal.palette.onCueWell }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Optional guided setup is paused at %1.").arg(WelcomeModule.State.lastVisitedScene)
                    color: Signal.palette.onCueWell
                    font.pointSize: Appearance.font.size.smaller
                }

                TextButton {
                    type: TextButton.Tonal
                    text: qsTr("Resume First Flight")
                    onClicked: Welcome.goToScene(WelcomeModule.State.lastVisitedScene || "arrival")
                }
            }
        }

        // Embedded ShortcutsView when user opens Full Shortcuts Sheet
        Loader {
            active: Welcome.exploreSubView === "shortcuts"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "ShortcutsView.qml"
        }

        // Main Discovery Hub
        ColumnLayout {
            visible: Welcome.exploreSubView !== "shortcuts"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            SearchBar {
                id: discoverySearch

                Layout.fillWidth: true
                placeholderText: qsTr("Search features, settings, shortcuts, apps, or extensions…")
                onTextChanged: root.query = text
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.categoryFilters

                    delegate: TextButton {
                        required property var modelData

                        type: root.selectedCategory === modelData.id ? TextButton.Filled : TextButton.Tonal
                        text: modelData.label
                        horizontalPadding: Appearance.padding.normal
                        verticalPadding: Appearance.padding.small
                        onClicked: {
                            root.kindFilter = "all";
                            root.selectedCategory = root.selectedCategory === modelData.id ? "" : modelData.id;
                        }
                    }
                }
            }

            StyledFlickable {
                id: resultsFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                flickableDirection: Flickable.VerticalFlick
                contentHeight: resultsFlow.implicitHeight

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: resultsFlick
                }

                Flow {
                    id: resultsFlow

                    width: parent.width - Appearance.padding.small
                    spacing: Appearance.spacing.normal

                    Repeater {
                        model: root.unifiedResults

                        delegate: StyledRect {
                            id: resultCard

                            required property var modelData

                            width: Math.max(280, (resultsFlow.width - Appearance.spacing.normal) / 2)
                            implicitHeight: cardInner.implicitHeight + Appearance.padding.normal * 2
                            radius: Appearance.rounding.small
                            color: Signal.palette.panel
                            border.width: 1
                            border.color: Signal.palette.rule

                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.title
                            Accessible.description: modelData.subtitle

                            Interactive {
                                onClicked: {
                                    if (resultCard.modelData.action)
                                        Actions.executeTypedAction(resultCard.modelData.action);
                                }
                            }

                            ColumnLayout {
                                id: cardInner

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    Glyph {
                                        name: resultCard.modelData.icon || "compass"
                                        color: Signal.palette.signal
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: resultCard.modelData.title
                                        font.weight: Appearance.font.weight.strong
                                        elide: Text.ElideRight
                                    }

                                    AvailabilityPill {
                                        availability: resultCard.modelData.badge === "Installed" ? "supported" : resultCard.modelData.badge
                                        available: resultCard.modelData.available
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: resultCard.modelData.available
                                        ? resultCard.modelData.subtitle
                                        : qsTr("%1 (%2)").arg(resultCard.modelData.subtitle).arg(resultCard.modelData.unavailableReason)
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: resultCard.modelData.category
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
