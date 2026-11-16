// Unit tests for components/placement/Placement.js (RFC 0001 §4).
// Run: node --test tests/placement/  (wired into pytest by
// tests/test_placement_solver.py).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");

function load(rel) {
    const src = readFileSync(join(root, rel), "utf8").replace(/^\.pragma library\s*$/m, "");
    // QML ".pragma library" files are plain scripts: evaluate in a fresh
    // context and read the declared functions back off its global.
    const ctx = vm.createContext({});
    vm.runInContext(src, ctx, { filename: rel });
    // Results come from another realm: copy them into this one so
    // deepStrictEqual compares values, not prototypes.
    const local = {};
    for (const name of ["solve", "seedRect", "sideForEdge", "oppositeSide"])
        local[name] = (...args) => JSON.parse(JSON.stringify(ctx[name](...args)));
    return local;
}

const P = load("components/placement/Placement.js");

const FHD = { x: 0, y: 0, width: 1920, height: 1080, scale: 1 };
const EPS = 1e-6;

function screen(base, reserved) {
    return { ...base, reserved: reserved ?? {} };
}

function bar(edge, style = "attached", extra = {}) {
    const thickness = edge === "top" || edge === "bottom" ? (edge === "top" ? 36 : 30) : 40;
    return { edge, style, thickness, margin: style === "attached" ? 0 : 8, ...extra };
}

// A trigger inside a bar slab: `along` is the main-axis position of its
// centre on that bar, `len` its length.
function triggerOn(scr, b, along, len = 32) {
    const t = b.thickness;
    const m = b.margin ?? 0;
    switch (b.edge) {
    case "top":
        return { x: scr.x + along - len / 2, y: scr.y + m + 2, width: len, height: t - 4 };
    case "bottom":
        return { x: scr.x + along - len / 2, y: scr.y + scr.height - m - t + 2, width: len, height: t - 4 };
    case "left":
        return { x: scr.x + m + 2, y: scr.y + along - len / 2, width: t - 4, height: len };
    default:
        return { x: scr.x + scr.width - m - t + 2, y: scr.y + along - len / 2, width: t - 4, height: len };
    }
}

function reservedFor(b) {
    const inner = (b.margin ?? 0) + b.thickness;
    return { top: 0, bottom: 0, left: 0, right: 0, [b.edge]: inner };
}

function isSnapped(v, scale) {
    const k = v * scale;
    return Math.abs(k - Math.round(k)) < 1e-6;
}

test("top attached Cockpit rail: opens down, flush, centred on the trigger", () => {
    const b = bar("top");
    const trig = { x: 1700, y: 2, width: 36, height: 32 };
    const p = P.solve({ trigger: trig, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 360, height: 300 } });
    assert.equal(p.side, "below");
    assert.equal(p.edge, "top");
    assert.equal(p.attached, true);
    assert.equal(p.flipped, false);
    assert.equal(p.y, 36, "flush with the bar's inner edge");
    assert.equal(p.x, 1718 - 180);
    assert.equal(p.width, 360);
    assert.equal(p.height, 300);
    assert.deepEqual(p.origin, { x: 180, y: 0 });
    assert.deepEqual(p.notch, { start: 162, length: 36 });
    assert.deepEqual(p.travel, { dx: 0, dy: 1 });
    assert.equal(p.scroll, false);
    assert.equal(p.clamped, false);
});

test("right corner clamps to the gutter and keeps origin/notch on the trigger", () => {
    const b = bar("top");
    const trig = { x: 1890, y: 2, width: 24, height: 32 };
    const p = P.solve({ trigger: trig, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 360, height: 200 } });
    assert.equal(p.x, 1920 - 8 - 360);
    assert.equal(p.clamped, true);
    assert.equal(p.origin.x, 1902 - p.x);
    assert.equal(p.notch.start, 1890 - p.x);
    assert.equal(p.notch.length, p.width - p.notch.start, "notch is clipped to the surface");
});

test("left corner clamps to the gutter", () => {
    const b = bar("top");
    const p = P.solve({ trigger: { x: 4, y: 2, width: 30, height: 32 }, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 400, height: 200 } });
    assert.equal(p.x, 8);
    assert.equal(p.clamped, true);
    assert.equal(p.origin.x, 19 - 8);
});

test("bottom strip opens up and sits on its inner edge", () => {
    const b = bar("bottom");
    const trig = triggerOn(FHD, b, 900);
    const p = P.solve({ trigger: trig, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 320, height: 240 } });
    assert.equal(p.side, "above");
    assert.equal(p.edge, "bottom");
    assert.equal(p.y + p.height, 1080 - 30);
    assert.equal(p.origin.y, p.height);
    assert.deepEqual(p.travel, { dx: 0, dy: -1 });
});

test("left rail opens right, right rail opens left (hornero-left / hornero-right)", () => {
    const l = bar("left");
    const pl = P.solve({ trigger: triggerOn(FHD, l, 540), bar: l, screen: screen(FHD, reservedFor(l)), size: { width: 340, height: 260 } });
    assert.equal(pl.side, "right");
    assert.equal(pl.edge, "left");
    assert.equal(pl.x, 40);
    assert.equal(pl.y, 540 - 130);
    assert.deepEqual(pl.origin, { x: 0, y: 130 });

    const r = bar("right");
    const pr = P.solve({ trigger: triggerOn(FHD, r, 1060), bar: r, screen: screen(FHD, reservedFor(r)), size: { width: 340, height: 260 } });
    assert.equal(pr.side, "left");
    assert.equal(pr.edge, "right");
    assert.equal(pr.x + pr.width, 1920 - 40);
    assert.equal(pr.y + pr.height, 1080 - 8, "clamped above the bottom gutter");
    assert.equal(pr.origin.x, pr.width);
    assert.equal(pr.clamped, true);
});

test("floating island keeps a 4 px gap and is not attached", () => {
    const b = bar("top", "floating");
    const trig = triggerOn(FHD, b, 960);
    const p = P.solve({ trigger: trig, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 300, height: 200 } });
    assert.equal(p.attached, false);
    assert.equal(p.y, 8 + 36 + 4);
    assert.equal(p.anchorLine, 44);
});

test("islands, inset and dock styles count as floating unless said otherwise", () => {
    for (const style of ["islands", "inset", "dock", "floating"]) {
        const b = { edge: "bottom", style, thickness: 30, margin: 6 };
        const p = P.solve({ trigger: triggerOn(FHD, b, 500), bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 200, height: 100 } });
        assert.equal(p.attached, false, style);
        assert.equal(p.y + p.height, 1080 - 6 - 30 - 4, style);
    }
});

test("Cockpit Clear bars never attach: their popouts are cards", () => {
    const b = bar("top", "attached", { clear: true });
    const p = P.solve({ trigger: triggerOn(FHD, b, 600), bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 300, height: 200 } });
    assert.equal(p.attached, false);
    assert.equal(p.y, 36 + 4);
});

test("bar rect inner edge wins over margin + thickness", () => {
    const b = { edge: "top", style: "islands", thickness: 36, margin: 8, rect: { x: 800, y: 6, width: 320, height: 40 } };
    const p = P.solve({ trigger: { x: 900, y: 10, width: 30, height: 30 }, bar: b, screen: screen(FHD, { top: 46 }), size: { width: 200, height: 100 } });
    assert.equal(p.y, 46 + 4);
});

test("Cockpit dual bar: top popout from top bar, bottom popout from bottom bar", () => {
    const top = bar("top");
    const bottom = bar("bottom");
    const scr = screen(FHD, { top: 36, bottom: 30 });
    const tall = { width: 360, height: 5000 };

    const pt = P.solve({ trigger: triggerOn(FHD, top, 1800), bar: top, screen: scr, size: tall });
    assert.equal(pt.side, "below");
    assert.equal(pt.y, 36);
    assert.equal(pt.maxHeight, 1080 - 30 - 8 - 36);
    assert.equal(pt.height, pt.maxHeight);
    assert.equal(pt.scroll, true);
    assert.equal(pt.flipped, false, "a bar surface never flips into its bar");

    const pb = P.solve({ trigger: triggerOn(FHD, bottom, 100), bar: bottom, screen: scr, size: tall });
    assert.equal(pb.side, "above");
    assert.equal(pb.y + pb.height, 1080 - 30);
    assert.equal(pb.y, 36 + 8);
    assert.equal(pb.scroll, true);
    assert.equal(pb.x, 8, "left corner clamp");

    // Ordinary sizes never touch the opposite bar.
    const small = { width: 320, height: 400 };
    const a = P.solve({ trigger: triggerOn(FHD, top, 960), bar: top, screen: scr, size: small });
    const c = P.solve({ trigger: triggerOn(FHD, bottom, 960), bar: bottom, screen: scr, size: small });
    assert.ok(a.y + a.height <= 1080 - 30 - 8);
    assert.ok(c.y >= 36 + 8);
});

test("vertical rail between horizontal bars clamps inside both reservations", () => {
    const l = bar("left");
    const scr = screen(FHD, { left: 40, top: 36, bottom: 30 });
    const p = P.solve({ trigger: triggerOn(FHD, l, 50), bar: l, screen: scr, size: { width: 300, height: 400 } });
    assert.equal(p.y, 36 + 8);
    const q = P.solve({ trigger: triggerOn(FHD, l, 1060), bar: l, screen: scr, size: { width: 300, height: 400 } });
    assert.equal(q.y + q.height, 1080 - 30 - 8);
});

test("non-bar surface flips once when the preferred side cannot fit", () => {
    const scr = screen(FHD);
    const trig = { x: 900, y: 1030, width: 40, height: 30 };
    const p = P.solve({ trigger: trig, preferredSide: "below", screen: scr, size: { width: 120, height: 32 } });
    assert.equal(p.side, "above");
    assert.equal(p.flipped, true);
    assert.equal(p.y + p.height, 1030 - 4);
    assert.equal(p.edge, "bottom");
});

test("flip hysteresis: a flipped surface stays flipped while it still fits", () => {
    const scr = screen(FHD);
    const trig = { x: 900, y: 500, width: 40, height: 30 };
    const fresh = P.solve({ trigger: trig, preferredSide: "below", screen: scr, size: { width: 120, height: 32 } });
    assert.equal(fresh.side, "below");
    const sticky = P.solve({ trigger: trig, preferredSide: "below", previousSide: "above", screen: scr, size: { width: 120, height: 32 } });
    assert.equal(sticky.side, "above");
    // ...but returns home once the flipped side no longer fits.
    const back = P.solve({ trigger: { ...trig, y: 20 }, preferredSide: "below", previousSide: "above", screen: scr, size: { width: 120, height: 32 } });
    assert.equal(back.side, "below");
});

test("left/right preferred sides flip horizontally", () => {
    const scr = screen(FHD);
    const p = P.solve({ trigger: { x: 1880, y: 500, width: 30, height: 30 }, preferredSide: "right", screen: scr, size: { width: 200, height: 40 } });
    assert.equal(p.side, "left");
    assert.equal(p.x + p.width, 1880 - 4);
    const q = P.solve({ trigger: { x: 10, y: 500, width: 30, height: 30 }, preferredSide: "left", screen: scr, size: { width: 200, height: 40 } });
    assert.equal(q.side, "right");
    assert.equal(q.x, 44);
});

test("neither side fits: keep the preferred side, clamp and scroll", () => {
    const scr = screen({ x: 0, y: 0, width: 1280, height: 720, scale: 1 });
    const p = P.solve({ trigger: { x: 600, y: 300, width: 40, height: 40 }, preferredSide: "below", screen: scr, size: { width: 300, height: 600 } });
    assert.equal(p.side, "below");
    assert.equal(p.scroll, true);
    assert.equal(p.height, 720 - 8 - 344);
    assert.equal(p.maxHeight, p.height);
});

test("surface wider than the usable width clamps to it", () => {
    const b = bar("top");
    const small = screen({ x: 0, y: 0, width: 300, height: 600, scale: 1 }, reservedFor(b));
    const p = P.solve({ trigger: { x: 140, y: 2, width: 20, height: 32 }, bar: b, screen: small, size: { width: 420, height: 100 } });
    assert.equal(p.width, 300 - 16);
    assert.equal(p.x, 8);
    assert.equal(p.maxWidth, 284);
    assert.ok(p.clamped);
});

test("mixed-scale multi-monitor: results stay on the trigger's screen and snap to its pixels", () => {
    // DP-1 1920x1080@1 at 0,0; HDMI 2560x1440@1.5 (1706.67x960 logical) at 1920,0.
    const s2 = { x: 1920, y: 0, width: 2560 / 1.5, height: 1440 / 1.5, scale: 1.5 };
    const b = bar("top");
    const trig = { x: 1920 + 1690, y: 2, width: 13.333, height: 32 };
    const p = P.solve({ trigger: trig, bar: b, screen: screen(s2, reservedFor(b)), size: { width: 333.3, height: 222.2 } });
    assert.ok(p.x >= s2.x + 8 - EPS);
    assert.ok(p.x + p.width <= s2.x + s2.width - 8 + 1 / 1.5);
    assert.ok(isSnapped(p.x, 1.5) && isSnapped(p.y, 1.5));
    assert.ok(Math.abs(p.localX - (p.x - 1920)) < EPS);
    assert.equal(p.localY, p.y);

    // Same trigger offset on DP-1 is unaffected by the other screen.
    const q = P.solve({ trigger: { ...trig, x: 900 }, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 300, height: 200 } });
    assert.ok(q.x >= 8 && q.x + q.width <= 1912);
});

test("screens at negative offsets and 2x scale", () => {
    const s = { x: -1920, y: -1080, width: 1920, height: 1080, scale: 2 };
    const b = bar("bottom");
    const trig = { x: -1920 + 3, y: -1080 + 1080 - 28, width: 24, height: 26 };
    const p = P.solve({ trigger: trig, bar: b, screen: screen(s, reservedFor(b)), size: { width: 300.25, height: 200 } });
    assert.equal(p.x, -1920 + 8);
    assert.equal(p.y + p.height, -30);
    assert.equal(p.localX, 8);
    assert.ok(isSnapped(p.x, 2));
});

test("live anchor: moving the trigger moves the surface continuously", () => {
    const b = bar("top");
    const scr = screen(FHD, reservedFor(b));
    let prev = null;
    for (let cx = 300; cx <= 1600; cx += 7) {
        const p = P.solve({ trigger: { x: cx - 16, y: 2, width: 32, height: 32 }, bar: b, screen: scr, size: { width: 360, height: 260 } });
        if (prev) {
            assert.ok(Math.abs(p.x - prev.x - 7) < 1, "tracks the trigger 1:1 while unclamped");
            assert.equal(p.y, prev.y);
        }
        assert.equal(p.origin.x, 180);
        prev = p;
    }
});

test("adjacent triggers: switching keeps the edge and only shifts the cross axis", () => {
    const b = bar("top");
    const scr = screen(FHD, reservedFor(b));
    const audio = P.solve({ trigger: { x: 1600, y: 2, width: 32, height: 32 }, bar: b, screen: scr, size: { width: 340, height: 220 } });
    const network = P.solve({ trigger: { x: 1640, y: 2, width: 32, height: 32 }, bar: b, screen: scr, size: { width: 380, height: 420 } });
    assert.equal(audio.edge, network.edge);
    assert.equal(audio.y, network.y);
    assert.notEqual(audio.x, network.x);
});

test("live anchor: bar reorder / monitor change re-solves without stale state", () => {
    const top = bar("top");
    const left = bar("left");
    const a = P.solve({ trigger: triggerOn(FHD, top, 500), bar: top, screen: screen(FHD, reservedFor(top)), size: { width: 300, height: 200 } });
    const b = P.solve({ trigger: triggerOn(FHD, left, 500), bar: left, screen: screen(FHD, reservedFor(left)), size: { width: 300, height: 200 } });
    assert.equal(a.side, "below");
    assert.equal(b.side, "right");
    const s2 = { x: 1920, y: 0, width: 1280, height: 720, scale: 1 };
    const c = P.solve({ trigger: triggerOn(s2, top, 500), bar: top, screen: screen(s2, reservedFor(top)), size: { width: 300, height: 200 } });
    assert.equal(c.localX, a.localX);
    assert.equal(c.x, a.x + 1920);
});

test("centred surface without a trigger (detached windows)", () => {
    const p = P.solve({ trigger: null, screen: screen(FHD, { top: 36, bottom: 30 }), size: { width: 800, height: 600 } });
    assert.equal(p.side, "center");
    assert.equal(p.x, 560);
    assert.equal(p.y, 36 + (1080 - 66 - 600) / 2);
});

test("garbage input never throws and never yields NaN", () => {
    const cases = [
        {},
        { trigger: { x: NaN, y: "a", width: -5, height: undefined } },
        { trigger: { x: 1, y: 1, width: 1, height: 1 }, bar: { edge: "diagonal" }, screen: { width: 0, height: 0 } },
        { trigger: { x: 1, y: 1, width: 1, height: 1 }, bar: { edge: "top", thickness: "x" }, screen: { width: 100, height: 100, scale: 0 }, size: { width: -1, height: Infinity } }
    ];
    for (const c of cases) {
        const p = P.solve(c);
        for (const k of ["x", "y", "width", "height", "localX", "localY", "maxWidth", "maxHeight"])
            assert.ok(Number.isFinite(p[k]), `${k} finite for ${JSON.stringify(c)}`);
        assert.ok(p.width >= 0 && p.height >= 0);
    }
});

test("seed rect: trigger-wide, zero-depth, on the anchor line", () => {
    const b = bar("top");
    const p = P.solve({ trigger: { x: 1000, y: 2, width: 40, height: 32 }, bar: b, screen: screen(FHD, reservedFor(b)), size: { width: 300, height: 200 } });
    assert.deepEqual(P.seedRect(p), { x: 1000, y: 36, width: 40, height: 0 });
    const r = bar("right");
    const q = P.solve({ trigger: triggerOn(FHD, r, 300, 40), bar: r, screen: screen(FHD, reservedFor(r)), size: { width: 300, height: 200 } });
    const s = P.seedRect(q);
    assert.equal(s.x, 1880);
    assert.equal(s.width, 0);
    assert.equal(s.y, 280);
    assert.equal(s.height, 40);
    const c = P.seedRect(P.solve({ screen: screen(FHD), size: { width: 100, height: 100 } }));
    assert.equal(c.width, 0);
});

// Exhaustive sweep: every edge x style x position x size x screen must
// satisfy the contract invariants.
test("exhaustive invariants across edges, styles, scales and constrained space", () => {
    const screens = [
        { x: 0, y: 0, width: 1280, height: 720, scale: 1 },
        { x: 0, y: 0, width: 1366, height: 768, scale: 1 },
        { x: 0, y: 0, width: 1920, height: 1080, scale: 1 },
        { x: 1920, y: 0, width: 2560 / 1.5, height: 1440 / 1.5, scale: 1.5 },
        { x: 0, y: 1080, width: 1920, height: 1080, scale: 2 },
        { x: -3440, y: 0, width: 3440, height: 1440, scale: 1 },
        { x: 0, y: 0, width: 1536, height: 864, scale: 1.25 }
    ];
    const styles = ["attached", "inset", "floating", "islands", "clear"];
    const sizes = [[120, 32], [340, 260], [420, 700], [900, 2000], [0, 0]];
    let count = 0;
    for (const s of screens) {
        for (const edge of ["top", "bottom", "left", "right"]) {
            for (const st of styles) {
                const b = st === "clear" ? bar(edge, "attached", { clear: true }) : bar(edge, st);
                const res = reservedFor(b);
                const scr = screen(s, res);
                const mainLen = edge === "top" || edge === "bottom" ? s.width : s.height;
                for (let along = 0; along <= mainLen; along += mainLen / 13) {
                    const trig = triggerOn(s, b, along);
                    for (const [w, h] of sizes) {
                        const p = P.solve({ trigger: trig, bar: b, screen: scr, size: { width: w, height: h } });
                        count++;
                        const ctx = `${edge}/${st}@${s.width}x${s.height}*${s.scale} along=${along} size=${w}x${h}`;
                        assert.equal(p.side, P.sideForEdge(edge), ctx);
                        assert.equal(p.edge, edge, ctx);
                        assert.equal(p.attached, st === "attached", ctx);
                        assert.ok(p.width <= w + EPS && p.height <= h + EPS, `never grows: ${ctx}`);
                        // Stays inside the screen minus the gutter (+1 device px of snap).
                        const px = 1 / s.scale + EPS;
                        const inner = (b.margin ?? 0) + b.thickness;
                        if (edge === "top" || edge === "bottom") {
                            assert.ok(p.x >= s.x + 8 - px && p.x + p.width <= s.x + s.width - 8 + px, `x in bounds: ${ctx}`);
                        } else {
                            assert.ok(p.y >= s.y + 8 - px && p.y + p.height <= s.y + s.height - 8 + px, `y in bounds: ${ctx}`);
                        }
                        // Never overlaps its own bar; flush when attached.
                        const gap = st === "attached" ? 0 : 4;
                        if (edge === "top")
                            assert.ok(Math.abs(p.y - (s.y + inner + gap)) <= px, ctx);
                        if (edge === "bottom")
                            assert.ok(Math.abs(p.y + p.height - (s.y + s.height - inner - gap)) <= px, ctx);
                        if (edge === "left")
                            assert.ok(Math.abs(p.x - (s.x + inner + gap)) <= px, ctx);
                        if (edge === "right")
                            assert.ok(Math.abs(p.x + p.width - (s.x + s.width - inner - gap)) <= px, ctx);
                        // Motion origin and notch lie on the surface's anchor edge.
                        assert.ok(p.origin.x >= -EPS && p.origin.x <= p.width + EPS && p.origin.y >= -EPS && p.origin.y <= p.height + EPS, ctx);
                        const along2 = edge === "top" || edge === "bottom" ? p.width : p.height;
                        assert.ok(p.notch.start >= 0 && p.notch.start + p.notch.length <= along2 + EPS, ctx);
                        assert.ok(isSnapped(p.x, s.scale) && isSnapped(p.y, s.scale), `snapped: ${ctx}`);
                        assert.equal(p.scroll, (edge === "top" || edge === "bottom" ? h : w) > (edge === "top" || edge === "bottom" ? p.maxHeight : p.maxWidth) + EPS, ctx);
                    }
                }
            }
        }
    }
    assert.ok(count > 4000, `swept ${count} cases`);
});
