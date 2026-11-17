import { readFileSync, readdirSync } from "node:fs";
import vm from "node:vm";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
test("anchored placement sweep: every preset, screen, scale, trigger and size", () => {
const src = readFileSync(join(root, "components/placement/Placement.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const ctx = vm.createContext({}); vm.runInContext(src, ctx);
const solve = i => JSON.parse(JSON.stringify(ctx.solve(i)));
const screens = [[1366,768,1],[1920,1080,1.25],[2560,1440,1.5],[3440,1440,1],[3840,2160,2]];
const sizes = [[285,240],[360,420],[560,700],[900,1000]];
const problems = {};
let n = 0;
for (const f of readdirSync(root + "/presets")) {
  const p = JSON.parse(readFileSync(root + "/presets/" + f));
  const bars = p.bar.bars;
  for (const [pw, ph, sc] of screens) for (const uiScale of [1, 1.25]) {
    const W = Math.round(pw / sc), H = Math.round(ph / sc);
    const dens = 1;
    const reserved = { top: 0, bottom: 0, left: 0, right: 0 };
    const rects = [];
    for (const b of bars) {
      const t = b.thickness ?? (b.edge === "top" || b.edge === "bottom" ? 36 : 44);
      const m = b.style === "attached" ? 0 : (b.margin ?? 0);
      const th = t + m;
      reserved[b.edge] = Math.max(reserved[b.edge], th);
    }
    for (const b of bars) {
      const t = b.thickness ?? (b.edge === "top" || b.edge === "bottom" ? 36 : 44);
      const m = b.style === "attached" ? 0 : (b.margin ?? 0);
      const vert = b.edge === "left" || b.edge === "right";
      const along = vert ? H : W;
      for (const frac of [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.98]) for (const [sw, sh] of sizes) {
        const c = along * frac, len = 32;
        let trig;
        if (b.edge === "top") trig = { x: c - len/2, y: m + 2, width: len, height: t - 4 };
        else if (b.edge === "bottom") trig = { x: c - len/2, y: H - m - t + 2, width: len, height: t - 4 };
        else if (b.edge === "left") trig = { x: m + 2, y: c - len/2, width: t - 4, height: len };
        else trig = { x: W - m - t + 2, y: c - len/2, width: t - 4, height: len };
        const input = { trigger: trig, bar: { edge: b.edge, style: b.style, thickness: t, margin: m, clear: b.backdrop === "clear" },
          screen: { x: 0, y: 0, width: W, height: H, scale: sc, reserved }, size: { width: sw, height: sh }, uiScale };
        const r = solve(input); n++;
        const usable = { x: reserved.left, y: reserved.top, w: W - reserved.left - reserved.right, h: H - reserved.top - reserved.bottom };
        const tag = (k) => { const key = k + " " + f + " " + b.edge + " " + b.style; (problems[key] ??= []).push(`${W}x${H} ui${uiScale} frac${frac} size${sw}x${sh} -> ${JSON.stringify([r.x,r.y,r.width,r.height,r.side])}`); };
        if (r.x < -0.01 || r.y < -0.01 || r.x + r.width > W + 0.01 || r.y + r.height > H + 0.01) tag("offscreen");
        const eps = 0.51;
        if (r.x < usable.x - eps || r.y < usable.y - eps || r.x + r.width > usable.x + usable.w + eps || r.y + r.height > usable.y + usable.h + eps) tag("outside-usable");
        const ox = Math.min(r.x + r.width, trig.x + trig.width) - Math.max(r.x, trig.x), oy = Math.min(r.y + r.height, trig.y + trig.height) - Math.max(r.y, trig.y);
        if (ox > 0.5 && oy > 0.5) tag("covers-trigger");
        if (r.width < Math.min(sw, 200) - 1 || r.height < Math.min(sh, 120) - 1) tag("squeezed");
      }
    }
  }
}
assert.ok(n > 1000);
assert.deepEqual(Object.keys(problems), [], JSON.stringify(Object.entries(problems).map(([k, v]) => [k, v[0]]).slice(0, 5)));
});
