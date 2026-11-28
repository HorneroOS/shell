pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Bottom First Flight navigation rail: Show-on-login persistence toggle,
// adaptive 5-chapter core rail + optional deep-dive chapters (05..08),
// Back, Skip to Ready, and primary Next / Enter Desktop CTA.
StyledRect {
    id: root

    required property string currentScene
    required property int sceneIndex

    property bool showDeepDives: root.sceneIndex >= 4 && root.sceneIndex <= 7

    readonly property var chapters: [
        { id: "arrival", num: "01", label: qsTr("Arrival"), core: true },
        { id: "personalize", num: "02", label: qsTr("Personalize"), core: true },
        { id: "workstation", num: "03", label: qsTr("Workstation"), core: true },
        { id: "companion", num: "04", label: qsTr("Javi"), core: true },
        { id: "practice", num: "05", label: qsTr("Practice"), core: false },
        { id: "extensions", num: "06", label: qsTr("Extensions"), core: false },
        { id: "showcase", num: "07", label: qsTr("Showcase"), core: false },
        { id: "trust", num: "08", label: qsTr("Trust"), core: false },
        { id: "ready", num: "09", label: qsTr("Ready"), core: true }
    ]

    Layout.fillWidth: true
    Layout.preferredHeight: WelcomeModule.State.writeFailed ? 92 : 66
    color: Signal.palette.panel

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            // Left: Show on login toggle
            RowLayout {
                spacing: Appearance.spacing.small

                StyledSwitch {
                    id: loginSwitch

                    focusPolicy: Qt.TabFocus
                    checked: WelcomeModule.State.showOnLogin
                    Accessible.name: qsTr("Show Welcome on login")
                    onToggled: WelcomeModule.State.writeShowOnLogin(checked)
                }

                StyledText {
                    text: qsTr("Show on login")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Center: adaptive 5-chapter default rail + expandable optional deep dives
            RowLayout {
                visible: Welcome.mode === "first-flight"
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.chapters

                    delegate: StyledRect {
                        id: stepBtn

                        required property int index
                        required property var modelData

                        readonly property bool isCurrent: root.currentScene === modelData.id
                        readonly property bool isPast: index < root.sceneIndex
                        readonly property bool visibleInRail: modelData.core || root.showDeepDives || isCurrent

                        visible: visibleInRail
                        implicitWidth: stepRow.implicitWidth + Appearance.padding.normal
                        implicitHeight: 30
                        radius: Appearance.rounding.small
                        color: isCurrent ? Signal.palette.signalWell : (isPast ? Signal.palette.raised : "transparent")
                        border.width: 1
                        border.color: isCurrent ? Signal.palette.signal : Signal.palette.rule

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Chapter %1: %2").arg(stepBtn.modelData.num).arg(stepBtn.modelData.label)
                        Accessible.checked: stepBtn.isCurrent

                        Interactive {
                            color: stepBtn.isCurrent ? Signal.palette.onSignalWell : Signal.palette.ink
                            onClicked: Welcome.goToScene(stepBtn.modelData.id)
                        }

                        RowLayout {
                            id: stepRow

                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: stepBtn.modelData.num
                                mono: true
                                font.pointSize: Appearance.font.size.small
                                font.weight: stepBtn.isCurrent ? Appearance.font.weight.strong : Appearance.font.weight.regular
                                color: stepBtn.isCurrent ? Signal.palette.onSignalWell : (stepBtn.isPast ? Signal.palette.phosphor : Signal.palette.inkMuted)
                            }

                            StyledText {
                                visible: stepBtn.isCurrent || stepBtn.modelData.core
                                text: stepBtn.modelData.label
                                font.pointSize: Appearance.font.size.small
                                font.weight: stepBtn.isCurrent ? Appearance.font.weight.strong : Appearance.font.weight.regular
                                color: stepBtn.isCurrent ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                            }
                        }
                    }
                }

                TextButton {
                    type: TextButton.Text
                    text: root.showDeepDives ? qsTr("Core 5") : qsTr("+4 Deep Dives")
                    horizontalPadding: Appearance.padding.small
                    verticalPadding: Appearance.padding.small
                    onClicked: root.showDeepDives = !root.showDeepDives
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Right: Back / Next / Enter Desktop
            RowLayout {
                spacing: Appearance.spacing.small

                TextButton {
                    visible: Welcome.mode === "first-flight" && root.sceneIndex > 0
                    type: TextButton.Tonal
                    text: qsTr("Back")
                    onClicked: Welcome.prevScene()
                }

                TextButton {
                    visible: Welcome.mode === "first-flight" && root.sceneIndex < 8
                    type: TextButton.Text
                    text: qsTr("Skip to Ready")
                    onClicked: Welcome.goToScene("ready")
                }

                TextButton {
                    visible: Welcome.mode === "first-flight"
                    type: TextButton.Filled
                    text: root.sceneIndex >= 8 ? qsTr("Enter my desktop") : qsTr("Continue")
                    onClicked: Welcome.nextScene()
                }

                TextButton {
                    visible: Welcome.mode !== "first-flight"
                    type: TextButton.Filled
                    text: qsTr("Done")
                    onClicked: Welcome.close()
                }
            }
        }

        StyledText {
            visible: WelcomeModule.State.writeFailed
            Layout.fillWidth: true
            text: WelcomeModule.State.lastWriteError !== "" ? WelcomeModule.State.lastWriteError : qsTr("Preference kept for this session only")
            color: Signal.palette.alert
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }
}
