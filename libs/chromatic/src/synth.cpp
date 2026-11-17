// SPDX-License-Identifier: GPL-3.0-only
//
// Role synthesis and the contrast solver: a port of the RFC 0002 reference
// model (§4.5–§4.9) extended with the RFC rules the model left out (contrast
// levels, surface depth, chroma scale, faithful seeds, focus on every
// surface, inkFaint floor, terminal separation, minSurfaceAlpha, ClearInk).
#include "hornero/chromatic/synth.hpp"

#include "hornero/chromatic/json.hpp"

#include <QCryptographicHash>
#include <QJsonDocument>

#include <algorithm>
#include <cmath>

namespace hornero::chromatic {

namespace {

// Signal house hues (RFC 0002 §4.4) and the neutral hues of Signal Night
// surfaces / Signal Day paper (ink takes the opposite hue).
constexpr double kHouseSignalHue = 69.0;
constexpr double kHouseCueHue = 236.0;
constexpr double kHouseChroma = 0.13;
constexpr double kHouseNeutralDark = 256.0;
constexpr double kHouseNeutralLight = 72.0;
constexpr double kAlertAnchor = 29.0;
constexpr double kPhosphorAnchor = 150.0;

struct Col {
    double L = 0, C = 0, h = 0;
    Col() = default;
    Col(double l, double c, double hue)
        : L(l)
        , C(c)
        , h(wrapHue(hue)) {}
    [[nodiscard]] Rgb8 rgb() const { return toRgb8(Oklch { L, C, h }); }
    [[nodiscard]] QString hex() const { return toHex(rgb()); }
};

struct Ladder {
    double ground, sunken, base, panel, raised, lifted, rule, ruleStrong, ink, inkMuted, inkFaint;
    double signal, cue, phosphor, alert, well, onWell, on;
};

constexpr Ladder kDark { .167, .189, .203, .229, .263, .305, .318, .575, .926, .739, .573, .78, .78, .80, .70, .29, .91,
    .18 };
constexpr Ladder kLight { .910, .877, .950, .968, .983, .995, .847, .537, .234, .443, .597, .49, .47, .47, .50, .915, .28,
    .995 };

double harmonise(double anchor, double seed, double cap) {
    const double d = hueDiff(seed, anchor);
    return wrapHue(anchor + std::max(-cap, std::min(cap, d * 0.25)));
}

using Palette = QMap<QString, Col>;

struct Pushed {
    Col col;
    QString failedOn; // first background that failed before the move
};

// Move `fg` lightness away from every background until each ratio reaches
// `minimum + margin` (bisection, 30 steps). Unreachable → chroma 0 at the
// extreme of the range, which always passes on the ladder's surfaces.
Pushed push(const Col& fg, const QList<QPair<QString, Rgb8>>& bgs, double minimum, bool preferUp, double margin) {
    const double target = minimum + margin;
    const auto failing = [&](double L) -> QString {
        const Rgb8 c = Col(L, fg.C, fg.h).rgb();
        for (const auto& [name, bg] : bgs)
            if (contrastRatio(c, bg) < target)
                return name;
        return {};
    };
    const QString first = failing(fg.L);
    if (first.isEmpty())
        return { fg, {} };
    double lo = preferUp ? fg.L : 0.0;
    double hi = preferUp ? 1.0 : fg.L;
    const double end = preferUp ? hi : lo;
    if (!failing(end).isEmpty())
        return { Col(end, 0.0, fg.h), first };
    for (int i = 0; i < 30; ++i) {
        const double mid = (lo + hi) / 2.0;
        const bool ok = failing(mid).isEmpty();
        if (preferUp)
            (ok ? hi : lo) = mid;
        else
            (ok ? lo : hi) = mid;
    }
    return { Col(preferUp ? hi : lo, fg.C, fg.h), first };
}

QString capitalised(const QString& s) {
    return s.left(1).toUpper() + s.mid(1);
}

QString hueName(double h) {
    struct Band {
        double upTo;
        const char* name;
    };
    static constexpr Band kBands[] = { { 40, "red" }, { 60, "orange" }, { 85, "amber" }, { 115, "yellow" },
        { 135, "lime" }, { 170, "green" }, { 200, "teal" }, { 230, "cyan" }, { 275, "blue" }, { 295, "indigo" },
        { 320, "violet" }, { 350, "magenta" }, { 360.0001, "red" } };
    for (const auto& band : kBands)
        if (h < band.upTo)
            return QString::fromLatin1(band.name);
    return QStringLiteral("red");
}

QString chromaClassFor(double c) {
    if (c < 0.025)
        return QStringLiteral("grey");
    if (c < 0.06)
        return QStringLiteral("soft");
    if (c < 0.12)
        return QStringLiteral("rich");
    return QStringLiteral("intense");
}

QString temperatureFor(double h) {
    if (h >= 20.0 && h <= 110.0)
        return QStringLiteral("warm");
    if (h >= 180.0 && h <= 300.0)
        return QStringLiteral("cool");
    return QStringLiteral("neutral");
}

QString num(double v, int decimals = 2) {
    return QString::number(v, 'f', decimals);
}

// The seed set synthesis works from, resolved from the source.
struct Seeds {
    double hp = kHouseSignalHue;
    double cp = kHouseChroma;
    std::optional<double> Lp; // faithful: the seed's own lightness
    std::optional<double> hs;
    double hn = kHouseNeutralDark;
    QStringList hexes;
    QStringList reasons;
};

Seeds resolveSeeds(const Analysis* a, const Request& r, Mode mode, Variant variant) {
    Seeds s;
    s.hn = mode == Mode::Light ? kHouseNeutralLight : kHouseNeutralDark;
    const auto house = [&s]() {
        s.hp = kHouseSignalHue;
        s.cp = kHouseChroma;
        s.hs = kHouseCueHue;
        s.hexes = { toHex(Oklch { 0.78, kHouseChroma, kHouseSignalHue }), toHex(Oklch { 0.78, 0.10, kHouseCueHue }) };
    };
    if (r.source == SourceSel::Seed) {
        const Oklch p = toOklch(*parseHex(r.seeds.at(0)));
        s.hp = p.h;
        s.cp = p.C;
        s.Lp = p.L;
        s.hn = p.h;
        if (p.C < 0.02) {
            // A grey seed has no hue to keep: borrow the house hue, softly.
            s.hp = kHouseSignalHue;
            s.hn = mode == Mode::Light ? kHouseNeutralLight : kHouseNeutralDark;
            s.cp = 0.06;
            s.Lp.reset();
            s.reasons << QStringLiteral("grey seed: Signal house hue at chroma 0.06");
        }
        if (r.seeds.size() > 1)
            s.hs = toOklch(*parseHex(r.seeds.at(1))).h;
        s.hexes = r.seeds;
    } else if (r.source == SourceSel::House) {
        house();
        if (a && a->neutralHue) {
            s.hn = *a->neutralHue;
            s.reasons << QStringLiteral("house hues; surface tint from the wallpaper");
        } else {
            s.reasons << QStringLiteral("house hues");
        }
    } else if (a && !a->seeds.isEmpty() && (!a->achromatic || a->seeds.first().lch.C >= 0.06)) {
        // A saturated object on a grey field still wins (RFC §4.4).
        const Seed& p = a->seeds.first();
        s.hp = p.lch.h;
        s.cp = p.lch.C;
        s.Lp = p.lch.L;
        s.hn = variant == Variant::Faithful && a->neutralHue ? *a->neutralHue : p.lch.h;
        s.hexes = { p.hex };
        for (qsizetype i = 1; i < a->seeds.size(); ++i) {
            if (std::abs(hueDiff(a->seeds[i].lch.h, p.lch.h)) >= 50.0) {
                s.hs = a->seeds[i].lch.h;
                s.hexes << a->seeds[i].hex;
                break;
            }
        }
    } else if (a && a->weakHue) {
        s.hp = *a->weakHue;
        s.cp = 0.06;
        s.hn = *a->weakHue;
        s.hexes = { toHex(Oklch { 0.7, 0.06, *a->weakHue }) };
        s.reasons << QStringLiteral("achromatic image: faint hue %1° kept at chroma 0.06").arg(num(*a->weakHue, 0));
    } else {
        house();
        s.reasons << QStringLiteral("image has no hue: Signal house hues");
    }
    if (std::abs(r.hueShift) > 1e-9) {
        s.hp = wrapHue(s.hp + r.hueShift);
        if (s.hs)
            s.hs = wrapHue(*s.hs + r.hueShift);
        s.hn = wrapHue(s.hn + r.hueShift);
        s.Lp.reset(); // a shifted seed is no longer "the seed itself"
    }
    return s;
}

QList<QPair<QString, Rgb8>> bgList(const Palette& p, const QStringList& names) {
    QList<QPair<QString, Rgb8>> out;
    out.reserve(names.size());
    for (const auto& n : names)
        out.append({ n, p.value(n).rgb() });
    return out;
}

} // namespace

Rgb8 ensureContrast(Rgb8 fg, Rgb8 bg, double minimum, double margin) {
    if (contrastRatio(fg, bg) >= minimum + margin)
        return fg;
    const Oklch f = toOklch(fg);
    const Col start(f.L, f.C, f.h);
    const QList<QPair<QString, Rgb8>> bgs { { QStringLiteral("bg"), bg } };
    const bool up = relativeLuminance(bg) < 0.18;
    const Rgb8 first = push(start, bgs, minimum, up, margin).col.rgb();
    if (contrastRatio(first, bg) >= minimum + margin)
        return first;
    const Rgb8 second = push(start, bgs, minimum, !up, margin).col.rgb();
    return contrastRatio(second, bg) > contrastRatio(first, bg) ? second : first;
}

const QStringList& signalRoles() {
    static const QStringList roles { QStringLiteral("ground"), QStringLiteral("sunken"), QStringLiteral("base"),
        QStringLiteral("panel"), QStringLiteral("raised"), QStringLiteral("lifted"), QStringLiteral("ink"),
        QStringLiteral("inkMuted"), QStringLiteral("inkFaint"), QStringLiteral("rule"), QStringLiteral("ruleStrong"),
        QStringLiteral("signal"), QStringLiteral("onSignal"), QStringLiteral("signalWell"),
        QStringLiteral("onSignalWell"), QStringLiteral("cue"), QStringLiteral("onCue"), QStringLiteral("cueWell"),
        QStringLiteral("onCueWell"), QStringLiteral("phosphor"), QStringLiteral("onPhosphor"),
        QStringLiteral("phosphorWell"), QStringLiteral("onPhosphorWell"), QStringLiteral("alert"),
        QStringLiteral("onAlert"), QStringLiteral("alertWell"), QStringLiteral("onAlertWell"),
        QStringLiteral("inverse"), QStringLiteral("onInverse"), QStringLiteral("inverseSignal"),
        QStringLiteral("scrim"), QStringLiteral("shadow"), QStringLiteral("focus") };
    return roles;
}

const QStringList& surfaceRoles() {
    static const QStringList roles { QStringLiteral("ground"), QStringLiteral("sunken"), QStringLiteral("base"),
        QStringLiteral("panel"), QStringLiteral("raised"), QStringLiteral("lifted") };
    return roles;
}

const VariantParams& params(Variant v) {
    // sC, iC, aCmin, aCmax, cueRot, harm, term, darkOnly, highContrast, glow
    static const VariantParams kBalanced { .016, .014, .09, .15, 165, 10, 10, false, false, true, "Balanced",
        "Signal Night/Day character re-hued: quiet surfaces, one confident accent" };
    static const VariantParams kVibrant { .028, .014, .14, .40, 165, 12, 15, false, false, true, "Vibrant",
        "Stronger accents and tinted chrome" };
    static const VariantParams kExpressive { .022, .016, .11, .17, 120, 20, 20, false, false, true, "Expressive",
        "Triadic cue unless the image has a second hue; more harmonised status colours" };
    static const VariantParams kFaithful { .020, .012, 0.0, .40, 165, 8, 8, false, false, true, "Faithful",
        "Signal is the seed itself when it passes the gates; surfaces take the image's dominant hue" };
    static const VariantParams kMuted { .008, .008, .05, .08, 165, 5, 5, false, false, true, "Muted",
        "Near-neutral chrome, soft accents" };
    static const VariantParams kMonochrome { 0.0, 0.0, .035, .035, 165, 0, 0, false, false, false, "Monochrome",
        "Neutral chrome and ink; accents whisper the seed hue; status colours keep their meaning" };
    static const VariantParams kHighContrast { .006, 0.0, .12, .17, 165, 5, 5, false, true, false, "High contrast",
        "Maximum gates, deeper ground, brighter ink; no glow, no translucency" };
    static const VariantParams kNeon { .030, .020, .16, .40, 180, 0, 0, true, false, true, "Neon",
        "Dark only; complementary cue, saturated terminal, glow at gamut" };
    switch (v) {
    case Variant::Vibrant:
        return kVibrant;
    case Variant::Expressive:
        return kExpressive;
    case Variant::Faithful:
        return kFaithful;
    case Variant::Muted:
        return kMuted;
    case Variant::Monochrome:
        return kMonochrome;
    case Variant::HighContrast:
        return kHighContrast;
    case Variant::Neon:
        return kNeon;
    case Variant::Auto:
    case Variant::Balanced:
        break;
    }
    return kBalanced;
}

Inference infer(const Analysis* a, const Request& r) {
    Inference inf;
    // --- mode (§5.1) ---
    double modeConfidence = 1.0;
    if (r.mode != Mode::Auto) {
        inf.mode = r.mode;
        inf.reasons << QStringLiteral("mode %1 requested").arg(name(r.mode));
    } else if (a) {
        double L = a->meanL;
        QString what = QStringLiteral("mean lightness");
        const bool bandsDisagree =
            std::abs(a->top.meanL - a->meanL) > 0.25 || std::abs(a->bottom.meanL - a->meanL) > 0.25;
        if (bandsDisagree) {
            L = (a->top.meanL + a->bottom.meanL) / 2.0;
            what = QStringLiteral("bar-band lightness");
        }
        if (L < 0.58) {
            inf.mode = Mode::Dark;
            inf.reasons << QStringLiteral("%1 %2 < 0.58: dark").arg(what, num(L));
            modeConfidence = std::min(1.0, 0.5 + (0.58 - L) * 2.5);
        } else if (L > 0.68) {
            inf.mode = Mode::Light;
            inf.reasons << QStringLiteral("%1 %2 > 0.68: light").arg(what, num(L));
            modeConfidence = std::min(1.0, 0.5 + (L - 0.68) * 2.5);
        } else {
            inf.mode = r.currentMode.value_or(Mode::Dark);
            inf.reasons << QStringLiteral("%1 %2 between 0.58 and 0.68: keep %3")
                               .arg(what, num(L), r.currentMode ? name(*r.currentMode) : QStringLiteral("dark"));
            modeConfidence = 0.4;
        }
    } else {
        inf.mode = r.currentMode.value_or(Mode::Dark);
        inf.reasons << QStringLiteral("no image: %1").arg(name(inf.mode));
        modeConfidence = 0.6;
    }

    // --- variant (§5.2) ---
    double variantConfidence = 1.0;
    if (r.variant != Variant::Auto) {
        inf.variant = r.variant;
    } else if (r.source == SourceSel::House) {
        inf.variant = Variant::Balanced;
        inf.reasons << QStringLiteral("house: balanced (Signal tinted)");
    } else if (a) {
        const double c90 = a->C90;
        bool twoHues = false;
        if (a->seeds.size() > 1 && a->seeds[0].share >= 0.10) {
            for (qsizetype i = 1; i < a->seeds.size(); ++i)
                if (a->seeds[i].share >= 0.10 && std::abs(hueDiff(a->seeds[i].lch.h, a->seeds[0].lch.h)) >= 50.0)
                    twoHues = true;
        }
        if (c90 < 0.025) {
            inf.variant = Variant::Muted;
            inf.reasons << QStringLiteral("C90 %1 < 0.025: muted").arg(num(c90, 3));
        } else if (c90 < 0.06) {
            inf.variant = Variant::Balanced;
            inf.reasons << QStringLiteral("C90 %1 < 0.06: balanced").arg(num(c90, 3));
        } else if (c90 < 0.12 && twoHues) {
            inf.variant = Variant::Expressive;
            inf.reasons << QStringLiteral("C90 %1 with two hues ≥ 50° apart: expressive").arg(num(c90, 3));
        } else if (c90 < 0.12) {
            inf.variant = Variant::Balanced;
            inf.reasons << QStringLiteral("C90 %1 < 0.12: balanced").arg(num(c90, 3));
        } else {
            inf.variant = Variant::Vibrant;
            inf.reasons << QStringLiteral("C90 %1 ≥ 0.12: vibrant").arg(num(c90, 3));
        }
        variantConfidence = std::min(1.0, 0.5 + std::min({ std::abs(c90 - 0.025), std::abs(c90 - 0.06),
                                                    std::abs(c90 - 0.12) }) * 10.0);
        if (a->meanL < 0.30 && a->brightC95 > 0.18 && inf.variant != Variant::Neon) {
            inf.suggestion = Variant::Neon;
            inf.reasons << QStringLiteral("dark image with saturated highlights: neon suggested");
        }
    } else {
        inf.variant = Variant::Balanced;
    }
    if (params(inf.variant).darkOnly && inf.mode == Mode::Light) {
        inf.mode = Mode::Dark;
        inf.reasons << QStringLiteral("%1 is dark only: dark").arg(name(inf.variant));
    }

    // --- contrast (§5.3) ---
    const bool busy = a && a->detail > 0.08;
    if (r.contrast == Contrast::Auto) {
        inf.contrast = busy ? Contrast::Boosted : Contrast::Standard;
        if (busy)
            inf.reasons << QStringLiteral("detail %1 > 0.08: boosted").arg(num(a->detail, 3));
    } else {
        inf.contrast = r.contrast;
        if (busy && r.contrast == Contrast::Standard)
            inf.reasons << QStringLiteral("detail %1 > 0.08: boosted recommended").arg(num(a->detail, 3));
    }
    if (params(inf.variant).highContrast && inf.contrast != Contrast::Maximum) {
        inf.contrast = Contrast::Maximum;
        inf.reasons << QStringLiteral("high-contrast variant: maximum gates");
    }

    // --- personality (§5.4) ---
    double hue = kHouseSignalHue;
    double chroma = kHouseChroma;
    if (r.source == SourceSel::Seed && !r.seeds.isEmpty()) {
        const Oklch p = toOklch(*parseHex(r.seeds.first()));
        hue = p.h;
        chroma = p.C;
    } else if (r.source != SourceSel::House && a) {
        if (!a->seeds.isEmpty() && (!a->achromatic || a->seeds.first().lch.C >= 0.06)) {
            hue = a->seeds.first().lch.h;
            chroma = a->C90;
        } else if (a->weakHue) {
            hue = *a->weakHue;
            chroma = a->C90;
        } else {
            chroma = a->C90;
        }
    }
    hue = wrapHue(hue + r.hueShift);
    inf.chromaClass = chromaClassFor(chroma);
    inf.temperature = temperatureFor(hue);
    QString energy = QStringLiteral("steady");
    if (a)
        energy = a->detail < 0.03 ? QStringLiteral("calm") : a->detail < 0.08 ? QStringLiteral("lively")
                                                                               : QStringLiteral("busy");
    const QString hueWord = inf.chromaClass == QLatin1String("grey") && !(a && a->weakHue)
        ? QStringLiteral("neutral")
        : inf.temperature + QLatin1Char(' ') + hueName(hue);
    inf.personality = QStringLiteral("%1 · %2 · %3 · %4")
                          .arg(capitalised(name(inf.mode)), QString::fromLatin1(params(inf.variant).label).toLower(),
                              hueWord, energy);
    inf.confidence = std::round(std::min(modeConfidence, variantConfidence) * 100.0) / 100.0;
    return inf;
}

Expected<Generated> synthesise(const Analysis* a, const Request& r, const Inference& inf, const GateTable& table) {
    const Variant variant = inf.variant == Variant::Auto ? Variant::Balanced : inf.variant;
    const VariantParams& V = params(variant);
    const bool hc = V.highContrast;
    const Mode mode = (V.darkOnly || inf.mode == Mode::Auto) ? Mode::Dark : inf.mode;
    const bool dark = mode == Mode::Dark;
    const Contrast level = hc ? Contrast::Maximum : (inf.contrast == Contrast::Auto ? Contrast::Standard : inf.contrast);
    const LevelGates& gates = table.level(level);
    const double margin = table.margin;

    const double k = r.chroma;
    const double sC = V.sC * k;
    const double iC = V.iC * k;
    const double lo = V.aCmin * k;
    const double hi = V.aCmax * k;

    Seeds seeds = resolveSeeds(a, r, mode, variant);
    const double seedH = seeds.hp;
    const double nh = seeds.hn;
    const double inkH = wrapHue(nh + 180.0);

    const Ladder& Ld = dark ? kDark : kLight;
    Ladder lad = Ld;
    if (hc) {
        if (dark) {
            lad.ground = .10, lad.sunken = .12, lad.base = .13, lad.panel = .15, lad.raised = .18, lad.lifted = .22;
            lad.ink = .985, lad.inkMuted = .86, lad.ruleStrong = .76;
        } else {
            lad.ground = .97, lad.sunken = .95, lad.base = .99, lad.panel = 1.0, lad.raised = 1.0, lad.lifted = 1.0;
            lad.ink = .12, lad.inkMuted = .30, lad.ruleStrong = .40;
        }
    }
    if (r.depth == Depth::Deep) {
        for (double* v : { &lad.ground, &lad.sunken, &lad.base, &lad.panel, &lad.raised, &lad.lifted })
            *v = dark ? *v - 0.03 : std::min(1.0, *v + 0.015);
    }

    Palette p;
    const std::pair<const char*, std::pair<double, double>> ramp[] = { { "ground", { lad.ground, .75 } },
        { "sunken", { lad.sunken, .85 } }, { "base", { lad.base, 1.0 } }, { "panel", { lad.panel, 1.1 } },
        { "raised", { lad.raised, 1.25 } }, { "lifted", { lad.lifted, 1.3 } }, { "rule", { lad.rule, 1.3 } },
        { "ruleStrong", { lad.ruleStrong, 1.4 } } };
    for (const auto& [role, lk] : ramp)
        p[QString::fromLatin1(role)] = Col(lk.first, sC * lk.second, nh);
    p[QStringLiteral("ink")] = Col(lad.ink, iC, inkH);
    p[QStringLiteral("inkMuted")] = Col(lad.inkMuted, iC * .5, inkH);
    p[QStringLiteral("inkFaint")] = Col(lad.inkFaint, iC * .5, inkH);

    const auto ac = [&](double L, double h, double c) { return Col(L, std::max(lo, std::min({ hi, c, maxChroma(L, h) })), h); };

    double sigH = seedH;
    double alertH = harmonise(kAlertAnchor, seedH, V.harm);
    const double phosH = harmonise(kPhosphorAnchor, seedH, V.harm);
    QList<double> cands;
    if (seeds.hs)
        cands << *seeds.hs;
    cands << wrapHue(seedH + V.cueRot) << wrapHue(seedH - V.cueRot) << wrapHue(seedH + 180.0)
          << harmonise(kHouseCueHue, seedH, 15.0) << wrapHue(seedH + 120.0) << wrapHue(seedH - 120.0);
    const auto mind = [&](double h) { return std::min(std::abs(hueDiff(h, alertH)), std::abs(hueDiff(h, phosH))); };
    std::optional<double> cue;
    for (double h : cands) {
        if (mind(h) >= 35.0 && std::abs(hueDiff(h, seedH)) >= 60.0) {
            cue = h;
            break;
        }
    }
    if (!cue) {
        double best = cands.first();
        for (double h : cands)
            if (mind(h) > mind(best))
                best = h;
        cue = best;
    }
    double cueH = *cue;

    // Faithful keeps the seed: move alert inside 10°–45° instead, when that
    // reaches the 30° separation.
    if (variant == Variant::Faithful) {
        const double d = hueDiff(sigH, alertH);
        if (std::abs(d) < 30.0) {
            const double moved = wrapHue(d >= 0 ? sigH - 30.0 : sigH + 30.0);
            if (moved >= 10.0 && moved <= 45.0)
                alertH = moved;
        }
    }
    // Semantic separation: live/focus accents keep ≥ 30° from status anchors.
    for (double* h : { &sigH, &cueH }) {
        for (double anchor : { alertH, phosH }) {
            const double d = hueDiff(*h, anchor);
            // 31° so the 30° rule still holds after 8-bit quantisation.
            if (std::abs(d) < 31.0 && variant != Variant::Monochrome)
                *h = wrapHue(anchor + (d >= 0 ? 31.0 : -31.0));
        }
    }

    const double sc = seeds.cp * (variant == Variant::Faithful ? 1.0 : 1.15) * k;
    const double sigL = hc ? (dark ? .84 : .40) : Ld.signal;
    const double cueL = hc ? (dark ? .84 : .40) : Ld.cue;
    const double phosL = hc ? (dark ? .86 : .40) : Ld.phosphor;
    const double alertL = hc ? (dark ? .78 : .42) : Ld.alert;
    const bool up = dark;
    const QString accents[] = { QStringLiteral("signal"), QStringLiteral("cue"), QStringLiteral("phosphor"),
        QStringLiteral("alert") };
    const Palette p0 = p;
    QList<Adjustment> adjustments;
    bool keepSeed = false;
    double dSig = 0.0;
    double dCue = 0.0;
    double dAlert = 0.0; // status anchors may move in lightness only (hue keeps meaning)
    double dPhos = 0.0;
    double dSigC = 0.0; // extra accent chroma, only when separation needs it
    double dCueC = 0.0;
    // One full accent build + contrast solve for the current hues/offsets.
    const auto attempt = [&]() {
        p = p0;
        adjustments.clear();
        keepSeed = variant == Variant::Faithful && seeds.Lp && std::abs(sigH - seedH) < 1e-9 && std::abs(dSig) < 1e-9;
        if (keepSeed)
            p[QStringLiteral("signal")] = Col(*seeds.Lp, std::min(sc, maxChroma(*seeds.Lp, sigH)), sigH);
        else
            p[QStringLiteral("signal")] = ac(sigL + dSig, sigH, std::max(sc, lo));
        // The cue is not the seed: faithful still gives it a visible chroma.
        p[QStringLiteral("cue")] = ac(cueL + dCue, cueH, std::max(sc * .8, variant == Variant::Faithful ? 0.08 * k : lo));
        // Last-resort separation room: extra chroma for the live accents.
        for (const auto& [role, extra] : { std::pair { QStringLiteral("signal"), dSigC }, std::pair { QStringLiteral("cue"), dCueC } }) {
            if (extra > 0) {
                Col& c = p[role];
                c.C = std::min(c.C + extra, maxChroma(c.L, c.h));
            }
        }
        const double phosC = variant == Variant::Muted ? .07 : std::max(variant != Variant::Monochrome ? .11 : .07, lo);
        p[QStringLiteral("phosphor")] = ac(phosL + dPhos, phosH, phosC);
        const double alertC = (variant == Variant::Muted || variant == Variant::Monochrome) ? .09 : .16;
        p[QStringLiteral("alert")] = ac(alertL + dAlert, alertH, alertC);
        for (const auto& acc : accents) {
            const Col A = p.value(acc);
            const QString cap = capitalised(acc);
            p[acc + QStringLiteral("Well")] = Col(Ld.well, std::min(A.C * .32, .055), A.h);
            p[QStringLiteral("on") + cap + QStringLiteral("Well")] = Col(Ld.onWell, std::min(A.C * .5, .085), A.h);
            p[QStringLiteral("on") + cap] = Col(Ld.on, dark ? .03 : 0.0, A.h);
        }
        p[QStringLiteral("inverse")] = p.value(QStringLiteral("ink"));
        p[QStringLiteral("onInverse")] = p.value(QStringLiteral("panel"));
        const Col sig = p.value(QStringLiteral("signal"));
        p[QStringLiteral("inverseSignal")] = Col(dark ? .49 : .776, sig.C * .75, sig.h);
        p[QStringLiteral("scrim")] = Col(0, 0, 0);
        p[QStringLiteral("shadow")] = Col(0, 0, 0);

        // --- contrast solver (surfaces fixed; order fixed) ---
        const auto solve = [&](const QString& role, const QStringList& on, double minimum, bool preferUp) {
            const Col before = p.value(role);
            const Pushed res = push(before, bgList(p, on), minimum, preferUp, margin);
            p[role] = res.col;
            if (!res.failedOn.isEmpty() && before.hex() != res.col.hex())
                adjustments.append({ role, before.hex(), res.col.hex(), QStringLiteral("contrast on %1").arg(res.failedOn) });
        };
        if (keepSeed && !r.seeds.isEmpty()) {
            // Report against the user's colour, not the gamut-mapped start.
            const QString seedHex = r.seeds.first();
            const QString startHex = p.value(QStringLiteral("signal")).hex();
            if (seedHex != startHex)
                adjustments.append({ QStringLiteral("signal"), seedHex, startHex, QStringLiteral("gamut") });
        }
        for (const auto& role : gates.textRoles)
            solve(role, gates.textOn, gates.textMinFor(role), up);
        QStringList boundaryOn = gates.boundaryOn;
        for (const auto& s : gates.textOn)
            if (!boundaryOn.contains(s))
                boundaryOn << s;
        for (const auto& role : gates.boundaryRoles)
            solve(role, boundaryOn, gates.boundaryMin, up);
        p[QStringLiteral("focus")] = p.value(QStringLiteral("cue"));
        solve(QStringLiteral("focus"), surfaceRoles(), std::max(gates.focusMin, table.focusOnEverySurfaceMin), up);
        p[QStringLiteral("inverse")] = p.value(QStringLiteral("ink"));
        for (const auto& acc : accents) {
            const QString cap = capitalised(acc);
            solve(QStringLiteral("on") + cap, { acc }, gates.onPairsMin, !dark);
            solve(QStringLiteral("on") + cap + QStringLiteral("Well"), { acc + QStringLiteral("Well") }, gates.onPairsMin,
                dark);
        }
        solve(QStringLiteral("onInverse"), { QStringLiteral("inverse") }, gates.onPairsMin, !dark);
        solve(QStringLiteral("inverseSignal"), { QStringLiteral("inverse") }, gates.onPairsMin, !dark);
        // inkFaint is decorative (never essential text): a 3:1 floor keeps marks visible.
        solve(QStringLiteral("inkFaint"), { QStringLiteral("base"), QStringLiteral("panel") }, 3.0, up);
        if (dark && V.glow) {
            const Col s = p.value(QStringLiteral("signal"));
            p[QStringLiteral("glow")] = Col(std::min(s.L + .05, .95), s.C * 1.1, s.h);
        }
    };

    // Accent separation (config chromaticExtra): live and focus accents
    // must differ from the status anchors and from each other in both OKLab
    // distance and hue. Rotate the movable accent away first; once hue alone
    // cannot get there (low chroma), step its lightness away instead.
    const SeparationGates& sep = table.separation;
    const auto separated = [&](const QString& x, const QString& y) {
        const Oklab la = toOklab(toSrgb(p.value(x).rgb()));
        const Oklab lb = toOklab(toSrgb(p.value(y).rgb()));
        return deltaEOK(la, lb) >= sep.minDeltaEOK + 0.005
            && std::abs(hueDiff(toOklch(la).h, toOklch(lb).h)) >= sep.minHueDeg + 1.0;
    };
    const auto moveAway = [&](double& h, double& dL, const QString& x, const QString& y) {
        const double d = hueDiff(toOklch(p.value(x).rgb()).h, toOklch(p.value(y).rgb()).h);
        if (std::abs(d) < 110.0)
            h = wrapHue(h + (d >= 0 ? 6.0 : -6.0));
        else // away from the surfaces, so the contrast solver never undoes it
            dL = std::clamp(dL + (dark ? 0.02 : -0.02), -0.4, 0.4);
    };
    for (int iteration = 0; iteration < 80; ++iteration) {
        attempt();
        const bool sa = separated(QStringLiteral("signal"), QStringLiteral("alert"));
        const bool cp = separated(QStringLiteral("cue"), QStringLiteral("phosphor"));
        const bool sc2 = separated(QStringLiteral("signal"), QStringLiteral("cue"));
        if (sa && cp && sc2)
            break;
        if (!sa)
            moveAway(sigH, dSig, QStringLiteral("signal"), QStringLiteral("alert"));
        if (!cp)
            moveAway(cueH, dCue, QStringLiteral("cue"), QStringLiteral("phosphor"));
        else if (!sc2)
            moveAway(cueH, dCue, QStringLiteral("cue"), QStringLiteral("signal"));
    }
    // Rare leftovers (accents squeezed together at one end of the ladder):
    // greedy search over hue and lightness moves of both live accents,
    // maximising the worst separation margin. Deterministic: fixed move
    // order, strict improvement only.
    // Total separation shortfall (0 when every pair passes; hue scaled to OKLab units).
    const auto margin3 = [&]() {
        double total = 0;
        const std::pair<const char*, const char*> pairs[] = { { "signal", "alert" }, { "cue", "phosphor" }, { "signal", "cue" } };
        for (const auto& [x, y] : pairs) {
            const Oklab la = toOklab(toSrgb(p.value(QString::fromLatin1(x)).rgb()));
            const Oklab lb = toOklab(toSrgb(p.value(QString::fromLatin1(y)).rgb()));
            total += std::min(0.0, deltaEOK(la, lb) - (sep.minDeltaEOK + 0.005));
            total += std::min(0.0, (std::abs(hueDiff(toOklch(la).h, toOklch(lb).h)) - (sep.minHueDeg + 1.0)) / 250.0);
        }
        return total;
    };
    attempt();
    double best = margin3();
    for (int iteration = 0; iteration < 80 && best < 0; ++iteration) {
        struct Move {
            double* v;
            double step;
            bool hue;
            double* v2 = nullptr;
            double step2 = 0;
        };
        const Move moves[] = { { &cueH, 8, true }, { &cueH, -8, true }, { &dCue, 0.03, false }, { &dCue, -0.03, false },
            { &sigH, 8, true }, { &sigH, -8, true }, { &dSig, 0.03, false }, { &dSig, -0.03, false },
            { &cueH, 3, true }, { &cueH, -3, true }, { &dCue, 0.01, false }, { &dCue, -0.01, false },
            { &sigH, 3, true }, { &sigH, -3, true }, { &dSig, 0.01, false }, { &dSig, -0.01, false },
            { &dAlert, 0.03, false }, { &dAlert, -0.03, false }, { &dPhos, 0.03, false }, { &dPhos, -0.03, false },
            { &dSig, 0.03, false, &dCue, 0.06 }, { &dSig, -0.03, false, &dCue, -0.06 },
            { &dSig, 0.03, false, &dAlert, -0.03 }, { &dSig, -0.03, false, &dAlert, 0.03 },
            { &dCue, 0.03, false, &dPhos, -0.03 }, { &dCue, -0.03, false, &dPhos, 0.03 },
            { &dSigC, 0.02, false }, { &dCueC, 0.02, false } };
        const Move* pick = nullptr;
        double pickScore = best;
        const auto apply = [&dSigC, &dCueC](const Move& m) {
            *m.v = m.hue ? wrapHue(*m.v + m.step) : std::clamp(*m.v + m.step, -0.45, 0.45);
            if (m.v == &dSigC || m.v == &dCueC)
                *m.v = std::min(*m.v, 0.10);
            if (m.v2)
                *m.v2 = std::clamp(*m.v2 + m.step2, -0.45, 0.45);
        };
        for (const Move& m : moves) {
            const double saved = *m.v;
            const double saved2 = m.v2 ? *m.v2 : 0.0;
            apply(m);
            attempt();
            const double score = margin3();
            *m.v = saved;
            if (m.v2)
                *m.v2 = saved2;
            if (score > pickScore + 1e-12) {
                pickScore = score;
                pick = &m;
            }
        }
        if (!pick)
            break;
        apply(*pick);
        best = pickScore;
    }
    attempt();

    // --- terminal (§4.8) ---
    const double th[7] = { 0, alertH, phosH, harmonise(85, seedH, V.term), harmonise(255, seedH, V.term),
        harmonise(325, seedH, V.term), harmonise(190, seedH, V.term) };
    const double tc = variant == Variant::Monochrome ? .06 : (variant == Variant::Muted ? .09 : .14);
    const double nL = dark ? .77 : .48;
    const double bL = dark ? .87 : .39;
    std::array<Col, 16> term;
    term[0] = Col(dark ? .26 : .23, sC, nh);
    term[7] = Col(dark ? .82 : .60, .02, inkH);
    term[8] = Col(dark ? .54 : .44, .02, nh);
    term[15] = Col(dark ? .95 : .60, .01, inkH);
    for (std::size_t i = 1; i < 7; ++i) {
        term[i] = Col(nL, std::min(tc, maxChroma(nL, th[i])), th[i]);
        term[i + 8] = Col(bL, std::min(tc * .85, maxChroma(bL, th[i])), th[i]);
    }
    const TerminalGates& tg = table.terminal;
    const QList<QPair<QString, Rgb8>> termBg { { tg.background, p.value(tg.background).rgb() } };
    for (std::size_t i = 1; i < 7; ++i) {
        term[i] = push(term[i], termBg, tg.normalMin, up, margin).col;
        term[i + 8] = push(term[i + 8], termBg, tg.brightMin, up, margin).col;
    }
    // Visible normal → bright step: walk the bright away from the background.
    for (std::size_t i = 1; i < 7; ++i) {
        for (int step = 0; step < 40 && deltaE76(term[i].rgb(), term[i + 8].rgb()) < tg.rampMinDeltaE76 + 0.5; ++step) {
            const double L = std::clamp(term[i + 8].L + (up ? 0.01 : -0.01), 0.0, 1.0);
            term[i + 8] = Col(L, std::min(term[i + 8].C, maxChroma(L, term[i + 8].h)), term[i + 8].h);
        }
    }

    // --- assemble ---
    Generated g;
    g.request = r;
    if (a)
        g.analysis = *a;
    g.inference = inf;
    g.inference.mode = mode;
    g.inference.variant = variant;
    g.inference.contrast = level;
    g.inference.reasons << seeds.reasons;
    g.seeds = seeds.hexes;
    g.sourceKey = a ? a->sourceDigest : QString();
    Scheme& s = g.scheme;
    s.mode = mode;
    for (const auto& role : signalRoles())
        s.palette.insert(role, p.value(role).hex());
    if (p.contains(QStringLiteral("glow")))
        s.palette.insert(QStringLiteral("glow"), p.value(QStringLiteral("glow")).hex());
    for (std::size_t i = 0; i < 16; ++i)
        s.terminal[i] = term[i].hex();

    // --- minSurfaceAlpha (§4.9) ---
    const QStringList alphaRoles { QStringLiteral("sunken"), QStringLiteral("base"), QStringLiteral("panel"),
        QStringLiteral("raised"), QStringLiteral("lifted") };
    const bool haveWall = a && r.source != SourceSel::Seed && !hc;
    const Rgb8 inkRgb = p.value(QStringLiteral("ink")).rgb();
    const Rgb8 mutedRgb = p.value(QStringLiteral("inkMuted")).rgb();
    const double inkMin = gates.textMinFor(QStringLiteral("ink"));
    const double mutedMin = gates.textMinFor(QStringLiteral("inkMuted"));
    for (const auto& role : alphaRoles) {
        double alpha = 1.0;
        if (haveWall) {
            const double wallH = a->neutralHue.value_or(nh);
            const Rgb8 walls[2] = { toRgb8(Oklch { a->Lmin, 0.01, wallH }), toRgb8(Oklch { a->Lmax, 0.01, wallH }) };
            const Rgb8 surface = p.value(role).rgb();
            for (int step = 50; step <= 100; ++step) {
                const double t = step / 100.0;
                bool ok = true;
                for (const Rgb8& w : walls) {
                    const Rgb8 c = composite(surface, t, w);
                    ok = ok && contrastRatio(inkRgb, c) >= inkMin && contrastRatio(mutedRgb, c) >= mutedMin;
                }
                if (ok) {
                    alpha = t;
                    break;
                }
            }
        }
        s.minSurfaceAlpha.insert(role, alpha);
    }

    // --- ClearInk (§4.9): foreground sets for both polarities, re-hued ---
    {
        const Col sigC = p.value(QStringLiteral("signal"));
        const Col alertC2 = p.value(QStringLiteral("alert"));
        const Col lightHalo(0.14, std::min(0.012, maxChroma(0.14, nh)), nh);
        const Col darkHalo(1.0, 0.0, nh);
        const struct {
            const char* key;
            Col halo;
            double ink, muted, signal, alert;
            bool preferUp;
        } sets[] = {
            { "light", lightHalo, .93, .76, .82, .74, true },
            { "dark", darkHalo, .24, .43, .47, .49, false },
        };
        for (const auto& set : sets) {
            const QList<QPair<QString, Rgb8>> halo { { QStringLiteral("halo"), set.halo.rgb() } };
            QMap<QString, QString> out;
            const auto solved = [&](double L, double C, double h) {
                return push(Col(L, std::min(C, maxChroma(L, h)), h), halo, 4.5, set.preferUp, margin).col.hex();
            };
            out.insert(QStringLiteral("ink"), solved(set.ink, iC, inkH));
            out.insert(QStringLiteral("inkMuted"), solved(set.muted, iC * .5, inkH));
            out.insert(QStringLiteral("signal"), solved(set.signal, sigC.C, sigC.h));
            out.insert(QStringLiteral("alert"), solved(set.alert, alertC2.C, alertC2.h));
            out.insert(QStringLiteral("halo"), set.halo.hex());
            s.clearInk.insert(QString::fromLatin1(set.key), out);
        }
    }

    g.adjustments = adjustments;
    g.gates = validate(s, level, table, true);
    g.fingerprint = schemeFingerprint(g);
    if (!allPass(g.gates)) {
        QStringList failed;
        for (const auto& row : g.gates)
            if (!row.pass)
                failed << QStringLiteral("%1 %2 < %3").arg(row.label, num(row.ratio), num(row.min));
        return Error { Error::GatesUnreachable,
            QStringLiteral("generated scheme fails its gates (engine bug): %1").arg(failed.join(QStringLiteral("; "))) };
    }
    return g;
}

} // namespace hornero::chromatic
