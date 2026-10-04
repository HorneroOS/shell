import Quickshell.Io

JsonObject {
    property bool persistent: true
    property bool showOnHover: true
    property int dragThreshold: 20
    // Optional per-screen bar-set overrides: [{ screen: "MONITOR-NAME", bars: [...] }]
    property list<var> perScreen: []

    // Every bar is explicit, edge-unique, and grouped into start/center/end.
    property list<var> bars: [{
        edge: "left", style: "attached", reserve: true, margin: 0,
        thickness: 40, density: "values", backdrop: "solid",
        groups: {
            start: [{id: "logo", enabled: true}, {id: "workspaces", enabled: true}],
            center: [{id: "activeWindow", enabled: true}],
            end: [{id: "tray", enabled: true}, {id: "clock", enabled: true}, {id: "statusIcons", enabled: true}, {id: "power", enabled: true}]
        }
    }]

    readonly property var barEdges: ["top", "bottom", "left", "right"]
    readonly property var barStyles: ["attached", "inset", "floating", "islands", "dock"]
    // What a bar paints behind its components: "solid" (slab or frame strip)
    // or "clear" (no slab, components sit on the wallpaper over a soft
    // edge scrim). Geometry and reservation are unaffected.
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
            margin: typeof b.margin === "number" ? Math.max(0, Math.min(b.margin, 256)) : 8,
            thickness: typeof b.thickness === "number" ? Math.max(16, Math.min(b.thickness, 256)) : sizes.innerWidth,
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
        property string label: "  " // if empty, will show workspace name's first letter
        property string occupiedLabel: "󰮯"
        property string activeLabel: "󰮯"
        property string capitalisation: "preserve" // upper, lower, or preserve - relevant only if label is empty
        property list<var> specialWorkspaceIcons: []
    }

    component ActiveWindow: JsonObject {
        property bool inverted: false
    }

    component Tray: JsonObject {
        property bool background: false
        property bool recolour: false
        property bool compact: false
        property list<var> iconSubs: []
        property list<string> hiddenIcons: []
    }

    component Status: JsonObject {
        property bool showAudio: false
        property bool showMicrophone: false
        property bool showKbLayout: false
        property bool showNetwork: true
        property bool showWifi: true
        property bool showBluetooth: true
        property bool showBattery: true
        property bool showLockStatus: true
    }

    component Clock: JsonObject {
        property bool showIcon: true
        property bool showDate: false
        property bool background: false
    }

    component Sizes: JsonObject {
        property int innerWidth: 40
        property int windowPreviewSize: 400
        property int trayMenuWidth: 300
        property int batteryWidth: 250
        property int networkWidth: 320
        property int kbLayoutWidth: 320
    }
}
