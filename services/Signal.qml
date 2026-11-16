pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

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

    signal builtInThemePersisted(string id, bool ok, string error)

    // High contrast is a shell-wide accessibility override: it swaps in
    // the contrast table without changing the persisted theme identity.
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
                    "ground": "#0C0F13",
                    "sunken": "#101419",
                    "base": "#13171D",
                    "panel": "#181D24",
                    "raised": "#1F252E",
                    "lifted": "#283039",
                    "ink": "#ECE6DA",
                    "inkMuted": "#A8ABAD",
                    "inkFaint": "#737980",
                    "rule": "#2C333C",
                    "ruleStrong": "#707A85",
                    "focus": "#7EC1EA",
                    "signal": "#F2A33A",
                    "glow": "#FFB650",
                    "onSignal": "#1A1205",
                    "signalWell": "#3A2A12",
                    "onSignalWell": "#FFD9A3",
                    "cue": "#7EC1EA",
                    "onCue": "#06151F",
                    "cueWell": "#16303F",
                    "onCueWell": "#CDE8F8",
                    "phosphor": "#8BD49A",
                    "onPhosphor": "#07170C",
                    "phosphorWell": "#173222",
                    "onPhosphorWell": "#CDEFD4",
                    "alert": "#F0705A",
                    "onAlert": "#1E0905",
                    "alertWell": "#3D1A14",
                    "onAlertWell": "#FFD3CA",
                    "inverse": "#ECE6DA",
                    "onInverse": "#181D24",
                    "inverseSignal": "#8A5200",
                    "scrim": "#000000",
                    "shadow": "#000000"
                },
                "terminal": ["#13171D", "#F0705A", "#8BD49A", "#F2A33A", "#7EC1EA", "#C9A0DC", "#6FD0C5", "#ECE6DA", "#66707B", "#FF8E7A", "#A8E6B4", "#FFC46E", "#A6D6F4", "#DDBDEB", "#9BE3DA", "#FFFFFF"]
            },
            "hornero-signal-day": {
                "id": "hornero-signal-day",
                "name": "Hornero Signal Day",
                "mode": "light",
                "palette": {
                    "ground": "#E6E1D5",
                    "sunken": "#DCD6C8",
                    "base": "#F2EEE5",
                    "panel": "#F7F4EE",
                    "raised": "#FBF9F5",
                    "lifted": "#FFFFFF",
                    "ink": "#1B1E22",
                    "inkMuted": "#4E545B",
                    "inkFaint": "#7A8086",
                    "rule": "#D3CCBD",
                    "ruleStrong": "#736D62",
                    "focus": "#1A5F88",
                    "signal": "#8F4B00",
                    "glow": "#8F4B00",
                    "onSignal": "#FFFFFF",
                    "signalWell": "#F6DDB8",
                    "onSignalWell": "#3D2200",
                    "cue": "#1A5F88",
                    "onCue": "#FFFFFF",
                    "cueWell": "#D3E7F3",
                    "onCueWell": "#0B2E44",
                    "phosphor": "#256A3B",
                    "onPhosphor": "#FFFFFF",
                    "phosphorWell": "#D5EBD9",
                    "onPhosphorWell": "#0E2E17",
                    "alert": "#A8341C",
                    "onAlert": "#FFFFFF",
                    "alertWell": "#F7D7D0",
                    "onAlertWell": "#4A1209",
                    "inverse": "#1B1E22",
                    "onInverse": "#F2EEE5",
                    "inverseSignal": "#F2A33A",
                    "scrim": "#000000",
                    "shadow": "#000000"
                },
                "terminal": ["#1B1E22", "#B0371F", "#2A7341", "#9A5100", "#1D6894", "#7A3E8C", "#126B66", "#DCD6C8", "#4E545B", "#C9482E", "#348A4F", "#B36200", "#2A7DB0", "#8F4FA3", "#188079", "#F2EEE5"]
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
        if (!scheme || !isCompletePalette(scheme.palette)) {
            console.warn("Signal: ignoring scheme without a complete schema-v2 palette");
            return false;
        }
        _fill(current, scheme);
        themeId = scheme.id || "";
        themeMode = scheme.mode === "light" ? "light" : "dark";
        themeStateReady = true;
        return true;
    }

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
        if (scheme && scheme.schemaVersion === 2 && applyScheme(scheme))
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
        if (themeStateReady)
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
    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;
        if (layer === 0)
            return Qt.alpha(c, transparency.base);
        const depth = layer ?? 1;
        const lift = (light ? -0.04 : 0.05) * depth;
        return Qt.rgba(Math.max(0, Math.min(1, c.r + lift)), Math.max(0, Math.min(1, c.g + lift)), Math.max(0, Math.min(1, c.b + lift)), transparency.layers);
    }

    // Resolved backdrop alpha for a named surface (bar, launcher,
    // dashboard, session, sidebar, utilities, notifications, osd, lock,
    // layoutpicker): its elements[] override, else the global base.
    function elementAlpha(element: string): real {
        if (!transparency.enabled)
            return 1;
        const els = transparency.elements ?? {};
        const v = els[element];
        if (typeof v === "number" && !isNaN(v))
            return Math.max(0, Math.min(1, v));
        return transparency.base;
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
        readonly property color ground: root.layer(root.palette.ground, 0)
        readonly property color sunken: root.layer(root.palette.sunken)
        readonly property color base: root.layer(root.palette.base, 0)
        readonly property color panel: root.layer(root.palette.panel)
        readonly property color raised: root.layer(root.palette.raised)
        readonly property color lifted: root.layer(root.palette.lifted)
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
        property color onSignal: "#1A1205"
        property color onSignalWell: "#FFD9A3"
        property color onCue: "#06151F"
        property color onCueWell: "#CDE8F8"
        property color onPhosphor: "#07170C"
        property color onPhosphorWell: "#CDEFD4"
        property color onAlert: "#1E0905"
        property color onAlertWell: "#FFD3CA"
        property color onInverse: "#181D24"
    }

    // Defaults are Signal Night so the first frame is already on-brand.
    component SignalPalette: SignalInkRoles {
        property color ground: "#0C0F13"
        property color sunken: "#101419"
        property color base: "#13171D"
        property color panel: "#181D24"
        property color raised: "#1F252E"
        property color lifted: "#283039"
        property color ink: "#ECE6DA"
        property color inkMuted: "#A8ABAD"
        property color inkFaint: "#737980"
        property color rule: "#2C333C"
        property color ruleStrong: "#707A85"
        property color focus: "#7EC1EA"
        property color signal: "#F2A33A"
        // Optional luminous accent (amendment 2); themes may omit it.
        property color glow: "#FFB650"
        property color signalWell: "#3A2A12"
        property color cue: "#7EC1EA"
        property color cueWell: "#16303F"
        property color phosphor: "#8BD49A"
        property color phosphorWell: "#173222"
        property color alert: "#F0705A"
        property color alertWell: "#3D1A14"
        property color inverse: "#ECE6DA"
        property color inverseSignal: "#8A5200"
        property color scrim: "#000000"
        property color shadow: "#000000"
        property color term0: "#13171D"
        property color term1: "#F0705A"
        property color term2: "#8BD49A"
        property color term3: "#F2A33A"
        property color term4: "#7EC1EA"
        property color term5: "#C9A0DC"
        property color term6: "#6FD0C5"
        property color term7: "#ECE6DA"
        property color term8: "#66707B"
        property color term9: "#FF8E7A"
        property color term10: "#A8E6B4"
        property color term11: "#FFC46E"
        property color term12: "#A6D6F4"
        property color term13: "#DDBDEB"
        property color term14: "#9BE3DA"
        property color term15: "#FFFFFF"
    }
}
