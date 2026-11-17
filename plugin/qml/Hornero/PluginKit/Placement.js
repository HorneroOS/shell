.pragma library

// Anchored-surface solver (RFC 0001 §4). One pure function places every
// popout, tooltip, menu and extension popover in the shell; nothing in
// here knows about QML items, so it is unit tested headless
// (tests/placement/placement.test.mjs).
//
// Coordinates are logical pixels in one global space (the compositor's
// layout space), so triggers on any monitor of a mixed-scale arrangement
// are solved the same way. `screen.scale` is the monitor's device pixel
// ratio and is only used to snap results to whole device pixels.
//
// solve(input) -> placement
//
// input:
//   trigger   {x, y, width, height}   live trigger rect (global). Omit or
//                                     null for a centred surface.
//   bar       owning bar or null:
//               edge       "top" | "bottom" | "left" | "right"
//               style      "attached" | "inset" | "floating" | "islands" | "dock"
//               thickness  visual thickness of the bar slab
//               margin     float gap between the screen edge and the slab
//               rect       optional slab/island rect (global); its inner
//                          edge wins over margin + thickness
//               floating   bool (style !== "attached" when omitted)
//               clear      bool (Cockpit Clear: no slab to attach to)
//   preferredSide  "below" | "above" | "right" | "left" for surfaces not
//                  owned by a bar (default "below")
//   previousSide   side used by the last solve of the same surface; a
//                  flipped surface stays flipped while it still fits
//                  there, so a live resize never oscillates
//   screen    {x, y, width, height, scale, reserved: {top, bottom, left, right}}
//             reserved = logical px taken from each edge by bars, frame
//   size      {width, height} preferred surface size
//   gutter    clearance from the usable rect (default 8 * uiScale)
//   uiScale   shell UI scale (default 1)
//   gap       distance between anchor line and surface. Default: 0 for a
//             bar-attached surface, 4 * uiScale otherwise.
//
// placement:
//   x, y, width, height   global rect, device-pixel snapped
//   localX, localY        the same, relative to the screen origin
//   side                  "below" | "above" | "right" | "left" | "center"
//   edge                  surface edge facing the anchor ("top" when the
//                         surface opens below its trigger), "" when centred
//   attached              flush against an attached bar (omit that border)
//   flipped               opened on the side opposite the preferred one
//   clamped               cross axis was shifted off the trigger centre
//   scroll                content exceeds the space: body must scroll
//   maxWidth, maxHeight   the largest rect that fits on the chosen side
//   origin {x, y}         surface-local point where motion originates:
//                         the trigger centre on the anchor edge
//   notch {start, length} trigger extent along the anchor edge,
//                         surface-local, clipped to the surface
//   travel {dx, dy}       unit vector pointing away from the anchor; the
//                         scan-in offsets content by -travel * distance
//   anchorLine            global coordinate of the anchor line

var SIDES = ["below", "above", "right", "left"];

function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : (fallback === undefined ? 0 : fallback);
}

function rectOf(r) {
    if (!r)
        return null;
    var w = Math.max(0, num(r.width));
    var h = Math.max(0, num(r.height));
    return {
        x: num(r.x),
        y: num(r.y),
        width: w,
        height: h
    };
}

function sideForEdge(edge) {
    switch (edge) {
    case "top":
        return "below";
    case "bottom":
        return "above";
    case "left":
        return "right";
    case "right":
        return "left";
    }
    return "";
}

function oppositeSide(side) {
    switch (side) {
    case "below":
        return "above";
    case "above":
        return "below";
    case "right":
        return "left";
    case "left":
        return "right";
    }
    return side;
}

function surfaceEdgeFor(side) {
    switch (side) {
    case "below":
        return "top";
    case "above":
        return "bottom";
    case "right":
        return "left";
    case "left":
        return "right";
    }
    return "";
}

function isHorizontalSide(side) {
    return side === "left" || side === "right";
}

function snap(v, scale) {
    var s = scale > 0 ? scale : 1;
    return Math.round(v * s) / s;
}

function clamp(v, lo, hi) {
    if (hi < lo)
        return lo;
    return Math.max(lo, Math.min(hi, v));
}

// Usable rect: the screen minus reserved edges.
function usableRect(screen) {
    var res = screen.reserved || {};
    var top = Math.max(0, num(res.top));
    var bottom = Math.max(0, num(res.bottom));
    var left = Math.max(0, num(res.left));
    var right = Math.max(0, num(res.right));
    return {
        x: screen.x + left,
        y: screen.y + top,
        width: Math.max(0, screen.width - left - right),
        height: Math.max(0, screen.height - top - bottom)
    };
}

// Inner edge (content-facing line) of the owning bar.
function barInnerLine(bar, screen) {
    var rect = rectOf(bar.rect);
    var thick = Math.max(0, num(bar.thickness));
    var margin = Math.max(0, num(bar.margin));
    switch (bar.edge) {
    case "top":
        return rect ? rect.y + rect.height : screen.y + margin + thick;
    case "bottom":
        return rect ? rect.y : screen.y + screen.height - margin - thick;
    case "left":
        return rect ? rect.x + rect.width : screen.x + margin + thick;
    case "right":
        return rect ? rect.x : screen.x + screen.width - margin - thick;
    }
    return 0;
}

// Anchor line for a side: where the surface's anchor edge sits before the gap.
function anchorLineFor(side, trigger, bar, screen, barSide) {
    if (bar && side === barSide)
        return barInnerLine(bar, screen);
    switch (side) {
    case "below":
        return trigger.y + trigger.height;
    case "above":
        return trigger.y;
    case "right":
        return trigger.x + trigger.width;
    case "left":
        return trigger.x;
    }
    return 0;
}

// Main-axis room on a side between the anchor line (+gap) and the usable
// rect minus the gutter.
function roomOn(side, line, gap, usable, gutter) {
    switch (side) {
    case "below":
        return usable.y + usable.height - gutter - (line + gap);
    case "above":
        return line - gap - (usable.y + gutter);
    case "right":
        return usable.x + usable.width - gutter - (line + gap);
    case "left":
        return line - gap - (usable.x + gutter);
    }
    return 0;
}

function centred(screen, size, usable, gutter) {
    var maxW = Math.max(0, usable.width - gutter * 2);
    var maxH = Math.max(0, usable.height - gutter * 2);
    var w = Math.min(size.width, maxW);
    var h = Math.min(size.height, maxH);
    var x = snap(usable.x + (usable.width - w) / 2, screen.scale);
    var y = snap(usable.y + (usable.height - h) / 2, screen.scale);
    return {
        x: x,
        y: y,
        width: w,
        height: h,
        localX: x - screen.x,
        localY: y - screen.y,
        side: "center",
        edge: "",
        attached: false,
        flipped: false,
        clamped: false,
        scroll: size.height > maxH || size.width > maxW,
        maxWidth: maxW,
        maxHeight: maxH,
        origin: {
            x: w / 2,
            y: h / 2
        },
        notch: {
            start: 0,
            length: 0
        },
        travel: {
            dx: 0,
            dy: 0
        },
        anchorLine: 0
    };
}

function solve(input) {
    input = input || {};
    var scr = input.screen || {};
    var screen = {
        x: num(scr.x),
        y: num(scr.y),
        width: Math.max(0, num(scr.width)),
        height: Math.max(0, num(scr.height)),
        scale: num(scr.scale, 1) > 0 ? num(scr.scale, 1) : 1,
        reserved: scr.reserved || {}
    };
    var uiScale = num(input.uiScale, 1) > 0 ? num(input.uiScale, 1) : 1;
    var gutter = input.gutter === undefined ? 8 * uiScale : Math.max(0, num(input.gutter));
    var size = {
        width: Math.max(0, num(input.size ? input.size.width : 0)),
        height: Math.max(0, num(input.size ? input.size.height : 0))
    };
    var usable = usableRect(screen);
    var trigger = rectOf(input.trigger);
    if (!trigger)
        return centred(screen, size, usable, gutter);

    var bar = input.bar && sideForEdge(input.bar.edge) ? input.bar : null;
    var barSide = bar ? sideForEdge(bar.edge) : "";
    var floating = bar ? (bar.floating === undefined ? (bar.style !== undefined && bar.style !== "attached") : !!bar.floating) : true;
    var clear = bar ? !!bar.clear : false;
    var attachable = bar !== null && !floating && !clear;
    var looseGap = input.gap === undefined ? 4 * uiScale : Math.max(0, num(input.gap));
    var preferred = barSide || (SIDES.indexOf(input.preferredSide) >= 0 ? input.preferredSide : "below");
    var other = oppositeSide(preferred);

    function gapFor(side) {
        // Flush only against the attached bar's own inner edge.
        return attachable && side === barSide ? 0 : looseGap;
    }

    var mainOf = function (side) {
        return isHorizontalSide(side) ? size.width : size.height;
    };
    var linePref = anchorLineFor(preferred, trigger, bar, screen, barSide);
    var lineOther = anchorLineFor(other, trigger, bar, screen, barSide);
    var roomPref = roomOn(preferred, linePref, gapFor(preferred), usable, gutter);
    var roomOther = roomOn(other, lineOther, gapFor(other), usable, gutter);
    var need = mainOf(preferred);

    var side = preferred;
    if (input.previousSide === other && need <= roomOther)
        side = other; // hysteresis: stay flipped while it still fits
    else if (need > roomPref && need <= roomOther)
        side = other; // flip once
    else if (need > roomPref && !bar && roomOther > roomPref && roomPref <= 0)
        side = other; // nothing fits, but the preferred side has no room at all

    var line = side === preferred ? linePref : lineOther;
    var gap = gapFor(side);
    var room = Math.max(0, side === preferred ? roomPref : roomOther);
    var horizontal = isHorizontalSide(side);

    // Cross axis: centre on the trigger, clamp to usable minus gutter.
    var crossStart = horizontal ? usable.y : usable.x;
    var crossLen = horizontal ? usable.height : usable.width;
    var crossMax = Math.max(0, crossLen - gutter * 2);
    var crossSize = Math.min(horizontal ? size.height : size.width, crossMax);
    var trigStart = horizontal ? trigger.y : trigger.x;
    var trigLen = horizontal ? trigger.height : trigger.width;
    var trigCentre = trigStart + trigLen / 2;
    var ideal = trigCentre - crossSize / 2;
    var crossPos = clamp(ideal, crossStart + gutter, crossStart + crossLen - gutter - crossSize);
    crossPos = snap(crossPos, screen.scale);

    var mainSize = Math.min(mainOf(side), room);
    var mainPos;
    switch (side) {
    case "below":
    case "right":
        mainPos = line + gap;
        break;
    default:
        mainPos = line - gap - mainSize;
    }
    mainPos = snap(mainPos, screen.scale);

    var w = horizontal ? mainSize : crossSize;
    var h = horizontal ? crossSize : mainSize;
    var x = horizontal ? mainPos : crossPos;
    var y = horizontal ? crossPos : mainPos;

    var originAlong = clamp(trigCentre - crossPos, 0, crossSize);
    var edge = surfaceEdgeFor(side);
    var origin;
    switch (edge) {
    case "top":
        origin = {
            x: originAlong,
            y: 0
        };
        break;
    case "bottom":
        origin = {
            x: originAlong,
            y: h
        };
        break;
    case "left":
        origin = {
            x: 0,
            y: originAlong
        };
        break;
    default:
        origin = {
            x: w,
            y: originAlong
        };
    }

    var nStart = clamp(trigStart - crossPos, 0, crossSize);
    var nEnd = clamp(trigStart + trigLen - crossPos, 0, crossSize);

    var travel = {
        dx: side === "right" ? 1 : side === "left" ? -1 : 0,
        dy: side === "below" ? 1 : side === "above" ? -1 : 0
    };

    return {
        x: x,
        y: y,
        width: w,
        height: h,
        localX: x - screen.x,
        localY: y - screen.y,
        side: side,
        edge: edge,
        attached: attachable && side === barSide,
        flipped: side !== preferred,
        clamped: Math.abs(crossPos - snap(ideal, screen.scale)) > 0.5 || crossSize < (horizontal ? size.height : size.width),
        scroll: mainOf(side) > room,
        maxWidth: horizontal ? room : crossMax,
        maxHeight: horizontal ? crossMax : room,
        origin: origin,
        notch: {
            start: nStart,
            length: Math.max(0, nEnd - nStart)
        },
        travel: travel,
        anchorLine: line
    };
}

// The collapsed frame a surface grows from: trigger-wide, zero-depth, on
// the anchor line (RFC §4 rule 4, visual language §11.1). Surface-local
// rects are relative to the final placement.
function seedRect(placement) {
    var p = placement;
    var len = p.notch.length > 0 ? p.notch.length : Math.min(24, p.edge === "left" || p.edge === "right" ? p.height : p.width);
    var start = p.notch.length > 0 ? p.notch.start : Math.max(0, (p.edge === "left" || p.edge === "right" ? p.origin.y : p.origin.x) - len / 2);
    switch (p.edge) {
    case "top":
        return {
            x: p.x + start,
            y: p.y,
            width: len,
            height: 0
        };
    case "bottom":
        return {
            x: p.x + start,
            y: p.y + p.height,
            width: len,
            height: 0
        };
    case "left":
        return {
            x: p.x,
            y: p.y + start,
            width: 0,
            height: len
        };
    case "right":
        return {
            x: p.x + p.width,
            y: p.y + start,
            width: 0,
            height: len
        };
    }
    return {
        x: p.x + p.width / 2,
        y: p.y + p.height / 2,
        width: 0,
        height: 0
    };
}
