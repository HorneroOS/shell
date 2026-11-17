pragma Singleton

import "experience.js" as Model
import "deck.js" as Deck
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
    // Glow budget (§9): at most three glowing items on a screen, shared by
    // every native instrument and every PluginKit trace. Extension traces
    // leave `reserve` slots to the shell's own (on-air bar, dashboard
    // scopes), so opening the dashboard never has to take a lease away.
    readonly property int glowLimit: Math.max(1, Math.min(6, Math.round(Config.appearance.glow.limit)))
    property var _glowHolders: []
    readonly property int glowHeld: root._glowHolders.length

    function acquireGlow(owner: var, reserve: int): bool {
        if (root._glowHolders.indexOf(owner) >= 0)
            return true;
        if (root._glowHolders.length >= root.glowLimit - Math.max(0, reserve))
            return false;
        root._glowHolders = root._glowHolders.concat([owner]);
        return true;
    }

    function releaseGlow(owner: var): void {
        const i = root._glowHolders.indexOf(owner);
        if (i < 0)
            return;
        const next = root._glowHolders.slice();
        next.splice(i, 1);
        root._glowHolders = next;
    }

    // Scope scanlines (§10): Signal mode only, never in day themes.
    readonly property bool scanlines: fields["scanlines"] && !Signal.light && !Config.appearance.highContrast

    readonly property bool fullscreenActive: Compositor.hasFullscreenOnFocusedOutput()
    // The one definition of what the mode means under a fullscreen window
    // (services/experience.js `policy`, executed headless in tests).
    readonly property var policy: Model.policy(fields, {
        mode: mode,
        fullscreen: fullscreenActive
    })
    // Notification policy: non-critical popups are held (filed in the
    // notification center without a popup) while this is true.
    readonly property bool holdPopups: policy.holdPopups
    property int heldCount: 0

    // Shared telemetry providers (§6.5): 1 Hz everyday, 2 Hz signal,
    // paused while a fullscreen window covers the shell when the profile
    // asks for it (drawers close and refuse to open over fullscreen).
    readonly property int telemetryIntervalMs: Model.telemetryInterval(fields, Config.dashboard.resourceUpdateInterval)
    readonly property bool telemetryPaused: policy.telemetryPaused

    // Desktop layer: none hides desktop widgets and the desktop clock,
    // user keeps the user's set, instruments adds the Signal deck.
    readonly property string desktopWidgets: fields["desktopWidgets"]
    readonly property bool desktopWidgetsVisible: policy.desktopWidgetsVisible
    readonly property bool instruments: desktopWidgets === "instruments"

    readonly property string preferredLayout: fields["layout.preset"]
    readonly property string powerSuggestion: fields["power.suggest"]
    readonly property bool idleInhibit: policy.idleInhibit
    // Edition hooks. Missing capabilities stay off and are reported.
    readonly property bool hyprlandTuningAvailable: Compositor.supports("hyprlandTuning")
    readonly property bool hyprlandTuning: fields["hooks.hyprlandTuning"] && hyprlandTuningAvailable
    readonly property bool studioAudioWanted: fields["hooks.studioAudio"]

    // Studio audio availability (horneroctl studio mode show).
    property bool studioAudioAvailable: false
    property bool studioAudioProbed: false
    property string studioAudioMode: ""
    property string studioAudioMessage: ""
    // Result of `horneroctl studio audio status` (quantum, xruns, DSP load).
    property string studioAudioStatus: ""

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
        Config.experience.deck = Deck.reset(Config.experience.deck, id, "");
        Config.save();
        return "ok";
    }

    // Signal instrument deck (services/deck.js). Overrides are per mode and
    // per screen; resetDeck restores the factory composition.
    readonly property var deckHidden: Deck.hiddenFor(Config.experience.deck, root.mode)
    readonly property bool deckCustomised: Deck.isCustomised(Config.experience.deck, root.mode)

    function deckHiddenFor(id: string): var {
        return Deck.hiddenFor(Config.experience.deck, id);
    }

    function deckCustomisedFor(id: string): bool {
        return Deck.isCustomised(Config.experience.deck, id);
    }

    function deckItems(hints: var, measured: var): var {
        return Deck.fitMeasured(Deck.items(hints, Deck.prefsFor(Config.experience.deck, root.mode)), measured ?? ({}));
    }

    // The same factory/anchored/ordered items for any mode (the Control
    // Center manager previews the mode being edited, not only the active one).
    function deckItemsFor(id: string, hints: var): var {
        return Deck.items(hints, Deck.prefsFor(Config.experience.deck, id));
    }

    function deckSavedFor(id: string, screenName: string): var {
        return Deck.savedFor(Config.experience.deck, id, screenName);
    }

    function deckAnchorsFor(id: string): var {
        return Deck.anchorsFor(Config.experience.deck, id);
    }

    function deckOrderFor(id: string): var {
        return Deck.orderFor(Config.experience.deck, id);
    }

    function deckPresetNames(id: string): var {
        return Deck.presetNames(Config.experience.deck, id);
    }

    function deckStyleOf(id: string, widgetId: string): var {
        return Deck.styleOf(Config.experience.deck, id, widgetId);
    }

    function setDeckStyle(id: string, widgetId: string, key: string, value: var): string {
        return root._deckWrite(Deck.setStyle(Config.experience.deck, id, widgetId, key, value));
    }

    readonly property var deckBuiltinPresets: Deck.builtinPresets()

    function _deckWrite(res: var): string {
        if (!res.ok)
            return `error: ${res.error}`;
        Config.experience.deck = res.deck;
        Config.save();
        return "ok";
    }

    function setDeckAnchor(id: string, widgetId: string, anchor: string): string {
        return root._deckWrite(Deck.setAnchor(Config.experience.deck, id, widgetId, anchor));
    }

    function moveDeckWidget(id: string, widgetId: string, delta: int): string {
        return root._deckWrite(Deck.moveWidget(Config.experience.deck, id, widgetId, delta));
    }

    function applyDeckBuiltin(id: string, presetId: string): string {
        return root._deckWrite(Deck.applyBuiltin(Config.experience.deck, id, presetId));
    }

    function saveDeckPreset(id: string, name: string): string {
        return root._deckWrite(Deck.savePreset(Config.experience.deck, id, name));
    }

    function applyDeckPreset(id: string, name: string): string {
        return root._deckWrite(Deck.applyPreset(Config.experience.deck, id, name));
    }

    function deleteDeckPreset(id: string, name: string): string {
        return root._deckWrite(Deck.deletePreset(Config.experience.deck, id, name));
    }

    function deckCompose(input: var): var {
        return Deck.compose(input);
    }

    function deckStatus(composition: var, availability: var, hidden: var): var {
        return Deck.status(composition, availability, hidden);
    }

    readonly property var deckCatalogue: Deck.ids()

    function deckSaved(screenName: string): var {
        return Deck.savedFor(Config.experience.deck, root.mode, screenName);
    }

    function setDeckHidden(id: string, widgetId: string, hide: bool): string {
        const res = Deck.setHidden(Config.experience.deck, id, widgetId, hide);
        if (!res.ok)
            return `error: ${res.error}`;
        Config.experience.deck = res.deck;
        Config.save();
        return "ok";
    }

    // Geometry is always written for the active mode: it comes from the
    // desktop edit mode, which only edits what is on screen.
    function setDeckGeometry(screenName: string, widgetId: string, geometry: var): string {
        const res = Deck.setGeometry(Config.experience.deck, root.mode, screenName, widgetId, geometry);
        if (!res.ok)
            return `error: ${res.error}`;
        Config.experience.deck = res.deck;
        Config.save();
        return "ok";
    }

    // screenName empty resets every screen and the hidden set of `id`.
    function resetDeck(id: string, screenName: string): string {
        Config.experience.deck = Deck.reset(Config.experience.deck, id, screenName);
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
        if (!studioStatusProc.running)
            studioStatusProc.running = true;
    }

    function noteHeld(): void {
        root.heldCount++;
    }

    function _onModeChanged(leaving: string, src: string): void {
        if (Config.experience.toasts)
            Toaster.toast(qsTr("%1 mode").arg(root.label), src === "auto" ? qsTr("Switched automatically. Run \"Revert mode\" or open Settings › Experience to go back.") : root.profile.description, root.glyph);
        if (root.fields["layout.apply"])
            root.applyPreferredLayout();
        root._syncStudioAudio(src);
        root.modeApplied(root.mode, src);
    }

    // Studio low-latency profile through horneroctl: applied on a deliberate
    // switch into a mode whose hook is on, reverted when that stops being
    // true. horneroctl owns the PipeWire drop-in and never overwrites a
    // personal file; a failure is shown in the Experience pane, not hidden.
    function _syncStudioAudio(src: string): void {
        const action = Model.studioAudioAction(root.studioAudioWanted, root.studioAudioRestore !== "", src);
        if (action === "apply") {
            studioSetProc.applying = true;
            studioSetProc.exec(["horneroctl", "--json", "studio", "audio", "apply", "--yes"]);
        } else if (action === "revert") {
            studioSetProc.applying = false;
            studioSetProc.exec(["horneroctl", "--json", "studio", "audio", "revert", "--yes"]);
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
            if (first) {
                // One-shot: persisted selections of removed presets move to
                // their survivor (services/experience.js RETIRED_PRESETS).
                const mig = Model.sanitizeOverrides(Config.experience.modes);
                if (JSON.stringify(mig) !== JSON.stringify(Config.experience.modes))
                    Config.experience.modes = mig;
            }
            root._adopt(st);
            root.stateReady = true;
            if (first) {
                root._syncStudioAudio("startup");
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
        id: studioStatusProc

        command: ["horneroctl", "--json", "studio", "audio", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.studioAudioStatus = Model.parseStudioAudioStatus(text).summary
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.studioAudioStatus.length === 0)
                root.studioAudioStatus = qsTr("unavailable: horneroctl studio audio is not available (update horneroctl)");
        }
    }

    Process {
        id: studioSetProc

        // true: this call applies the profile; false: it reverts it.
        property bool applying: false

        stdout: StdioCollector {
            onStreamFinished: {
                let res = null;
                try {
                    res = JSON.parse(text);
                } catch (e) {
                    res = null;
                }
                root.studioAudioProbed = true;
                if (!res || res.ok !== true) {
                    root.studioAudioAvailable = false;
                    root.studioAudioMessage = res?.message ?? qsTr("horneroctl studio audio is not available on this system (update horneroctl).");
                    if (studioSetProc.applying)
                        Toaster.toast(qsTr("Studio audio not applied"), String(root.studioAudioMessage).split("\n")[0], "wave-square", Toast.Warning);
                    return;
                }
                root.studioAudioAvailable = true;
                root.studioAudioMessage = "";
                // "applied" is only remembered so a later revert is possible;
                // the previous mode itself is horneroctl's record.
                root.studioAudioRestore = studioSetProc.applying ? "balanced" : "";
                root._persist();
                root.probeStudioAudio();
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

        // Signal deck: JSON {mode, instruments, hidden: [id], customised}.
        function deck(mode: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return JSON.stringify({
                mode: mode,
                instruments: root.profileFor(mode).fields["desktopWidgets"] === "instruments",
                catalogue: root.deckCatalogue,
                hidden: root.deckHiddenFor(mode),
                anchors: root.deckAnchorsFor(mode),
                order: root.deckOrderFor(mode),
                customised: root.deckCustomisedFor(mode)
            });
        }

        function setDeckHidden(mode: string, widget: string, hide: bool): string {
            return root.setDeckHidden(mode, widget, hide);
        }

        // Anchor: left-top | left-bottom | right-top | right-bottom, or "" for factory.
        function setDeckAnchor(mode: string, widget: string, anchor: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.setDeckAnchor(mode, widget, anchor);
        }

        // direction: up (placed earlier) or down.
        function moveDeckWidget(mode: string, widget: string, direction: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            if (direction !== "up" && direction !== "down")
                return `error: direction must be up or down`;
            return root.moveDeckWidget(mode, widget, direction === "up" ? -1 : 1);
        }

        // JSON {builtin: [{id, label, show}], saved: [name]} for the mode.
        function deckPresets(mode: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return JSON.stringify({
                builtin: root.deckBuiltinPresets,
                saved: root.deckPresetNames(mode)
            });
        }

        // Applies a built-in preset id (all, cozy, kawaii-night, monitor, time, minimal).
        // key: opacity (0.3-1) | size (small normal large) | accent (default
        // signal cue) | density (compact cozy roomy); empty value = factory.
        function setDeckStyle(mode: string, widget: string, key: string, value: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.setDeckStyle(mode, widget, key, key === "opacity" && value !== "" ? Number(value) : value);
        }

        function applyDeckBuiltin(mode: string, preset: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.applyDeckBuiltin(mode, preset);
        }

        function saveDeckPreset(mode: string, name: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.saveDeckPreset(mode, name);
        }

        function applyDeckPreset(mode: string, name: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.applyDeckPreset(mode, name);
        }

        function deleteDeckPreset(mode: string, name: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.deleteDeckPreset(mode, name);
        }

        function resetDeck(mode: string): string {
            if (!Model.isMode(mode))
                return `error: unknown mode: ${mode}`;
            return root.resetDeck(mode, "");
        }

        function setAuto(enabled: bool): string {
            root.setAuto(enabled);
            return enabled ? "ok: auto on" : "ok: auto off";
        }
    }
}
