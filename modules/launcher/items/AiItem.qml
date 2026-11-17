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
    readonly property string lang: AssistantCopy.lang(Qt.locale().name)
    readonly property string question: list.search.text.slice(`${Config.launcher.actionPrefix}ai `.length).trim()

    function onClicked(): void {
        // A failed ask is never a dead end: activating the row
        // falls back to the previous summon-Javi behaviour.
        if (InlineAsk.needsWorkbench)
            InlineAsk.openInWorkbench(root.list);
        else if (InlineAsk.failed)
            InlineAsk.openInJavi(root.list);
        else if (InlineAsk.busy)
            InlineAsk.stop();
        else
            InlineAsk.ask(root.question);
    }

    implicitHeight: Math.max(Config.launcher.sizes.itemHeight, content.implicitHeight + Appearance.padding.normal * 2)

    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: InlineAsk.needsWorkbench ? AssistantCopy.t("action.continue-workbench", root.lang) : InlineAsk.failed ? qsTr("Open this question in the Javi chat") : (InlineAsk.busy ? qsTr("Stop Javi") : (root.question !== "" ? qsTr("Ask Javi: %1").arg(root.question) : qsTr("Ask Javi")))

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
                text: {
                    if (InlineAsk.busy)
                        return qsTr("Javi is thinking… (click to stop)");
                    if (InlineAsk.needsWorkbench)
                        return AssistantCopy.t("quick.needs-workbench", root.lang) + "  \u2192 " + AssistantCopy.t("action.continue-workbench", root.lang);
                    if (InlineAsk.failed)
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
            visible: InlineAsk.errorText !== "" && !InlineAsk.needsWorkbench
            text: InlineAsk.errorText
            color: Signal.palette.alert
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.fillWidth: true
            visible: InlineAsk.text !== ""
            text: InlineAsk.text
            color: Signal.palette.ink
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.small
        }
    }
}
