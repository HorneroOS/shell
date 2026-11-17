pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Experience (RFC 0001 §5a, Signal Visual Language §13):
// view, switch and customise the five experience modes. Switching and
// per-mode customisations go through services/Experience.qml, so the
// pane, the IPC contract and horneroctl always share one state file
// ($XDG_STATE_HOME/hornero/experience.json) and one set of overrides
// (shell.json experience.modes). Nothing here writes config directly
// except the two Experience preferences the service itself exposes.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    // The mode being inspected/customised; starts on the active mode.
    property string selectedMode: Experience.mode
    property string actionMessage: ""
    property bool confirmReset: false
    property real previewLevel: 0.62

    readonly property var selProfile: {
        // Re-resolve whenever the stored overrides change.
        const _modes = Config.experience.modes;
        return Experience.profileFor(root.selectedMode);
    }
    readonly property var selFields: root.selProfile.fields
    readonly property bool selActive: root.selectedMode === Experience.mode
    // Effective glow/scanlines for the *active* mode (day themes, high
    // contrast and low motion force them off inside the service).
    readonly property bool glowGated: root.selActive && root.selFields["glow"] && !Experience.glow
    readonly property bool scanlinesGated: root.selActive && root.selFields["scanlines"] && !Experience.scanlines

    function field(key: string): var {
        return root.selFields[key];
    }

    function locked(key: string): bool {
        return Experience.isLocked(root.selectedMode, key);
    }

    function customise(key: string, value: var): void {
        const res = Experience.customise(root.selectedMode, key, value);
        root.actionMessage = res.startsWith("error") ? res : "";
    }

    function activate(id: string): void {
        const res = Experience.set(id, "user");
        root.actionMessage = res.startsWith("error") ? res : "";
        root.selectedMode = id;
    }

    onSelectedModeChanged: {
        root.actionMessage = "";
        root.confirmReset = false;
        if (root.selectedMode === "studio")
            Experience.probeStudioAudio();
    }

    // Preview telemetry cadence: ticks at the selected mode's rate while
    // its motion level allows movement, so the cadence/motion choices are
    // visible before the mode is activated.
    Timer {
        interval: Math.max(50, Math.round(1000 / Math.max(0.2, Number(root.field("telemetry.rateHz") ?? 1))))
        running: root.visible && root.field("motion") !== "off" && !Appearance.anim.reduced
        repeat: true
        onTriggered: root.previewLevel = 0.25 + Math.random() * 0.7
    }

    component EnumRow: StyledRect {
        id: enumRow

        required property string label
        required property var options // [{value, label}]
        required property string value
        property bool rowLocked: false

        signal picked(string value)

        Layout.fillWidth: true
        implicitHeight: enumCol.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.normal
        color: Signal.layer(Signal.palette.panel, 2)

        ColumnLayout {
            id: enumCol

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: enumRow.label
                }

                Glyph {
                    visible: enumRow.rowLocked
                    name: "lock"
                    size: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }

                StyledText {
                    visible: enumRow.rowLocked
                    text: qsTr("fixed in this mode")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: enumRow.options

                    TextButton {
                        required property var modelData

                        text: modelData.label
                        checked: modelData.value === enumRow.value
                        toggle: true
                        disabled: enumRow.rowLocked
                        type: TextButton.Tonal
                        onClicked: enumRow.picked(modelData.value)
                    }
                }
            }
        }
    }

    component SectionCard: StyledRect {
        id: card

        required property string title
        default property alias body: bodyCol.data

        Layout.fillWidth: true
        radius: Appearance.rounding.normal
        color: Signal.layer(Signal.palette.panel, 1)
        implicitHeight: bodyCol.implicitHeight + Appearance.padding.large * 2

        ColumnLayout {
            id: bodyCol

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.small

            StyledText {
                text: card.title
                font.pointSize: Appearance.font.size.normal
                font.weight: Appearance.font.weight.medium
            }
        }
    }

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
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

                PaneHeader {
                    paneId: "experience"
                    intro: qsTr("A mode is how Hornero behaves right now — motion, density, glow, telemetry cadence and notification policy. It composes with your edition, layout preset and theme; it never replaces them. Switches are explicit and reversible, and your per-mode customisations are kept.")
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.actionMessage.length > 0
                    text: root.actionMessage
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.WordWrap
                }

                SectionCard {
                    title: qsTr("Mode")

                    Repeater {
                        model: Experience.summary

                        StyledRect {
                            id: modeCard

                            required property var modelData

                            readonly property bool isActive: modelData.id === Experience.mode
                            readonly property bool isSelected: modelData.id === root.selectedMode
                            readonly property var prof: Experience.profileFor(modelData.id)

                            Layout.fillWidth: true
                            implicitHeight: modeRow.implicitHeight + Appearance.padding.large * 2
                            radius: Appearance.rounding.normal
                            color: isSelected ? Signal.layer(Signal.palette.lifted, 1) : Signal.layer(Signal.palette.panel, 2)
                            border.width: isActive ? 2 : 1
                            border.color: isActive ? (Experience.glow ? Signal.palette.glow : Signal.palette.signal) : Qt.alpha(Signal.palette.ruleStrong, 0.35)

                            Interactive {
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Inspect %1 mode").arg(modeCard.modelData.label)

                                function onClicked(): void {
                                    root.selectedMode = modeCard.modelData.id;
                                }
                            }

                            RowLayout {
                                id: modeRow

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.large
                                spacing: Appearance.spacing.normal

                                Glyph {
                                    name: modeCard.modelData.glyph
                                    size: Appearance.font.size.extraLarge
                                    color: modeCard.isActive ? Signal.palette.signal : Signal.palette.inkMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        spacing: Appearance.spacing.small

                                        StyledText {
                                            text: modeCard.modelData.label
                                            font.pointSize: Appearance.font.size.normal
                                            font.weight: Appearance.font.weight.strong
                                        }

                                        StyledText {
                                            visible: modeCard.isActive
                                            text: qsTr("Active")
                                            font.pointSize: Appearance.font.size.small
                                            color: Signal.palette.signal
                                        }

                                        StyledText {
                                            visible: modeCard.prof.customised.length > 0
                                            text: qsTr("Customised")
                                            font.pointSize: Appearance.font.size.small
                                            color: Signal.palette.cue
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modeCard.modelData.description
                                        font.pointSize: Appearance.font.size.small
                                        color: Signal.palette.inkMuted
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                TextButton {
                                    visible: !modeCard.isActive
                                    text: qsTr("Switch")
                                    type: TextButton.Tonal
                                    onClicked: root.activate(modeCard.modelData.id)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        TextButton {
                            visible: Experience.previousMode !== Experience.mode
                            text: qsTr("Revert to previous mode")
                            type: TextButton.Text
                            onClicked: {
                                const res = Experience.revert();
                                root.actionMessage = res.startsWith("error") ? res : "";
                                root.selectedMode = Experience.mode;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        TextButton {
                            text: root.confirmReset ? qsTr("Confirm factory reset") : qsTr("Factory reset")
                            type: root.confirmReset ? TextButton.Filled : TextButton.Text
                            onClicked: {
                                if (!root.confirmReset) {
                                    root.confirmReset = true;
                                    return;
                                }
                                root.confirmReset = false;
                                const res = Experience.reset();
                                root.actionMessage = res.startsWith("error") ? res : "";
                                root.selectedMode = Experience.mode;
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Factory reset returns to Everyday + Cockpit + Signal Night. Per-mode customisations are kept.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }

                SectionCard {
                    title: qsTr("%1 preview").arg(root.selProfile.label)

                    // Sunken scope well (Visual Language §10): density picks
                    // what each cell shows, the trace ticks at the mode's
                    // telemetry cadence, and glow/scanlines follow the
                    // mode's own profile (gated exactly as in the service
                    // when the mode is the active one).
                    StyledRect {
                        id: previewWell

                        readonly property bool showGlow: root.field("glow") && (!root.selActive || Experience.glow)
                        readonly property bool showScan: root.field("scanlines") && (!root.selActive || Experience.scanlines)

                        Layout.fillWidth: true
                        implicitHeight: previewCol.implicitHeight + Appearance.padding.large * 2
                        radius: Appearance.rounding.normal
                        color: Signal.palette.sunken
                        border.width: showGlow ? 2 : 1
                        border.color: showGlow ? Signal.palette.glow : Qt.alpha(Signal.palette.ruleStrong, 0.35)

                        ColumnLayout {
                            id: previewCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.large

                                Repeater {
                                    model: [
                                        {
                                            "glyph": "cpu",
                                            "eyebrow": qsTr("CPU"),
                                            "value": "42%"
                                        },
                                        {
                                            "glyph": "activity",
                                            "eyebrow": qsTr("MEM"),
                                            "value": "61%"
                                        },
                                        {
                                            "glyph": "wifi",
                                            "eyebrow": qsTr("NET"),
                                            "value": "12 Mb/s"
                                        }
                                    ]

                                    RowLayout {
                                        required property var modelData

                                        spacing: Appearance.spacing.small

                                        Glyph {
                                            name: modelData.glyph
                                            color: previewWell.showGlow ? Signal.palette.glow : Signal.palette.signal
                                        }

                                        ColumnLayout {
                                            visible: root.field("density") !== "icons"
                                            spacing: 0

                                            StyledText {
                                                visible: root.field("density") === "labels"
                                                text: modelData.eyebrow
                                                font.pointSize: Appearance.font.size.small
                                                color: Signal.palette.inkMuted
                                            }

                                            StyledText {
                                                text: modelData.value
                                                font.family: Appearance.font.family.mono
                                                color: Signal.palette.ink
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: qsTr("%1 Hz · %2").arg(Number(root.field("telemetry.rateHz") ?? 1).toFixed(1)).arg(root.field("motion"))
                                    font.family: Appearance.font.family.mono
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Qt.alpha(Signal.palette.ink, 0.12)

                                Rectangle {
                                    width: parent.width * root.previewLevel
                                    height: parent.height
                                    radius: parent.radius
                                    color: previewWell.showGlow ? Signal.palette.glow : Signal.palette.signal

                                    Behavior on width {
                                        Anim {
                                            duration: Appearance.anim.durations.short
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.fill: parent
                            visible: previewWell.showScan
                            spacing: 3

                            Repeater {
                                model: Math.floor(previewWell.height / 4)

                                Rectangle {
                                    width: previewWell.width
                                    height: 1
                                    color: Qt.alpha(Signal.palette.ink, 0.08)
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.glowGated || root.scanlinesGated
                        text: qsTr("Glow and scanlines stay off in day themes, high contrast and low motion levels, whatever the profile says.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.selActive ? qsTr("Effective now: motion %1 · telemetry %2 ms%3 · popups %4 · desktop widgets %5.").arg(Appearance.anim.level).arg(Experience.telemetryIntervalMs).arg(Experience.telemetryPaused ? qsTr(" (paused)") : "").arg(Experience.holdPopups ? qsTr("held") : qsTr("shown")).arg(Experience.desktopWidgetsVisible ? qsTr("visible") : qsTr("hidden")) : qsTr("Preview only — switch to %1 to apply it.").arg(root.selProfile.label)
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }

                SectionCard {
                    title: qsTr("Customise %1").arg(root.selProfile.label)

                    EnumRow {
                        label: qsTr("Motion")
                        value: root.field("motion")
                        rowLocked: root.locked("motion")
                        options: [
                            {
                                "value": "full",
                                "label": qsTr("Full")
                            },
                            {
                                "value": "standard",
                                "label": qsTr("Standard")
                            },
                            {
                                "value": "reduced",
                                "label": qsTr("Reduced")
                            },
                            {
                                "value": "off",
                                "label": qsTr("Off")
                            }
                        ]
                        onPicked: v => root.customise("motion", v)
                    }

                    EnumRow {
                        label: qsTr("Instrumentation density")
                        value: root.field("density")
                        options: [
                            {
                                "value": "icons",
                                "label": qsTr("Icons")
                            },
                            {
                                "value": "values",
                                "label": qsTr("Values")
                            },
                            {
                                "value": "labels",
                                "label": qsTr("Labels")
                            }
                        ]
                        onPicked: v => root.customise("density", v)
                    }

                    SwitchRow {
                        label: qsTr("Glow")
                        checked: root.field("glow")
                        enabled: !root.locked("glow")
                        onToggled: checked => root.customise("glow", checked)
                    }

                    SwitchRow {
                        label: qsTr("Scope scanlines")
                        checked: root.field("scanlines")
                        enabled: !root.locked("scanlines")
                        onToggled: checked => root.customise("scanlines", checked)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.locked("glow") || root.locked("scanlines") || root.locked("motion")
                        text: qsTr("Some fields are fixed in this mode (RFC guardrails): %1.").arg(root.selProfile.locked.join(", "))
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    SliderInput {
                        Layout.fillWidth: true

                        label: qsTr("Telemetry cadence")
                        value: Number(root.field("telemetry.rateHz") ?? 1)
                        from: 0.2
                        to: 4
                        stepSize: 0.1
                        suffix: "Hz"
                        decimals: 1
                        onValueModified: newValue => root.customise("telemetry.rateHz", Math.round(newValue * 10) / 10)
                    }

                    SwitchRow {
                        label: qsTr("Pause telemetry under fullscreen")
                        checked: root.field("telemetry.pauseWhenHidden")
                        onToggled: checked => root.customise("telemetry.pauseWhenHidden", checked)
                    }

                    EnumRow {
                        label: qsTr("Desktop widgets")
                        value: root.field("desktopWidgets")
                        options: [
                            {
                                "value": "none",
                                "label": qsTr("None")
                            },
                            {
                                "value": "user",
                                "label": qsTr("Yours")
                            },
                            {
                                "value": "instruments",
                                "label": qsTr("Instruments")
                            }
                        ]
                        onPicked: v => root.customise("desktopWidgets", v)
                    }

                    SwitchRow {
                        label: qsTr("Hold notification popups")
                        checked: root.field("notifications.hold")
                        onToggled: checked => root.customise("notifications.hold", checked)
                    }

                    SwitchRow {
                        label: qsTr("Suppress popups over fullscreen")
                        checked: root.field("notifications.suppressFullscreen")
                        onToggled: checked => root.customise("notifications.suppressFullscreen", checked)
                    }

                    SwitchRow {
                        label: qsTr("Keep awake over fullscreen")
                        checked: root.field("idle.inhibitFullscreen")
                        onToggled: checked => root.customise("idle.inhibitFullscreen", checked)
                    }

                    EnumRow {
                        label: qsTr("Power suggestion")
                        value: root.field("power.suggest")
                        options: [
                            {
                                "value": "",
                                "label": qsTr("None")
                            },
                            {
                                "value": "performance",
                                "label": qsTr("Performance")
                            },
                            {
                                "value": "power-saver",
                                "label": qsTr("Power saver")
                            }
                        ]
                        onPicked: v => root.customise("power.suggest", v)
                    }

                    SwitchRow {
                        label: qsTr("Hyprland gaming tuning")
                        checked: root.field("hooks.hyprlandTuning")
                        onToggled: checked => root.customise("hooks.hyprlandTuning", checked)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.field("hooks.hyprlandTuning") && !Experience.hyprlandTuningAvailable
                        text: qsTr("Hyprland tuning is unavailable on this compositor; the hook stays off and is reported in the mode status.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    SwitchRow {
                        label: qsTr("Apply PipeWire Low Latency when switching into this mode")
                        checked: root.field("hooks.studioAudio")
                        onToggled: checked => root.customise("hooks.studioAudio", checked)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedMode === "studio"
                        text: !Experience.studioAudioProbed ? qsTr("Reading studio audio…") : Experience.studioAudioAvailable ? qsTr("Studio audio: %1 (via horneroctl). PipeWire now: %2.").arg(Experience.studioAudioMode || qsTr("available")).arg(Experience.studioAudioStatus || qsTr("unavailable")) : qsTr("%1 PipeWire now: %2.").arg(Experience.studioAudioMessage || qsTr("Studio audio is not available on this system.")).arg(Experience.studioAudioStatus || qsTr("unavailable"))
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    EnumRow {
                        label: qsTr("Preferred layout preset")
                        value: root.field("layout.preset")
                        // Surviving presets (Visual Language §14); the two
                        // "Remove" presets are not offered as new choices.
                        options: ["cockpit", "cockpit-clear", "hornero-left", "hornero-right", "minimal-top", "minimal-left", "classic-top", "classic-bottom", "cozy-minimal", "dock-bottom", "gaming", "horizon", "islands", "studio"].map(id => ({
                                    "value": id,
                                    "label": id
                                }))
                        onPicked: v => root.customise("layout.preset", v)
                    }

                    SwitchRow {
                        label: qsTr("Apply preferred layout on switch")
                        checked: root.field("layout.apply")
                        onToggled: checked => root.customise("layout.apply", checked)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        TextButton {
                            visible: root.selActive && String(root.field("layout.preset") ?? "").length > 0
                            text: qsTr("Apply %1 now").arg(root.field("layout.preset"))
                            type: TextButton.Text
                            onClicked: Experience.applyPreferredLayout()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        TextButton {
                            visible: root.selProfile.customised.length > 0
                            text: qsTr("Reset %1 customisations").arg(root.selProfile.label)
                            type: TextButton.Text
                            onClicked: {
                                const res = Experience.resetCustomisations(root.selectedMode);
                                root.actionMessage = res.startsWith("error") ? res : "";
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Customisations are stored per mode in shell.json (experience.modes) and survive switches, restarts and factory resets of other modes. Applying a layout preset rewrites the bars, so it is off unless you opt in.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }

                SectionCard {
                    id: deckCard

                    visible: root.field("desktopWidgets") === "instruments"
                    title: qsTr("Desktop widgets")

                    DeckManager {
                        Layout.fillWidth: true
                        mode: root.selectedMode
                        modeLabel: root.selProfile.label
                        session: root.session
                        onFailed: message => root.actionMessage = message
                    }
                }

                SectionCard {
                    title: qsTr("Behaviour")

                    SwitchRow {
                        label: qsTr("Switch to Gaming automatically for fullscreen games")
                        checked: Experience.autoEnabled
                        onToggled: checked => Experience.setAuto(checked)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Off by default and local-only: it reads the focused window's app id and fullscreen state, nothing else. An automatic switch can be undone with “Revert to previous mode”, and your explicit choice is never overridden.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: Experience.autoSwitched
                        text: qsTr("The current mode was switched automatically.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.cue
                        wrapMode: Text.WordWrap
                    }

                    SwitchRow {
                        label: qsTr("Toast when the mode changes")
                        checked: Config.experience.toasts
                        onToggled: checked => {
                            Config.experience.toasts = checked;
                            Config.save();
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: Experience.lastError.length > 0
                        text: Experience.lastError
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.alert
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Active mode state: %1").arg(Experience.statePath)
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}
