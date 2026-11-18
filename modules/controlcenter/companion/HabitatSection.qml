import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.modules.companion
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Control Center > Javi > Nest: where the habitat lives, how it is lit and
// how loud it is in each Experience mode. Every control writes one key of
// CompanionStore.habitatSettings (validated by habitat.js), previews live on
// the real nest, and has a Reset back to the shipped default.
ChannelPanel {
    id: root

    readonly property var h: CompanionStore.habitatSettings

    function set(path: string, value: var): void {
        CompanionStore.patchPref("habitat", path, value);
    }

    title: qsTr("Nest")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        SwitchRow {
            label: qsTr("Show the nest")
            checked: CompanionStore.nestEnabled
            onToggled: checked => CompanionStore.nestEnabled = checked
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Placeholder art: the final nest is still being drawn. The placement, lighting and mode controls below already work and will carry over.")
            wrapMode: Text.Wrap
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        PrefPick {
            label: qsTr("Placement")
            current: root.h.placement
            defaultValue: "anchored"
            options: [{ "id": "anchored", "label": qsTr("Own corner") }, { "id": "withJavi", "label": qsTr("Beside Javi") }]
            help: qsTr("Own corner keeps the nest in one place on your desktop, and Javi flies home to it. Beside Javi carries it along.")
            onPicked: id => root.set("placement", id)
        }

        PrefPick {
            visible: root.h.placement === "anchored"
            label: qsTr("Corner")
            current: root.h.anchor
            defaultValue: "bottom-right"
            options: [{ "id": "bottom-right", "label": qsTr("Bottom right") }, { "id": "bottom-left", "label": qsTr("Bottom left") }, { "id": "top-right", "label": qsTr("Top right") }, { "id": "top-left", "label": qsTr("Top left") }]
            onPicked: id => root.set("anchor", id)
        }

        PrefSlider {
            visible: root.h.placement === "anchored"
            label: qsTr("Distance from the side")
            value: root.h.marginX
            from: 0
            to: 400
            defaultValue: 24
            suffix: "px"
            onChanged: v => root.set("marginX", Math.round(v))
        }

        PrefSlider {
            visible: root.h.placement === "anchored"
            label: qsTr("Distance from the edge")
            value: root.h.marginY
            from: 0
            to: 400
            defaultValue: 48
            suffix: "px"
            onChanged: v => root.set("marginY", Math.round(v))
        }

        PrefSlider {
            label: qsTr("Nest size")
            value: root.h.scale
            from: 0.5
            to: 2.0
            stepSize: 0.05
            decimals: 2
            defaultValue: 1.0
            suffix: "×"
            onChanged: v => root.set("scale", v)
        }

        PrefPick {
            visible: root.h.placement === "anchored"
            label: qsTr("Monitor")
            current: root.h.monitor
            defaultValue: ""
            options: [{ "id": "", "label": qsTr("With Javi") }].concat(Quickshell.screens.map(s => ({ "id": s.name, "label": s.name })))
            onPicked: id => root.set("monitor", id)
        }

        PrefPick {
            label: qsTr("Lighting")
            current: root.h.lighting
            defaultValue: "auto"
            options: [{ "id": "auto", "label": qsTr("Follow theme") }, { "id": "warm", "label": qsTr("Warm") }, { "id": "cool", "label": qsTr("Cool") }, { "id": "off", "label": qsTr("Off") }]
            help: qsTr("Follow theme uses your wallpaper and Chromatic colours. Lights only show real state: assistant link, a run in progress, an approval waiting, the current mode.")
            onPicked: id => root.set("lighting", id)
        }

        PrefSlider {
            label: qsTr("Light intensity")
            value: root.h.intensity
            from: 0.2
            to: 1.0
            stepSize: 0.05
            decimals: 2
            defaultValue: 0.8
            onChanged: v => root.set("intensity", v)
        }

        SwitchRow {
            label: qsTr("Indicator lights")
            checked: root.h.indicators
            onToggled: checked => root.set("indicators", checked)
        }

        SwitchRow {
            label: qsTr("Screen glow while the assistant works")
            checked: root.h.phosphor
            onToggled: checked => root.set("phosphor", checked)
        }

        SwitchRow {
            label: qsTr("Dim in quiet hours")
            checked: root.h.dimInQuietHours
            onToggled: checked => root.set("dimInQuietHours", checked)
        }

        PrefPick {
            label: qsTr("Click on the nest")
            current: root.h.clickAction
            defaultValue: "none"
            options: [{ "id": "none", "label": qsTr("Nothing") }, { "id": "radio", "label": qsTr("Javi Radio") }, { "id": "workbench", "label": qsTr("Workbench") }, { "id": "settings", "label": qsTr("Settings") }]
            help: qsTr("Nothing (the default) keeps the nest click-through. Any other choice makes only the nest art clickable.")
            onPicked: id => root.set("clickAction", id)
        }

        StyledText {
            text: qsTr("Per mode")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        Repeater {
            model: ["focus", "everyday", "signal", "gaming", "studio"]

            PrefPick {
                id: modeRow

                required property string modelData

                label: modelData === "focus" ? qsTr("Focus") : modelData === "everyday" ? qsTr("Everyday") : modelData === "signal" ? qsTr("Signal") : modelData === "gaming" ? qsTr("Gaming") : qsTr("Studio")
                current: root.h.modeLevel[modelData]
                defaultValue: ({ "focus": "dim", "everyday": "normal", "signal": "rich", "gaming": "hidden", "studio": "dim" })[modelData]
                options: [{ "id": "hidden", "label": qsTr("Hidden") }, { "id": "dim", "label": qsTr("Dim") }, { "id": "normal", "label": qsTr("Normal") }, { "id": "rich", "label": qsTr("Rich") }]
                onPicked: id => root.set("modeLevel." + modeRow.modelData, id)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            // Developer aid for checking each construction stage; hidden
            // unless the shell runs with HORNERO_COMPANION_DEV=1 (building
            // is otherwise earned by real activity, never bought).
            TextButton {
                visible: Quickshell.env("HORNERO_COMPANION_DEV") === "1"
                text: qsTr("Build the next stage now")
                type: TextButton.Tonal
                enabled: CompanionStore.nestEnabled && CompanionStore.nestStage < 4
                onClicked: {
                    CompanionStore.nestStage = CompanionStore.nestStage + 1;
                    CompanionStore.nestProgress = 0;
                    CompanionStore.markDirty();
                }
            }

            TextButton {
                text: qsTr("Reset the nest section")
                type: TextButton.Text
                onClicked: CompanionStore.resetPref("habitat")
            }
        }
    }
}
