import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.modules.companion
import qs.services
import QtQuick
import QtQuick.Layouts

// Control Center > Javi > Radio: the quick assistant. Radio only asks
// quick questions; it never runs an agent, approves, attaches or reads the
// screen, so nothing here widens what the assistant may do (permissions stay
// under Permissions & security). These controls choose where Radio can be
// opened from.
ChannelPanel {
    id: root

    readonly property var r: CompanionStore.radioSettings

    title: qsTr("Javi Radio")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        SwitchRow {
            label: qsTr("Enable Javi Radio")
            checked: root.r.enabled
            onToggled: checked => CompanionStore.patchPref("radio", "enabled", checked)
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Quick questions only. A question never turns into an agent run: if the assistant needs your approval, Radio sends you to the Workbench.")
            wrapMode: Text.Wrap
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        StyledText {
            text: qsTr("Open Radio from")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        Repeater {
            model: [{ "id": "shortcut", "label": qsTr("Keyboard shortcut") }, { "id": "launcher", "label": qsTr("Launcher") }, { "id": "javi", "label": qsTr("Clicking Javi") }, { "id": "bar", "label": qsTr("Bar item") }, { "id": "menu", "label": qsTr("Javi's menu") }, { "id": "nest", "label": qsTr("Clicking the nest") }, { "id": "plugin", "label": qsTr("Extension actions (no keyboard until you click)") }, { "id": "keybind", "label": qsTr("Compositor key binding over IPC (cannot be verified)") }]

            SwitchRow {
                id: entryRow

                required property var modelData

                enabled: root.r.enabled
                label: modelData.label
                checked: root.r.entryPoints[modelData.id]
                onToggled: checked => CompanionStore.patchPref("radio", "entryPoints." + entryRow.modelData.id, checked)
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Extension actions and the IPC key binding come through qs ipc, which any local program can call: they are refused in Focus, Gaming and fullscreen, and they can only open Radio or put text in it, never send a question.")
            wrapMode: Text.Wrap
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        PrefPick {
            label: qsTr("Clicking Javi")
            current: root.r.clickOnJavi
            defaultValue: "radio"
            options: [{ "id": "radio", "label": qsTr("Javi Radio") }, { "id": "tip", "label": qsTr("Tip") }, { "id": "chat", "label": qsTr("Chat") }, { "id": "none", "label": qsTr("Nothing") }]
            onPicked: id => CompanionStore.patchPref("radio", "clickOnJavi", id)
        }

        SwitchRow {
            label: qsTr("Show Radio in the bar")
            checked: root.r.showInBar
            onToggled: checked => CompanionStore.patchPref("radio", "showInBar", checked)
        }

        SwitchRow {
            label: qsTr("Keep Radio open after an answer")
            checked: root.r.keepOpenAfterAnswer
            onToggled: checked => CompanionStore.patchPref("radio", "keepOpenAfterAnswer", checked)
        }

        SwitchRow {
            label: qsTr("Show the answer in Javi's bubble")
            checked: root.r.answerBubble
            onToggled: checked => CompanionStore.patchPref("radio", "answerBubble", checked)
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Global shortcut name: javiRadio (suggested binding %1). Bind it in your compositor or Keybinds settings.").arg(root.r.shortcut)
            wrapMode: Text.Wrap
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        TextButton {
            text: qsTr("Reset the Radio section")
            type: TextButton.Text
            onClicked: CompanionStore.resetPref("radio")
        }
    }
}
