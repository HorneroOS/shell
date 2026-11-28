pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Top telemetry & accessibility chrome bar for Hornero Welcome.
// Houses the Hornero brand chip, 3-mode switcher, EN/ES language toggle,
// Reduced Motion toggle, and an always-reachable Skip / Enter Desktop CTA.
StyledRect {
    id: root

    required property string currentMode
    required property bool hasUnseenWhatsNew
    property Item trailingSlotTarget: null

    Layout.fillWidth: true
    Layout.preferredHeight: 58
    color: Signal.palette.panel

    Hairline {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.normal
        spacing: Appearance.spacing.normal

        // Brand chip: logo.svg on inverse ceramic/ink backing for both themes.
        RowLayout {
            spacing: Appearance.spacing.small

            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: Signal.palette.inverse

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)
                    fillMode: Image.PreserveAspectFit
                    Accessible.name: qsTr("Hornero logo")
                }
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: qsTr("Hornero Welcome")
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    text: Welcome.mode === "first-flight"
                        ? qsTr("First Flight · %1 / 09").arg(String(Welcome.sceneIndex + 1).padStart(2, "0"))
                        : (Welcome.mode === "explore" ? qsTr("Discovery Hub") : qsTr("Release Notes"))
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        ModeSwitcher {
            currentMode: root.currentMode
            hasUnseenWhatsNew: root.hasUnseenWhatsNew
            onModeSelected: modeId => Welcome.setMode(modeId)
        }

        Item {
            Layout.fillWidth: true
        }

        // Language quick switch: EN / ES (Rioplatense)
        TextButton {
            readonly property bool isEs: Language.uiLocale.toLowerCase().startsWith("es")

            type: TextButton.Tonal
            text: isEs ? qsTr("ES") : qsTr("EN")
            horizontalPadding: Appearance.padding.normal
            verticalPadding: Appearance.padding.small
            Accessible.name: isEs ? qsTr("Switch language to English") : qsTr("Cambiar idioma a Español (Argentina)")
            onClicked: Actions.setLanguage(isEs ? "en" : "es_AR")
        }

        // Reduced Motion quick toggle
        ToggleButton {
            toggled: Appearance.anim.reduced
            icon: "accessible"
            label: qsTr("Motion")
            accent: "cue"
            horizontalPadding: Appearance.padding.normal
            verticalPadding: Appearance.padding.small
            tooltip: Appearance.anim.reduced ? qsTr("Reduced motion is on") : qsTr("Toggle reduced motion")
            onClicked: Actions.setReducedMotion(!Config.appearance.reducedMotion)
        }

        // Always-accessible exit door from frame 1
        TextButton {
            type: TextButton.Text
            text: qsTr("Enter Desktop")
            onClicked: Welcome.skipToDesktop()
        }

        // Host places the Close Welcome IconButton in Window.qml right beside here.
        Item {
            id: closeHostSlot

            Layout.preferredWidth: 36
            Layout.preferredHeight: 36

            Component.onCompleted: root.trailingSlotTarget = closeHostSlot
        }
    }
}
