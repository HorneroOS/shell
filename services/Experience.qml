pragma Singleton

import "experience.js" as Model
import qs.services
import qs.config
import qs.utils
import Hornero
import Quickshell
import Quickshell.Io
import Quickshell.Wayland as Wayland
import QtQuick

// Experience modes (RFC 0001 §5a, Signal Visual Language §13): focus,
// everyday (default), signal, gaming, studio. A mode is a behaviour
// profile that composes with the edition, the layout preset and the
// theme; it never replaces them.
//
// - Factory profiles, validation and state parsing: services/experience.js.
// - Per-mode customisations: shell.json `experience.modes` (Config).
// - Active mode: $XDG_STATE_HOME/hornero/experience.json, written
//   atomically here and watched, so horneroctl can read or write it while
//   the shell runs or not (contract in docs/IPC.md).
//
// Consumers read the derived properties below (motionLevel, density,
// glow, holdPopups, telemetryIntervalMs, telemetryPaused, ...) and never
// compare mode ids themselves, so a user customisation always applies.
Singleton {
    id: root

    readonly property var modeIds: Model.MODE_IDS
    readonly property var summary: Model.summary()
    readonly property string factoryLayout: Model.FACTORY_LAYOUT
    readonly property string factoryTheme: Model.FACTORY_THEME
    readonly property string statePath: Paths.experienceState

    property string mode: Model.DEFAULT_MODE
    property string previousMode: Model.DEFAULT_MODE
    property string source: "user"
    property bool autoSwitched: false
    property string changedAt: ""
    property string studioAudioRestore: ""
    property bool stateReady: false
    property string lastError: ""

    readonly property var profile: Model.resolve(mode, Config.experience.modes)
    readonly property var fields: profile.fields

    readonly property string label: profile.label
    readonly property string glyph: profile.glyph
    readonly property bool gaming: mode === "gaming"
    readonly property bool focus: mode === "focus"
    readonly property bool immersive: mode === "signal"
    readonly property bool studio: mode === "studio"

    // Motion level (§11.3). appearance.reducedMotion / the system
    // preference still force `off` inside Appearance.anim.
    readonly property string motionLevel: fields["motion"]
    // Instrumentation density (§4.3): icons | values | labels.
    readonly property string density: fields["density"]
    // Luminous accents (§9): off in day themes, high contrast and the
    // low motion levels, whatever the profile says.
    readonly property bool glow: fields["glow"] && !Signal.light && !Config.appearance.highContrast && (motionLevel === "full" || motionLevel === "standard")
    // Scope scanlines (§10): Signal mode only, never in day themes.
    readonly property bool scanlines: fields["scanlines"] && !Signal.light && !Config.appearance.highContrast

    readonly property bool fullscreenActive: Compositor.hasFullscreenOnFocusedOutput()
    // Notification policy: non-critical popups are held (filed in the
    // notification center without a popup) while this is true.
    readonly property bool holdPopups: fields["notifications.hold"] || (fields["notifications.suppressFullscreen"] && fullscreenActive)
    property int heldCount: 0

    // Shared telemetry providers (§6.5): 1 Hz everyday, 2 Hz signal,
    // paused while a fullscreen window covers the shell when the profile
    // asks for it (drawers close and refuse to open over fullscreen).
    readonly property int telemetryIntervalMs: Model.telemetryInterval(fields, Config.dashboard.resourceUpdateInterval)
    readonly property bool telemetryPaused: fields["telemetry.pauseWhenHidden"] && fullscreenActive

    // Desktop layer: none hides desktop widgets and the desktop clock,
    // user keeps the user's set, instruments adds the Signal deck.
    readonly property string desktopWidgets: fields["desktopWidgets"]
    readonly property bool desktopWidgetsVisible: desktopWidgets !== "none" && !(gaming && fullscreenActive)
    readonly property bool instruments: desktopWidgets === "instruments"

    readonly property string preferredLayout: fields["layout.preset"]
    readonly property string powerSuggestion: fields["power.suggest"]
    readonly property bool idleInhibit: fields["idle.inhibitFullscreen"] && fullscreenActive
    // Edition hooks. Missing capabilities stay off and are reported.
    readonly property bool hyprlandTuningAvailable: Compositor.supports("hyprlandTuning")
    readonly property bool hyprlandTuning: fields["hooks.hyprlandTuning"] && hyprlandTuningAvailable
    readonly property bool studioAudioWanted: fields["hooks.studioAudio"]

    // Studio audio availability (horneroctl studio mode show).
    property bool studioAudioAvailable: false
    property bool studioAudioProbed: false
    property string studioAudioMode: ""
    property string studioAudioMessage: ""

    // Automatic switching (off by default, local-only).
    readonly property bool autoEnabled: Config.experience.auto.fullscreenGaming
    readonly property string focusedAppId: Compositor.activeWindowAppId

    // Instantiates the Hyprland tuning hook (services/GameMode.qml).
    readonly property bool _gameModeHook: GameMode.enabled

    signal modeApplied(string mode, string source)

    function isMode(id: string): bool {
        return Model.isMode(id);
    }

    function profileFor(id: string): var {
        return Model.resolve(id, Config.experience.modes);
    }

    function factoryFor(id: string): var {
        return Model.isMode(id) ? Model.FACTORY[id] : null;
    }

    function fieldSpec(key: string): var {
        return Model.FIELDS[key] ?? null;
    }

    function isLocked(id: string, key: string): bool {
        return Model.isLocked(id, key);
    }

    // Bar density in the bar's own vocabulary (glyphs | values).
    function barDensity(specDensity: string): string {
        return Model.barDensity(root.fields, specDensity);
    }

    function _state(): var {
        return {
            schemaVersion: Model.SCHEMA_VERSION,
            mode: root.mode,
            previous: root.previousMode,
            source: root.source,
            auto: root.autoSwitched,
            changedAt: root.changedAt,
            studioAudioRestore: root.studioAudioRestore
        };
    }

    function _adopt(st: var): void {
        const changed = st.mode !== root.mode;
        const leaving = root.mode;
        root.previousMode = st.previous;
        root.source = st.source;
        root.autoSwitched = st.auto;
        root.changedAt = st.changedAt;
        root.studioAudioRestore = st.studioAudioRestore;
        root.mode = st.mode;
        if (changed && root.stateReady)
            root._onModeChanged(leaving, st.source);
    }

    // Explicit switch. Returns "ok: <mode>" or "error: <reason>".
    function set(id: string, src: string): string {
        const res = Model.transition(root._state(), id, src || "user", new Date().toISOString());
        if (!res.ok) {
            root.lastError = res.error;
            return `error: ${res.error}`;
        }
        if (!res.changed && root.autoSwitched === res.state.auto && root.source === res.state.source)
            return `ok: ${id}`;
        root._adopt(res.state);
        root._persist();
        return `ok: ${id}`;
    }

    // Toggles a mode: entering it, or returning to the previous one.
    function toggle(id: string): string {
        if (root.mode === id)
            return root.set(root.previousMode !== id ? root.previousMode : Model.DEFAULT_MODE, "user");
        return root.set(id, "user");
    }

    // One-action revert to the mode active before the last switch.
    function revert(): string {
        return root.set(root.previousMode, "user");
    }

    // Factory reset (RFC §5a): everyday + Cockpit + Signal Night. Per-mode
    // customisations are kept; clear them with resetCustomisations().
    function reset(): string {
        const res = root.set(Model.DEFAULT_MODE, "reset");
        if (res.startsWith("error"))
            return res;
        layoutProc.exec(["horneroctl", "shell", "preset", "apply", Model.FACTORY_LAYOUT, "--yes"]);
        ThemePipeline.applyTheme(Model.FACTORY_THEME, "");
        return `ok: ${Model.DEFAULT_MODE} + ${Model.FACTORY_LAYOUT} + ${Model.FACTORY_THEME}`;
    }

    function customise(id: string, key: string, value: var): string {
        const res = Model.setOverride(Config.experience.modes, id, key, value);
        if (!res.ok)
            return `error: ${res.error}`;
        Config.experience.modes = res.overrides;
        Config.save();
        return "ok";
    }

    function resetCustomisations(id: string): string {
        if (!Model.isMode(id))
            return `error: unknown mode: ${id}`;
        Config.experience.modes = Model.clearOverrides(Config.experience.modes, id);
        Config.save();
        return "ok";
    }

    function setAuto(enabled: bool): void {
        Config.experience.auto.fullscreenGaming = enabled;
        Config.save();
        if (!enabled && root.autoSwitched)
            root.revert();
    }

    // Applies the mode's preferred layout preset. Always an explicit act
    // (or the per-mode layout.apply opt-in): presets rewrite the bars.
    function applyPreferredLayout(): void {
        if (root.preferredLayout.length > 0)
            layoutProc.exec(["horneroctl", "shell", "preset", "apply", root.preferredLayout, "--yes"]);
    }

    function probeStudioAudio(): void {
        if (!studioShowProc.running)
            studioShowProc.running = true;
    }

    function noteHeld(): void {
        root.heldCount++;
    }

    function _onModeChanged(leaving: string, src: string): void {
        if (Config.experience.toasts)
            Toaster.toast(qsTr("%1 mode").arg(root.label), src === "auto" ? qsTr("Switched automatically. Run \"Revert mode\" or open Settings › Experience to go back.") : root.profile.description, root.glyph);
        if (root.fields["layout.apply"])
            root.applyPreferredLayout();
        root._syncStudioAudio(leaving);
        root.modeApplied(root.mode, src);
    }

    // Studio low-latency hint through horneroctl (records intent; PipeWire
    // drop-ins are owned by HorneroOS/config). Restores what it changed.
    function _syncStudioAudio(leaving: string): void {
        if (root.studioAudioWanted && root.studioAudioRestore === "") {
            studioSetProc.restoreAfter = true;
            studioSetProc.exec(["horneroctl", "--json", "studio", "mode", "audio", "low-latency", "--yes"]);
        } else if (!root.studioAudioWanted && root.studioAudioRestore !== "") {
            const target = root.studioAudioRestore;
            studioSetProc.restoreAfter = false;
            studioSetProc.exec(["horneroctl", "--json", "studio", "mode", "audio", target, "--yes"]);
        }
    }

    function _persist(): void {
        writeProc.payload = Model.serializeState(root._state());
        if (!writeProc.running)
            writeProc.running = true;
        else
            writeProc.pending = true;
    }

    function _autoEvaluate(): void {
        if (!root.stateReady)
            return;
        const action = Model.autoDecision(root._state(), {
            enabled: root.autoEnabled,
            fullscreen: root.fullscreenActive,
            appId: root.focusedAppId,
            patterns: Array.from(Config.experience.auto.gamePatterns ?? [])
        });
        if (action === "enter")
            root.set("gaming", "auto");
        else if (action === "leave")
            root.set(root.previousMode, "auto");
    }

    function _toastHeld(): void {
        if (root.heldCount > 0 && Config.experience.toasts)
            Toaster.toast(qsTr("Notifications held"), qsTr("%n notification(s) arrived while held. They are in the notification center.", "", root.heldCount), "bell");
        root.heldCount = 0;
    }

    function _status(): var {
        return {
            schemaVersion: Model.SCHEMA_VERSION,
            mode: root.mode,
            previous: root.previousMode,
            source: root.source,
            auto: root.autoSwitched,
            autoEnabled: root.autoEnabled,
            changedAt: root.changedAt,
            statePath: root.statePath,
            fields: root.fields,
            customised: root.profile.customised,
            effective: {
                motion: Appearance.anim.level,
                glow: root.glow,
                scanlines: root.scanlines,
                holdPopups: root.holdPopups,
                heldCount: root.heldCount,
                telemetryIntervalMs: root.telemetryIntervalMs,
                telemetryPaused: root.telemetryPaused,
                desktopWidgetsVisible: root.desktopWidgetsVisible,
                hyprlandTuning: GameMode.enabled,
                idleInhibit: root.idleInhibit,
                studioAudioRestore: root.studioAudioRestore
            },
            unavailable: [
                ...(!root.hyprlandTuningAvailable && root.fields["hooks.hyprlandTuning"] ? ["hooks.hyprlandTuning"] : []),
                ...(root.studioAudioProbed && !root.studioAudioAvailable && root.studioAudioWanted ? ["hooks.studioAudio"] : [])
            ]
        };
    }

    onHoldPopupsChanged: {
        if (!holdPopups)
            _toastHeld();
    }
    onFullscreenActiveChanged: _autoEvaluate()
    onFocusedAppIdChanged: _autoEvaluate()
    onAutoEnabledChanged: _autoEvaluate()

    Component.onCompleted: Appearance.anim.level = Qt.binding(() => root.motionLevel)

    // Idle inhibition for the fullscreen-gaming hint; independent of the
    // user's manual idle inhibitor toggle.
    // Qualified: services/IdleInhibitor.qml shadows the Wayland type.
    Wayland.IdleInhibitor {
        enabled: root.idleInhibit
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const st = Model.parseState(text());
            if (!st) {
                console.warn(`[experience] ignoring invalid ${root.statePath}; keeping ${root.mode}`);
                root.stateReady = true;
                return;
            }
            const first = !root.stateReady;
            root._adopt(st);
            root.stateReady = true;
            if (first) {
                root._syncStudioAudio("");
                root._autoEvaluate();
            }
        }
        onLoadFailed: err => {
            if (root.stateReady)
                return;
            root.stateReady = true;
            if (err !== FileViewError.FileNotFound) {
                console.warn(`[experience] could not read ${root.statePath}: ${FileViewError.toString(err)}`);
                return;
            }
            // First run on this account: fold a Gaming Focus toggle that
            // survived a hot reload into the gaming mode, then publish the
            // state so horneroctl and the shell agree from the start.
            const migrated = Model.migrateLegacy({
                gameModeEnabled: GameMode.legacyEnabled,
                hasState: false
            });
            if (migrated.state)
                root._adopt(migrated.state);
            root._persist();
        }
    }

    Process {
        id: writeProc

        property string payload: ""
        property bool pending: false

        command: ["sh", "-c", 'set -e; mkdir -p "$(dirname "$HORNERO_EXPERIENCE_STATE")"; tmp="$HORNERO_EXPERIENCE_STATE.tmp.$$"; printf "%s" "$HORNERO_EXPERIENCE_PAYLOAD" > "$tmp"; mv -f "$tmp" "$HORNERO_EXPERIENCE_STATE"']
        environment: ({
                "HORNERO_EXPERIENCE_STATE": root.statePath,
                "HORNERO_EXPERIENCE_PAYLOAD": writeProc.payload
            })
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.lastError = `could not write ${root.statePath} (exit ${exitCode})`;
                console.warn(`[experience] ${root.lastError}`);
            }
            // A watcher armed on a missing file never fires; re-arm it.
            stateFile.reload();
            if (writeProc.pending) {
                writeProc.pending = false;
                writeProc.payload = Model.serializeState(root._state());
                writeProc.running = true;
            }
        }
    }

    Process {
        id: layoutProc

        onExited: exitCode => {
            if (exitCode !== 0)
                Toaster.toast(qsTr("Layout not applied"), qsTr("horneroctl shell preset apply failed (exit %1).").arg(exitCode), "layout-dashboard", Toast.Warning);
        }
    }

    Process {
        id: studioShowProc

        command: ["horneroctl", "--json", "studio", "mode", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let res = null;
                try {
                    res = JSON.parse(text);
                } catch (e) {
                    res = null;
                }
                root.studioAudioProbed = true;
                root.studioAudioAvailable = !!res && res.ok === true;
                root.studioAudioMode = res?.data?.audio_mode ?? "";
                root.studioAudioMessage = root.studioAudioAvailable ? "" : (res?.message ?? qsTr("horneroctl studio mode is not available on this system."));
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && !root.studioAudioAvailable) {
                root.studioAudioProbed = true;
                root.studioAudioAvailable = false;
                if (root.studioAudioMessage.length === 0)
                    root.studioAudioMessage = qsTr("horneroctl studio mode is not available on this system.");
            }
        }
    }

    Process {
        id: studioSetProc

        // true: this call applies low-latency and records what to restore.
        property bool restoreAfter: false

        stdout: StdioCollector {
            onStreamFinished: {
                let res = null;
                try {
                    res = JSON.parse(text);
                } catch (e) {
                    res = null;
                }
                if (!res || res.ok !== true) {
                    root.studioAudioAvailable = false;
                    root.studioAudioProbed = true;
                    root.studioAudioMessage = res?.message ?? qsTr("horneroctl studio mode is not available on this system.");
                    return;
                }
                root.studioAudioAvailable = true;
                root.studioAudioProbed = true;
                root.studioAudioMode = res.data?.audio_mode ?? "";
                const prev = res.data?.previous_audio_mode ?? "";
                // "already low-latency": the user chose it; nothing to restore.
                root.studioAudioRestore = studioSetProc.restoreAfter && prev.length > 0 && prev !== "low-latency" && !String(res.message).includes("already") ? prev : "";
                root._persist();
            }
        }
    }

    IpcHandler {
        target: "experience"

        // Active mode id.
        function get(): string {
            return root.mode;
        }

        function set(mode: string): string {
            return root.set(mode, "cli");
        }

        function toggle(mode: string): string {
            return root.toggle(mode);
        }

        function revert(): string {
            return root.revert();
        }

        function reset(): string {
            return root.reset();
        }

        // JSON array: [{id, label, description, glyph, active, customised}].
        function list(): string {
            return JSON.stringify(root.modeIds.map(id => {
                const p = root.profileFor(id);
                return {
                    id: id,
                    label: p.label,
                    description: p.description,
                    glyph: p.glyph,
                    active: id === root.mode,
                    customised: p.customised
                };
            }));
        }

        // JSON: the resolved profile of one mode (factory + customisations).
        function profile(mode: string): string {
            if (!root.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return JSON.stringify(root.profileFor(mode));
        }

        // JSON: active mode, state file fields and effective behaviour.
        function status(): string {
            return JSON.stringify(root._status());
        }

        // value is JSON (true, 2, "minimal-top"); null clears the override.
        function customise(mode: string, key: string, value: string): string {
            let parsed;
            try {
                parsed = JSON.parse(value);
            } catch (e) {
                return `error: value must be JSON, got ${value}`;
            }
            return root.customise(mode, key, parsed);
        }

        function resetCustomisations(mode: string): string {
            return root.resetCustomisations(mode);
        }

        function setAuto(enabled: bool): string {
            root.setAuto(enabled);
            return enabled ? "ok: auto on" : "ok: auto off";
        }
    }
}
