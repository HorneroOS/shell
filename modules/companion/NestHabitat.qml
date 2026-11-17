pragma ComponentBehavior: Bound

import "habitat.js" as Habitat
import "reactions.js" as Reactions
import qs.modules.companion
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

// The Nest as ambient desktop chrome: a small Bottom-layer surface on the
// user's chosen corner and monitor, separate from Javi's window. It is not
// a window the user manages: no keyboard focus, no exclusive zone, no
// taskbar entry, and an empty input region unless a click action is set
// (then only the nest art itself takes clicks).
//
// All decisions are made by habitat.js (pure, tested under node); this file
// binds them to live shell state:
// - level: the user's per-mode choice (hidden / dim / normal / rich), never
//   louder than allowed; quiet hours step it down one notch.
// - state: resting / working / building / sleeping / summoned / hidden,
//   derived from the companion store and the assistant bridge only.
// - lights: lit only by real signals (assistant link, a run in flight, an
//   approval waiting, the active mode). They never show content.
// Hidden (or Gaming, or no nest built yet) means no surface and no timers:
// the Variants model is empty, so nothing exists to cost anything.
//
// The art is a clearly marked placeholder (Habitat.ART); final art replaces
// the frames without touching this logic.
Scope {
    id: root

    // The assistant bridge owned by CompanionHost.
    required property var bridge
    // True while Javi Radio has a question in flight (lights the radio LED).
    property bool radioBusy: false

    // The click action the user chose ("radio", "workbench", "settings").
    signal activated(string action)

    readonly property var settings: CompanionStore.habitatSettings
    property int minute: new Date().getHours() * 60 + new Date().getMinutes()
    readonly property bool quiet: Reactions.inQuietHours(CompanionStore.reactionSettings.quietHours, root.minute)
    readonly property string level: Habitat.effectiveLevel(root.settings, Experience.mode, root.quiet)
    readonly property bool awaiting: root.bridge.pendingApproval !== null || root.bridge.pendingClarify !== null
    readonly property string presentation: Habitat.stateFor({
        "visible": CompanionStore.visible,
        "storeState": CompanionStore.state,
        "running": root.bridge.busy,
        "awaitingApproval": root.awaiting,
        "overrideAnim": CompanionStore.overrideAnim
    })
    readonly property bool wanted: Habitat.surfaceWanted({
        "enabled": CompanionStore.enabled,
        "nestEnabled": CompanionStore.nestEnabled,
        "placement": root.settings.placement,
        "level": root.level,
        "visible": CompanionStore.visible,
        "stage": CompanionStore.nestStage
    })
    readonly property var lights: Habitat.lights({
        "settings": root.settings,
        "mode": Experience.mode,
        "level": root.level,
        "connected": root.bridge.assistantEnabled && root.bridge.gatewayReachable,
        "running": root.bridge.busy,
        "awaitingApproval": root.awaiting,
        "failed": root.bridge.assistantEnabled && !root.bridge.gatewayReachable,
        "radioBusy": root.radioBusy,
        "reducedMotion": CompanionStore.reducedMotion,
        "sleeping": root.presentation === "sleeping"
    })
    readonly property bool anyBlink: Habitat.LIGHT_IDS.some(id => root.lights[id].blink)
    property bool blinkOn: true

    // Slow clock for the quiet-hours window; only while a surface exists.
    Timer {
        interval: 60000
        running: root.wanted
        repeat: true
        onTriggered: root.minute = new Date().getHours() * 60 + new Date().getMinutes()
    }

    // The only animation: a pending approval pulses (at most 1.4 Hz), and
    // only while one is pending, motion is allowed and the nest is lit.
    Timer {
        interval: 700
        running: root.wanted && root.anyBlink
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
        onRunningChanged: {
            if (!running)
                root.blinkOn = true;
        }
    }

    Variants {
        model: root.wanted ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData

            readonly property string wantedScreen: root.settings.monitor
            readonly property string targetScreen: {
                const names = Quickshell.screens.map(s => s.name);
                if (win.wantedScreen !== "" && names.indexOf(win.wantedScreen) >= 0)
                    return win.wantedScreen;
                if (CompanionStore.screenName !== "" && names.indexOf(CompanionStore.screenName) >= 0)
                    return CompanionStore.screenName;
                return Compositor.focusedOutputName || names[0];
            }
            readonly property var place: Habitat.layout(root.settings, win.modelData.width, win.modelData.height)
            readonly property bool clickable: root.settings.clickAction !== "none"

            screen: win.modelData
            visible: win.modelData.name === win.targetScreen
            color: "transparent"
            WlrLayershell.namespace: "hornero-nest"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.left: true
            margins.top: win.place.y
            margins.left: win.place.x
            implicitWidth: win.place.size
            implicitHeight: win.place.size

            // Nothing is clickable unless the user gave the nest a click
            // action; then only the art square is.
            mask: Region {
                item: win.clickable ? art : null
            }

            Item {
                id: art

                anchors.fill: parent
                // Sleeping dims the whole nest a little; the lights are
                // dimmed separately by habitat.js.
                opacity: root.presentation === "sleeping" ? 0.8 : 1.0

                Accessible.role: win.clickable ? Accessible.Button : Accessible.Graphic
                Accessible.name: qsTr("Javi's nest, %1").arg(JaviVoice.line("nest." + root.presentation))

                Image {
                    anchors.fill: parent
                    sourceSize: Qt.size(Math.min(512, win.place.size * 2), Math.min(512, win.place.size * 2))
                    source: Companion.nestSource(["none", "twigs", "cup", "dome", "home"][CompanionStore.nestStage] ?? "none")
                    fillMode: Image.PreserveAspectFit
                    cache: true
                    asynchronous: true
                }

                // CRT phosphor: lit only while the assistant is working,
                // and never at the dim level.
                Rectangle {
                    readonly property var rect: Companion.nestScreen
                    readonly property real k: win.place.size / 512

                    visible: root.settings.phosphor && root.presentation === "working" && root.level !== "dim" && root.settings.lighting !== "off" && CompanionStore.nestStage >= 4
                    x: rect[0] * k
                    y: rect[1] * k
                    width: (rect[2] - rect[0]) * k
                    height: (rect[3] - rect[1]) * k
                    radius: 2
                    color: Signal.palette.phosphor
                    opacity: 0.35 * root.settings.intensity
                }

                // Indicator lights at the sockets painted into the art.
                // Only the finished home carries electronics.
                Repeater {
                    model: CompanionStore.nestStage >= 4 ? Habitat.LIGHT_IDS : []

                    Rectangle {
                        id: led

                        required property string modelData
                        readonly property var info: root.lights[led.modelData]
                        readonly property var socket: Companion.nestLights[led.modelData] ? Habitat.socket(Companion.nestLights[led.modelData], win.place.size) : null

                        visible: led.info.on && led.socket !== null
                        x: led.socket ? led.socket.x - led.socket.r : 0
                        y: led.socket ? led.socket.y - led.socket.r : 0
                        width: led.socket ? led.socket.r * 2 : 0
                        height: width
                        radius: width / 2
                        color: Signal.palette[led.info.role]
                        opacity: led.info.blink && !root.blinkOn ? led.info.alpha * 0.25 : led.info.alpha

                        Accessible.role: Accessible.Indicator
                        Accessible.name: JaviVoice.line("nest.light." + led.modelData)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: win.clickable
                    cursorShape: win.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.activated(root.settings.clickAction)
                }
            }
        }
    }
}
