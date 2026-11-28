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

// Scene 09 — Ready ("You're Ready to Fly"):
// Honest summary of what the user actually configured during First Flight,
// subtle Javi farewell, and primary "Enter my desktop" CTA that never blocks
// on background app/extension installs.
Item {
    id: root

    property bool windowActive: true

    readonly property var summaryRows: [
        {
            label: qsTr("Theme"),
            value: Config.appearance.highContrast ? qsTr("High Contrast") : (Signal.themeId || Config.appearance.theme),
            icon: "palette"
        },
        {
            label: qsTr("Layout Preset"),
            value: PreviewTransaction.currentLayoutPreset !== "" ? PreviewTransaction.currentLayoutPreset : qsTr("Active shell default"),
            icon: "layout-dashboard"
        },
        {
            label: qsTr("Experience Mode"),
            value: Experience.label,
            icon: "wave-sine"
        },
        {
            label: qsTr("Javi Companion"),
            value: (WelcomeModule.State.mascotEnabled && CompanionStore.enabled) ? qsTr("Active (%1)").arg(CompanionStore.effectiveSkin) : qsTr("Disabled"),
            icon: "feather"
        },
        {
            label: qsTr("Tutorials Verified"),
            value: qsTr("%1 of 4 completed").arg(WelcomeModule.State.completedTutorials.length),
            icon: "checklist"
        },
        {
            label: qsTr("Hornero Apps Queue"),
            value: Actions.appsBusy ? qsTr("Running in background") : qsTr("Ready in Hornero Apps"),
            icon: "apps"
        }
    ]

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(760, parent.width - Appearance.padding.large * 4)
        spacing: Appearance.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: qsTr("FIRST FLIGHT COMPLETE")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.phosphor
                }

                StyledText {
                    text: qsTr("You're ready to fly")
                    font.pointSize: Appearance.font.size.display * 0.68
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Your desktop reflects the choices below. Any background app or extension installs continue peacefully on their own.")
                    font.pointSize: Appearance.font.size.normal
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            HorneroSprite {
                visible: WelcomeModule.State.mascotEnabled
                pixel: 4
                force: true
                pose: root.windowActive ? "perch" : "sleep"
            }
        }

        // Honest configuration ledger
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight + Appearance.padding.large * 2
            radius: Appearance.rounding.normal
            color: Signal.palette.panel
            border.width: 1
            border.color: Signal.palette.rule

            GridLayout {
                id: grid

                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                columns: 2
                columnSpacing: Appearance.spacing.large
                rowSpacing: Appearance.spacing.normal

                Repeater {
                    model: root.summaryRows

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Glyph {
                            name: modelData.icon
                            color: Signal.palette.signal
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: modelData.label
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                            }

                            StyledText {
                                text: modelData.value
                                mono: true
                                font.weight: Appearance.font.weight.strong
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Primary exit CTA + secondary exploration doors
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            TextButton {
                type: TextButton.Filled
                text: qsTr("Enter my desktop")
                horizontalPadding: Appearance.padding.large
                verticalPadding: Appearance.padding.normal
                onClicked: Welcome.completeFirstFlight()
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("Open Explore Hornero")
                onClicked: {
                    WelcomeModule.State.markFirstRunCompleted();
                    Welcome.setMode("explore");
                }
            }

            TextButton {
                type: TextButton.Text
                text: qsTr("Open Launcher")
                onClicked: Actions.openLauncher()
            }
        }
    }
}
