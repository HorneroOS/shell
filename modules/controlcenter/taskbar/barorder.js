.pragma library

// Pure bar-section ordering for the Layout pane (shell#466). A layout
// preset writes `bar.bars` (one bar per edge, each with start/center/end
// groups of {id, enabled, options}); from then on the active layout is that
// config, so reordering edits the same structure. Every function returns a
// deep copy and keeps unknown fields and per-entry options untouched, so a
// reordered layout stays a valid preset-shaped bar set.

var GROUPS = ["start", "center", "end"];

var ENTRIES = {
    logo: { label: "Logo", icon: "flutter_dash" },
    workspaces: { label: "Workspaces", icon: "grid_view" },
    activeWindow: { label: "Active window", icon: "web_asset" },
    tray: { label: "System tray", icon: "apps" },
    extensions: { label: "Extensions", icon: "extension" },
    clock: { label: "Clock", icon: "schedule" },
    statusIcons: { label: "Status icons", icon: "wifi" },
    audioSlider: { label: "Volume slider", icon: "volume_up" },
    brightnessSlider: { label: "Brightness slider", icon: "brightness_6" },
    media: { label: "Media", icon: "music_note" },
    resources: { label: "Resources", icon: "monitoring" },
    kbLayout: { label: "Keyboard layout", icon: "keyboard" },
    weather: { label: "Weather", icon: "partly_cloudy_day" },
    pinnedApps: { label: "Pinned apps", icon: "push_pin" },
    quickActions: { label: "Quick actions", icon: "bolt" },
    battery: { label: "Battery", icon: "battery_full" },
    power: { label: "Power", icon: "power_settings_new" }
};

function entryInfo(id) {
    return ENTRIES[id] || { label: id, icon: "widgets" };
}

function clone(value) {
    return JSON.parse(JSON.stringify(value === undefined ? null : value));
}

// QML list<var> values are not JS Arrays.
function toArray(v) {
    if (!v || typeof v !== "object" || typeof v.length !== "number")
        return [];
    return Array.prototype.slice.call(v);
}

function normalizeGroups(bar) {
    var g = bar.groups || {};
    var out = {};
    for (var i = 0; i < GROUPS.length; i++) {
        out[GROUPS[i]] = toArray(g[GROUPS[i]]).map(function (e) {
            return typeof e === "string" ? { id: e, enabled: true } : e;
        });
    }
    bar.groups = out;
    return bar;
}

function cloneBars(bars) {
    return clone(toArray(bars)).map(normalizeGroups);
}

// Group titles follow the bar's orientation.
function groupTitle(edge, group) {
    var vertical = edge === "left" || edge === "right";
    if (group === "start")
        return vertical ? "Top" : "Left";
    if (group === "end")
        return vertical ? "Bottom" : "Right";
    return vertical ? "Middle" : "Center";
}

// Moves one entry by delta (-1 up/left, +1 down/right). Past the edge of
// its group it crosses into the neighbouring group (end of the previous,
// start of the next); at the very first/last position it stays.
function move(bars, barIndex, group, index, delta) {
    var out = cloneBars(bars);
    var bar = out[barIndex];
    if (!bar || GROUPS.indexOf(group) < 0)
        return out;
    var list = bar.groups[group];
    if (index < 0 || index >= list.length)
        return out;
    var target = index + delta;
    if (target >= 0 && target < list.length) {
        var item = list.splice(index, 1)[0];
        list.splice(target, 0, item);
        return out;
    }
    var gi = GROUPS.indexOf(group) + (delta < 0 ? -1 : 1);
    if (gi < 0 || gi >= GROUPS.length)
        return out;
    var moved = list.splice(index, 1)[0];
    var next = bar.groups[GROUPS[gi]];
    if (delta < 0)
        next.push(moved);
    else
        next.unshift(moved);
    return out;
}

function canMove(bars, barIndex, group, index, delta) {
    var bar = toArray(bars)[barIndex];
    if (!bar)
        return false;
    var gi = GROUPS.indexOf(group);
    var len = toArray((bar.groups || {})[group]).length;
    if (delta < 0)
        return index > 0 || gi > 0;
    return index < len - 1 || gi < GROUPS.length - 1;
}

function setEnabled(bars, barIndex, group, index, enabled) {
    var out = cloneBars(bars);
    var bar = out[barIndex];
    if (bar && bar.groups[group] && bar.groups[group][index])
        bar.groups[group][index].enabled = !!enabled;
    return out;
}

// The bar set a scope edits: "" is the global set, otherwise the
// per-screen override for that screen.
function barsForScope(globalBars, perScreen, scope) {
    if (scope === "")
        return cloneBars(globalBars);
    var overrides = toArray(perScreen);
    for (var i = 0; i < overrides.length; i++)
        if (overrides[i] && overrides[i].screen === scope)
            return cloneBars(overrides[i].bars);
    return [];
}

// Writes an edited bar set back into a copy of perScreen.
function withScreenBars(perScreen, scope, bars) {
    var out = clone(toArray(perScreen));
    for (var i = 0; i < out.length; i++)
        if (out[i] && out[i].screen === scope)
            out[i].bars = clone(bars);
    return out;
}

function overrideScreens(perScreen) {
    return toArray(perScreen).filter(function (o) {
        return o && typeof o.screen === "string" && toArray(o.bars).length > 0;
    }).map(function (o) {
        return o.screen;
    });
}

// Known sections not present in any group of this bar, in catalogue order.
function missingIds(bars, barIndex) {
    var bar = toArray(bars)[barIndex];
    if (!bar)
        return [];
    var used = {};
    for (var i = 0; i < GROUPS.length; i++)
        toArray((bar.groups || {})[GROUPS[i]]).forEach(function (e) {
            used[typeof e === "string" ? e : e.id] = true;
        });
    return Object.keys(ENTRIES).filter(function (id) {
        return !used[id];
    });
}

// Appends a known section to a group; no-op when it is already on the bar.
function addEntry(bars, barIndex, group, id) {
    var out = cloneBars(bars);
    var bar = out[barIndex];
    if (!bar || GROUPS.indexOf(group) < 0 || !ENTRIES[id] || missingIds(out, barIndex).indexOf(id) < 0)
        return out;
    bar.groups[group].push({ id: id, enabled: true });
    return out;
}
