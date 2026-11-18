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
// a window the user manages: no keyboard focus, no exclusive zone of its
// own (it reserves nothing, but it respects the bars' zones, so a bar on
// its corner never covers it), no taskbar entry, and an empty input region
// unless a click action is set (then only the nest art itself takes
// clicks).
//
// All decisions are made by habitat.js (pure, tested under node); this file
// binds them to live shell state:
// - level: the user's per-mode choice (hidden / dim / normal / rich), never
//   louder than allowed; quiet hours step it down one notch.
// - state: resting / working / building / sleeping / summoned / hidden,
//   derived from the companion store and the assistant bridge only.
// - lights: lit only by real signals (assistant link, a run in flight, an
//   approval waiting, the active mode). They never show content. The link
//   light is off until the first status probe and while the assistant is
//   switched off; a slow (60 s) probe keeps it current, only while the
//   lights are drawn.
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
    // Bound by Javi Radio (shell#639) through CompanionHost.habitat.
    property bool radioBusy: false

    // The click action the user chose ("radio", "workbench", "settings").
    signal activated(string action)

    // The one monitor the nest lives on (habitat.js resolveScreen).
    readonly property string screenName: Habitat.resolveScreen(root.settings.monitor, CompanionStore.screenName, Quickshell.screens.map(s => s.name))

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
    readonly property string link: Habitat.linkState({
        "ok": root.bridge.assistantEnabled,
        "message": root.bridge.statusMessage
    })
    readonly property bool ledsShown: root.wanted && Habitat.ledsShown(root.settings, root.level, CompanionStore.nestStage)
    readonly property var lights: Habitat.lights({
        "settings": root.settings,
        "mode": Experience.mode,
        "level": root.level,
        "connected": root.link === "ok",
        "running": root.bridge.busy,
        "awaitingApproval": root.awaiting,
        "failed": root.link === "failed",
        "radioBusy": root.radioBusy,
        "reducedMotion": CompanionStore.reducedMotion,
        "sleeping": root.presentation === "sleeping"
    })
    readonly property bool anyBlink: Habitat.LIGHT_IDS.some(id => root.lights[id].blink)
    property bool blinkOn: true

    // Slow clock for the quiet-hours window and the link light; only while
    // a surface exists. Fires on start so a nest that appears after a long
    // hidden spell never shows a stale quiet-hours level or link state.
    Timer {
        interval: 60000
        running: root.wanted
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.minute = new Date().getHours() * 60 + new Date().getMinutes();
            // One cheap `horneroctl assistant status` probe (no-op while a
            // probe is already running), only while the lights are drawn.
            if (root.ledsShown)
                root.bridge.refreshStatus();
        }
    }

    // The only animation: a pending approval pulses (at most 1.4 Hz), and
    // only while one is pending, motion is allowed and the LEDs are drawn.
    Timer {
        interval: 700
        running: root.ledsShown && root.anyBlink
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

            // The bars' reserved edges on this screen (the same values the
            // drawers publish as exclusive zones).
            readonly property var barSet: Visibilities.bars.get(win.modelData) ?? null
            readonly property var insets: ({
                    "left": win.barSet?.reservedLeft ?? 0,
                    "right": win.barSet?.reservedRight ?? 0,
                    "top": win.barSet?.reservedTop ?? 0,
                    "bottom": win.barSet?.reservedBottom ?? 0
                })
            readonly property var place: Habitat.layout(root.settings, win.modelData.width, win.modelData.height, win.insets)
            readonly property bool clickable: root.settings.clickAction !== "none"

            screen: win.modelData
            visible: win.modelData.name === root.screenName
            color: "transparent"
            WlrLayershell.namespace: "hornero-nest"
            WlrLayershell.layer: WlrLayer.Bottom
            // Normal with a zero zone: reserve nothing, but stay out of the
            // bars' zones (a right or bottom bar never covers the nest).
            WlrLayershell.exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Anchored on the chosen corner; the compositor measures the
            // margins from the usable area's edges.
            anchors.left: win.place.left
            anchors.right: !win.place.left
            anchors.top: win.place.top
            anchors.bottom: !win.place.top
            margins.left: win.place.marginX
            margins.right: win.place.marginX
            margins.top: win.place.marginY
            margins.bottom: win.place.marginY
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
                Accessible.name: JaviVoice.line("nest.accessible", [JaviVoice.line("nest." + root.presentation)])

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
                    radius: 2 // fixed: LED glow dot in the nest model, scaled with the art, not a theme corner
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
