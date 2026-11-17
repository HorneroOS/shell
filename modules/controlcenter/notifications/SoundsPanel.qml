import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.services
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

// Event sounds: off by default, volume, which events chime, and the
// installed sound theme. Sounds come from /usr/share/sounds via pw-play.
ChannelPanel {
    id: root

    title: qsTr("Sounds")

    FolderListModel {
        id: themes

        folder: "file:///usr/share/sounds"
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
    }

    // Installed themes that carry the stereo files we play.
    readonly property var themeOptions: {
        const out = [];
        for (let i = 0; i < themes.count; i++) {
            const n = themes.get(i, "fileName");
            out.push({
                id: n,
                label: n
            });
        }
        if (!out.some(o => o.id === Config.sounds.theme))
            out.push({
                id: Config.sounds.theme,
                label: Config.sounds.theme
            });
        return out;
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        SwitchRow {
            label: qsTr("Play event sounds")
            checked: Config.sounds.enabled
            onToggled: checked => {
                Config.sounds.enabled = checked;
                Config.save();
            }
        }

        SizeSlider {
            target: Config.sounds
            key: "volume"
            label: qsTr("Volume")
            from: 0
            to: 1
            defaultValue: 0.5
            stepSize: 0.05
            decimals: 2
            suffix: ""
        }

        SwitchRow {
            label: qsTr("New notification")
            checked: Config.sounds.events.notification
            onToggled: checked => {
                Config.sounds.events.notification = checked;
                Config.save();
            }
        }

        SwitchRow {
            label: qsTr("Battery warning")
            checked: Config.sounds.events.battery
            onToggled: checked => {
                Config.sounds.events.battery = checked;
                Config.save();
            }
        }

        SwitchRow {
            label: qsTr("Charger plugged in")
            checked: Config.sounds.events.charger
            onToggled: checked => {
                Config.sounds.events.charger = checked;
                Config.save();
            }
        }

        ChoiceRow {
            target: Config.sounds
            key: "theme"
            label: qsTr("Sound theme")
            defaultValue: "freedesktop"
            options: root.themeOptions
        }

        RowLayout {
            spacing: Appearance.spacing.small

            TextButton {
                text: qsTr("Test notification sound")
                type: TextButton.Tonal
                onClicked: Sounds.preview("notification")
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Quiet while Do Not Disturb is on and in Focus and Gaming modes.")
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }
        }
    }
}
