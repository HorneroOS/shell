pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 07 — Showcase ("Create, Build & Play"):
// Adaptive 3-column editorial showcase tailored to user interests
// (Creative Studio, AI & Dev, Gaming) with honest readiness indicators
// and typed interactive actions.
Item {
    id: root

    property bool windowActive: true

    readonly property var interestOptions: [
        { id: "creative", label: qsTr("Creative Studio"), icon: "music" },
        { id: "dev", label: qsTr("AI & Engineering"), icon: "code" },
        { id: "gaming", label: qsTr("PC Gaming"), icon: "device-gamepad-2" }
    ]

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
                    text: qsTr("ADAPTIVE WORKLOADS")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("Create, build, and play")
                    font.pointSize: Appearance.font.size.extraLarge * 0.78
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Highlight what you use this machine for — we'll surface relevant guides in Explore Hornero.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            Flow {
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.interestOptions

                    delegate: ToggleButton {
                        required property var modelData

                        toggled: WelcomeModule.State.hasInterest(modelData.id)
                        icon: modelData.icon
                        label: modelData.label
                        accent: "signal"
                        horizontalPadding: Appearance.padding.normal
                        verticalPadding: Appearance.padding.small
                        onClicked: WelcomeModule.State.toggleInterest(modelData.id)
                    }
                }
            }
        }

        // Magazine 3-Column Triptych
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            // Column 1: Create · Studio Audio & Routing
            StyledRect {
                readonly property bool emphasized: WelcomeModule.State.selectedInterests.length === 0 || WelcomeModule.State.hasInterest("creative")

                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: emphasized ? 2 : 1
                border.color: emphasized ? Signal.palette.signal : Signal.palette.rule

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        spacing: Appearance.spacing.small
                        Glyph { name: "music"; color: Signal.palette.signal }
                        StyledText { text: qsTr("CREATE · STUDIO"); mono: true; font.pointSize: Appearance.font.size.small; color: Signal.palette.signal }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Low-latency audio & routing kits")
                        font.pointSize: Appearance.font.size.large
                        font.weight: Appearance.font.weight.strong
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Experience.studioAudioAvailable
                            ? qsTr("PipeWire Studio Audio is ready: live-call, browser backing, and REAPER routing kits are available.")
                            : qsTr("Studio Audio profile is optional and not active yet. Open Studio settings to inspect PipeWire readiness.")
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    TextButton {
                        Layout.fillWidth: true
                        type: TextButton.Tonal
                        text: qsTr("Open Studio Settings")
                        onClicked: Actions.openControlCenter("studio", false)
                    }
                }
            }

            // Column 2: Build · AI-native Dev & Terminal
            StyledRect {
                readonly property bool emphasized: WelcomeModule.State.selectedInterests.length === 0 || WelcomeModule.State.hasInterest("dev")

                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: emphasized ? 2 : 1
                border.color: emphasized ? Signal.palette.cue : Signal.palette.rule

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        spacing: Appearance.spacing.small
                        Glyph { name: "code"; color: Signal.palette.cue }
                        StyledText { text: qsTr("BUILD · ENGINEERING"); mono: true; font.pointSize: Appearance.font.size.small; color: Signal.palette.cue }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Terminal, Agents & Tooling")
                        font.pointSize: Appearance.font.size.large
                        font.weight: Appearance.font.weight.strong
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Configured terminal: %1. Inspect local coding agents, sandbox rules, and Hermes readiness in Agent Center.")
                            .arg(Array.from(Config.general.apps.terminal || ["kitty"]).join(" "))
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        TextButton {
                            Layout.fillWidth: true
                            type: TextButton.Tonal
                            text: qsTr("Terminal")
                            onClicked: Actions.openTerminal()
                        }

                        TextButton {
                            Layout.fillWidth: true
                            type: TextButton.Tonal
                            text: qsTr("Agent Center")
                            onClicked: Actions.openControlCenter("agents", false)
                        }
                    }
                }
            }

            // Column 3: Play · Gaming & Compatibility
            StyledRect {
                readonly property bool emphasized: WelcomeModule.State.selectedInterests.length === 0 || WelcomeModule.State.hasInterest("gaming")

                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: emphasized ? 2 : 1
                border.color: emphasized ? Signal.palette.phosphor : Signal.palette.rule

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        spacing: Appearance.spacing.small
                        Glyph { name: "device-gamepad-2"; color: Signal.palette.phosphor }
                        StyledText { text: qsTr("PLAY · GAMING"); mono: true; font.pointSize: Appearance.font.size.small; color: Signal.palette.phosphor }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Zero-distraction fullscreen focus")
                        font.pointSize: Appearance.font.size.large
                        font.weight: Appearance.font.weight.strong
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Gaming mode pauses background shell glow and holds popups during fullscreen play. Check Gamescope and MangoHud readiness honestly before launching.")
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    SwitchRow {
                        Layout.fillWidth: true
                        label: qsTr("Auto fullscreen gaming")
                        checked: Experience.autoEnabled
                        onToggled: checked => Actions.setFullscreenGamingAuto(checked)
                    }

                    Item { Layout.fillHeight: true }

                    TextButton {
                        Layout.fillWidth: true
                        type: TextButton.Tonal
                        text: qsTr("Gaming Readiness")
                        onClicked: Actions.openControlCenter("gaming", false)
                    }
                }
            }
        }
    }
}
