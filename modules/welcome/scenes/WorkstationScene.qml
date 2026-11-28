pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 03 — Workstation ("Build Your Workstation"):
// Left column: Experience Mode selector reading real Experience profiles
// and capabilities (Everyday, Focus, Signal, Studio, Gaming).
// Right column: Real Hornero Apps workstation profiles via AppsProfilePanel
// (backed by AppsStore / services/store.js) + Open Hornero Apps + team manifest.
Item {
    id: root

    property bool windowActive: true

    property string inspectedMode: Experience.mode
    readonly property var inspectedProfile: Experience.profileFor(inspectedMode)
    readonly property var modeRows: [
        { id: "everyday", title: qsTr("Everyday"), icon: "layout-dashboard", summary: qsTr("Balanced Cockpit layout, standard motion, clear values.") },
        { id: "focus", title: qsTr("Focus"), icon: "circle-dot", summary: qsTr("Quiet motion, minimal chrome, notifications held for deep work.") },
        { id: "signal", title: qsTr("Signal"), icon: "wave-sine", summary: qsTr("2 Hz telemetry, desktop instrument deck, subtle scanlines.") },
        { id: "studio", title: qsTr("Studio"), icon: "music", summary: qsTr("Creative workflow with optional low-latency PipeWire audio.") },
        { id: "gaming", title: qsTr("Gaming"), icon: "device-gamepad-2", summary: qsTr("Zero shell overhead and fullscreen gaming focus.") }
    ]

    Component.onCompleted: Actions.ensureAppProfiles()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large

        // Left 38%: Experience Mode Selector
        ColumnLayout {
            Layout.fillWidth: false
            Layout.minimumWidth: 340
            Layout.maximumWidth: Math.round(parent.width * 0.42)
            Layout.preferredWidth: Math.round(parent.width * 0.38)
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: qsTr("WORKSTATION CADENCE")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("Build your workstation")
                    font.pointSize: Appearance.font.size.extraLarge * 0.78
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Pick an Experience Mode for how the desktop behaves, then queue your apps.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            Repeater {
                model: root.modeRows

                delegate: StyledRect {
                    id: modeCard

                    required property var modelData

                    readonly property bool selected: root.inspectedMode === modelData.id
                    readonly property bool activeMode: Experience.mode === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: modeInner.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: selected ? Signal.palette.raised : Signal.palette.panel
                    border.width: 1
                    border.color: selected ? Signal.palette.signal : Signal.palette.rule

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title
                    Accessible.checked: activeMode

                    OnAirBar {
                        edge: "left"
                        visible: modeCard.activeMode
                    }

                    Interactive {
                        onClicked: {
                            root.inspectedMode = modeCard.modelData.id;
                            Actions.setExperienceMode(modeCard.modelData.id);
                        }
                    }

                    RowLayout {
                        id: modeInner

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Glyph {
                            name: modeCard.modelData.icon
                            color: modeCard.activeMode ? Signal.palette.signal : Signal.palette.inkMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    text: modeCard.modelData.title
                                    font.weight: Appearance.font.weight.strong
                                }

                                StyledText {
                                    visible: modeCard.activeMode
                                    text: qsTr("ACTIVE")
                                    mono: true
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.phosphor
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modeCard.modelData.summary
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // Live spec readout for inspected mode
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: specCol.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Signal.palette.sunken
                border.width: 1
                border.color: Signal.palette.rule

                ColumnLayout {
                    id: specCol

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Motion: %1 · Density: %2 · Rate: %3 Hz")
                            .arg(root.inspectedProfile.fields.motion)
                            .arg(root.inspectedProfile.fields.density)
                            .arg(root.inspectedProfile.fields["telemetry.rateHz"])
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.ink
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Experience.studioAudioAvailable
                            ? qsTr("Studio Audio: Ready")
                            : qsTr("Studio Audio: Optional profile not installed")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Right 62%: Hornero Apps Workstation Profiles + Store actions
        StyledFlickable {
            id: rightFlick

            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            contentHeight: rightCol.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: rightFlick
            }

            ColumnLayout {
                id: rightCol

                width: parent.width - Appearance.padding.small
                spacing: Appearance.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: qsTr("WORKSTATION SOFTWARE")
                            mono: true
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.signal
                        }

                        StyledText {
                            text: qsTr("Curated app bundles via Hornero Apps")
                            font.pointSize: Appearance.font.size.large
                            font.weight: Appearance.font.weight.strong
                        }
                    }

                    TextButton {
                        type: TextButton.Tonal
                        text: qsTr("Open Hornero Apps")
                        onClicked: Actions.openApps("discover")
                    }
                }

                AppsProfilePanel {
                    Layout.fillWidth: true
                }

                // Fallback curated collections & team manifest action when profiles aren't available
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: manifestRow.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: Signal.palette.panel
                    border.width: 1
                    border.color: Signal.palette.rule

                    RowLayout {
                        id: manifestRow

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Glyph {
                            name: "folders"
                            color: Signal.palette.cue
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: qsTr("Browse full catalog or import a team manifest")
                                font.weight: Appearance.font.weight.strong
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Hornero Apps tracks Arch, Flatpak, AppImage, and Web App provenance cleanly in the background.")
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WordWrap
                            }
                        }

                        TextButton {
                            type: TextButton.Tonal
                            text: qsTr("Sources & Policy")
                            onClicked: Actions.openApps("sources")
                        }
                    }
                }
            }
        }
    }
}
