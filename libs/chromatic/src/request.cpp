// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/request.hpp"

#include "hornero/chromatic/colour.hpp"

#include <QJsonArray>
#include <QJsonDocument>

#include <array>
#include <cmath>
#include <utility>

namespace hornero::chromatic {

namespace {

template <typename E, std::size_t N>
std::optional<E> lookup(const std::array<std::pair<E, const char*>, N>& table, const QString& text) {
    for (const auto& [value, label] : table)
        if (text == QLatin1String(label))
            return value;
    return std::nullopt;
}

template <typename E, std::size_t N> QString label(const std::array<std::pair<E, const char*>, N>& table, E v) {
    for (const auto& [value, text] : table)
        if (value == v)
            return QString::fromLatin1(text);
    return {};
}

constexpr std::array<std::pair<Variant, const char*>, 9> kVariants { {
    { Variant::Auto, "auto" },
    { Variant::Balanced, "balanced" },
    { Variant::Vibrant, "vibrant" },
    { Variant::Expressive, "expressive" },
    { Variant::Faithful, "faithful" },
    { Variant::Muted, "muted" },
    { Variant::Monochrome, "monochrome" },
    { Variant::HighContrast, "high-contrast" },
    { Variant::Neon, "neon" },
} };
constexpr std::array<std::pair<Mode, const char*>, 3> kModes { {
    { Mode::Auto, "auto" },
    { Mode::Dark, "dark" },
    { Mode::Light, "light" },
} };
constexpr std::array<std::pair<Contrast, const char*>, 4> kContrasts { {
    { Contrast::Auto, "auto" },
    { Contrast::Standard, "standard" },
    { Contrast::Boosted, "boosted" },
    { Contrast::Maximum, "maximum" },
} };
constexpr std::array<std::pair<Depth, const char*>, 2> kDepths { {
    { Depth::Standard, "standard" },
    { Depth::Deep, "deep" },
} };
constexpr std::array<std::pair<SourceSel, const char*>, 4> kSources { {
    { SourceSel::Wallpaper, "wallpaper" },
    { SourceSel::Image, "image" },
    { SourceSel::Seed, "seed" },
    { SourceSel::House, "house" },
} };

QByteArray fixed4(double v) {
    return QByteArray::number(v, 'f', 4);
}

Error usage(const QString& message) {
    return Error { Error::Usage, message };
}

} // namespace

QString name(Variant v) {
    return label(kVariants, v);
}
QString name(Mode v) {
    return label(kModes, v);
}
QString name(Contrast v) {
    return label(kContrasts, v);
}
QString name(Depth v) {
    return label(kDepths, v);
}
QString name(SourceSel v) {
    return label(kSources, v);
}
std::optional<Variant> parseVariant(const QString& s) {
    return lookup(kVariants, s);
}
std::optional<Mode> parseMode(const QString& s) {
    return lookup(kModes, s);
}
std::optional<Contrast> parseContrast(const QString& s) {
    return lookup(kContrasts, s);
}
std::optional<Depth> parseDepth(const QString& s) {
    return lookup(kDepths, s);
}
std::optional<SourceSel> parseSource(const QString& s) {
    return lookup(kSources, s);
}

const QList<Variant>& concreteVariants() {
    static const QList<Variant> list { Variant::Balanced, Variant::Vibrant, Variant::Expressive, Variant::Faithful,
        Variant::Muted, Variant::Monochrome, Variant::HighContrast, Variant::Neon };
    return list;
}

QJsonObject Request::toJson(bool withPath) const {
    QJsonObject o;
    o.insert(QStringLiteral("source"), name(source));
    if (withPath)
        o.insert(QStringLiteral("path"), path);
    o.insert(QStringLiteral("seeds"), QJsonArray::fromStringList(seeds));
    o.insert(QStringLiteral("variant"), name(variant));
    o.insert(QStringLiteral("mode"), name(mode));
    o.insert(QStringLiteral("contrast"), name(contrast));
    o.insert(QStringLiteral("surfaceDepth"), name(depth));
    o.insert(QStringLiteral("chroma"), std::round(chroma * 1e4) / 1e4);
    o.insert(QStringLiteral("hueShift"), std::round(hueShift * 1e4) / 1e4);
    return o;
}

QByteArray Request::canonicalJson() const {
    // Hand-built so the float format is fixed and independent of Qt's
    // shortest-representation printer. Keys sorted.
    QByteArray seedList;
    for (qsizetype i = 0; i < seeds.size(); ++i) {
        if (i)
            seedList += ',';
        seedList += '"' + seeds[i].toLatin1() + '"';
    }
    QByteArray out = "{";
    out += "\"chroma\":" + fixed4(chroma);
    out += ",\"contrast\":\"" + name(contrast).toLatin1() + '"';
    out += ",\"currentMode\":\"" + (currentMode ? name(*currentMode).toLatin1() : QByteArray("none")) + '"';
    out += ",\"hueShift\":" + fixed4(hueShift);
    out += ",\"mode\":\"" + name(mode).toLatin1() + '"';
    out += ",\"seeds\":[" + seedList + ']';
    out += ",\"source\":\"" + name(source).toLatin1() + '"';
    out += ",\"surfaceDepth\":\"" + name(depth).toLatin1() + '"';
    out += ",\"variant\":\"" + name(variant).toLatin1() + '"';
    out += '}';
    return out;
}

Expected<Request> requestFromJson(const QJsonObject& o) {
    Request r;
    const auto text = [&o](const char* key) { return o.value(QLatin1String(key)).toString(); };
    if (o.contains(QLatin1String("source"))) {
        const QString s = text("source");
        // "image:/path" is the horneroctl flag spelling; accept it here too.
        if (s.startsWith(QLatin1String("image:"))) {
            r.source = SourceSel::Image;
            r.path = s.mid(6);
        } else if (const auto v = parseSource(s)) {
            r.source = *v;
        } else {
            return usage(QStringLiteral("unknown source '%1'").arg(s));
        }
    }
    if (o.contains(QLatin1String("path")))
        r.path = text("path");
    if (o.contains(QLatin1String("seeds"))) {
        const auto seeds = o.value(QLatin1String("seeds"));
        if (!seeds.isArray())
            return usage(QStringLiteral("seeds must be an array"));
        for (const auto& s : seeds.toArray()) {
            const auto hex = parseHex(s.toString());
            if (!hex)
                return usage(QStringLiteral("seed '%1' is not #RRGGBB").arg(s.toString()));
            r.seeds.append(toHex(*hex));
        }
    }
    const auto parseInto = [&](const char* key, auto parser, auto& field) -> std::optional<Error> {
        if (!o.contains(QLatin1String(key)))
            return std::nullopt;
        const auto v = parser(text(key));
        if (!v)
            return usage(QStringLiteral("unknown %1 '%2'").arg(QLatin1String(key), text(key)));
        field = *v;
        return std::nullopt;
    };
    if (auto e = parseInto("variant", parseVariant, r.variant))
        return *e;
    if (auto e = parseInto("mode", parseMode, r.mode))
        return *e;
    if (auto e = parseInto("contrast", parseContrast, r.contrast))
        return *e;
    if (auto e = parseInto("surfaceDepth", parseDepth, r.depth))
        return *e;
    if (o.contains(QLatin1String("currentMode")) && !o.value(QLatin1String("currentMode")).isNull()) {
        const auto m = parseMode(text("currentMode"));
        if (!m || *m == Mode::Auto)
            return usage(QStringLiteral("currentMode must be dark or light"));
        r.currentMode = *m;
    }
    if (o.contains(QLatin1String("chroma")))
        r.chroma = o.value(QLatin1String("chroma")).toDouble(-1.0);
    if (o.contains(QLatin1String("hueShift")))
        r.hueShift = o.value(QLatin1String("hueShift")).toDouble(999.0);
    if (auto e = checkRequest(r))
        return *e;
    return r;
}

std::optional<Error> checkRequest(const Request& r) {
    if (!(r.chroma >= 0.5 && r.chroma <= 1.5))
        return usage(QStringLiteral("chroma must be within 0.5..1.5"));
    if (!(r.hueShift >= -180.0 && r.hueShift <= 180.0))
        return usage(QStringLiteral("hueShift must be within -180..180"));
    if (r.seeds.size() > 2)
        return usage(QStringLiteral("at most two seeds"));
    if (r.source == SourceSel::Seed && r.seeds.isEmpty())
        return usage(QStringLiteral("source 'seed' needs at least one seed colour"));
    if (r.source == SourceSel::Image && r.path.isEmpty())
        return usage(QStringLiteral("source 'image' needs a path"));
    return std::nullopt;
}

} // namespace hornero::chromatic
