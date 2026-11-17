pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import "../../../../services/accents.js" as Accents
import "../../../../services/chromatic.js" as Colour
import "../../../../services/experience.js" as Model

// Appearance > Accent. One accent colour laid over any theme: everywhere,
// per colour mode (dark or light), or per experience mode. "Theme default"
// removes the override. Preview is live (the shell repaints as soon as the
// value changes) and every row has its own reset. The warm pastel presets
// are opt-in starting points; any hex works, and a contrast readout says
// when an accent is hard to read on the current theme.
CollapsibleSection {
    id: root

    required property var previewController
    required property var session

    title: qsTr("Accent")
    description: qsTr("Your own accent colour over any theme: everywhere, per light or dark, or per experience mode. Reset returns to the theme's accent.")
    showBackground: true

    readonly property var prefs: Config.appearance.accent
    readonly property var scopes: {
        const rows = [
            {
                "key": "all",
                "label": qsTr("Everywhere")
            },
            {
                "key": "dark",
                "label": qsTr("When dark")
            },
            {
                "key": "light",
                "label": qsTr("When light")
            }
        ];
        for (const id of Model.MODE_IDS)
            rows.push({
                "key": "exp:" + id,
                "label": qsTr("In %1 mode").arg(id)
            });
        return rows;
    }

    function valueOf(key: string): string {
        if (key === "all")
            return prefs.color;
        if (key === "dark" || key === "light")
            return prefs.perMode[key];
        return prefs.perExperience[key.substr(4)] ?? "";
    }

    function setValue(key: string, hex: string): void {
        const v = hex === "" ? "" : String(hex).toUpperCase();
        if (key === "all") {
            Config.appearance.accent.color = v;
        } else if (key === "dark" || key === "light") {
            Config.appearance.accent.perMode[key] = v;
        } else {
            const map = Object.assign({}, prefs.perExperience);
            if (v === "")
                delete map[key.substr(4)];
            else
                map[key.substr(4)] = v;
            Config.appearance.accent.perExperience = map;
        }
        Config.save();
    }

    // A preset adapts: it sets the dark and light twins for the colour mode
    // rows, and the colour of the current mode for the other rows.
    function usePreset(key: string, preset: var): void {
        if (key === "all") {
            Config.appearance.accent.color = "";
            Config.appearance.accent.perMode.dark = preset.dark;
            Config.appearance.accent.perMode.light = preset.light;
            Config.save();
        } else {
            setValue(key, Accents.forMode(preset, key === "light" ? "light" : key === "dark" ? "dark" : Signal.themeMode));
        }
    }

    function ratio(hex: string): real {
        return Colour.contrast(hex, String(Signal.palette.ground));
    }

    component AccentRow: ColumnLayout {
        id: row

        required property var scope

        readonly property string value: root.valueOf(scope.key)
        readonly property bool valid: /^#[0-9A-Fa-f]{6}$/.test(field.text)

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Well {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                color: row.value !== "" ? row.value : Signal.palette.signal
                outline: row.value !== "" ? Signal.palette.signal : Signal.palette.ruleStrong
                Accessible.ignored: true
            }

            StyledText {
                Layout.preferredWidth: 150
                text: row.scope.label
                elide: Text.ElideRight
            }

            Well {
                Layout.preferredWidth: 132
                Layout.preferredHeight: 28
                outline: field.activeFocus ? Signal.palette.focus : Signal.palette.ruleStrong

                StyledTextField {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.small
                    anchors.rightMargin: Appearance.padding.small
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: qsTr("Theme default")
                    text: row.value
                    maximumLength: 7
                    color: row.valid || text === "" ? Signal.palette.ink : Signal.palette.alert
                    Accessible.name: qsTr("Accent for %1, hex").arg(row.scope.label)
                    onTextEdited: if (row.valid)
                        root.setValue(row.scope.key, text)
                    Connections {
                        target: row

                        function onValueChanged(): void {
                            if (!field.activeFocus)
                                field.text = row.value;
                        }
                    }
                }
            }

            TextButton {
                visible: row.value !== ""
                text: qsTr("Reset")
                type: TextButton.Text
                Accessible.name: qsTr("Reset accent for %1").arg(row.scope.label)
                onClicked: {
                    root.setValue(row.scope.key, "");
                    field.text = "";
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: row.value !== "" && root.ratio(row.value) < 3
                text: qsTr("Low contrast on this theme")
                color: Signal.palette.alert
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 28 + Appearance.spacing.small
            spacing: Appearance.spacing.small

            Repeater {
                model: Accents.PRESETS

                Rectangle {
                    id: chip

                    required property var modelData

                    readonly property string shown: Accents.forMode(modelData, row.scope.key === "light" ? "light" : row.scope.key === "dark" ? "dark" : Signal.themeMode)

                    width: 30
                    height: 24
                    radius: Appearance.rounding.large
                    color: shown
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Signal.palette.focus : Signal.palette.ruleStrong
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("%1 accent for %2").arg(modelData.name).arg(row.scope.label)
                    Accessible.onPressAction: root.usePreset(row.scope.key, modelData)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.usePreset(row.scope.key, modelData);
                            event.accepted = true;
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            chip.forceActiveFocus();
                            root.usePreset(row.scope.key, chip.modelData);
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Repeater {
            model: root.scopes

            AccentRow {
                required property var modelData

                scope: modelData
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            text: qsTr("An experience mode beats a light or dark choice, which beats Everywhere. Pastel presets are optional; pick any colour you like. The accent changes the accent, its glow and the text on it; surfaces and status colours stay the theme's.")
        }
    }
}
