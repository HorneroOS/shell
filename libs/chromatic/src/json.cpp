// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/json.hpp"

#include <QCryptographicHash>
#include <QJsonDocument>

#include <cmath>

namespace hornero::chromatic {

namespace {

QString kindName(SourceKind k) {
    switch (k) {
    case SourceKind::Animated:
        return QStringLiteral("animated");
    case SourceKind::Video:
        return QStringLiteral("video");
    case SourceKind::Still:
        break;
    }
    return QStringLiteral("still");
}

std::optional<SourceKind> parseKind(const QString& s) {
    if (s == QLatin1String("still"))
        return SourceKind::Still;
    if (s == QLatin1String("animated"))
        return SourceKind::Animated;
    if (s == QLatin1String("video"))
        return SourceKind::Video;
    return std::nullopt;
}

QJsonValue optionalNumber(const std::optional<double>& v, bool rounded = true) {
    if (!v)
        return QJsonValue::Null;
    return rounded ? round4(*v) : *v;
}

QJsonObject band(const BandStats& b, bool rounded) {
    return { { QStringLiteral("meanL"), rounded ? round4(b.meanL) : b.meanL },
        { QStringLiteral("stdL"), rounded ? round4(b.stdL) : b.stdL } };
}

QJsonArray seedsJson(const QList<Seed>& seeds, bool rounded) {
    QJsonArray out;
    const auto r = [rounded](double v) { return rounded ? round4(v) : v; };
    for (const auto& s : seeds) {
        out.append(QJsonObject { { QStringLiteral("hex"), s.hex },
            { QStringLiteral("oklch"), QJsonArray { r(s.lch.L), r(s.lch.C), r(s.lch.h) } },
            { QStringLiteral("share"), r(s.share) }, { QStringLiteral("score"), r(s.score) } });
    }
    return out;
}

QJsonObject statsJson(const Analysis& a, bool rounded) {
    const auto r = [rounded](double v) { return rounded ? round4(v) : v; };
    QJsonObject o;
    o.insert(QStringLiteral("sourceKey"), a.sourceDigest.isEmpty() ? QJsonValue(QJsonValue::Null) : a.sourceDigest);
    o.insert(QStringLiteral("kind"), kindName(a.kind));
    o.insert(QStringLiteral("meanL"), r(a.meanL));
    o.insert(QStringLiteral("Lmin"), r(a.Lmin));
    o.insert(QStringLiteral("Lmax"), r(a.Lmax));
    o.insert(QStringLiteral("L5"), r(a.L5));
    o.insert(QStringLiteral("L50"), r(a.L50));
    o.insert(QStringLiteral("L95"), r(a.L95));
    o.insert(QStringLiteral("stdL"), r(a.stdL));
    o.insert(QStringLiteral("meanC"), r(a.meanC));
    o.insert(QStringLiteral("C90"), r(a.C90));
    o.insert(QStringLiteral("C95"), r(a.C95));
    o.insert(QStringLiteral("brightC95"), r(a.brightC95));
    o.insert(QStringLiteral("hueEntropy"), r(a.hueEntropy));
    o.insert(QStringLiteral("detail"), r(a.detail));
    o.insert(QStringLiteral("top"), band(a.top, rounded));
    o.insert(QStringLiteral("bottom"), band(a.bottom, rounded));
    o.insert(QStringLiteral("seeds"), seedsJson(a.seeds, rounded));
    o.insert(QStringLiteral("neutralHue"), optionalNumber(a.neutralHue, rounded));
    o.insert(QStringLiteral("achromatic"), a.achromatic);
    if (!a.note.isEmpty())
        o.insert(QStringLiteral("note"), a.note);
    return o;
}

QJsonObject paletteJson(const QMap<QString, QString>& m) {
    QJsonObject o;
    for (auto it = m.begin(); it != m.end(); ++it)
        o.insert(it.key(), it.value());
    return o;
}

} // namespace

double round4(double v) {
    const double r = std::round(v * 1e4) / 1e4;
    return r + 0.0; // -0 + 0 == +0: normalise negative zero
}

QByteArray compact(const QJsonObject& o) {
    return QJsonDocument(o).toJson(QJsonDocument::Compact);
}

QString sha256Hex(const QByteArray& bytes) {
    return QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
}

QJsonObject engineJson() {
    return { { QStringLiteral("name"), QString::fromLatin1(kEngineName) },
        { QStringLiteral("version"), QString::fromLatin1(kEngineVersion) }, { QStringLiteral("algorithm"), kAlgorithm } };
}

QJsonObject toJson(const Analysis& a) {
    return statsJson(a, true);
}

QJsonObject toCacheJson(const Analysis& a) {
    QJsonObject o = statsJson(a, false);
    o.insert(QStringLiteral("algorithm"), a.algorithm);
    QJsonArray clusters;
    for (const auto& c : a.clusters)
        clusters.append(QJsonArray { c.lab.L, c.lab.a, c.lab.b, c.share });
    o.insert(QStringLiteral("clusters"), clusters);
    o.insert(QStringLiteral("weakHue"), optionalNumber(a.weakHue, false));
    o.insert(QStringLiteral("lumaGrid"), QString::fromLatin1(a.lumaGrid.toBase64()));
    return o;
}

Expected<Analysis> analysisFromCacheJson(const QJsonObject& o) {
    Analysis a;
    const auto d = [&o](const char* k) { return o.value(QLatin1String(k)).toDouble(); };
    a.algorithm = o.value(QLatin1String("algorithm")).toInt(-1);
    if (a.algorithm != kAlgorithm)
        return Error { Error::Internal, QStringLiteral("cache entry from another algorithm") };
    a.sourceDigest = o.value(QLatin1String("sourceKey")).toString();
    const auto kind = parseKind(o.value(QLatin1String("kind")).toString());
    if (!kind)
        return Error { Error::Internal, QStringLiteral("cache entry: bad kind") };
    a.kind = *kind;
    a.meanL = d("meanL");
    a.Lmin = d("Lmin");
    a.Lmax = d("Lmax");
    a.L5 = d("L5");
    a.L50 = d("L50");
    a.L95 = d("L95");
    a.stdL = d("stdL");
    a.meanC = d("meanC");
    a.C90 = d("C90");
    a.C95 = d("C95");
    a.brightC95 = d("brightC95");
    a.hueEntropy = d("hueEntropy");
    a.detail = d("detail");
    const auto bandFrom = [&o](const char* k) {
        const QJsonObject b = o.value(QLatin1String(k)).toObject();
        return BandStats { b.value(QLatin1String("meanL")).toDouble(), b.value(QLatin1String("stdL")).toDouble() };
    };
    a.top = bandFrom("top");
    a.bottom = bandFrom("bottom");
    for (const auto& v : o.value(QLatin1String("seeds")).toArray()) {
        const QJsonObject s = v.toObject();
        const QJsonArray lch = s.value(QLatin1String("oklch")).toArray();
        a.seeds.append({ s.value(QLatin1String("hex")).toString(),
            Oklch { lch.at(0).toDouble(), lch.at(1).toDouble(), lch.at(2).toDouble() },
            s.value(QLatin1String("share")).toDouble(), s.value(QLatin1String("score")).toDouble() });
    }
    for (const auto& v : o.value(QLatin1String("clusters")).toArray()) {
        const QJsonArray c = v.toArray();
        a.clusters.append({ Oklab { c.at(0).toDouble(), c.at(1).toDouble(), c.at(2).toDouble() }, c.at(3).toDouble() });
    }
    if (o.value(QLatin1String("neutralHue")).isDouble())
        a.neutralHue = d("neutralHue");
    if (o.value(QLatin1String("weakHue")).isDouble())
        a.weakHue = d("weakHue");
    a.achromatic = o.value(QLatin1String("achromatic")).toBool();
    a.note = o.value(QLatin1String("note")).toString();
    a.lumaGrid = QByteArray::fromBase64(o.value(QLatin1String("lumaGrid")).toString().toLatin1());
    return a;
}

QJsonObject toJson(const Inference& i) {
    QJsonObject o;
    o.insert(QStringLiteral("mode"), name(i.mode));
    o.insert(QStringLiteral("variant"), name(i.variant));
    o.insert(QStringLiteral("contrast"), name(i.contrast));
    o.insert(QStringLiteral("reasons"), QJsonArray::fromStringList(i.reasons));
    o.insert(QStringLiteral("confidence"), round4(i.confidence));
    o.insert(QStringLiteral("personality"), i.personality);
    o.insert(QStringLiteral("chromaClass"), i.chromaClass);
    o.insert(QStringLiteral("temperature"), i.temperature);
    o.insert(QStringLiteral("suggestion"), i.suggestion ? QJsonValue(name(*i.suggestion)) : QJsonValue(QJsonValue::Null));
    return o;
}

QJsonObject toJson(const GateRow& r) {
    return { { QStringLiteral("label"), r.label }, { QStringLiteral("ratio"), round4(r.ratio) },
        { QStringLiteral("min"), r.min }, { QStringLiteral("pass"), r.pass } };
}

QJsonArray toJson(const QList<GateRow>& rows) {
    QJsonArray out;
    for (const auto& r : rows)
        out.append(QJsonArray { r.label, round4(r.ratio), r.min });
    return out;
}

QJsonObject schemeJson(const Generated& g, bool withFingerprint) {
    const Scheme& s = g.scheme;
    QJsonObject chromatic;
    chromatic.insert(QStringLiteral("version"), 1);
    chromatic.insert(QStringLiteral("engine"), QString::fromLatin1(kEngineVersion));
    chromatic.insert(QStringLiteral("algorithm"), kAlgorithm);
    if (withFingerprint)
        chromatic.insert(QStringLiteral("fingerprint"), g.fingerprint);
    QJsonObject request = g.request.toJson(false);
    chromatic.insert(QStringLiteral("request"), request);
    chromatic.insert(QStringLiteral("resolved"),
        QJsonObject { { QStringLiteral("mode"), name(g.inference.mode) },
            { QStringLiteral("variant"), name(g.inference.variant) },
            { QStringLiteral("contrast"), name(g.inference.contrast) } });
    chromatic.insert(QStringLiteral("seeds"), QJsonArray::fromStringList(g.seeds));
    chromatic.insert(QStringLiteral("sourceKey"), g.sourceKey.isEmpty() ? QJsonValue(QJsonValue::Null) : g.sourceKey);

    QJsonArray terminal;
    for (const auto& t : s.terminal)
        terminal.append(t);
    QJsonObject alpha;
    for (auto it = s.minSurfaceAlpha.begin(); it != s.minSurfaceAlpha.end(); ++it)
        alpha.insert(it.key(), std::round(it.value() * 100.0) / 100.0);
    QJsonObject clear;
    for (auto it = s.clearInk.begin(); it != s.clearInk.end(); ++it)
        clear.insert(it.key(), paletteJson(it.value()));

    QJsonObject o;
    o.insert(QStringLiteral("schemaVersion"), 2);
    o.insert(QStringLiteral("id"), s.id);
    o.insert(QStringLiteral("mode"), name(s.mode));
    o.insert(QStringLiteral("palette"), paletteJson(s.palette));
    o.insert(QStringLiteral("terminal"), terminal);
    o.insert(QStringLiteral("chromatic"), chromatic);
    o.insert(QStringLiteral("minSurfaceAlpha"), alpha);
    o.insert(QStringLiteral("clearInk"), clear);
    return o;
}

QString schemeFingerprint(const Generated& g) {
    return QStringLiteral("sha256:") + sha256Hex(compact(schemeJson(g, false)));
}

QJsonObject toJson(const Generated& g) {
    QJsonObject o;
    o.insert(QStringLiteral("schemaVersion"), kSchemaVersion);
    o.insert(QStringLiteral("engine"), engineJson());
    o.insert(QStringLiteral("request"), g.request.toJson(true));
    o.insert(QStringLiteral("analysis"), g.analysis ? QJsonValue(toJson(*g.analysis)) : QJsonValue(QJsonValue::Null));
    o.insert(QStringLiteral("inference"), toJson(g.inference));
    o.insert(QStringLiteral("scheme"), schemeJson(g, true));
    bool passed = allPass(g.gates);
    o.insert(QStringLiteral("gates"),
        QJsonObject { { QStringLiteral("level"), name(g.inference.contrast) }, { QStringLiteral("passed"), passed },
            { QStringLiteral("rows"), toJson(g.gates) } });
    QJsonArray adjustments;
    for (const auto& a : g.adjustments)
        adjustments.append(QJsonObject { { QStringLiteral("role"), a.role }, { QStringLiteral("from"), a.from },
            { QStringLiteral("to"), a.to }, { QStringLiteral("reason"), a.reason } });
    o.insert(QStringLiteral("adjustments"), adjustments);
    o.insert(QStringLiteral("fingerprint"), g.fingerprint);
    return o;
}

Expected<Scheme> schemeFromJson(const QJsonObject& o) {
    // Accept a helper `generate` document too: validate its scheme.
    if (o.value(QLatin1String("scheme")).isObject())
        return schemeFromJson(o.value(QLatin1String("scheme")).toObject());
    Scheme s;
    const QJsonValue palette = o.value(QLatin1String("palette"));
    if (!palette.isObject())
        return Error { Error::Usage, QStringLiteral("scheme has no palette object") };
    const QJsonObject p = palette.toObject();
    QStringList missing;
    for (const auto& role : signalRoles()) {
        const auto hex = parseHex(p.value(role).toString());
        if (!hex) {
            missing << role;
            continue;
        }
        s.palette.insert(role, toHex(*hex));
    }
    if (!missing.isEmpty())
        return Error { Error::Usage, QStringLiteral("palette missing or invalid roles: %1").arg(missing.join(u", ")) };
    if (const auto glow = parseHex(p.value(QLatin1String("glow")).toString()))
        s.palette.insert(QStringLiteral("glow"), toHex(*glow));
    const QJsonArray term = o.value(QLatin1String("terminal")).toArray();
    if (term.size() != 16)
        return Error { Error::Usage, QStringLiteral("terminal must hold exactly 16 colours") };
    for (qsizetype i = 0; i < 16; ++i) {
        const auto hex = parseHex(term.at(i).toString());
        if (!hex)
            return Error { Error::Usage, QStringLiteral("terminal[%1] is not #RRGGBB").arg(i) };
        s.terminal[static_cast<std::size_t>(i)] = toHex(*hex);
    }
    const auto mode = parseMode(o.value(QLatin1String("mode")).toString());
    s.mode = mode && *mode != Mode::Auto ? *mode : Mode::Dark;
    s.id = o.value(QLatin1String("id")).toString(s.id);
    return s;
}

} // namespace hornero::chromatic
