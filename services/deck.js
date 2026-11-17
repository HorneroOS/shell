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
    { id: "hornero-system-insight", glyph: "cpu", label: "System Insight", side: "right", edge: "top", width: 520, height: 360, minWidth: 380, minHeight: 240 },
    { id: "hornero-network-scope", glyph: "wifi", label: "Network Scope", side: "left", edge: "top", width: 440, height: 340, minWidth: 320, minHeight: 240 },
    { id: "hornero-audio-deck", glyph: "volume", label: "Audio Deck", side: "left", edge: "bottom", width: 420, height: 300, minWidth: 320, minHeight: 220 },
    { id: "hornero-calendar", glyph: "calendar", label: "Calendar", side: "right", edge: "top", width: 320, height: 420, minWidth: 260, minHeight: 340 },
    { id: "hornero-agenda", glyph: "list", label: "Agenda", side: "right", edge: "bottom", width: 320, height: 340, minWidth: 260, minHeight: 280 },
    { id: "hornero-moon-phase", glyph: "moon", label: "Moon Phase", side: "left", edge: "bottom", width: 320, height: 300, minWidth: 260, minHeight: 240 }
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
// `prefs` is the person's per-mode choice {anchors: {id: "left-top"...},
// order: [id]} (see anchorsFor/orderFor); it changes the preferred rail,
// the end of the rail a widget stacks from, and the priority order, and
// nothing else. Without prefs the factory composition is returned.
function items(hints, prefs) {
    var anchors = prefs && _isObject(prefs.anchors) ? prefs.anchors : {};
    var order = effectiveOrder(prefs && prefs.order);
    var out = [];
    for (var i = 0; i < CATALOGUE.length; i++) {
        var base = CATALOGUE[i];
        var hint = hints && hints[base.id] ? hints[base.id] : {};
        var minW = Math.max(80, Math.round(_num(hint.minWidth, base.minWidth)));
        var minH = Math.max(80, Math.round(_num(hint.minHeight, base.minHeight)));
        var side = base.side;
        var edge = base.edge;
        var st = prefs && _isObject(prefs.style) && _isObject(prefs.style[base.id]) ? prefs.style[base.id] : {};
        var factor = SIZE_FACTOR[st.size] || 1;
        if (ANCHORS.indexOf(anchors[base.id]) >= 0) {
            var parts = anchors[base.id].split("-");
            side = parts[0];
            edge = parts[1];
        }
        out.push({
            id: base.id,
            label: base.label,
            glyph: base.glyph,
            side: side,
            edge: edge,
            priority: order.indexOf(base.id),
            minWidth: minW,
            minHeight: minH,
            width: Math.max(minW, Math.round(_num(hint.width, base.width) * factor)),
            height: Math.max(minH, Math.round(_num(hint.height, base.height) * factor))
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
        // A blocker further along the rail (the Companion's perch, a widget
        // the person placed): shrink to the room before it when the item can
        // live with that, instead of giving up the whole rail.
        if (fromTop && blocker.y > y) {
            var above = _snapDown(blocker.y - GAP - y);
            if (above >= item.minHeight && above < wantH) {
                wantH = above;
                continue;
            }
        } else if (!fromTop && blocker.y + blocker.height < y + h) {
            var below = _snapDown(rail.bottom - (blocker.y + blocker.height + GAP));
            if (below >= item.minHeight && below < wantH) {
                wantH = below;
                continue;
            }
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
var MODES = ["focus", "everyday", "signal", "gaming", "studio"];
// Where a widget may be anchored: preferred rail, then the end of the rail
// it stacks from. The solver still moves it to the other rail when the
// preferred one is full, and never covers the bar or a reserved zone.
var ANCHORS = ["left-top", "left-bottom", "right-top", "right-bottom"];
// Per-widget appearance (all optional; the default is the factory look):
//   opacity 0.3-1   frame background opacity (content stays opaque)
//   size    small | normal | large   scales the default frame
//   accent  default | signal | cue   header tick and frame outline colour
//   density compact | cozy | roomy   inner padding
var STYLE_ENUMS = {
    size: ["small", "normal", "large"],
    accent: ["default", "signal", "cue"],
    density: ["compact", "cozy", "roomy"]
};
var STYLE_FACTORY = { opacity: 1, size: "normal", accent: "default", density: "cozy" };
var SIZE_FACTOR = { small: 0.85, normal: 1, large: 1.2 };
var MAX_PRESETS = 5;
var PRESET_NAME = /^[A-Za-z0-9][A-Za-z0-9 _-]{0,23}$/;

function _isObject(v) {
    return v && typeof v === "object" && !Array.isArray(v);
}

function _validId(id) {
    return typeof id === "string" && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id);
}

function _has(o, k) {
    return Object.prototype.hasOwnProperty.call(o, k);
}

function _cleanIds(list) {
    var seen = [];
    if (!Array.isArray(list))
        return seen;
    for (var i = 0; i < list.length; i++)
        if (_validId(list[i]) && seen.indexOf(list[i]) < 0)
            seen.push(list[i]);
    return seen;
}

function _cleanGeometryMap(screens) {
    var cleanScreens = {};
    if (!_isObject(screens))
        return cleanScreens;
    for (var screen in screens) {
        if (!_has(screens, screen) || !_isObject(screens[screen]))
            continue;
        var cleanEntries = {};
        for (var pid in screens[screen]) {
            if (!_has(screens[screen], pid) || !_validId(pid))
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
    return cleanScreens;
}

function _cleanAnchors(raw) {
    var out = {};
    if (!_isObject(raw))
        return out;
    for (var id in raw)
        if (_has(raw, id) && _validId(id) && ANCHORS.indexOf(raw[id]) >= 0)
            out[id] = raw[id];
    return out;
}

function _cleanStyleEntry(raw) {
    var out = {};
    if (!_isObject(raw))
        return out;
    if (typeof raw.opacity === "number" && isFinite(raw.opacity)) {
        var o = Math.max(0.3, Math.min(1, Math.round(raw.opacity * 100) / 100));
        if (o !== 1)
            out.opacity = o;
    }
    for (var key in STYLE_ENUMS)
        if (STYLE_ENUMS[key].indexOf(raw[key]) >= 0 && raw[key] !== STYLE_FACTORY[key])
            out[key] = raw[key];
    return out;
}

function _cleanStyle(raw) {
    var out = {};
    if (!_isObject(raw))
        return out;
    for (var id in raw) {
        if (!_has(raw, id) || !_validId(id))
            continue;
        var e = _cleanStyleEntry(raw[id]);
        if (Object.keys(e).length > 0)
            out[id] = e;
    }
    return out;
}

// One mode's overrides: {hidden: [id], geometry: {screen: {id: geo}},
// anchors: {id: anchor}, order: [id]}. Empty parts are omitted, so the
// factory deck is {}.
function _cleanState(raw) {
    var out = {};
    if (!_isObject(raw))
        return out;
    var hidden = _cleanIds(raw.hidden);
    if (hidden.length > 0)
        out.hidden = hidden;
    var geometry = _cleanGeometryMap(raw.geometry);
    if (Object.keys(geometry).length > 0)
        out.geometry = geometry;
    var anchors = _cleanAnchors(raw.anchors);
    if (Object.keys(anchors).length > 0)
        out.anchors = anchors;
    var order = _cleanIds(raw.order);
    if (order.length > 0 && !_isDefaultOrder(order))
        out.order = order;
    var style = _cleanStyle(raw.style);
    if (Object.keys(style).length > 0)
        out.style = style;
    return out;
}

function _isDefaultOrder(order) {
    var def = ids();
    var eff = effectiveOrder(order);
    for (var i = 0; i < def.length; i++)
        if (def[i] !== eff[i])
            return false;
    return true;
}

// The catalogue order with the person's preferred order first; ids they
// never ordered keep their factory place after it.
function effectiveOrder(order) {
    var out = _cleanIds(order).filter(function (id) {
        return entryFor(id) !== null;
    });
    var def = ids();
    for (var i = 0; i < def.length; i++)
        if (out.indexOf(def[i]) < 0)
            out.push(def[i]);
    return out;
}

function _stateOf(deck, mode) {
    var d = _isObject(deck) ? deck : {};
    return _cleanState({
        hidden: _isObject(d.hidden) ? d.hidden[mode] : null,
        geometry: _isObject(d.geometry) ? d.geometry[mode] : null,
        anchors: _isObject(d.anchors) ? d.anchors[mode] : null,
        order: _isObject(d.order) ? d.order[mode] : null,
        style: _isObject(d.style) ? d.style[mode] : null
    });
}

// Stored in shell.json under experience.deck, per mode:
//   hidden:   { "<mode>": ["<pluginId>", ...] }
//   geometry: { "<mode>": { "<screen>": { "<pluginId>": {fx, fy, width, height} } } }
//   anchors:  { "<mode>": { "<pluginId>": "left-top" | ... } }
//   order:    { "<mode>": ["<pluginId>", ...] }   (priority, first wins)
//   style:    { "<mode>": { "<pluginId>": {opacity, size, accent, density} } }
//   presets:  { "<mode>": { "<name>": <one mode's state, as above> } }
// Everything is written only when the person changes something and is
// cleared by a deck reset (presets are kept: they are saved on purpose).
function sanitizeDeck(raw) {
    var out = { hidden: {}, geometry: {} };
    if (!_isObject(raw))
        return out;
    for (var mi = 0; mi < MODES.length; mi++) {
        var mode = MODES[mi];
        var st = _stateOf(raw, mode);
        if (st.hidden)
            out.hidden[mode] = st.hidden;
        if (st.geometry)
            out.geometry[mode] = st.geometry;
        if (st.anchors) {
            out.anchors = out.anchors || {};
            out.anchors[mode] = st.anchors;
        }
        if (st.order) {
            out.order = out.order || {};
            out.order[mode] = st.order;
        }
        if (st.style) {
            out.style = out.style || {};
            out.style[mode] = st.style;
        }
        var presets = _isObject(raw.presets) ? raw.presets[mode] : null;
        if (_isObject(presets)) {
            var names = Object.keys(presets).filter(function (n) {
                return PRESET_NAME.test(n);
            }).slice(0, MAX_PRESETS);
            for (var ni = 0; ni < names.length; ni++) {
                out.presets = out.presets || {};
                out.presets[mode] = out.presets[mode] || {};
                out.presets[mode][names[ni]] = _cleanState(presets[names[ni]]);
            }
        }
    }
    return out;
}

function _withState(deck, mode, st) {
    var next = sanitizeDeck(deck);
    delete next.hidden[mode];
    delete next.geometry[mode];
    if (next.anchors)
        delete next.anchors[mode];
    if (next.order)
        delete next.order[mode];
    if (next.style)
        delete next.style[mode];
    var clean = _cleanState(st);
    if (clean.hidden)
        next.hidden[mode] = clean.hidden;
    if (clean.geometry)
        next.geometry[mode] = clean.geometry;
    if (clean.anchors) {
        next.anchors = next.anchors || {};
        next.anchors[mode] = clean.anchors;
    }
    if (clean.order) {
        next.order = next.order || {};
        next.order[mode] = clean.order;
    }
    if (clean.style) {
        next.style = next.style || {};
        next.style[mode] = clean.style;
    }
    if (next.style && Object.keys(next.style).length === 0)
        delete next.style;
    if (next.anchors && Object.keys(next.anchors).length === 0)
        delete next.anchors;
    if (next.order && Object.keys(next.order).length === 0)
        delete next.order;
    return next;
}

function hiddenFor(deck, mode) {
    return sanitizeDeck(deck).hidden[mode] || [];
}

function savedFor(deck, mode, screen) {
    var g = sanitizeDeck(deck).geometry[mode];
    return g && g[screen || "default"] ? g[screen || "default"] : {};
}

function anchorsFor(deck, mode) {
    var a = sanitizeDeck(deck).anchors;
    return a && a[mode] ? a[mode] : {};
}

function orderFor(deck, mode) {
    var o = sanitizeDeck(deck).order;
    return effectiveOrder(o && o[mode] ? o[mode] : []);
}

function styleFor(deck, mode) {
    var s = sanitizeDeck(deck).style;
    return s && s[mode] ? s[mode] : {};
}

// One widget's effective appearance: factory values under the overrides.
function styleOf(deck, mode, id) {
    return Object.assign({}, STYLE_FACTORY, styleFor(deck, mode)[id] || {});
}

// The person's per-mode layout preferences, as items() takes them.
function prefsFor(deck, mode) {
    return { anchors: anchorsFor(deck, mode), order: orderFor(deck, mode), style: styleFor(deck, mode) };
}

// key: opacity | size | accent | density; value "" (or null) restores the
// factory value of that key.
function setStyle(deck, mode, id, key, value) {
    if (MODES.indexOf(mode) < 0 || !_validId(id) || entryFor(id) === null)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    if (key !== "opacity" && !_has(STYLE_ENUMS, key))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid style key: " + key };
    var st = _stateOf(deck, mode);
    var entry = Object.assign({}, (st.style || {})[id] || {});
    if (value === "" || value === null || value === undefined) {
        delete entry[key];
    } else if (key === "opacity") {
        if (typeof value !== "number" || !isFinite(value) || value < 0.3 || value > 1)
            return { ok: false, deck: sanitizeDeck(deck), error: "opacity must be between 0.3 and 1" };
        entry.opacity = value;
    } else {
        if (STYLE_ENUMS[key].indexOf(value) < 0)
            return { ok: false, deck: sanitizeDeck(deck), error: "invalid " + key + ": " + value };
        entry[key] = value;
    }
    st.style = Object.assign({}, st.style || {});
    st.style[id] = entry;
    return { ok: true, deck: _withState(deck, mode, st), error: "" };
}

function setHidden(deck, mode, id, hide) {
    if (MODES.indexOf(mode) < 0 || !_validId(id))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    var st = _stateOf(deck, mode);
    var list = (st.hidden || []).filter(function (x) {
        return x !== id;
    });
    if (hide)
        list.push(id);
    st.hidden = list;
    return { ok: true, deck: _withState(deck, mode, st), error: "" };
}

function setGeometry(deck, mode, screen, id, geometry) {
    if (MODES.indexOf(mode) < 0 || !_validId(id))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    var probe = {};
    probe[screen || "default"] = {};
    probe[screen || "default"][id] = geometry;
    var clean = _cleanGeometryMap(probe);
    if (!clean[screen || "default"])
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid geometry" };
    var st = _stateOf(deck, mode);
    var key = screen || "default";
    st.geometry = st.geometry || {};
    st.geometry[key] = Object.assign({}, st.geometry[key] || {}, clean[key]);
    return { ok: true, deck: _withState(deck, mode, st), error: "" };
}

// anchor "" removes the preference (back to the factory rail).
function setAnchor(deck, mode, id, anchor) {
    if (MODES.indexOf(mode) < 0 || !_validId(id) || entryFor(id) === null)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    if (anchor !== "" && ANCHORS.indexOf(anchor) < 0)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid anchor: " + anchor };
    var st = _stateOf(deck, mode);
    st.anchors = Object.assign({}, st.anchors || {});
    if (anchor === "")
        delete st.anchors[id];
    else
        st.anchors[id] = anchor;
    return { ok: true, deck: _withState(deck, mode, st), error: "" };
}

// Moves one widget up (delta -1: earlier = higher priority, placed first)
// or down the priority order.
function moveWidget(deck, mode, id, delta) {
    if (MODES.indexOf(mode) < 0 || entryFor(id) === null)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode or widget id" };
    var order = orderFor(deck, mode);
    var at = order.indexOf(id);
    var to = Math.max(0, Math.min(order.length - 1, at + (delta < 0 ? -1 : 1)));
    order.splice(at, 1);
    order.splice(to, 0, id);
    var st = _stateOf(deck, mode);
    st.order = order;
    return { ok: true, deck: _withState(deck, mode, st), error: "" };
}

// Restores the factory deck: for one screen, or (screen omitted) the whole
// mode, including which widgets were turned off, their anchors and order.
// Saved presets are kept.
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
    return _withState(next, mode, {});
}

function isCustomised(deck, mode) {
    return Object.keys(_stateOf(deck, mode)).length > 0;
}

// ---- Presets -----------------------------------------------------------
//
// Built-in presets choose which instruments are on and, for the cozy ones,
// a soft look (the rest of the mode's overrides return to factory). Saved presets snapshot everything
// the person customised in that mode and are stored per mode.

var BUILTIN_PRESETS = [
    { id: "all", label: "Everything", show: null },
    { id: "cozy", label: "Cozy corner", show: ["hornero-calendar", "hornero-agenda", "hornero-moon-phase"], style: { opacity: 0.82, size: "large", accent: "cue", density: "roomy" } },
    { id: "kawaii-night", label: "Kawaii night", show: null, style: { opacity: 0.7, accent: "signal", density: "roomy" } },
    { id: "monitor", label: "System monitor", show: ["hornero-system-insight", "hornero-network-scope", "hornero-audio-deck"] },
    { id: "time", label: "Time and sky", show: ["hornero-calendar", "hornero-agenda", "hornero-moon-phase"] },
    { id: "minimal", label: "System Insight only", show: ["hornero-system-insight"] }
];

function builtinPresets() {
    return BUILTIN_PRESETS.map(function (p) {
        return { id: p.id, label: p.label, show: p.show ? p.show.slice() : ids(), style: p.style ? Object.assign({}, p.style) : null };
    });
}

function applyBuiltin(deck, mode, presetId) {
    if (MODES.indexOf(mode) < 0)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode" };
    for (var i = 0; i < BUILTIN_PRESETS.length; i++) {
        if (BUILTIN_PRESETS[i].id !== presetId)
            continue;
        var show = BUILTIN_PRESETS[i].show;
        var hidden = show ? ids().filter(function (id) {
            return show.indexOf(id) < 0;
        }) : [];
        var style = {};
        if (BUILTIN_PRESETS[i].style)
            ids().forEach(function (id) {
                style[id] = BUILTIN_PRESETS[i].style;
            });
        return { ok: true, deck: _withState(deck, mode, { hidden: hidden, style: style }), error: "" };
    }
    return { ok: false, deck: sanitizeDeck(deck), error: "unknown preset: " + presetId };
}

function presetNames(deck, mode) {
    var p = sanitizeDeck(deck).presets;
    return p && p[mode] ? Object.keys(p[mode]) : [];
}

function savePreset(deck, mode, name) {
    if (MODES.indexOf(mode) < 0)
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid mode" };
    if (typeof name !== "string" || !PRESET_NAME.test(name))
        return { ok: false, deck: sanitizeDeck(deck), error: "invalid preset name (letters, digits, space, - and _, up to 24)" };
    var names = presetNames(deck, mode);
    if (names.indexOf(name) < 0 && names.length >= MAX_PRESETS)
        return { ok: false, deck: sanitizeDeck(deck), error: "at most " + MAX_PRESETS + " saved presets per mode" };
    var next = sanitizeDeck(deck);
    next.presets = next.presets || {};
    next.presets[mode] = next.presets[mode] || {};
    next.presets[mode][name] = _stateOf(deck, mode);
    return { ok: true, deck: next, error: "" };
}

function applyPreset(deck, mode, name) {
    var p = sanitizeDeck(deck).presets;
    if (!p || !p[mode] || !_has(p[mode], name))
        return { ok: false, deck: sanitizeDeck(deck), error: "unknown preset: " + name };
    return { ok: true, deck: _withState(deck, mode, p[mode][name]), error: "" };
}

function deletePreset(deck, mode, name) {
    var next = sanitizeDeck(deck);
    if (!next.presets || !next.presets[mode] || !_has(next.presets[mode], name))
        return { ok: false, deck: next, error: "unknown preset: " + name };
    delete next.presets[mode][name];
    if (Object.keys(next.presets[mode]).length === 0)
        delete next.presets[mode];
    if (Object.keys(next.presets).length === 0)
        delete next.presets;
    return { ok: true, deck: next, error: "" };
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
