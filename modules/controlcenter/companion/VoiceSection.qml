import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.modules.companion
import qs.services
import QtQuick
import QtQuick.Layouts

// Control Center > Javi > Voice: the language and tone of Javi's small
// spoken lines (tips, reaction bubbles, Radio notices). The preview line is
// the real line in the chosen voice, not a mock.
ChannelPanel {
    id: root

    readonly property var v: CompanionStore.voiceSettings

    title: qsTr("Voice")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        PrefPick {
            label: qsTr("Language")
            current: root.v.language
            defaultValue: "auto"
            options: [{ "id": "auto", "label": qsTr("Follow system") }, { "id": "en", "label": "English" }, { "id": "es", "label": "Español" }]
            help: qsTr("Follow system uses the language the shell runs in.")
            onPicked: id => CompanionStore.patchPref("voice", "language", id)
        }

        PrefPick {
            label: qsTr("Tone")
            current: root.v.tone
            defaultValue: "warm"
            options: [{ "id": "warm", "label": qsTr("Warm") }, { "id": "plain", "label": qsTr("Plain") }]
            help: qsTr("Warm is Javi at his workbench. Plain says the same things with fewer words of character.")
            onPicked: id => CompanionStore.patchPref("voice", "tone", id)
        }

        StyledText {
            Layout.fillWidth: true
            text: JaviVoice.line("tip.start")
            wrapMode: Text.Wrap
            font.italic: true
            Accessible.name: qsTr("Preview: %1").arg(JaviVoice.line("tip.start"))
        }

        TextButton {
            text: qsTr("Reset the voice section")
            type: TextButton.Text
            onClicked: CompanionStore.resetPref("voice")
        }
    }
}
