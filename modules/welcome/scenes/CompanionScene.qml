pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.modules.companion
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 04 — Companion ("Meet Javi el Hornero"):
// Centered spotlight stage reusing canonical Companion assets & Player,
// skin switcher, animation triggers (paused when window hidden or reduced
// motion), toggle to disable mascot, honest local vs optional AI disclosure,
// and live safe local quick-question chips.
Item {
    id: root

    property bool windowActive: true

    property string previewAction: "greet"
    property string quickAnswer: qsTr("Ask me anything about shortcuts, themes, or where settings live.")

    readonly property var skinChoices: [
        { id: "default", label: qsTr("Classic") },
        { id: "argentina", label: qsTr("Argentina") },
        { id: "gaucho", label: qsTr("Gaucho") },
        { id: "blue-gold", label: qsTr("Blue & Gold") },
        { id: "nocturnal", label: qsTr("Nocturnal") },
        { id: "retro-terminal", label: qsTr("Retro CRT") },
        { id: "mono", label: qsTr("Mono") }
    ]

    readonly property var poseChoices: [
        { id: "greet", label: qsTr("Greet") },
        { id: "think", label: qsTr("Think") },
        { id: "work", label: qsTr("Work") },
        { id: "sleep", label: qsTr("Sleep") }
    ]

    readonly property var quickQuestions: [
        {
            q: qsTr("How do I open apps?"),
            a: qsTr("Press %1 for the Launcher, or open Hornero Apps from the bar.").arg(ShortcutHints.badge("exec-launcher") || "Super + Space")
        },
        {
            q: qsTr("Can I turn Javi off?"),
            a: qsTr("Yes — toggle Javi off right here or anytime in Settings › Javi.")
        },
        {
            q: qsTr("Is AI sent to the cloud?"),
            a: qsTr("Never by default. Javi's desktop animations are 100% local, and the optional Hermes gateway stays off until you enable it.")
        }
    ]

    readonly property var currentReel: Companion.reel(CompanionStore.effectiveSkin, root.previewAction)

    onCurrentReelChanged: syncReel()
    Component.onCompleted: syncReel()

    function syncReel(): void {
        const r = root.currentReel;
        if (r && Array.isArray(r.files))
            player.setReel(r.files, r.frameMs || 900, r.loop !== false, r.durations || []);
    }

    Player {
        id: player

        playing: root.windowActive && root.visible && WelcomeModule.State.mascotEnabled
        holdStill: Appearance.anim.reduced
        fallbackFrame: Companion.frameSource(CompanionStore.effectiveSkin, "idle")
        onFinished: root.previewAction = "idle"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large

        // Left: Intimate Spotlight Stage
        StyledRect {
            Layout.preferredWidth: parent.width * 0.45
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Signal.palette.sunken
            border.width: 1
            border.color: Signal.palette.rule

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: qsTr("JAVI EL HORNERO")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.signal
                    }

                    Item { Layout.fillWidth: true }

                    SwitchRow {
                        label: qsTr("Mascot active")
                        checked: WelcomeModule.State.mascotEnabled && CompanionStore.enabled
                        onToggled: checked => Actions.setMascotEnabled(checked)
                    }
                }

                // Spotlight stage
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Signal.palette.ground
                    border.width: 1
                    border.color: Signal.palette.ruleStrong

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.72
                        height: width
                        radius: width / 2
                        color: Qt.alpha(Signal.palette.signalWell, WelcomeModule.State.mascotEnabled ? 0.55 : 0.18)
                        border.width: 1
                        border.color: Signal.palette.rule
                    }

                    Image {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.62
                        height: width
                        source: player.currentFrame !== "" ? Qt.resolvedUrl("file://" + player.currentFrame) : ""
                        fillMode: Image.PreserveAspectFit
                        opacity: WelcomeModule.State.mascotEnabled ? 1.0 : 0.35
                        asynchronous: true
                        Accessible.name: qsTr("Javi the Hornero companion")
                    }
                }

                // Pose buttons
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.poseChoices

                        delegate: TextButton {
                            required property var modelData

                            type: root.previewAction === modelData.id ? TextButton.Filled : TextButton.Tonal
                            text: modelData.label
                            disabled: !WelcomeModule.State.mascotEnabled
                            horizontalPadding: Appearance.padding.normal
                            verticalPadding: Appearance.padding.small
                            onClicked: root.previewAction = modelData.id
                        }
                    }
                }

                // Skin switcher
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.skinChoices

                        delegate: ToggleButton {
                            required property var modelData

                            toggled: CompanionStore.effectiveSkin === modelData.id
                            label: modelData.label
                            accent: "cue"
                            horizontalPadding: Appearance.padding.small
                            verticalPadding: Appearance.padding.small
                            onClicked: Actions.setCompanionSkin(modelData.id)
                        }
                    }
                }
            }
        }

        // Right: Honest disclosure, quick questions & Companion settings
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            StyledText {
                text: qsTr("A calm desktop sidekick — never intrusive")
                font.pointSize: Appearance.font.size.extraLarge * 0.78
                font.weight: Appearance.font.weight.strong
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Honest Local vs Optional AI Gateway disclosure
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: gatewayCol.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Signal.palette.cueWell
                border.width: 1
                border.color: Signal.palette.cue

                ColumnLayout {
                    id: gatewayCol

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: 4

                    StyledText {
                        text: AssistantRun.gateway && AssistantRun.gateway.enabled
                            ? qsTr("Hermes Assistant: Local gateway enabled")
                            : qsTr("Local-only mascot · Optional AI off by default")
                        font.weight: Appearance.font.weight.strong
                        color: Signal.palette.onCueWell
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Javi's animations and status reactions run 100% locally. Optional Hermes AI requires explicit consent per action and refuses secret files.")
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.onCueWell
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Safe local quick-question chips
            StyledText {
                text: qsTr("Try a local quick question")
                font.weight: Appearance.font.weight.strong
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.quickQuestions

                    delegate: TextButton {
                        required property var modelData

                        type: TextButton.Tonal
                        text: modelData.q
                        horizontalPadding: Appearance.padding.normal
                        verticalPadding: Appearance.padding.small
                        onClicked: {
                            root.quickAnswer = modelData.a;
                            root.previewAction = "talk";
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: answerCol.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Signal.palette.panel
                border.width: 1
                border.color: Signal.palette.rule

                RowLayout {
                    id: answerCol

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    Glyph {
                        name: "message"
                        color: Signal.palette.signal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.quickAnswer
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                TextButton {
                    type: TextButton.Tonal
                    text: qsTr("Javi Settings")
                    onClicked: Actions.openControlCenter("companion", false)
                }

                TextButton {
                    type: TextButton.Tonal
                    text: qsTr("Agent & Hermes Center")
                    onClicked: Actions.openControlCenter("agents", false)
                }
            }
        }
    }
}
