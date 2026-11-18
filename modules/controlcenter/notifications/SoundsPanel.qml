import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// Event sounds: off by default, volume, which events chime, and the
// installed sound theme. Sounds come from /usr/share/sounds via pw-play.
ChannelPanel {
    id: root

    title: qsTr("Sounds")

    Component.onCompleted: Sounds.refreshThemes()

    // Real sound themes only (index.theme or the stereo file we play), never
    // every folder under /usr/share/sounds. A missing file falls back to the
    // freedesktop theme (sound naming spec inheritance), see sounds.js.
    readonly property var themeOptions: {
        const out = Sounds.themes.map(n => ({
                    id: n,
                    label: n
                }));
        if (Config.sounds.theme.length > 0 && !out.some(o => o.id === Config.sounds.theme))
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

        SwitchRow {
            label: qsTr("Chime even when the app plays its own sound")
            checked: Config.sounds.alwaysChime
            onToggled: checked => {
                Config.sounds.alwaysChime = checked;
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
                text: Sounds.previewStatus === "no-player" ? qsTr("pw-play was not found: install PipeWire tools to hear sounds.") : Sounds.previewStatus === "no-file" ? qsTr("No sound file found in this theme or in freedesktop.") : Sounds.previewStatus === "failed" ? qsTr("The sound could not be played.") : qsTr("Quiet while Do Not Disturb is on and in Focus and Gaming modes; a critical battery warning still chimes.")
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }
        }
    }
}
