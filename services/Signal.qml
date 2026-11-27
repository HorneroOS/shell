pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick
import "chromatic.js" as Chromatic

// Hornero Signal colour roles (RFC 0001 §3.1/§3.2).
//
// `Signal.palette.<role>` is the only colour API for shell surfaces. The
// three built-in themes are complete role tables below, so the shell is
// coherent before any live scheme arrives. Any other theme comes from the
// live scheme contract (schema v2):
//   ${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json
//   {"schemaVersion": 2, "id", "mode", "palette": {role: "#RRGGBB"},
//    "terminal": [16 colours]}
// written atomically by `horneroctl appearance theme apply <id>` and by
// this singleton for built-ins. Wallpaper changes never recolour the UI.
Singleton {
    id: root

    readonly property string defaultThemeId: "hornero-signal-night"
    readonly property string contrastThemeId: "hornero-signal-contrast"
    readonly property string schemePath: Paths.signalScheme

    // Exactly the RFC §3.1 role set (required); term0..term15 are carried
    // separately. `optionalRoles` may be omitted by a theme and fall back.
    readonly property var roles: ["ground", "sunken", "base", "panel", "raised", "lifted", "ink", "inkMuted", "inkFaint", "rule", "ruleStrong", "focus", "signal", "onSignal", "signalWell", "onSignalWell", "cue", "onCue", "cueWell", "onCueWell", "phosphor", "onPhosphor", "phosphorWell", "onPhosphorWell", "alert", "onAlert", "alertWell", "onAlertWell", "inverse", "onInverse", "inverseSignal", "scrim", "shadow"]
    readonly property var optionalRoles: ({
            "glow": "signal"
        })

    // Applied theme identity. Clean installs show Signal Night;
    // `themeStateReady` keeps that provisional value from being presented
    // as current before the live scheme has been read.
    property string themeId: defaultThemeId
    property string themeMode: "dark"
    property bool themeStateReady: false
    property string _pendingPersistId: ""

    // Hornero Chromatic (RFC 0002). Optional blocks of the live scheme;
    // `chromatic` is null for curated themes. `minSurfaceAlpha` and
    // `clearInk` are consumed by layer()/surface() and ClearInk.
    property var chromatic: null
    property var minSurfaceAlpha: ({})
    property var clearInk: null
    // "smooth" interpolates palette changes in OKLab (<= 12 steps over
    // <= 240 ms); "instant" swaps. Bound to appearance.chromatic.transition.
    property string transitionMode: Config.appearance.chromatic.transition
    // True while a candidate palette is shown in memory only (see
    // beginPreview); nothing is persisted until horneroctl applies it.
    readonly property bool previewing: _snapshot !== null
    property var _snapshot: null
    // Number of palette steps applied by the last transition (test hook).
    property int transitionSteps: 0
    readonly property bool transitionActive: _tween.active
    // Increments once per settled palette change (after the last tween
    // step, never per step) and on the High Contrast switch; PluginKit
    // exposes it as Theme.revision so canvases know when to repaint.
    property int paletteRevision: 0

    signal builtInThemePersisted(string id, bool ok, string error)

    // High contrast is a shell-wide accessibility override: it swaps in
    // the contrast table without changing the persisted theme identity.
    // Glow alpha multiplier (user setting `appearance.glow.intensity`),
    // clamped to 0..1.5 so a hand-edited value cannot exceed the visual
    // language limits. Whether a glow exists at all is Experience.glow.
    readonly property real glowIntensity: Math.max(0, Math.min(1.5, Config.appearance.glow.intensity))
    readonly property bool light: Config.appearance.highContrast ? false : themeMode === "light"
    readonly property SignalPalette palette: Config.appearance.highContrast ? contrastPalette : current
    readonly property SignalPalette current: SignalPalette {}
    readonly property SignalPalette contrastPalette: SignalPalette {}
    readonly property LayeredPalette tPalette: LayeredPalette {}
    readonly property Transparency transparency: Transparency {}

    readonly property var builtInThemes: ({
            "hornero-signal-night": {
                "id": "hornero-signal-night",
                "name": "Hornero Signal Night",
                "mode": "dark",
                "palette": {
                    "ground": "#0C1016",
                    "sunken": "#10151C",
                    "base": "#141B24",
                    "panel": "#1B2430",
                    "raised": "#24303D",
                    "lifted": "#2C3947",
                    "ink": "#E6EBF1",
                    "inkMuted": "#A9B7C6",
                    "inkFaint": "#8999AB",
                    "rule": "#2D3B4B",
                    "ruleStrong": "#8393A6",
                    "focus": "#8BCEF0",
                    "signal": "#F2AC52",
                    "glow": "#FFC06B",
                    "onSignal": "#1E1304",
                    "signalWell": "#3D2B12",
                    "onSignalWell": "#FFE0B0",
                    "cue": "#8BCEF0",
                    "onCue": "#071A26",
                    "cueWell": "#163345",
                    "onCueWell": "#D6EFFC",
                    "phosphor": "#8DDBAF",
                    "onPhosphor": "#071D12",
                    "phosphorWell": "#153425",
                    "onPhosphorWell": "#D1F5E0",
                    "alert": "#FF8494",
                    "onAlert": "#24070C",
                    "alertWell": "#421922",
                    "onAlertWell": "#FFD6DC",
                    "inverse": "#E6EBF1",
                    "onInverse": "#1B2430",
                    "inverseSignal": "#864700",
                    "scrim": "#000000",
                    "shadow": "#000000"
                },
                "terminal": ["#24303D", "#FF8494", "#8DDBAF", "#F2AC52", "#8BCEF0", "#C9A5F5", "#76D8CE", "#C5D0DC", "#8393A6", "#FFA6B2", "#B2EBC9", "#FFC87D", "#B2E0F8", "#DEC4FA", "#A3EAE2", "#E6EBF1"]
            },
            "hornero-signal-day": {
                "id": "hornero-signal-day",
                "name": "Hornero Signal Day",
                "mode": "light",
                "palette": {
                    "ground": "#E8EDF4",
                    "sunken": "#E0E6EF",
                    "base": "#EEF2F7",
                    "panel": "#F5F8FC",
                    "raised": "#FCFCFE",
                    "lifted": "#FFFFFF",
                    "ink": "#283344",
                    "inkMuted": "#505E70",
                    "inkFaint": "#606D80",
                    "rule": "#D2DAE6",
                    "ruleStrong": "#7A8798",
                    "focus": "#145D86",
                    "signal": "#864700",
                    "glow": "#864700",
                    "onSignal": "#FFFFFF",
                    "signalWell": "#FCE9C8",
                    "onSignalWell": "#432300",
                    "cue": "#145D86",
                    "onCue": "#FFFFFF",
                    "cueWell": "#D8EEF9",
                    "onCueWell": "#0B334B",
                    "phosphor": "#1E6448",
                    "onPhosphor": "#FFFFFF",
                    "phosphorWell": "#D6F4E8",
                    "onPhosphorWell": "#0E3425",
                    "alert": "#9C293E",
                    "onAlert": "#FFFFFF",
                    "alertWell": "#FADDE4",
                    "onAlertWell": "#4E111E",
                    "inverse": "#283344",
                    "onInverse": "#F5F8FC",
                    "inverseSignal": "#F2AC52",
                    "scrim": "#000000",
                    "shadow": "#000000"
                },
                "terminal": ["#283344", "#9C293E", "#1E6448", "#864700", "#145D86", "#6A3FA0", "#11666E", "#505E70", "#606D80", "#C03953", "#237C58", "#A35800", "#1A76A8", "#8450C8", "#14808A", "#384457"]
            },
            "hornero-signal-contrast": {
                "id": "hornero-signal-contrast",
                "name": "Hornero Signal High Contrast",
                "mode": "dark",
                "palette": {
                    "ground": "#000000",
                    "sunken": "#050607",
                    "base": "#0A0C0F",
                    "panel": "#101317",
                    "raised": "#181C21",
                    "lifted": "#22272E",
                    "ink": "#FFFFFF",
                    "inkMuted": "#E2E4E6",
                    "inkFaint": "#A9AEB4",
                    "rule": "#8A939C",
                    "ruleStrong": "#FFFFFF",
                    "focus": "#8FD3FF",
                    "signal": "#FFC247",
                    "glow": "#FFC247",
                    "onSignal": "#000000",
                    "signalWell": "#3D2C00",
                    "onSignalWell": "#FFE3A6",
                    "cue": "#8FD3FF",
                    "onCue": "#000000",
                    "cueWell": "#0E3346",
                    "onCueWell": "#DDF2FF",
                    "phosphor": "#9BF0AE",
                    "onPhosphor": "#000000",
                    "phosphorWell": "#0E3A1C",
                    "onPhosphorWell": "#DBFBE2",
                    "alert": "#FF8A73",
                    "onAlert": "#000000",
                    "alertWell": "#4A140B",
                    "onAlertWell": "#FFE0D9",
                    "inverse": "#FFFFFF",
                    "onInverse": "#000000",
                    "inverseSignal": "#8A5200",
                    "scrim": "#000000",
                    "shadow": "#000000"
                },
                "terminal": ["#000000", "#FF8A73", "#9BF0AE", "#FFC247", "#8FD3FF", "#E0B8FF", "#8FF0E4", "#FFFFFF", "#A9AEB4", "#FFA898", "#C2F7CE", "#FFD685", "#BDE6FF", "#EED6FF", "#BDF7F0", "#FFFFFF"]
            }
        })

    function isBuiltInTheme(id: string): bool {
        return builtInThemes.hasOwnProperty(id);
    }

    // True when `palette` carries every RFC §3.1 role as a hex colour.
    function isCompletePalette(palette: var): bool {
        if (!palette || typeof palette !== "object")
            return false;
        for (const role of roles) {
            if (!/^#[0-9A-Fa-f]{6}$/.test(String(palette[role] ?? "")))
                return false;
        }
        return true;
    }

    function _fill(target: var, scheme: var): void {
        const palette = scheme.palette ?? {};
        for (const role of roles) {
            if (palette[role])
                target[role] = palette[role];
        }
        for (const [role, fallback] of Object.entries(optionalRoles))
            target[role] = palette[role] || palette[fallback];
        const terminal = Array.isArray(scheme.terminal) ? scheme.terminal : [];
        for (let i = 0; i < 16 && i < terminal.length; i++)
            target[`term${i}`] = terminal[i];
    }

    // Apply a schema-v2 scheme object to the live palette. Returns false
    // (and leaves the palette untouched) for an incomplete scheme.
    function applyScheme(scheme: var): bool {
        return _adopt(scheme, false);
    }

    function _adopt(scheme: var, animate: bool): bool {
        if (!scheme || !isCompletePalette(scheme.palette)) {
            console.warn("Signal: ignoring scheme without a complete schema-v2 palette");
            return false;
        }
        // Mode first: the accent override depends on it.
        _baseScheme = scheme;
        themeMode = scheme.mode === "light" ? "light" : "dark";
        _paint(scheme, animate === true && themeStateReady);
        themeId = scheme.id || "";
        _chromaticSource = scheme.chromatic ?? null;
        chromatic = Chromatic.status(scheme);
        minSurfaceAlpha = Chromatic.cleanMinSurfaceAlpha(scheme.minSurfaceAlpha);
        clearInk = Chromatic.cleanClearInk(scheme.clearInk);
        themeStateReady = true;
        return true;
    }

    // Transitions never run for reduced motion, gaming mode, high contrast
    // or `transition: "instant"`.
    readonly property bool transitionAllowed: transitionMode !== "instant" && !Appearance.anim.reduced && !GameMode.enabled && !Config.appearance.highContrast

    function _currentFlat(): var {
        const flat = {};
        for (const role of roles)
            flat[role] = String(current[role]);
        flat.glow = String(current.glow);
        for (let i = 0; i < 16; i++)
            flat[`term${i}`] = String(current[`term${i}`]);
        return flat;
    }

    function _assign(flat: var): void {
        for (const key of Object.keys(flat))
            current[key] = flat[key];
    }

    // Paint `scheme` into the live palette: instantly, or through the
    // OKLab tween when `animate` and allowed.
    // The user's accent for the current colour mode and experience mode
    // ("" = the theme's own). Laid over every palette in _paint.
    readonly property string accentOverride: Chromatic.resolveAccent(Config.appearance.accent, Experience.mode, themeMode)
    property var _baseScheme: null

    onAccentOverrideChanged: {
        if (_baseScheme && themeStateReady)
            _paint(_baseScheme, true);
    }

    function _paint(scheme: var, animate: bool): void {
        _baseScheme = scheme;
        const target = Chromatic.withAccent(Chromatic.flatten(scheme), accentOverride);
        const steps = (animate && transitionAllowed) ? Chromatic.stepsFor(240) : 0;
        _tween.stop();
        const from = _currentFlat();
        let differs = false;
        for (const key of Object.keys(target)) {
            if (String(from[key]).toLowerCase() !== target[key].toLowerCase()) {
                differs = true;
                break;
            }
        }
        if (!differs)
            return;
        if (steps === 0) {
            transitionSteps = 0;
            _assign(target);
            paletteRevision++;
            return;
        }
        _tween.start(from, target, steps);
    }

    // Candidate palette shown in memory only. Validates completeness and
    // returns false (nothing changes) for an incomplete scheme. The first
    // call snapshots the live palette so cancelPreview() can restore it;
    // nothing is written anywhere.
    function beginPreview(scheme: var): bool {
        if (!scheme || !isCompletePalette(scheme.palette)) {
            console.warn("Signal: preview refused: incomplete schema-v2 palette");
            return false;
        }
        if (_snapshot === null) {
            _snapshot = _captureSnapshot();
            _snapshotReady = themeStateReady;
        }
        _adopt(scheme, true);
        return true;
    }

    // Ends the preview and keeps the candidate palette until the applied
    // scheme arrives through the live file (same fingerprint: no visible
    // change).
    function commitPreview(): void {
        _snapshot = null;
    }

    // Restores the pre-preview palette, theme identity and optional
    // blocks. Writes nothing.
    function cancelPreview(): void {
        const snap = _snapshot;
        if (snap === null)
            return;
        _snapshot = null;
        _adopt(snap, true);
        // A preview taken before the first live scheme must not count as
        // having adopted a theme: the configured one is still owed.
        themeStateReady = _snapshotReady;
        if (!themeStateReady && Config.loaded)
            _adoptConfiguredTheme();
    }

    property bool _snapshotReady: false

    function _captureSnapshot(): var {
        const palette = {};
        for (const role of roles)
            palette[role] = String(current[role]);
        palette.glow = String(current.glow);
        const terminal = [];
        for (let i = 0; i < 16; i++)
            terminal.push(String(current[`term${i}`]));
        return {
            "schemaVersion": 2,
            "id": themeId,
            "mode": themeMode,
            "palette": palette,
            "terminal": terminal,
            "chromatic": _chromaticSource,
            "minSurfaceAlpha": minSurfaceAlpha,
            "clearInk": clearInk
        };
    }

    // The scheme's raw chromatic block, kept so a snapshot restores it.
    property var _chromaticSource: null

    function applyBuiltInTheme(id: string): void {
        if (isBuiltInTheme(id))
            applyScheme(builtInThemes[id]);
    }

    // Serialise a scheme object to the live scheme contract.
    function schemeDocument(scheme: var): string {
        return JSON.stringify({
            "schemaVersion": 2,
            "id": scheme.id,
            "mode": scheme.mode === "light" ? "light" : "dark",
            "palette": scheme.palette,
            "terminal": scheme.terminal ?? []
        }, null, 2);
    }

    // Persist a scheme (built-in or catalogue palette) atomically to the
    // live scheme path; `builtInThemePersisted` reports the result.
    function persistScheme(scheme: var): void {
        if (!scheme || !isCompletePalette(scheme.palette)) {
            builtInThemePersisted(scheme?.id ?? "", false, "theme has no complete Signal palette");
            return;
        }
        _pendingPersistId = scheme.id;
        writeSchemeProc.payload = schemeDocument(scheme);
        writeSchemeProc.running = true;
    }

    function persistBuiltInTheme(id: string): void {
        if (!isBuiltInTheme(id)) {
            builtInThemePersisted(id, false, "unknown built-in theme");
            return;
        }
        persistScheme(builtInThemes[id]);
    }

    function load(text: string): void {
        let scheme = null;
        try {
            scheme = JSON.parse(text);
        } catch (e) {
            console.warn("Signal: live scheme is not valid JSON:", e);
        }
        if (scheme && scheme.schemaVersion === 2 && _snapshot !== null && isCompletePalette(scheme.palette)) {
            // A candidate is on screen: the file becomes what Cancel
            // restores, the preview itself stays untouched.
            _snapshot = scheme;
            return;
        }
        if (scheme && scheme.schemaVersion === 2 && _adopt(scheme, true))
            return;
        // Legacy/invalid scheme: present the configured built-in.
        schemeFile.loadFailedOnce = true;
        if (Config.loaded)
            _adoptConfiguredTheme();
    }

    property bool _missingScheme: false

    // No live scheme: present the configured built-in (shell.json, after
    // its one-shot migration) and, on first run, publish it so horneroctl
    // consumers (Hyprland borders, hyprlock) render the same roles.
    function _adoptConfiguredTheme(): void {
        if (themeStateReady || previewing)
            return;
        const id = isBuiltInTheme(Config.appearance.theme) ? Config.appearance.theme : defaultThemeId;
        applyBuiltInTheme(id);
        if (_missingScheme)
            persistBuiltInTheme(id);
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            if (Config.loaded && !root.themeStateReady && (root._missingScheme || schemeFile.loadFailedOnce))
                root._adoptConfiguredTheme();
        }
    }

    function reloadFromDisk(): void {
        schemeFile.reload();
    }

    // Translucency: layer 0 is the surface backdrop, nested layers keep a
    // slight lift so stacked cards stay distinguishable.
    function layer(c: color, layer: var, role: var): color {
        if (!transparency.enabled)
            return c;
        if (layer === 0)
            return Qt.alpha(c, Math.max(transparency.base, alphaFloor(role ? String(role) : "base")));
        const depth = layer ?? 1;
        const lift = (light ? -0.04 : 0.05) * depth;
        return Qt.rgba(Math.max(0, Math.min(1, c.r + lift)), Math.max(0, Math.min(1, c.g + lift)), Math.max(0, Math.min(1, c.b + lift)), Math.max(transparency.layers, alphaFloor(role ? String(role) : "panel")));
    }

    // Smallest backdrop alpha the live scheme allows for a surface role
    // (`minSurfaceAlpha`, RFC 0002 §4.9); 0 for curated themes. Only
    // consulted while translucency is on, so High Contrast (opaque) and
    // Cockpit Clear (no backdrop at all) are unaffected.
    function alphaFloor(role: string): real {
        const v = minSurfaceAlpha ? minSurfaceAlpha[role] : undefined;
        return typeof v === "number" && !isNaN(v) ? v : 0;
    }

    // Resolved backdrop alpha for a named surface (bar, launcher,
    // dashboard, session, sidebar, utilities, notifications, osd, lock,
    // layoutpicker): its elements[] override, else the global base.
    function elementAlpha(element: string): real {
        if (!transparency.enabled)
            return 1;
        const els = transparency.elements ?? {};
        const v = els[element];
        const floor = alphaFloor(element === "bar" ? "base" : "panel");
        if (typeof v === "number" && !isNaN(v))
            return Math.max(floor, Math.max(0, Math.min(1, v)));
        return Math.max(floor, transparency.base);
    }

    // Backdrop colour for a named surface: compose as
    // surface(layer(c, n), element); text and controls stay opaque.
    function surface(c: color, element: string): color {
        if (!transparency.enabled)
            return c;
        return Qt.alpha(c, elementAlpha(element));
    }

    // Readable ink for an arbitrary fill (data-driven colours only; use
    // the paired on* role whenever one exists).
    function on(c: color): color {
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        const darkInk = light ? palette.ink : palette.onInverse;
        const lightInk = light ? palette.onInverse : palette.ink;
        return lum > 0.45 ? darkInk : lightInk;
    }

    Component.onCompleted: _fill(contrastPalette, builtInThemes[contrastThemeId])

    Process {
        id: writeSchemeProc

        property string payload: ""

        command: ["sh", "-c", 'set -e; mkdir -p "$(dirname "$HORNERO_SIGNAL_SCHEME")"; tmp="$HORNERO_SIGNAL_SCHEME.tmp.$$"; printf "%s\\n" "$HORNERO_SIGNAL_PAYLOAD" > "$tmp"; mv -f "$tmp" "$HORNERO_SIGNAL_SCHEME"']
        environment: ({
                "HORNERO_SIGNAL_SCHEME": root.schemePath,
                "HORNERO_SIGNAL_PAYLOAD": writeSchemeProc.payload
            })
        onExited: (exitCode, exitStatus) => {
            const id = root._pendingPersistId;
            root._pendingPersistId = "";
            // A watcher armed on a missing file never fires; re-read so it
            // follows later writes (first run creates the file here).
            if (exitCode === 0)
                schemeFile.reload();
            root.builtInThemePersisted(id, exitCode === 0, exitCode === 0 ? "" : `could not write ${root.schemePath} (exit ${exitCode})`);
        }
    }

    FileView {
        id: schemeFile

        property bool loadFailedOnce: false

        path: root.schemePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text())
        onLoadFailed: err => {
            if (root.themeStateReady)
                return;
            schemeFile.loadFailedOnce = true;
            root._missingScheme = err === FileViewError.FileNotFound;
            if (Config.loaded)
                root._adoptConfiguredTheme();
        }
    }

    Connections {
        target: Config.appearance

        function onHighContrastChanged(): void {
            root.paletteRevision++;
        }
    }

    // OKLab palette tween: at most 12 steps, one Timer tick (20 ms) each.
    // Every tick assigns one interpolated frame to `current`; the final
    // tick assigns the exact target, so a tween can never leave the
    // palette between two colours.
    QtObject {
        id: tweenState

        property var from: null
        property var to: null
        property int step: 0
        property int steps: 0
    }

    Timer {
        id: tweenTimer

        interval: Chromatic.STEP_MS
        repeat: true
        onTriggered: {
            tweenState.step++;
            root._assign(Chromatic.frame(tweenState.from, tweenState.to, tweenState.step, tweenState.steps));
            root.transitionSteps = tweenState.step;
            if (tweenState.step >= tweenState.steps) {
                tweenTimer.stop();
                root.paletteRevision++;
            }
        }
    }

    readonly property QtObject _tween: QtObject {
        readonly property bool active: tweenTimer.running

        function start(from: var, to: var, steps: int): void {
            tweenState.from = from;
            tweenState.to = to;
            tweenState.step = 0;
            tweenState.steps = steps;
            root.transitionSteps = 0;
            tweenTimer.restart();
        }

        function stop(): void {
            tweenTimer.stop();
        }
    }

    IpcHandler {
        target: "signal"

        function reload(): void {
            root.reloadFromDisk();
        }

        function mode(): string {
            return root.light ? "light" : "dark";
        }

        function theme(): string {
            return root.themeId;
        }

        function previewing(): bool {
            return root.previewing;
        }
    }

    component Transparency: QtObject {
        readonly property bool enabled: Appearance.transparency.enabled && !Config.appearance.highContrast
        readonly property real base: Appearance.transparency.base - (root.light ? 0.1 : 0)
        readonly property real layers: Appearance.transparency.layers
        readonly property var elements: Appearance.transparency.elements ?? ({})
    }

    component LayeredInkRoles: QtObject {
        readonly property color onSignal: root.layer(root.palette.onSignal)
        readonly property color onSignalWell: root.layer(root.palette.onSignalWell)
        readonly property color onCue: root.layer(root.palette.onCue)
        readonly property color onCueWell: root.layer(root.palette.onCueWell)
        readonly property color onPhosphor: root.layer(root.palette.onPhosphor)
        readonly property color onPhosphorWell: root.layer(root.palette.onPhosphorWell)
        readonly property color onAlert: root.layer(root.palette.onAlert)
        readonly property color onAlertWell: root.layer(root.palette.onAlertWell)
        readonly property color onInverse: root.layer(root.palette.onInverse)
    }

    // Translucent variants of the surface roles; content roles stay opaque.
    component LayeredPalette: LayeredInkRoles {
        readonly property color ground: root.layer(root.palette.ground, 0, "base")
        readonly property color sunken: root.layer(root.palette.sunken, 1, "sunken")
        readonly property color base: root.layer(root.palette.base, 0, "base")
        readonly property color panel: root.layer(root.palette.panel, 1, "panel")
        readonly property color raised: root.layer(root.palette.raised, 1, "raised")
        readonly property color lifted: root.layer(root.palette.lifted, 1, "lifted")
        readonly property color ink: root.layer(root.palette.ink)
        readonly property color inkMuted: root.layer(root.palette.inkMuted)
        readonly property color inkFaint: root.layer(root.palette.inkFaint)
        readonly property color rule: root.layer(root.palette.rule)
        readonly property color ruleStrong: root.layer(root.palette.ruleStrong)
        readonly property color focus: root.layer(root.palette.focus)
        readonly property color signal: root.layer(root.palette.signal)
        readonly property color glow: root.layer(root.palette.glow)
        readonly property color signalWell: root.layer(root.palette.signalWell)
        readonly property color cue: root.layer(root.palette.cue)
        readonly property color cueWell: root.layer(root.palette.cueWell)
        readonly property color phosphor: root.layer(root.palette.phosphor)
        readonly property color phosphorWell: root.layer(root.palette.phosphorWell)
        readonly property color alert: root.layer(root.palette.alert)
        readonly property color alertWell: root.layer(root.palette.alertWell)
        readonly property color inverse: root.layer(root.palette.inverse, 0)
        readonly property color inverseSignal: root.layer(root.palette.inverseSignal)
        readonly property color scrim: root.layer(root.palette.scrim)
        readonly property color shadow: root.layer(root.palette.shadow)
    }

    // Content (on*) roles live in a base type: Qt parses `onX: …` beside a
    // property X in one object as X's change handler (see shell#427).
    component SignalInkRoles: QtObject {
        property color onSignal: "#1E1304"
        property color onSignalWell: "#FFE0B0"
        property color onCue: "#071A26"
        property color onCueWell: "#D6EFFC"
        property color onPhosphor: "#071D12"
        property color onPhosphorWell: "#D1F5E0"
        property color onAlert: "#24070C"
        property color onAlertWell: "#FFD6DC"
        property color onInverse: "#1B2430"
    }

    // Defaults are Signal Night so the first frame is already on-brand.
    component SignalPalette: SignalInkRoles {
        property color ground: "#0C1016"
        property color sunken: "#10151C"
        property color base: "#141B24"
        property color panel: "#1B2430"
        property color raised: "#24303D"
        property color lifted: "#2C3947"
        property color ink: "#E6EBF1"
        property color inkMuted: "#A9B7C6"
        property color inkFaint: "#8999AB"
        property color rule: "#2D3B4B"
        property color ruleStrong: "#8393A6"
        property color focus: "#8BCEF0"
        property color signal: "#F2AC52"
        // Optional luminous accent (amendment 2); themes may omit it.
        property color glow: "#FFC06B"
        property color signalWell: "#3D2B12"
        property color cue: "#8BCEF0"
        property color cueWell: "#163345"
        property color phosphor: "#8DDBAF"
        property color phosphorWell: "#153425"
        property color alert: "#FF8494"
        property color alertWell: "#421922"
        property color inverse: "#E6EBF1"
        property color inverseSignal: "#864700"
        property color scrim: "#000000"
        property color shadow: "#000000"
        property color term0: "#24303D"
        property color term1: "#FF8494"
        property color term2: "#8DDBAF"
        property color term3: "#F2AC52"
        property color term4: "#8BCEF0"
        property color term5: "#C9A5F5"
        property color term6: "#76D8CE"
        property color term7: "#C5D0DC"
        property color term8: "#8393A6"
        property color term9: "#FFA6B2"
        property color term10: "#B2EBC9"
        property color term11: "#FFC87D"
        property color term12: "#B2E0F8"
        property color term13: "#DEC4FA"
        property color term14: "#A3EAE2"
        property color term15: "#E6EBF1"
    }
}
