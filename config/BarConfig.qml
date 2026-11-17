import Quickshell.Io

JsonObject {
    property bool persistent: true
    property bool showOnHover: true
    // Cockpit Clear foreground style (signal-visual-language §12.3):
    // "auto" | "outline" | "shadow" | "contrast". High Contrast forces
    // "contrast".
    property string clearStyle: "auto"
    // Cockpit Clear ink knobs: shadow/outline strength (0..1.5), ring width
    // (0..2) and polarity ("auto" | "light" | "dark").
    property ClearInkKnobs clearInk: ClearInkKnobs {}
    // Typeface of values, dates and labels in the bars: "mono" (IBM Plex
    // Mono, the Signal data face) or "sans" (IBM Plex Sans, plain case, no
    // tracking). Clear layouts ship "sans".
    property string typeface: "mono"
    // Launcher mark in the bar: "hornero" (symbolic mark, signal amber) or
    // "distro" (the base distribution logo, in ink).
    property string mark: "hornero"
    property int dragThreshold: 20
    // Optional per-screen bar-set overrides: [{ screen: "MONITOR-NAME", bars: [...] }]
    property list<var> perScreen: []

    // Every bar is explicit, edge-unique, and grouped into start/center/end.
    // Factory default is the Cockpit layout (presets/cockpit.json): act on
    // top, glance below. Hornero Left/Right remain available as presets.
    property list<var> bars: [{
        edge: "top", style: "inset", reserve: true, margin: 18, radius: 11,
        thickness: 42, density: "values", backdrop: "solid",
        groups: {
            start: [{id: "logo", enabled: true}, {id: "quickActions", enabled: true, options: {actions: ["screenshot", "layoutPicker", "settings"]}}, {id: "audioSlider", enabled: true, options: {showValue: true}}, {id: "brightnessSlider", enabled: true, options: {showValue: true}}],
            center: [{id: "clock", enabled: true, options: {showDate: true}}, {id: "weather", enabled: true}],
            end: [{id: "modeIndicator", enabled: true}, {id: "statusIcons", enabled: true}, {id: "tray", enabled: true}, {id: "extensions", enabled: true}, {id: "power", enabled: true}]
        }
    }, {
        edge: "bottom", style: "attached", reserve: true, margin: 0,
        thickness: 28, density: "values", backdrop: "solid",
        groups: {
            start: [{id: "workspaces", enabled: true}],
            center: [{id: "media", enabled: true}],
            end: [{id: "kbLayout", enabled: true}, {id: "resources", enabled: true}, {id: "battery", enabled: true}]
        }
    }]

    readonly property var barEdges: ["top", "bottom", "left", "right"]
    readonly property var barStyles: ["attached", "inset", "floating", "islands", "dock"]
    // What a bar paints behind its components: "solid" (slab or frame strip)
    // or "clear" (no slab and no scrim: components sit directly on the
    // wallpaper with adaptive per-region ink). Geometry and reservation are unaffected.
    readonly property var barBackdrops: ["solid", "clear"]

    // QML list<var> values are not JS Arrays; copy them first.
    function toArray(v: var): var {
        if (!v || typeof v !== "object" || typeof v.length !== "number")
            return [];
        return Array.from(v);
    }

    function normalizeEntries(list: var): var {
        const out = [];
        for (const e of toArray(list)) {
            const entry = typeof e === "string" ? {id: e, enabled: true} : e;
            if (!entry || typeof entry.id !== "string" || entry.id === "spacer")
                continue;
            out.push({id: entry.id, enabled: entry.enabled !== false, options: entry.options ?? {}});
        }
        return out;
    }

    function normalizeBar(b: var): var {
        if (!b || !barEdges.includes(b.edge))
            return null;
        const style = barStyles.includes(b.style) ? b.style : "attached";
        const g = b.groups ?? {};
        return {
            edge: b.edge,
            style: style,
            reserve: typeof b.reserve === "boolean" ? b.reserve : styleReserves(style),
            margin: typeof b.margin === "number" ? Math.max(0, Math.min(b.margin, 256)) : 6,
            thickness: typeof b.thickness === "number" ? Math.max(20, Math.min(b.thickness, 256)) : sizes.innerWidth,
            // Slab corner radius in px; -1 keeps the style's own radius.
            radius: typeof b.radius === "number" ? Math.max(0, Math.min(b.radius, 24)) : -1,
            density: b.density === "glyphs" ? "glyphs" : "values",
            backdrop: barBackdrops.includes(b.backdrop) ? b.backdrop : "solid",
            groups: {
                start: normalizeEntries(g.start),
                center: normalizeEntries(g.center),
                end: normalizeEntries(g.end)
            }
        };
    }

    // Resolve per-screen bars before the global set; first valid bar per edge wins.
    function barsFor(screenName: string): var {
        const o = getOverride(screenName);
        const src = (o && toArray(o.bars).length > 0) ? toArray(o.bars) : toArray(bars);
        const out = [];
        const seen = [];
        for (const b of src) {
            const n = normalizeBar(b);
            if (!n || seen.includes(n.edge))
                continue;
            seen.push(n.edge);
            out.push(n);
        }
        return out;
    }

    // Default reservation per style (docs/LAYOUTS.md): strips (attached,
    // inset) and the dock reserve space; content pills (floating, islands)
    // overlay clients unless a spec opts in with explicit reserve: true.
    // Single source of truth for every default site below.
    function styleReserves(s: string): bool {
        return s === "attached" || s === "inset" || s === "dock";
    }

    // perScreen is a QML list<var>: Array.isArray() is false for it, which
    // silently disabled every per-screen override before.
    function getOverride(screenName: string): var {
        for (const o of toArray(perScreen))
            if (o && o.screen === screenName)
                return o;
        return null;
    }


    // Primary (first) bar of the resolved set, for consumers that only
    // need one anchor edge (desktop clock, visualiser).
    function positionFor(screenName: string): string {
        const resolved = barsFor(screenName);
        return resolved.length > 0 ? resolved[0].edge : "left";
    }

    function styleFor(screenName: string): string {
        const resolved = barsFor(screenName);
        return resolved.length > 0 ? resolved[0].style : "attached";
    }

    function isVerticalFor(screenName: string): bool {
        const p = positionFor(screenName);
        return p === "left" || p === "right";
    }

    function isFloatingFor(screenName: string): bool {
        return styleFor(screenName) !== "attached";
    }

    function reservesSpaceFor(screenName: string): bool {
        return styleReserves(styleFor(screenName));
    }

    property ScrollActions scrollActions: ScrollActions {}
    property Popouts popouts: Popouts {}
    property Workspaces workspaces: Workspaces {}
    property ActiveWindow activeWindow: ActiveWindow {}
    property Tray tray: Tray {}
    property Extensions extensions: Extensions {}
    property Status status: Status {}
    property Clock clock: Clock {}
    property Sizes sizes: Sizes {}
    property list<string> excludedScreens: []


    component ScrollActions: JsonObject {
        property bool workspaces: true
        property bool volume: true
        property bool brightness: true
    }

    component Popouts: JsonObject {
        property bool activeWindow: true
        property bool tray: true
        property bool statusIcons: true
    }

    component Workspaces: JsonObject {
        property int shown: 5
        property int maxWindowIcons: 5
        property bool activeIndicator: true
        property bool occupiedBg: true
        property bool showWindows: true
        property bool showWindowsOnSpecialWorkspaces: showWindows
        property bool activeTrail: false
        property bool perMonitorWorkspaces: true
        // Empty labels let Workspace.qml display the actual workspace name/ID.
        // State remains visible through its active indicator and occupied background.
        property string label: ""
        property string occupiedLabel: ""
        property string activeLabel: ""
        property string capitalisation: "preserve" // upper, lower, or preserve - relevant only if label is empty
        property list<var> specialWorkspaceIcons: []
    }

    component ActiveWindow: JsonObject {
        property bool inverted: false
    }

    component Tray: JsonObject {
        property bool background: false
        property bool recolour: true
        property bool compact: false
        property list<var> iconSubs: []
        property list<string> hiddenIcons: []
    }

    // Extensions island (shell#441): the same settings as the tray island —
    // background, recolour, compact, iconSubs, hiddenIcons — with the same
    // defaults, so both islands read and behave identically.
    component Extensions: JsonObject {
        property bool background: false
        property bool recolour: true
        property bool compact: false
        property list<var> iconSubs: []
        property list<string> hiddenIcons: []
    }

    component Status: JsonObject {
        // Cockpit factory set: audio in the top rail cluster, battery has
        // its own bottom-strip segment so it stays out of the cluster.
        property bool showAudio: true
        property bool showMicrophone: false
        property bool showKbLayout: false
        property bool showNetwork: true
        property bool showWifi: true
        property bool showBluetooth: true
        property bool showBattery: false
        property bool showLockStatus: true
    }

    component Clock: JsonObject {
        property bool showIcon: true
        property bool showDate: false
        property bool background: false
    }

    component ClearInkKnobs: JsonObject {
        property real strength: 1
        property real outline: 1
        property string polarity: "auto"
    }

    component Sizes: JsonObject {
        property int innerWidth: 24
        // Density (services/Density.qml): follow the screen's logical height,
        // times a user multiplier (0.75..1.5).
        property bool autoDensity: true
        property real densityScale: 1
        // Icon and label size multiplier (0.75..1.5): chunky rails raise it.
        property real contentScale: 1
        // Item style (all multipliers of the density-derived values): icon
        // size, text size, gap between items/segments, and the text weight
        // (300..600) of values, dates and labels.
        property real iconScale: 1
        property real textScale: 1
        property real itemSpacing: 1
        property int textWeight: 400
        property int windowPreviewSize: 400
        property int trayMenuWidth: 300
        property int batteryWidth: 250
        property int networkWidth: 320
        property int kbLayoutWidth: 320
    }
}
