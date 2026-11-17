// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/solver.hpp"

#include "hornero/chromatic/colour.hpp"
#include "hornero/chromatic/synth.hpp"

#include "chromatic_gates_data.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <cmath>
#include <cstdlib>

namespace hornero::chromatic {

namespace {

QJsonObject merged(const QJsonObject& parent, const QJsonObject& child) {
    QJsonObject out = parent;
    for (auto it = child.begin(); it != child.end(); ++it) {
        if (it.value().isObject() && out.value(it.key()).isObject())
            out.insert(it.key(), merged(out.value(it.key()).toObject(), it.value().toObject()));
        else
            out.insert(it.key(), it.value());
    }
    return out;
}

QStringList strings(const QJsonValue& v) {
    QStringList out;
    for (const auto& x : v.toArray())
        out << x.toString();
    return out;
}

QList<QPair<QString, QString>> pairs(const QJsonValue& v) {
    QList<QPair<QString, QString>> out;
    for (const auto& x : v.toArray()) {
        const QJsonArray p = x.toArray();
        out.append({ p.at(0).toString(), p.at(1).toString() });
    }
    return out;
}

Expected<LevelGates> parseLevel(const QJsonObject& o) {
    LevelGates g;
    const QJsonObject text = o.value(QLatin1String("text")).toObject();
    g.textRoles = strings(text.value(QLatin1String("roles")));
    g.textOn = strings(text.value(QLatin1String("on")));
    g.textMin = text.value(QLatin1String("min")).toDouble(-1);
    const QJsonObject over = o.value(QLatin1String("textOverrides")).toObject();
    for (auto it = over.begin(); it != over.end(); ++it)
        g.textOverrides.insert(it.key(), it.value().toDouble());
    const QJsonObject on = o.value(QLatin1String("onPairs")).toObject();
    g.onPairsMin = on.value(QLatin1String("min")).toDouble(-1);
    g.onPairs = pairs(on.value(QLatin1String("pairs")));
    const QJsonObject boundary = o.value(QLatin1String("boundary")).toObject();
    g.boundaryRoles = strings(boundary.value(QLatin1String("roles")));
    g.boundaryOn = strings(boundary.value(QLatin1String("on")));
    g.boundaryMin = boundary.value(QLatin1String("min")).toDouble(-1);
    const QJsonObject focus = o.value(QLatin1String("focus")).toObject();
    g.focusOn = strings(focus.value(QLatin1String("on")));
    g.focusMin = focus.value(QLatin1String("min")).toDouble(-1);
    if (g.textRoles.isEmpty() || g.textOn.isEmpty() || g.textMin <= 0 || g.onPairsMin <= 0 || g.onPairs.isEmpty()
        || g.boundaryMin <= 0 || g.focusMin <= 0)
        return Error { Error::Internal, QStringLiteral("gate level is incomplete") };
    return g;
}

QString level_name(Contrast c) {
    switch (c) {
    case Contrast::Boosted:
        return QStringLiteral("boosted");
    case Contrast::Maximum:
        return QStringLiteral("maximum");
    case Contrast::Auto:
    case Contrast::Standard:
        break;
    }
    return QStringLiteral("standard");
}

} // namespace

QByteArray GateTable::builtinJson() {
    return QByteArray(detail::kContrastGatesJson);
}

const GateTable& GateTable::builtin() {
    static const GateTable table = [] {
        auto parsed = fromJson(builtinJson());
        if (!parsed) {
            // The table is compiled in and covered by unit tests; a parse
            // failure here is a build defect, never user input.
            qFatal("hornero-chromatic: built-in gate table is invalid: %s", qPrintable(parsed.error().message));
        }
        return parsed.value();
    }();
    return table;
}

Expected<GateTable> GateTable::fromJson(const QByteArray& bytes) {
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return Error { Error::Internal, QStringLiteral("gate table: %1").arg(err.errorString()) };
    const QJsonObject root = doc.object();
    GateTable t;
    t.version = root.value(QLatin1String("version")).toInt();
    const QJsonObject levels = root.value(QLatin1String("levels")).toObject();
    QMap<QString, QJsonObject> resolved;
    // Resolve `inherits` (one level deep, as the table uses it).
    for (const QString& key : levels.keys()) {
        QJsonObject level = levels.value(key).toObject();
        const QString parent = level.value(QLatin1String("inherits")).toString();
        if (!parent.isEmpty()) {
            if (!levels.contains(parent))
                return Error { Error::Internal, QStringLiteral("gate level %1 inherits unknown %2").arg(key, parent) };
            level = merged(levels.value(parent).toObject(), level);
        }
        resolved.insert(key, level);
    }
    for (const char* key : { "standard", "boosted", "maximum" }) {
        const QString k = QString::fromLatin1(key);
        if (!resolved.contains(k))
            return Error { Error::Internal, QStringLiteral("gate table lacks level %1").arg(k) };
        auto level = parseLevel(resolved.value(k));
        if (!level)
            return Error { Error::Internal, QStringLiteral("level %1: %2").arg(k, level.error().message) };
        t.levels.insert(k, level.value());
    }
    const QJsonObject term = root.value(QLatin1String("terminal")).toObject();
    t.terminal.background = term.value(QLatin1String("background")).toString(QStringLiteral("base"));
    t.terminal.foreground = term.value(QLatin1String("foreground")).toString(QStringLiteral("ink"));
    t.terminal.normalMin = term.value(QLatin1String("normalMin")).toDouble(4.5);
    t.terminal.brightMin = term.value(QLatin1String("brightMin")).toDouble(3.0);
    t.terminal.rgyMinDeltaE76 = term.value(QLatin1String("rgyMinDeltaE76")).toDouble(10.0);
    t.terminal.rampMinDeltaE76 = term.value(QLatin1String("rampMinDeltaE76")).toDouble(6.0);
    const QJsonObject extra = root.value(QLatin1String("chromaticExtra")).toObject();
    t.focusOnEverySurfaceMin = extra.value(QLatin1String("focusOnEverySurfaceMin")).toDouble(3.0);
    const QJsonObject sep = extra.value(QLatin1String("separation")).toObject();
    t.separation.pairs = pairs(sep.value(QLatin1String("pairs")));
    t.separation.minDeltaEOK = sep.value(QLatin1String("minDeltaEOK")).toDouble(0.10);
    t.separation.minHueDeg = sep.value(QLatin1String("minHueDeg")).toDouble(25.0);
    t.margin = root.value(QLatin1String("margin")).toDouble(0.15);
    return t;
}

const LevelGates& GateTable::level(Contrast c) const {
    const auto it = levels.constFind(level_name(c));
    if (it != levels.constEnd())
        return *it;
    return *levels.constFind(QStringLiteral("standard"));
}

QList<GateRow> validate(const Scheme& s, Contrast level, const GateTable& table, bool chromaticExtra) {
    QList<GateRow> rows;
    const LevelGates& g = table.level(level);
    const auto rgb = [&s](const QString& role) { return parseHex(s.palette.value(role)).value_or(Rgb8 {}); };
    const auto ratioRow = [&](const QString& fg, const QString& bg, double minimum) {
        const double r = contrastRatio(rgb(fg), rgb(bg));
        rows.append({ QStringLiteral("%1 on %2").arg(fg, bg), r, minimum, r >= minimum });
    };
    for (const auto& role : g.textRoles)
        for (const auto& surface : g.textOn)
            ratioRow(role, surface, g.textMinFor(role));
    for (const auto& [fg, bg] : g.onPairs)
        ratioRow(fg, bg, g.onPairsMin);
    for (const auto& role : g.boundaryRoles)
        for (const auto& surface : g.boundaryOn)
            ratioRow(role, surface, g.boundaryMin);
    QStringList focusOn = g.focusOn;
    double focusMin = g.focusMin;
    if (chromaticExtra) {
        for (const auto& surface : surfaceRoles())
            if (!focusOn.contains(surface))
                focusOn << surface;
        focusMin = std::max(focusMin, table.focusOnEverySurfaceMin);
    }
    for (const auto& surface : focusOn)
        ratioRow(QStringLiteral("focus"), surface, focusMin);

    // Terminal (config terminal_errors semantics).
    const TerminalGates& tg = table.terminal;
    const Rgb8 bg = rgb(tg.background);
    {
        const double r = contrastRatio(rgb(tg.foreground), bg);
        rows.append({ QStringLiteral("terminal foreground (%1) on %2").arg(tg.foreground, tg.background), r,
            tg.normalMin, r >= tg.normalMin });
    }
    std::array<Rgb8, 16> term {};
    for (std::size_t i = 0; i < 16; ++i)
        term[i] = parseHex(s.terminal[i]).value_or(Rgb8 {});
    for (std::size_t i = 1; i < 7; ++i) {
        const double r = contrastRatio(term[i], bg);
        rows.append({ QStringLiteral("terminal[%1] on %2").arg(i).arg(tg.background), r, tg.normalMin, r >= tg.normalMin });
    }
    for (std::size_t i = 9; i < 15; ++i) {
        const double r = contrastRatio(term[i], bg);
        rows.append({ QStringLiteral("terminal[%1] on %2").arg(i).arg(tg.background), r, tg.brightMin, r >= tg.brightMin });
    }
    for (std::size_t start : { std::size_t { 1 }, std::size_t { 9 } }) {
        const struct {
            std::size_t a, b;
            const char* label;
        } rgy[] = { { 0, 1, "red/green" }, { 0, 2, "red/yellow" }, { 1, 2, "green/yellow" } };
        for (const auto& pr : rgy) {
            const double d = deltaE76(term[start + pr.a], term[start + pr.b]);
            rows.append({ QStringLiteral("terminal %1 (from %2) dE76").arg(QLatin1String(pr.label)).arg(start), d,
                tg.rgyMinDeltaE76, d >= tg.rgyMinDeltaE76 });
        }
    }
    for (std::size_t i = 1; i < 7; ++i) {
        const double d = deltaE76(term[i], term[i + 8]);
        rows.append({ QStringLiteral("terminal[%1] vs [%2] dE76").arg(i).arg(i + 8), d, tg.rampMinDeltaE76,
            d >= tg.rampMinDeltaE76 });
    }

    if (chromaticExtra) {
        for (const auto& surface : { QStringLiteral("base"), QStringLiteral("panel") })
            ratioRow(QStringLiteral("inkFaint"), surface, 3.0);
        for (const auto& [x, y] : table.separation.pairs) {
            const Oklab a = toOklab(toSrgb(rgb(x)));
            const Oklab b = toOklab(toSrgb(rgb(y)));
            const double d = deltaEOK(a, b);
            rows.append({ QStringLiteral("%1 vs %2 dEOK").arg(x, y), d, table.separation.minDeltaEOK,
                d >= table.separation.minDeltaEOK });
            const double dh = std::abs(hueDiff(toOklch(a).h, toOklch(b).h));
            rows.append({ QStringLiteral("%1 vs %2 hue").arg(x, y), dh, table.separation.minHueDeg,
                dh >= table.separation.minHueDeg });
        }
    }
    return rows;
}

bool allPass(const QList<GateRow>& rows) {
    for (const auto& r : rows)
        if (!r.pass)
            return false;
    return true;
}

} // namespace hornero::chromatic
