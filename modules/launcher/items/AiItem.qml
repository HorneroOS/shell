import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Launcher inline-AI row (shell#250 slice 3): shows the `>ai` prompt and
// streams Javi's answer in place. Click/Enter asks; while busy, click
// stops. Follow-ups and approvals live in the chat panel — this row is
// for one quick question without leaving the launcher.
Item {
    id: root

    required property var list
    readonly property string lang: AssistantCopy.lang(Language.uiLocale)
    // The quick ask is shared with Javi Radio: only a hand-off of a run
    // the launcher started is offered here.
    // Everything this row shows or stops is the launcher's own run; a
    // Javi Radio question on the shared quick ask is never shown here.
    readonly property bool mine: InlineAsk.owner === "launcher"
    readonly property bool busy: root.mine && InlineAsk.busy
    readonly property bool failed: root.mine && InlineAsk.failed
    readonly property bool handoff: InlineAsk.needsWorkbench && root.mine
    readonly property string question: list.search.text.slice(`${Config.launcher.actionPrefix}ai `.length).trim()

    function onClicked(): void {
        // A failed ask is never a dead end: activating the row
        // falls back to the previous summon-Javi behaviour.
        if (root.handoff)
            InlineAsk.openInWorkbench(root.list);
        else if (root.failed)
            InlineAsk.openInJavi(root.list);
        else if (root.busy)
            InlineAsk.cancel("launcher");
        else
            InlineAsk.ask(root.question, "launcher");
    }

    implicitHeight: Math.max(Config.launcher.sizes.itemHeight, content.implicitHeight + Appearance.padding.normal * 2)

    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: root.handoff ? AssistantCopy.t("action.continue-workbench", root.lang) : root.failed ? qsTr("Open this question in the Javi chat") : (root.busy ? qsTr("Stop Javi") : (root.question !== "" ? qsTr("Ask Javi: %1").arg(root.question) : qsTr("Ask Javi")))

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.onClicked();
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Glyph {
                name: "feather"
                font.pointSize: Appearance.font.size.extraLarge
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: {
                    if (root.busy)
                        return qsTr("Javi is thinking… (click to stop)");
                    if (root.handoff)
                        return AssistantCopy.t("quick.needs-workbench", root.lang) + "  \u2192 " + AssistantCopy.t("action.continue-workbench", root.lang);
                    if (root.failed)
                        return qsTr("Open this question in the Javi chat instead");
                    if (root.question !== "")
                        return qsTr("Ask Javi: %1").arg(root.question);
                    return qsTr("Type a question after %1ai").arg(Config.launcher.actionPrefix) + " \u00B7 " + AssistantCopy.t("quick.hint", root.lang);
                }
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.normal
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.mine && InlineAsk.errorText !== "" && !root.handoff
            text: InlineAsk.errorText
            color: Signal.palette.alert
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.mine && InlineAsk.text !== ""
            text: root.mine ? InlineAsk.text : ""
            color: Signal.palette.ink
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.small
        }
    }
}
