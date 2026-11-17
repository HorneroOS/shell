.pragma library

// Overflow policy for extension indicators in a bar island (shell#531).
//
// Pure model, executed under node by tests/test_bar_plugin_overflow.py.
// Every host (the Quick actions, clock and status islands) has a main-axis
// budget. Indicators are kept in priority order (highest first, declaration
// order breaks ties) until the budget is used; the first one that does not
// fit, and everything of lower priority, moves to the Extensions island
// instead of being painted over its neighbours. Strict priority keeps the
// result predictable: a small low-priority item never jumps the queue.

var DEFAULT_PRIORITY = 50;
var MIN_PRIORITY = 0;
var MAX_PRIORITY = 100;

function priorityOf(value) {
    if (typeof value !== "number")
        return DEFAULT_PRIORITY;
    var n = value;
    if (!isFinite(n) || Math.floor(n) !== n)
        return DEFAULT_PRIORITY;
    return Math.max(MIN_PRIORITY, Math.min(MAX_PRIORITY, n));
}

// An item wider than `max` is drawn `max` wide (the host elides it).
function clampWidth(width, max) {
    var w = Number(width);
    if (!(w > 0))
        return 0;
    return max > 0 ? Math.min(w, max) : w;
}

// items: [{id, width, priority}] in declaration order. `budget` <= 0 means
// unlimited. Items whose width is 0 (not loaded yet, or reporting nothing to
// show) take no room and are always kept. Returns {keep: [ids], overflow: [ids]}
// with both lists in declaration order.
function plan(items, budget, gap, maxItemWidth) {
    var list = (items || []).map(function (it, order) {
        return {
            id: it.id,
            order: order,
            width: clampWidth(it.width, maxItemWidth),
            priority: priorityOf(it.priority)
        };
    });
    if (!(budget > 0))
        return { keep: list.map(function (it) { return it.id; }), overflow: [] };
    var ranked = list.slice().sort(function (a, b) {
        return b.priority - a.priority || a.order - b.order;
    });
    var spent = 0;
    var used = 0;
    var overflowed = false;
    var drop = {};
    ranked.forEach(function (it) {
        if (it.width <= 0)
            return;
        if (!overflowed) {
            var next = spent + (used > 0 ? gap : 0) + it.width;
            if (next <= budget) {
                spent = next;
                used++;
                return;
            }
            overflowed = true;
        }
        drop[it.id] = true;
    });
    return {
        keep: list.filter(function (it) { return !drop[it.id]; }).map(function (it) { return it.id; }),
        overflow: list.filter(function (it) { return drop[it.id]; }).map(function (it) { return it.id; })
    };
}

// Main-axis budget of a host: a percentage of the bar's main axis.
function budgetFor(barMain, percent) {
    var m = Number(barMain);
    var p = Number(percent);
    if (!(m > 0) || !(p > 0))
        return 0;
    return Math.floor(m * Math.min(100, p) / 100);
}
