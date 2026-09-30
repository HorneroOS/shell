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

    function normalizeEntries(list: var): var {
        if (!Array.isArray(list))
            return [];
        const out = [];
        for (const e of list) {
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
        const src = Array.isArray(list) ? list : [];
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
            reserve: typeof b.reserve === "boolean" ? b.reserve : style !== "floating",
            margin: typeof b.margin === "number" ? Math.max(0, Math.min(b.margin, 256)) : floatingMargin,
            thickness: typeof b.thickness === "number" ? Math.max(16, Math.min(b.thickness, 256)) : sizes.innerWidth,
            density: b.density === "glyphs" ? "glyphs" : "values",
            groups: {
                start: normalizeEntries(g.start),
                center: normalizeEntries(g.center),
                end: normalizeEntries(g.end)
            }
        };
    }

    function legacyBarFor(screenName: string): var {
        const o = getOverride(screenName);
        return {
            edge: (o && barEdges.includes(o.position)) ? o.position : (barEdges.includes(position) ? position : "left"),
            style: (o && barStyles.includes(o.style)) ? o.style : (barStyles.includes(style) ? style : "attached"),
            reserve: ((o && o.style) ? o.style : style) !== "floating",
            margin: floatingMargin,
            thickness: sizes.innerWidth,
            density: "values",
            groups: splitLegacyEntries(entries)
        };
    }

    // Resolved bar set for a screen: per-screen bars, else global bars,
    // else the synthesized legacy bar. Invalid bars are dropped and the
    // first bar wins on a duplicated edge; an unusable set falls back to
    // the legacy bar so the user always keeps desktop chrome.
    function barsFor(screenName: string): var {
        const o = getOverride(screenName);
        const src = (o && Array.isArray(o.bars) && o.bars.length > 0) ? o.bars : bars;
        const out = [];
        const seen = [];
        for (const b of (src ?? [])) {
            const n = normalizeBar(b);
            if (!n || seen.includes(n.edge))
                continue;
            seen.push(n.edge);
            out.push(n);
        }
        return out.length > 0 ? out : [legacyBarFor(screenName)];
    }

    function getOverride(screenName: string): var {
        if (!perScreen || !Array.isArray(perScreen))
            return null;
        for (let i = 0; i < perScreen.length; i++) {
            if (perScreen[i] && perScreen[i].screen === screenName)
                return perScreen[i];
        }
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
        return style !== "floating";
    }

    function reservesSpaceFor(screenName: string): bool {
        return styleFor(screenName) !== "floating";
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
