pragma ComponentBehavior: Bound

import "../../../services/welcome_whatsnew.js" as WhatsNew
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

// Mode C — What's New: version-aware release notes from releases.json,
// historical release switcher, Try-It typed actions, and Mark Seen state.
Item {
    id: root

    property bool windowActive: true

    property var releasesDoc: null
    property string selectedVersion: ""

    readonly property var capabilitiesSnapshot: ({
            hyprland: Compositor.isHyprland,
            studioAudio: Experience.studioAudioAvailable,
            companion: WelcomeModule.State.mascotEnabled && CompanionStore.enabled,
            assistantGateway: AssistantRun.gateway && AssistantRun.gateway.enabled === true,
            btrfsSnapshots: TrustDiagnostics.btrfsReady
        })

    readonly property var releases: WhatsNew.filterReleases(root.releasesDoc, root.capabilitiesSnapshot, WelcomeModule.State.lastSeenReleaseVersion)
    readonly property var activeRelease: {
        if (root.releases.length === 0)
            return null;
        for (let i = 0; i < root.releases.length; i++) {
            if (root.releases[i].version === root.selectedVersion)
                return root.releases[i];
        }
        return root.releases[0];
    }

    FileView {
        path: Qt.resolvedUrl("../data/releases.json")
        onLoaded: {
            try {
                root.releasesDoc = JSON.parse(text());
            } catch (e) {
                root.releasesDoc = null;
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large

        // Left release history rail
        ColumnLayout {
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            StyledText {
                text: qsTr("RELEASES")
                mono: true
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.signal
            }

            Repeater {
                model: root.releases

                delegate: StyledRect {
                    id: verRow

                    required property var modelData

                    readonly property bool selected: root.activeRelease && root.activeRelease.version === modelData.version

                    Layout.fillWidth: true
                    implicitHeight: verInner.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: selected ? Signal.palette.raised : Signal.palette.panel
                    border.width: 1
                    border.color: selected ? Signal.palette.signal : Signal.palette.rule

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Version %1").arg(modelData.version)
                    Accessible.checked: selected

                    OnAirBar {
                        edge: "left"
                        visible: verRow.selected
                    }

                    Interactive {
                        onClicked: root.selectedVersion = verRow.modelData.version
                    }

                    ColumnLayout {
                        id: verInner

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: qsTr("v%1").arg(verRow.modelData.version)
                                mono: true
                                font.weight: Appearance.font.weight.strong
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                visible: verRow.modelData.isCurrent
                                text: qsTr("CURRENT")
                                mono: true
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.phosphor
                            }
                        }

                        StyledText {
                            text: verRow.modelData.date
                            mono: true
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Right release highlights
        StyledFlickable {
            id: relFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            contentHeight: relCol.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: relFlick
            }

            ColumnLayout {
                id: relCol

                width: parent.width - Appearance.padding.small
                spacing: Appearance.spacing.normal
                visible: root.activeRelease !== null

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: root.activeRelease ? qsTr("RELEASE v%1 · %2").arg(root.activeRelease.version).arg(root.activeRelease.date) : ""
                            mono: true
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.signal
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activeRelease ? root.activeRelease.title : qsTr("No release selected")
                            font.pointSize: Appearance.font.size.extraLarge * 0.78
                            font.weight: Appearance.font.weight.strong
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activeRelease ? root.activeRelease.summary : ""
                            font.pointSize: Appearance.font.size.normal
                            color: Signal.palette.inkMuted
                            wrapMode: Text.WordWrap
                        }
                    }

                    TextButton {
                        type: WelcomeModule.State.hasUnseenRelease ? TextButton.Filled : TextButton.Tonal
                        text: WelcomeModule.State.hasUnseenRelease ? qsTr("Mark seen") : qsTr("Seen")
                        disabled: !WelcomeModule.State.hasUnseenRelease
                        onClicked: WelcomeModule.State.markReleaseSeen(root.activeRelease ? root.activeRelease.version : "")
                    }
                }

                Hairline { Layout.fillWidth: true }

                Repeater {
                    model: root.activeRelease ? root.activeRelease.highlights : []

                    delegate: StyledRect {
                        id: hlCard

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: hlRow.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.panel
                        border.width: 1
                        border.color: Signal.palette.rule

                        RowLayout {
                            id: hlRow

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.normal

                            Glyph {
                                name: hlCard.modelData.icon || "sparkles"
                                font.pointSize: Appearance.font.size.large
                                color: Signal.palette.signal
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    StyledText {
                                        text: hlCard.modelData.title
                                        font.weight: Appearance.font.weight.strong
                                    }

                                    AvailabilityPill {
                                        availability: hlCard.modelData.availability
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: hlCard.modelData.summary
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.WordWrap
                                }
                            }

                            TextButton {
                                visible: hlCard.modelData.action !== null
                                type: TextButton.Tonal
                                text: qsTr("Try it")
                                onClicked: Actions.executeTypedAction(hlCard.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
