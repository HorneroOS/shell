pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.modules.companion
import qs.config
import qs.services
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center › Companion: enable, character, size, idle-to-sleep,
// tips, edge, bubble theme, and position reset. Binds straight onto
// CompanionStore (persisted via PersistentProperties, no save step).
Item {
    id: root

    required property Session session

    anchors.fill: parent

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
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

                StyledText {
                    text: qsTr("Javi · el Hornero")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Javi, el Hornero: your sidekick. Idles, greets, shows tips — and, with Hermes enabled, chats, reads the system and always asks before changing anything.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: generalCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: generalCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("General")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SwitchRow {
                            label: qsTr("Enabled")
                            checked: CompanionStore.enabled
                            onToggled: checked => CompanionStore.enabled = checked
                        }

                        SwitchRow {
                            label: qsTr("Show tips on click")
                            checked: CompanionStore.tipsEnabled
                            onToggled: checked => CompanionStore.tipsEnabled = checked
                        }

                        SwitchRow {
                            label: qsTr("Reduced motion")
                            checked: CompanionStore.reducedMotion
                            onToggled: checked => CompanionStore.reducedMotion = checked
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Size")
                            value: CompanionStore.sizeScale
                            from: 0.5
                            to: 2.0
                            stepSize: 0.05
                            suffix: "×"
                            decimals: 2
                            onValueModified: newValue => CompanionStore.sizeScale = newValue
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Sleep after idle")
                            value: CompanionStore.sleepMinutes
                            from: 0
                            to: 30
                            stepSize: 1
                            suffix: "min"
                            validator: IntValidator {
                                bottom: 0
                                top: 30
                            }
                            formatValueFunction: val => val === 0 ? qsTr("never") : `${Math.round(val)} min`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => CompanionStore.sleepMinutes = Math.round(newValue)
                        }
                    }
                }


                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: assistantCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: assistantCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Assistant (Hermes)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: assistantStatus.text
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Optional and local: Hermes runs as your user on loopback, Javi talks to it only through horneroctl, and nothing changes the system without your approval. Keys never enter this panel.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Enable assistant")
                                type: TextButton.Filled
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "enable", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Disable")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "disable", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Refresh status")
                                type: TextButton.Tonal
                                onClicked: assistantStatus.refresh()
                            }
                        }

                        SwitchRow {
                            label: qsTr("Stream answers live")
                            checked: CompanionStore.chatStreaming
                            onToggled: checked => CompanionStore.chatStreaming = checked
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Chat history kept")
                            value: CompanionStore.chatHistoryLimit
                            from: 0
                            to: 200
                            stepSize: 10
                            suffix: qsTr("msgs")
                            validator: IntValidator {
                                bottom: 0
                                top: 200
                            }
                            formatValueFunction: val => val === 0 ? qsTr("off") : `${Math.round(val)}`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => CompanionStore.chatHistoryLimit = Math.round(newValue)
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: hermesCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: hermesCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Hermes agent")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Live state from horneroctl. Model, provider, API keys and token usage are managed in the Hermes dashboard — keys never enter this panel.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        DetailRow {
                            label: qsTr("Endpoint")
                            value: assistantStatus.data.endpoint || "—"
                        }

                        DetailRow {
                            label: qsTr("Gateway")
                            value: assistantStatus.data.gateway || "—"
                        }

                        DetailRow {
                            label: qsTr("Protocol")
                            value: assistantStatus.data.protocol || "—"
                        }

                        DetailRow {
                            label: qsTr("Model")
                            value: hermesModel.text
                        }

                        DetailRow {
                            label: qsTr("Chat sessions")
                            value: hermesSessions.text
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Start gateway")
                                type: TextButton.Filled
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "gateway", "start", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Stop gateway")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "gateway", "stop", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Open Hermes dashboard")
                                type: TextButton.Tonal
                                onClicked: {
                                    Quickshell.execDetached(["hermes", "dashboard", "--no-open"]);
                                    dashboardTimer.restart();
                                }
                            }
                        }

                        Timer {
                            id: dashboardTimer

                            interval: 1800
                            repeat: false
                            onTriggered: Quickshell.execDetached(["app2unit", "-O", "--", "http://127.0.0.1:9119"])
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: charCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: charCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Character")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            text: qsTr("Skin")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: Companion.knownSkins

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: CompanionStore.skin === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.setSkin(modelData)
                                }
                            }
                        }

                        StyledText {
                            text: qsTr("Summon edge")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Left")
                                toggle: true
                                checked: CompanionStore.edge === "left"
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.edge = "left"
                            }
                            TextButton {
                                text: qsTr("Right")
                                toggle: true
                                checked: CompanionStore.edge === "right"
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.edge = "right"
                            }
                        }

                        StyledText {
                            text: qsTr("Speech bubble theme")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: ["auto", "dark", "light", "pampa"]

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: CompanionStore.bubbleTheme === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.bubbleTheme = modelData
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: actionCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: actionCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Actions")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: CompanionStore.state === "hidden" ? qsTr("Summon") : qsTr("Peek out")
                                type: TextButton.Filled
                                Layout.fillWidth: true
                                onClicked: CompanionStore.summon()
                            }
                            TextButton {
                                text: qsTr("Reset position")
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.resetPosition()
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: assistantStatus

        property string text: qsTr("Checking assistant status…")
        property var data: ({})

        function refresh(): void {
            assistantStatusProc.out = "";
            assistantStatusProc.command = ["horneroctl", "assistant", "status", "--json"];
            assistantStatusProc.running = true;
            hermesModel.refresh();
            hermesSessions.refresh();
        }
    }

    Process {
        id: assistantStatusProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantStatusProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantStatusProc.out.trim());
                assistantStatus.text = payload.message ? payload.message.toString() : qsTr("Unknown status");
                assistantStatus.data = payload.data ?? {};
            } catch (e) {
                assistantStatus.text = qsTr("horneroctl assistant unavailable on this system.");
                assistantStatus.data = {};
            }
        }
    }

    QtObject {
        id: hermesModel

        property string text: "—"

        function refresh(): void {
            hermesModelProc.out = "";
            hermesModelProc.command = ["horneroctl", "assistant", "model", "list", "--json"];
            hermesModelProc.running = true;
        }
    }

    Process {
        id: hermesModelProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                hermesModelProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(hermesModelProc.out.trim());
                hermesModel.text = payload.ok ? ((payload.data ?? {}).models ?? "—").toString() : "—";
            } catch (e) {
                hermesModel.text = "—";
            }
        }
    }

    QtObject {
        id: hermesSessions

        property string text: "—"

        function refresh(): void {
            hermesSessionsProc.out = "";
            hermesSessionsProc.command = ["horneroctl", "assistant", "sessions", "list", "--json"];
            hermesSessionsProc.running = true;
        }
    }

    Process {
        id: hermesSessionsProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                hermesSessionsProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(hermesSessionsProc.out.trim());
                hermesSessions.text = payload.ok ? ((payload.data ?? {}).count ?? "—").toString() : "—";
            } catch (e) {
                hermesSessions.text = "—";
            }
        }
    }

    // Label/value row for live Hermes state.
    component DetailRow: RowLayout {
        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.preferredWidth: 130
            text: label
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true
            text: value
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurface
            wrapMode: Text.Wrap
        }
    }

    QtObject {
        id: assistantCtl

        function run(cmd): void {
            assistantCtlProc.command = cmd;
            assistantCtlProc.running = true;
        }
    }

    Process {
        id: assistantCtlProc

        onExited: (exitCode, exitStatus) => assistantStatus.refresh()
    }

    Component.onCompleted: assistantStatus.refresh()
}
