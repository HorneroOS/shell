import Quickshell.Io

JsonObject {
    property bool persistent: true
    property bool showOnHover: true
    property int dragThreshold: 20
    // Layout: which screen edge the bar attaches to, and how
    property string position: "left" // left | right | top | bottom
    property string style: "attached" // attached | floating | dock
    property int floatingMargin: 8
    // Optional per-screen overrides: [{ screen: "MONITOR-NAME", position: "...", style: "..." }]
    property list<var> perScreen: []

    // Layout schema v2 (docs/LAYOUTS.md): a set of bars, at most one per
    // screen edge, each split into start/center/end groups. Empty means the
    // legacy single bar (position/style/entries) is synthesized instead, so
    // every v1 preset and user shell.json keeps working unchanged.
    property list<var> bars: []

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

    // v1 entries split at enabled spacers: before the first -> start, between
    // first and last -> center, after the last -> end.
    function splitLegacyEntries(list: var): var {
        const src = toArray(list);
        const cuts = [];
        for (let i = 0; i < src.length; i++)
            if (src[i] && src[i].id === "spacer" && src[i].enabled !== false)
                cuts.push(i);
        if (cuts.length === 0)
            return {start: normalizeEntries(src), center: [], end: []};
        const first = cuts[0];
        const last = cuts[cuts.length - 1];
        if (cuts.length === 1)
            return {start: normalizeEntries(src.slice(0, first)), center: [], end: normalizeEntries(src.slice(first + 1))};
        return {
            start: normalizeEntries(src.slice(0, first)),
            center: normalizeEntries(src.slice(first + 1, last)),
            end: normalizeEntries(src.slice(last + 1))
        };
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
            margin: typeof b.margin === "number" ? Math.max(0, Math.min(b.margin, 256)) : floatingMargin,
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

    function legacyBarFor(screenName: string): var {
        const o = getOverride(screenName);
        const rawStyle = (o && o.style) ? o.style : style;
        const resolvedStyle = barStyles.includes(rawStyle) ? rawStyle : "attached";
        return {
            edge: (o && barEdges.includes(o.position)) ? o.position : (barEdges.includes(position) ? position : "left"),
            style: resolvedStyle,
            reserve: styleReserves(resolvedStyle),
            margin: floatingMargin,
            thickness: sizes.innerWidth,
            density: "values",
            backdrop: "solid",
            groups: splitLegacyEntries(entries)
        };
    }

    // Resolved bar set for a screen: per-screen bars, else global bars,
    // else the synthesized legacy bar. Invalid bars are dropped and the
    // first bar wins on a duplicated edge; an unusable set falls back to
    // the legacy bar so the user always keeps desktop chrome.
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
        return out.length > 0 ? out : [legacyBarFor(screenName)];
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
        return barsFor(screenName)[0].edge;
    }

    function styleFor(screenName: string): string {
        return barsFor(screenName)[0].style;
    }

    function isVertical(): bool {
        return position === "left" || position === "right";
    }

    function isVerticalFor(screenName: string): bool {
        const p = positionFor(screenName);
        return p === "left" || p === "right";
    }

    function isFloating(): bool {
        return style !== "attached";
    }

    function isFloatingFor(screenName: string): bool {
        return styleFor(screenName) !== "attached";
    }

    function reservesSpace(): bool {
        return styleReserves(barStyles.includes(style) ? style : "attached");
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

    property list<var> entries: [
        {
            id: "logo",
            enabled: true
        },
        {
            id: "workspaces",
            enabled: true
        },
        {
            id: "spacer",
            enabled: true
        },
        {
            id: "activeWindow",
            enabled: true
        },
        {
            id: "spacer",
            enabled: true
        },
        {
            id: "tray",
            enabled: true
        },
        {
            id: "clock",
            enabled: true
        },
        {
            id: "statusIcons",
            enabled: true
        },
        {
            id: "power",
            enabled: true
        }
    ]

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
