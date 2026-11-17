.pragma library

// Signal instrument deck (RFC 0001 §5a/§5b, Signal Visual Language §13).
//
// In the `signal` experience (desktopWidgets === "instruments") the shell
// shows a curated set of PluginKit desktop widgets at sensible default
// positions. This module is the pure part of that: the curated catalogue,
// the layout solver and the per-mode override rules. It runs headless under
// node (tests/test_signal_deck.py); services/Experience.qml and
// modules/plugins/PluginDesktopWidgets.qml are the QML consumers.
//
// All coordinates are logical pixels relative to one screen's widget area:
// the desktop layer already excludes the bar (and its edge) and the shell
// margin, so the deck can never cover a bar or a reserved zone. Scale is
// folded into logical pixels by the compositor (3840x2160 at 2x is a
// 1920x1080 area); the solver never sees device pixels.

var GRID = 8;
var GAP = 16;
// The middle of the screen stays open for windows and the wallpaper: the
// deck is two rails on the flanks, never a wall.
var MIN_CENTRE = 480;
// On narrow displays the open middle may shrink to this share of the
// width, so a 1366 px laptop still gets a deck instead of an empty rail.
var MIN_CENTRE_SHARE = 0.3;

function minCentre(areaWidth) {
    return Math.min(MIN_CENTRE, Math.floor(areaWidth * MIN_CENTRE_SHARE));
}

// Curated instruments in priority order. `side` is the preferred rail,
// `edge` which end of the rail the module stacks from. Default and minimum
// sizes match each extension's manifest hint (HorneroOS/plugins); when the
// installed manifest declares a hint the host passes it and wins.
var CATALOGUE = [
    { id: "hornero-system-insight", label: "System Insight", side: "right", edge: "top", width: 520, height: 360, minWidth: 380, minHeight: 240 },
    { id: "hornero-network-scope", label: "Network Scope", side: "left", edge: "top", width: 440, height: 340, minWidth: 320, minHeight: 240 },
    { id: "hornero-audio-deck", label: "Audio Deck", side: "left", edge: "bottom", width: 420, height: 300, minWidth: 320, minHeight: 220 },
    { id: "hornero-calendar", label: "Calendar", side: "right", edge: "top", width: 320, height: 420, minWidth: 260, minHeight: 340 },
    { id: "hornero-agenda", label: "Agenda", side: "right", edge: "bottom", width: 320, height: 340, minWidth: 260, minHeight: 280 },
    { id: "hornero-moon-phase", label: "Moon Phase", side: "left", edge: "bottom", width: 320, height: 300, minWidth: 260, minHeight: 240 }
];

function ids() {
    return CATALOGUE.map(function (c) {
        return c.id;
    });
}

function entryFor(id) {
    for (var i = 0; i < CATALOGUE.length; i++)
        if (CATALOGUE[i].id === id)
            return CATALOGUE[i];
    return null;
}

function _num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
}

function _snapDown(v) {
    return Math.floor(v / GRID) * GRID;
}

// Catalogue entries with the installed manifest's size hints applied.
// `hints` is {id: {width, height, minWidth, minHeight}} (all optional).
function items(hints) {
    var out = [];
    for (var i = 0; i < CATALOGUE.length; i++) {
        var base = CATALOGUE[i];
        var hint = hints && hints[base.id] ? hints[base.id] : {};
        var minW = Math.max(80, Math.round(_num(hint.minWidth, base.minWidth)));
        var minH = Math.max(80, Math.round(_num(hint.minHeight, base.minHeight)));
        out.push({
            id: base.id,
            label: base.label,
            side: base.side,
            edge: base.edge,
            priority: i,
            minWidth: minW,
            minHeight: minH,
            width: Math.max(minW, Math.round(_num(hint.width, base.width))),
            height: Math.max(minH, Math.round(_num(hint.height, base.height)))
        });
    }
    return out;
}

// Widgets are never shorter than their content: `need` is
// {id: measured frame height} reported by the host from each loaded
// widget's implicit height. It raises minHeight and height (snapped up to
// the grid); it never lowers anything, so the solver converges.
function fitMeasured(list, need) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var it = list[i];
        var n = need ? _num(need[it.id], 0) : 0;
        if (n > it.minHeight) {
            var snapped = Math.ceil(n / GRID) * GRID;
            it = Object.assign({}, it, { minHeight: snapped, height: Math.max(it.height, snapped) });
        }
        out.push(it);
    }
    return out;
}

function _hit(a, b, gap) {
    return a.x < b.x + b.width + gap && b.x < a.x + a.width + gap && a.y < b.y + b.height + gap && b.y < a.y + a.height + gap;
}

function _rects(raw) {
    var out = [];
    if (!Array.isArray(raw))
        return out;
    for (var i = 0; i < raw.length; i++) {
        var r = raw[i];
        if (!r || typeof r !== "object")
            continue;
        var w = _num(r.width, 0);
        var h = _num(r.height, 0);
        if (w > 0 && h > 0)
            out.push({ x: _num(r.x, 0), y: _num(r.y, 0), width: w, height: h });
    }
    return out;
}

// Validated user geometry: {fx, fy, width, height}, clamped to the area
// and to the item's minimum size. null when nothing usable is stored.
function cleanGeometry(raw, item, area) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var hasPos = typeof raw.fx === "number" && isFinite(raw.fx) && typeof raw.fy === "number" && isFinite(raw.fy);
    var hasSize = Number.isInteger(raw.width) && Number.isInteger(raw.height);
    if (!hasPos && !hasSize)
        return null;
    var w = hasSize ? Math.min(area.width, Math.max(item.minWidth, raw.width)) : null;
    var h = hasSize ? Math.min(area.height, Math.max(item.minHeight, raw.height)) : null;
    return {
        fx: hasPos ? Math.max(0, Math.min(1, raw.fx)) : null,
        fy: hasPos ? Math.max(0, Math.min(1, raw.fy)) : null,
        width: w,
        height: h
    };
}

// Lays the deck out on one screen.
//
// input:
//   area      {width, height}    the screen's widget area (bar excluded)
//   items     items(hints) subset the installed set can show (order = priority)
//   hidden    [id]               the person turned these off for this mode
//   reserved  [{x, y, width, height}]  zones to keep clear (desktop clock)
//   saved     {id: {fx, fy, width, height}}  the person's own geometry
//
// returns { placements: [{id, x, y, width, height, fx, fy, source}],
//           dropped:    [{id, reason}] }
//   source "deck" = solver default, "user" = the person's saved geometry.
//   reason  "hidden" | "no-room".
function compose(input) {
    var area = { width: Math.max(0, _num(input && input.area && input.area.width, 0)), height: Math.max(0, _num(input && input.area && input.area.height, 0)) };
    var list = input && Array.isArray(input.items) ? input.items.slice() : [];
    var hidden = input && Array.isArray(input.hidden) ? input.hidden : [];
    var reserved = _rects(input && input.reserved);
    var saved = input && input.saved && typeof input.saved === "object" ? input.saved : {};

    var placements = [];
    var dropped = [];
    var placed = [];
    // Rails fill from both ends; `top`/`bottom` are the free cursors.
    var rails = {
        left: { width: 0, top: 0, bottom: area.height },
        right: { width: 0, top: 0, bottom: area.height }
    };

    list.sort(function (a, b) {
        return a.priority - b.priority;
    });

    // Pass 1: the person's own geometry is placed first, so the default
    // rails flow around it instead of under it.
    var pending = [];
    for (var i = 0; i < list.length; i++) {
        var item = list[i];
        if (hidden.indexOf(item.id) >= 0) {
            dropped.push({ id: item.id, reason: "hidden" });
            continue;
        }
        var geo = cleanGeometry(saved[item.id], item, area);
        if (geo && geo.fx !== null && geo.fy !== null) {
            var uw = geo.width !== null ? geo.width : Math.min(area.width, item.width);
            var uh = geo.height !== null ? geo.height : Math.min(area.height, item.height);
            var userRect = {
                id: item.id,
                x: Math.round(geo.fx * Math.max(0, area.width - uw)),
                y: Math.round(geo.fy * Math.max(0, area.height - uh)),
                width: uw,
                height: uh,
                source: "user"
            };
            placed.push(userRect);
            placements.push(userRect);
        } else {
            pending.push({ item: item, geo: geo });
        }
    }

    // Pass 2: defaults by priority, onto the rails.
    for (var q = 0; q < pending.length; q++) {
        var cand = pending[q];
        var sides = cand.item.side === "left" ? ["left", "right"] : ["right", "left"];
        var rect = null;
        for (var s = 0; s < sides.length && !rect; s++)
            rect = _tryRail(cand.item, cand.geo, sides[s], rails, area, reserved, placed);
        if (!rect) {
            dropped.push({ id: cand.item.id, reason: "no-room" });
            continue;
        }
        placed.push(rect);
        placements.push(rect);
    }

    for (var p = 0; p < placements.length; p++) {
        var pl = placements[p];
        var freeW = area.width - pl.width;
        var freeH = area.height - pl.height;
        pl.fx = freeW > 0 ? Math.round(pl.x / freeW * 10000) / 10000 : 0;
        pl.fy = freeH > 0 ? Math.round(pl.y / freeH * 10000) / 10000 : 0;
    }
    return { placements: placements, dropped: dropped };
}

function _tryRail(item, geo, side, rails, area, reserved, placed) {
    var rail = rails[side];
    var other = rails[side === "left" ? "right" : "left"];
    var wantW = geo && geo.width !== null ? geo.width : item.width;
    var wantH = geo && geo.height !== null ? geo.height : item.height;
    // Widest column this rail may grow to while the other rail keeps its
    // own and the centre stays open.
    var avail = Math.max(area.width - other.width - minCentre(area.width), rail.width);
    var w = Math.min(wantW, avail);
    if (w < item.minWidth)
        return null;
    w = Math.max(item.minWidth, _snapDown(w));

    var fromTop = item.edge !== "bottom";
    for (var attempt = 0; attempt < 12; attempt++) {
        var room = rail.bottom - rail.top;
        var h = Math.min(wantH, room);
        if (h < item.minHeight)
            return null;
        h = Math.max(item.minHeight, _snapDown(h));
        var y = fromTop ? rail.top : rail.bottom - h;
        var x = side === "left" ? 0 : area.width - w;
        var rect = { id: item.id, x: x, y: y, width: w, height: h, source: "deck" };
        var blocker = null;
        var others = reserved.concat(placed);
        for (var b = 0; b < others.length && !blocker; b++)
            if (_hit(rect, others[b], GAP))
                blocker = others[b];
        if (!blocker) {
            if (fromTop)
                rail.top = y + h + GAP;
            else
                rail.bottom = y - GAP;
            rail.width = Math.max(rail.width, w);
            return rect;
        }
        // Step past the blocker along the rail and retry.
        if (fromTop)
            rail.top = Math.max(rail.top, blocker.y + blocker.height + GAP);
        else
            rail.bottom = Math.min(rail.bottom, blocker.y - GAP);
    }
    return null;
}

// ---- Per-mode overrides ------------------------------------------------
//
// Stored in shell.json under experience.deck:
//   hidden:   { "<mode>": ["<pluginId>", ...] }
//   geometry: { "<mode>": { "<screen>": { "<pluginId>": {fx, fy, width, height} } } }
// Both are written only when the person changes something and are cleared
// by a deck reset (one screen or the whole mode).

var MODES = ["focus", "everyday", "signal", "gaming", "studio"];

function _isObject(v) {
    return v && typeof v === "object" && !Array.isArray(v);
}

function _validId(id) {
    return typeof id === "string" && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id);
}

function sanitizeDeck(raw) {
    var out = { hidden: {}, geometry: {} };
    if (!_isObject(raw))
        return out;
    var mi;
    for (mi = 0; mi < MODES.length; mi++) {
        var mode = MODES[mi];
        if (_isObject(raw.hidden) && Array.isArray(raw.hidden[mode])) {
            var seen = [];
            for (var i = 0; i < raw.hidden[mode].length; i++) {
                var id = raw.hidden[mode][i];
                if (_validId(id) && seen.indexOf(id) < 0)
                    seen.push(id);
            }
            if (seen.length > 0)
                out.hidden[mode] = seen;
        }
        var screens = _isObject(raw.geometry) ? raw.geometry[mode] : null;
        if (!_isObject(screens))
            continue;
        var cleanScreens = {};
        for (var screen in screens) {
            if (!Object.prototype.hasOwnProperty.call(screens, screen) || !_isObject(screens[screen]))
                continue;
            var cleanEntries = {};
            for (var pid in screens[screen]) {
                if (!Object.prototype.hasOwnProperty.call(screens[screen], pid) || !_validId(pid))
                    continue;
                var g = screens[screen][pid];
                if (!_isObject(g))
                    continue;
                var e = {};
                if (typeof g.fx === "number" && isFinite(g.fx) && typeof g.fy === "number" && isFinite(g.fy)) {
                    e.fx = Math.max(0, Math.min(1, Math.round(g.fx * 10000) / 10000));
                    e.fy = Math.max(0, Math.min(1, Math.round(g.fy * 10000) / 10000));
                }
                if (Number.isInteger(g.width) && Number.isInteger(g.height) && g.width >= 80 && g.width <= 4000 && g.height >= 80 && g.height <= 4000) {
                    e.width = g.width;
                    e.height = g.height;
                }
                if (Object.keys(e).length > 0)
                    cleanEntries[pid] = e;
            }
            if (Object.keys(cleanEntries).length > 0)
                cleanScreens[screen] = cleanEntries;
        }
        if (Object.keys(cleanScreens).length > 0)
            out.geometry[mode] = cleanScreens;
    }
    return out;
}

function hiddenFor(deck, mode) {
    return sanitizeDeck(deck).hidden[mode] || [];
}

function savedFor(deck, mode, screen) {
    var g = sanitizeDeck(deck).geometry[mode];
    return g && g[screen || "default"] ? g[screen || "default"] : {};
}

function setHidden(deck, mode, id, hide) {
    if (MODES.indexOf(mode) < 0 || !_validId(id))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    var next = sanitizeDeck(deck);
    var list = (next.hidden[mode] || []).filter(function (x) {
        return x !== id;
    });
    if (hide)
        list.push(id);
    if (list.length > 0)
        next.hidden[mode] = list;
    else
        delete next.hidden[mode];
    return { ok: true, deck: next, error: "" };
}

function setGeometry(deck, mode, screen, id, geometry) {
    if (MODES.indexOf(mode) < 0 || !_validId(id))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    var next = sanitizeDeck(deck);
    var probe = { hidden: {}, geometry: {} };
    probe.geometry[mode] = {};
    probe.geometry[mode][screen || "default"] = {};
    probe.geometry[mode][screen || "default"][id] = geometry;
    var clean = sanitizeDeck(probe).geometry[mode];
    if (!clean)
        return { ok: false, deck: next, error: "invalid geometry" };
    if (!next.geometry[mode])
        next.geometry[mode] = {};
    var key = screen || "default";
    next.geometry[mode][key] = Object.assign({}, next.geometry[mode][key] || {}, clean[key]);
    return { ok: true, deck: next, error: "" };
}

// Restores the factory deck: for one screen, or (screen omitted) the whole
// mode, including which widgets were turned off.
function reset(deck, mode, screen) {
    var next = sanitizeDeck(deck);
    if (screen) {
        if (next.geometry[mode]) {
            delete next.geometry[mode][screen];
            if (Object.keys(next.geometry[mode]).length === 0)
                delete next.geometry[mode];
        }
        return next;
    }
    delete next.hidden[mode];
    delete next.geometry[mode];
    return next;
}

function isCustomised(deck, mode) {
    var d = sanitizeDeck(deck);
    return !!d.hidden[mode] || !!d.geometry[mode];
}

// Honest per-widget status for the Experience pane and the deck host.
// `installed` is {id: "ready" | "not-installed" | "untrusted" | "failed"}.
// state: shown | hidden | no-room | not-installed | untrusted | failed
function status(composition, installed, hidden) {
    var out = [];
    var shown = {};
    var dropped = {};
    for (var i = 0; i < composition.placements.length; i++)
        shown[composition.placements[i].id] = true;
    for (var d = 0; d < composition.dropped.length; d++)
        dropped[composition.dropped[d].id] = composition.dropped[d].reason;
    for (var c = 0; c < CATALOGUE.length; c++) {
        var id = CATALOGUE[c].id;
        var avail = installed && installed[id] ? installed[id] : "not-installed";
        var state;
        if (avail !== "ready")
            state = avail;
        else if (hidden.indexOf(id) >= 0)
            state = "hidden";
        else if (shown[id])
            state = "shown";
        else
            state = dropped[id] === "no-room" ? "no-room" : "hidden";
        out.push({ id: id, label: CATALOGUE[c].label, state: state });
    }
    return out;
}
