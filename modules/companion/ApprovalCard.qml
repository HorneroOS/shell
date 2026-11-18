pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.companion
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Explicit approval card. Shows exactly what Hermes asked to do, for
// which run, under which mode/workspace/isolation, and the scope of
// the answer. There is no "approve all", no remember-choice, no
// auto-approve and no default-focused Allow button: each request is
// decided on its own, and Allow means this one action, once
// (horneroctl maps it to the gateway choice `once`).
//
// Honesty: the backend does not rate risk or name a capability, so
// the card never invents either. It shows the exact (redacted)
// request text and the last tool the gateway reported, and says so.
Rectangle {
    id: root

    required property var bridge
    // Compact (panel): request + scope + decision, details on demand.
    // The Workbench shows everything.
    property bool expanded: false

    property bool showDetails: false
    // A short enable delay whenever a card appears or its request
    // changes: a click aimed at the previous card cannot land on a new
    // request that replaced it a moment ago.
    property bool armed: false
    readonly property string requestKey: root.pend ? `${root.pend.runId}|${root.pend.requestId}|${root.pend.detail}` : ""
    onRequestKeyChanged: {
        root.armed = false;
        if (root.requestKey !== "")
            armTimer.restart();
    }

    // The request id that has been on screen for the whole arm delay:
    // decisions carry it, and the bridge refuses them if it is no longer
    // the request that is waiting.
    property string armedRequest: ""

    Timer {
        id: armTimer

        interval: 700
        onTriggered: {
            root.armedRequest = root.pend ? root.pend.requestId : "";
            root.armed = true;
        }
    }

    readonly property var pend: root.bridge.pendingApproval
    readonly property string lang: root.bridge.lang
    readonly property var gw: AssistantRun.gateway

    function lastTool(): string {
        const tl = AssistantRun.timeline;
        for (let i = tl.length - 1; i >= 0; i--)
            if (tl[i].kind === "tool")
                return tl[i].name;
        return "";
    }

    visible: root.pend !== null
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Appearance.padding.large * 2
    radius: Appearance.rounding.small
    color: Qt.alpha(Signal.palette.alert, 0.10)
    border.width: 1
    border.color: Qt.alpha(Signal.palette.alert, 0.7)

    Accessible.role: Accessible.Pane
    Accessible.name: AssistantCopy.t("approval.title", root.lang)

    component Row2: RowLayout {
        id: row

        property string label: ""
        property string value: ""
        property bool mono: true

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.preferredWidth: 96
            Layout.alignment: Qt.AlignTop
            text: row.label
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: row.value
            textFormat: Text.PlainText
            font.family: row.mono ? Appearance.font.family.mono : Appearance.font.family.sans
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.ink
            wrapMode: Text.WrapAnywhere
        }
    }

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        StyledText {
            text: "▲ " + AssistantCopy.t("approval.title", root.lang).toUpperCase()
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            font.bold: true
            color: Signal.palette.alert
        }

        // The exact request, whole. Long text scrolls inside the well;
        // it is never summarised or cut (see `truncated` below).
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(what.implicitHeight + Appearance.padding.normal * 2, 160)
            radius: Appearance.rounding.small
            color: Signal.palette.phosphorWell
            clip: true

            Flickable {
                id: wellFlick

                anchors.fill: parent
                contentWidth: width
                contentHeight: what.implicitHeight + Appearance.padding.normal * 2
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: wellFlick
                }

                StyledText {
                    id: what

                    x: Appearance.padding.normal
                    y: Appearance.padding.normal
                    width: wellFlick.width - Appearance.padding.normal * 2
                    text: root.pend ? root.pend.detail : ""
                    textFormat: Text.PlainText
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.ink
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.pend !== null && root.pend.truncated
            text: AssistantCopy.t("approval.truncated", root.lang)
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.pend !== null && root.pend.flagged
            text: AssistantCopy.t("approval.hidden-chars", root.lang)
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.pend !== null && root.pend.requestId === ""
            text: AssistantCopy.t("approval.unbound", root.lang)
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        // Not sandboxed is always visible: it changes how much the
        // decision matters.
        Row2 {
            visible: !root.expanded && !root.gw.sandboxed && root.gw.isolation !== "unknown"
            label: AssistantCopy.t("approval.isolation", root.lang)
            value: AssistantCopy.t("approval.isolation.unsandboxed", root.lang)
            mono: false
        }
        Row2 {
            visible: root.pend !== null && root.pend.requestId !== ""
            label: AssistantCopy.t("approval.scope", root.lang)
            value: AssistantCopy.t("approval.scope.once", root.lang)
            mono: false
        }

        TextButton {
            visible: !root.expanded
            text: root.showDetails ? qsTr("Hide details") : qsTr("Details")
            type: TextButton.Text
            onClicked: root.showDetails = !root.showDetails
        }

        ColumnLayout {
            visible: root.expanded || root.showDetails
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Row2 {
                label: AssistantCopy.t("approval.run", root.lang)
                value: root.pend ? root.pend.runId : ""
            }
            Row2 {
                visible: root.pend !== null && root.pend.requestId !== ""
                label: AssistantCopy.t("approval.request", root.lang)
                value: root.pend ? root.pend.requestId : ""
            }
            Row2 {
                visible: root.lastTool() !== ""
                label: qsTr("Tool")
                value: AssistantRun.visibleText(root.lastTool())
            }
            Row2 {
                label: AssistantCopy.t("approval.mode", root.lang)
                value: root.pend && ["ask", "agent", "chat"].includes(root.pend.mode) ? AssistantCopy.t("mode." + root.pend.mode, root.lang) : AssistantCopy.t("approval.mode.unknown", root.lang)
                mono: false
            }
            Row2 {
                visible: root.gw.workspace !== ""
                label: AssistantCopy.t("approval.workspace", root.lang)
                value: root.gw.workspace
            }
            Row2 {
                label: AssistantCopy.t("approval.isolation", root.lang)
                value: AssistantCopy.t(root.gw.sandboxed ? "approval.isolation.sandboxed" : (root.gw.isolation === "unknown" ? "approval.isolation.unknown" : "approval.isolation.unsandboxed"), root.lang)
                mono: false
            }
            Row2 {
                label: AssistantCopy.t("approval.risk", root.lang)
                value: AssistantCopy.t("approval.risk.text", root.lang)
                mono: false
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.pend !== null && root.pend.live === false
            text: AssistantCopy.t("approval.stream.closed", root.lang)
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.pend !== null && root.pend.error !== ""
            text: root.pend ? root.pend.error : ""
            textFormat: Text.PlainText
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.bridge.decisionBusy
            text: AssistantCopy.t("approval.deciding", root.lang)
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        RowLayout {
            spacing: Appearance.spacing.normal

            TextButton {
                text: AssistantCopy.t("approval.deny", root.lang)
                type: TextButton.Tonal
                enabled: root.armed && !root.bridge.decisionBusy
                onClicked: root.bridge.approve(root.pend.runId, "deny", root.armedRequest)
            }

            TextButton {
                text: AssistantCopy.t("approval.allow", root.lang)
                type: TextButton.Tonal
                enabled: root.armed && !root.bridge.decisionBusy && root.pend !== null && root.pend.mode === "agent" && root.pend.requestId !== "" && !root.pend.truncated
                onClicked: root.bridge.approve(root.pend.runId, "approve", root.armedRequest)
            }
        }
    }
}
