// SPDX-License-Identifier: GPL-3.0-only
//
// hornero-chromatic — internal helper for horneroctl (RFC 0002 §10.1).
// One JSON document on stdout, diagnostics on stderr.
// Exit: 0 ok · 2 usage · 3 source unreadable · 4 gates unreachable · 5 internal.
#include "hornero/chromatic/engine.hpp"
#include "hornero/chromatic/json.hpp"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QFile>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTextStream>

#include <cstdio>

using namespace hornero::chromatic;

namespace {

bool g_pretty = false;

int printJson(const QJsonObject& doc, int code = 0) {
    const QByteArray bytes = QJsonDocument(doc).toJson(g_pretty ? QJsonDocument::Indented : QJsonDocument::Compact);
    std::fwrite(bytes.constData(), 1, static_cast<std::size_t>(bytes.size()), stdout);
    if (!g_pretty)
        std::fputc('\n', stdout);
    std::fflush(stdout);
    return code;
}

int fail(const Error& e) {
    QTextStream(stderr) << "hornero-chromatic: " << e.codeName() << ": " << e.message << '\n';
    return printJson(QJsonObject { { QStringLiteral("schemaVersion"), kSchemaVersion },
                    { QStringLiteral("engine"), engineJson() },
                    { QStringLiteral("error"),
                        QJsonObject { { QStringLiteral("code"), e.codeName() },
                            { QStringLiteral("message"), e.message } } } },
        static_cast<int>(e.code));
}

int usage(const QString& message) {
    return fail(Error { Error::Usage, message });
}

constexpr const char* kSynopsis = R"(usage:
  hornero-chromatic analyze  --source PATH [--frames N] [--cache-dir DIR | --no-cache] [--pretty]
  hornero-chromatic generate (--source PATH | --seed HEX [--seed HEX] | --house) [--wallpaper PATH]
                             [--variant V] [--mode auto|dark|light] [--current-mode dark|light]
                             [--contrast auto|standard|boosted|maximum] [--depth standard|deep]
                             [--chroma 0.5..1.5] [--hue-shift -180..180] [--request FILE]
                             [--cache-dir DIR | --no-cache] [--pretty]
  hornero-chromatic validate --scheme FILE [--level standard|boosted|maximum] [--pretty]
  hornero-chromatic variants [--pretty]
  hornero-chromatic version  [--pretty]
)";

struct Common {
    QString cacheDir;
    bool noCache = false;
};

void addCommon(QCommandLineParser& p) {
    p.addOption({ QStringLiteral("pretty"), QStringLiteral("Indented JSON.") });
    p.addOption({ QStringLiteral("cache-dir"), QStringLiteral("Cache directory."), QStringLiteral("DIR") });
    p.addOption({ QStringLiteral("no-cache"), QStringLiteral("Do not read or write the disk cache.") });
}

Engine makeEngine(const QCommandLineParser& p, int frames = 8) {
    EngineOptions o;
    if (!p.isSet(QStringLiteral("no-cache")))
        o.cacheDir = p.isSet(QStringLiteral("cache-dir")) ? p.value(QStringLiteral("cache-dir")) : DiskCache::defaultDir();
    o.maxFrames = frames;
    return Engine(o);
}

std::optional<double> number(const QString& text) {
    bool ok = false;
    const double v = text.toDouble(&ok);
    return ok ? std::optional<double>(v) : std::nullopt;
}

int cmdAnalyze(const QStringList& args) {
    QCommandLineParser p;
    addCommon(p);
    p.addOption({ QStringLiteral("source"), QStringLiteral("Image or video."), QStringLiteral("PATH") });
    p.addOption({ QStringLiteral("frames"), QStringLiteral("Animated frames to sample (1..8)."), QStringLiteral("N") });
    if (!p.parse(args))
        return usage(p.errorText());
    g_pretty = p.isSet(QStringLiteral("pretty"));
    if (!p.positionalArguments().isEmpty())
        return usage(QStringLiteral("unexpected argument '%1'").arg(p.positionalArguments().first()));
    if (!p.isSet(QStringLiteral("source")))
        return usage(QStringLiteral("analyze needs --source PATH"));
    int frames = 8;
    if (p.isSet(QStringLiteral("frames"))) {
        bool ok = false;
        frames = p.value(QStringLiteral("frames")).toInt(&ok);
        if (!ok || frames < 1 || frames > 8)
            return usage(QStringLiteral("--frames must be 1..8"));
    }
    Engine engine = makeEngine(p, frames);
    const auto a = engine.analyse(p.value(QStringLiteral("source")));
    if (!a)
        return fail(a.error());
    Request r;
    r.source = SourceSel::Image;
    r.path = p.value(QStringLiteral("source"));
    const Inference inf = infer(&a.value(), r);
    return printJson({ { QStringLiteral("schemaVersion"), kSchemaVersion }, { QStringLiteral("engine"), engineJson() },
        { QStringLiteral("source"), QJsonObject { { QStringLiteral("path"), r.path } } },
        { QStringLiteral("analysis"), toJson(a.value()) }, { QStringLiteral("inference"), toJson(inf) } });
}

int cmdGenerate(const QStringList& args) {
    QCommandLineParser p;
    addCommon(p);
    const auto opt = [&p](const char* n, const char* help, const char* value = nullptr) {
        if (value)
            p.addOption({ QString::fromLatin1(n), QString::fromLatin1(help), QString::fromLatin1(value) });
        else
            p.addOption({ QString::fromLatin1(n), QString::fromLatin1(help) });
    };
    opt("source", "Image or video source.", "PATH");
    opt("seed", "Manual seed colour (repeat for a second).", "HEX");
    opt("house", "Signal house hues.");
    opt("wallpaper", "Wallpaper used by --house for the surface tint.", "PATH");
    opt("variant", "Variant.", "V");
    opt("mode", "auto|dark|light.", "M");
    opt("current-mode", "dark|light (hysteresis).", "M");
    opt("contrast", "auto|standard|boosted|maximum.", "C");
    opt("depth", "standard|deep.", "D");
    opt("chroma", "Chroma scale 0.5..1.5.", "F");
    opt("hue-shift", "Hue shift in degrees.", "DEG");
    opt("request", "JSON request file (RFC §8.3 keys); flags override.", "FILE");
    if (!p.parse(args))
        return usage(p.errorText());
    g_pretty = p.isSet(QStringLiteral("pretty"));
    if (!p.positionalArguments().isEmpty())
        return usage(QStringLiteral("unexpected argument '%1'").arg(p.positionalArguments().first()));

    Request r;
    if (p.isSet(QStringLiteral("request"))) {
        QFile f(p.value(QStringLiteral("request")));
        if (!f.open(QIODevice::ReadOnly))
            return usage(QStringLiteral("cannot read request file"));
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            return usage(QStringLiteral("request file is not a JSON object"));
        auto parsed = requestFromJson(doc.object());
        if (!parsed)
            return fail(parsed.error());
        r = parsed.value();
    }
    const int sources = int(p.isSet(QStringLiteral("source"))) + int(p.isSet(QStringLiteral("seed")))
        + int(p.isSet(QStringLiteral("house")));
    if (sources > 1)
        return usage(QStringLiteral("give one of --source, --seed or --house"));
    if (p.isSet(QStringLiteral("source"))) {
        // A request file may say "wallpaper"; keep that meaning for the path.
        if (r.source != SourceSel::Wallpaper)
            r.source = SourceSel::Image;
        r.path = p.value(QStringLiteral("source"));
        r.seeds.clear();
    } else if (p.isSet(QStringLiteral("seed"))) {
        r.source = SourceSel::Seed;
        r.path.clear();
        r.seeds.clear();
        for (const auto& s : p.values(QStringLiteral("seed"))) {
            const auto hex = parseHex(s);
            if (!hex)
                return usage(QStringLiteral("--seed '%1' is not #RRGGBB").arg(s));
            r.seeds << toHex(*hex);
        }
    } else if (p.isSet(QStringLiteral("house"))) {
        r.source = SourceSel::House;
        r.seeds.clear();
        r.path = p.value(QStringLiteral("wallpaper"));
    } else if (!p.isSet(QStringLiteral("request"))) {
        return usage(QStringLiteral("generate needs --source, --seed, --house or --request"));
    }
    if (p.isSet(QStringLiteral("wallpaper")) && r.source == SourceSel::House)
        r.path = p.value(QStringLiteral("wallpaper"));
    const auto enumFlag = [&p](const char* flag, auto parser, auto& field) -> std::optional<QString> {
        if (!p.isSet(QString::fromLatin1(flag)))
            return std::nullopt;
        const auto v = parser(p.value(QString::fromLatin1(flag)));
        if (!v)
            return QStringLiteral("unknown --%1 '%2'").arg(QLatin1String(flag), p.value(QString::fromLatin1(flag)));
        field = *v;
        return std::nullopt;
    };
    if (auto e = enumFlag("variant", parseVariant, r.variant))
        return usage(*e);
    if (auto e = enumFlag("mode", parseMode, r.mode))
        return usage(*e);
    if (auto e = enumFlag("contrast", parseContrast, r.contrast))
        return usage(*e);
    if (auto e = enumFlag("depth", parseDepth, r.depth))
        return usage(*e);
    if (p.isSet(QStringLiteral("current-mode"))) {
        const auto m = parseMode(p.value(QStringLiteral("current-mode")));
        if (!m || *m == Mode::Auto)
            return usage(QStringLiteral("--current-mode must be dark or light"));
        r.currentMode = *m;
    }
    if (p.isSet(QStringLiteral("chroma"))) {
        const auto v = number(p.value(QStringLiteral("chroma")));
        if (!v)
            return usage(QStringLiteral("--chroma must be a number"));
        r.chroma = *v;
    }
    if (p.isSet(QStringLiteral("hue-shift"))) {
        const auto v = number(p.value(QStringLiteral("hue-shift")));
        if (!v)
            return usage(QStringLiteral("--hue-shift must be a number"));
        r.hueShift = *v;
    }
    if (auto err = checkRequest(r))
        return fail(*err);
    Engine engine = makeEngine(p);
    const auto g = engine.generate(r);
    if (!g)
        return fail(g.error());
    return printJson(toJson(g.value()));
}

int cmdValidate(const QStringList& args) {
    QCommandLineParser p;
    p.addOption({ QStringLiteral("pretty"), QStringLiteral("Indented JSON.") });
    p.addOption({ QStringLiteral("scheme"), QStringLiteral("Scheme or theme JSON."), QStringLiteral("FILE") });
    p.addOption({ QStringLiteral("level"), QStringLiteral("standard|boosted|maximum."), QStringLiteral("L") });
    if (!p.parse(args))
        return usage(p.errorText());
    g_pretty = p.isSet(QStringLiteral("pretty"));
    if (!p.isSet(QStringLiteral("scheme")))
        return usage(QStringLiteral("validate needs --scheme FILE"));
    Contrast level = Contrast::Standard;
    if (p.isSet(QStringLiteral("level"))) {
        const auto l = parseContrast(p.value(QStringLiteral("level")));
        if (!l || *l == Contrast::Auto)
            return usage(QStringLiteral("--level must be standard, boosted or maximum"));
        level = *l;
    }
    QFile f(p.value(QStringLiteral("scheme")));
    if (!f.open(QIODevice::ReadOnly))
        return usage(QStringLiteral("cannot read scheme file"));
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return usage(QStringLiteral("scheme file is not a JSON object"));
    const auto scheme = schemeFromJson(doc.object());
    if (!scheme)
        return fail(scheme.error());
    QJsonObject root = doc.object();
    if (root.value(QLatin1String("scheme")).isObject())
        root = root.value(QLatin1String("scheme")).toObject();
    const bool extra = root.value(QLatin1String("chromatic")).isObject();
    const auto rows = validate(scheme.value(), level, GateTable::builtin(), extra);
    return printJson({ { QStringLiteral("schemaVersion"), kSchemaVersion }, { QStringLiteral("level"), name(level) },
        { QStringLiteral("chromaticExtra"), extra }, { QStringLiteral("passed"), allPass(rows) },
        { QStringLiteral("rows"), toJson(rows) } });
}

int cmdVariants(const QStringList& args) {
    QCommandLineParser p;
    p.addOption({ QStringLiteral("pretty"), QStringLiteral("Indented JSON.") });
    if (!p.parse(args))
        return usage(p.errorText());
    g_pretty = p.isSet(QStringLiteral("pretty"));
    QJsonArray list;
    for (Variant v : concreteVariants()) {
        const VariantParams& vp = params(v);
        list.append(QJsonObject { { QStringLiteral("id"), name(v) },
            { QStringLiteral("label"), QString::fromUtf8(vp.label) },
            { QStringLiteral("description"), QString::fromUtf8(vp.description) },
            { QStringLiteral("darkOnly"), vp.darkOnly },
            { QStringLiteral("auto"),
                v == Variant::Balanced || v == Variant::Vibrant || v == Variant::Expressive || v == Variant::Muted },
            { QStringLiteral("params"),
                QJsonObject { { QStringLiteral("surfaceChroma"), vp.sC }, { QStringLiteral("inkChroma"), vp.iC },
                    { QStringLiteral("accentChroma"), QJsonArray { vp.aCmin, vp.aCmax } },
                    { QStringLiteral("cueRotation"), vp.cueRot }, { QStringLiteral("harmonise"), vp.harm },
                    { QStringLiteral("terminalHarmonise"), vp.term }, { QStringLiteral("glow"), vp.glow },
                    { QStringLiteral("highContrast"), vp.highContrast } } } });
    }
    return printJson({ { QStringLiteral("schemaVersion"), kSchemaVersion }, { QStringLiteral("engine"), engineJson() },
        { QStringLiteral("variants"), list } });
}

int cmdVersion(const QStringList& args) {
    QCommandLineParser p;
    p.addOption({ QStringLiteral("pretty"), QStringLiteral("Indented JSON.") });
    if (!p.parse(args))
        return usage(p.errorText());
    g_pretty = p.isSet(QStringLiteral("pretty"));
    QStringList formats;
    for (const auto& f : QImageReader::supportedImageFormats())
        formats << QString::fromLatin1(f).toLower();
    formats.removeDuplicates();
    formats.sort();
    const QString ffmpeg = findFfmpeg();
    return printJson({ { QStringLiteral("schemaVersion"), kSchemaVersion }, { QStringLiteral("engine"), engineJson() },
        { QStringLiteral("algorithm"), kAlgorithm }, { QStringLiteral("qt"), QString::fromLatin1(qVersion()) },
        { QStringLiteral("formats"), QJsonArray::fromStringList(formats) },
        { QStringLiteral("ffmpeg"), ffmpeg.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(ffmpeg) } });
}

} // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("hornero-chromatic"));
    QCoreApplication::setApplicationVersion(QString::fromLatin1(kEngineVersion));
    QStringList args = QCoreApplication::arguments();
    if (args.size() < 2) {
        QTextStream(stderr) << kSynopsis;
        return usage(QStringLiteral("missing verb"));
    }
    const QString verb = args.takeAt(1);
    if (verb == QLatin1String("--help") || verb == QLatin1String("-h") || verb == QLatin1String("help")) {
        QTextStream(stdout) << kSynopsis;
        return 0;
    }
    if (verb == QLatin1String("analyze") || verb == QLatin1String("analyse"))
        return cmdAnalyze(args);
    if (verb == QLatin1String("generate"))
        return cmdGenerate(args);
    if (verb == QLatin1String("validate"))
        return cmdValidate(args);
    if (verb == QLatin1String("variants"))
        return cmdVariants(args);
    if (verb == QLatin1String("version") || verb == QLatin1String("--version"))
        return cmdVersion(args);
    QTextStream(stderr) << kSynopsis;
    return usage(QStringLiteral("unknown verb '%1'").arg(verb));
}
