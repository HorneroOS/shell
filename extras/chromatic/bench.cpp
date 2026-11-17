// SPDX-License-Identifier: GPL-3.0-only
//
// chromatic-bench <corpus-dir> [--iterations N]: RFC 0002 §14 timings as
// JSON (milliseconds, median of N). Not installed.
#include "hornero/chromatic/engine.hpp"
#include "hornero/chromatic/json.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QTemporaryDir>
#include <QTextStream>

#include <algorithm>
#include <cstdio>
#include <functional>
#include <vector>

using namespace hornero::chromatic;

namespace {

double medianMs(int n, const std::function<bool()>& fn) {
    std::vector<double> t;
    for (int i = 0; i < n; ++i) {
        QElapsedTimer timer;
        timer.start();
        if (!fn())
            return -1;
        t.push_back(static_cast<double>(timer.nsecsElapsed()) / 1e6);
    }
    std::sort(t.begin(), t.end());
    return t[t.size() / 2];
}

} // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    QStringList args = QCoreApplication::arguments();
    if (args.size() < 2) {
        std::fputs("usage: chromatic-bench <corpus-dir> [--iterations N]\n", stderr);
        return 2;
    }
    if (args.at(1) == QLatin1String("--sweep")) {
        // Seed sweep (RFC §4.7 reference grid × contrast levels): prints
        // failing gate labels with counts. Exit 1 when anything fails.
        QMap<QString, int> fails;
        QMap<QString, QString> examples;
        int total = 0, bad = 0;
        for (Variant v : concreteVariants())
            for (Mode m : { Mode::Dark, Mode::Light })
                for (Contrast c : { Contrast::Standard, Contrast::Boosted, Contrast::Maximum })
                    for (int h = 0; h < 360; h += 5)
                        for (double ch : { 0.0, 0.03, 0.08, 0.15, 0.25 })
                            for (bool second : { false, true }) {
                                Request r;
                                r.source = SourceSel::Seed;
                                r.seeds = { toHex(Oklch { 0.65, ch, static_cast<double>(h) }) };
                                if (second)
                                    r.seeds << toHex(Oklch { 0.65, 0.12, static_cast<double>((h + 90) % 360) });
                                r.variant = v;
                                r.mode = m;
                                r.contrast = c;
                                const auto a = parseHex(r.seeds.first());
                                (void)a;
                                Engine e;
                                const auto g = e.generate(r);
                                ++total;
                                if (!g) {
                                    ++bad;
                                    QString key = name(v) + QLatin1Char('/') + name(m) + QLatin1Char('/') + name(c) + QStringLiteral(": ")
                                        + g.error().message.section(QStringLiteral("): "), 1).section(QLatin1Char(' '), 0, 2);
                                    if (!fails.contains(key))
                                        examples[key] = r.seeds.join(u',') + QLatin1Char(' ') + g.error().message.section(QStringLiteral("): "), 1);
                                    fails[key]++;
                                }
                            }
        QTextStream o(stdout);
        o << total << " palettes, " << bad << " failing\n";
        for (auto it = fails.begin(); it != fails.end(); ++it)
            o << it.value() << "  " << it.key() << "  e.g. " << examples.value(it.key()) << '\n';
        return bad ? 1 : 0;
    }
    const QDir dir(args.at(1));
    int n = 5;
    const qsizetype it = args.indexOf(QStringLiteral("--iterations"));
    if (it > 0 && it + 1 < args.size())
        n = std::max(1, args.at(it + 1).toInt());

    QJsonObject out;
    const auto decodeAnalyse = [&](const char* file, const char* key) {
        const QString path = dir.filePath(QString::fromLatin1(file));
        if (!QFileInfo::exists(path))
            return;
        out.insert(QString::fromLatin1(key), medianMs(n, [&] {
            Engine e(EngineOptions {});
            return e.analyse(path).ok();
        }));
    };
    decodeAnalyse("bench-4k.jpg", "decodeAnalyse4kJpeg");
    decodeAnalyse("bench-4k.png", "decodeAnalyse4kPng");
    decodeAnalyse("bench-8k.png", "decodeAnalyse8kPng");
    decodeAnalyse("gif-anim.gif", "decodeAnalyseGif");

    // Synthesis + solver from a cached analysis (memory LRU hit).
    const QString wall = dir.filePath(QStringLiteral("bench-4k.jpg"));
    if (QFileInfo::exists(wall)) {
        Engine e(EngineOptions {});
        Request r;
        r.source = SourceSel::Image;
        r.path = wall;
        const auto a = e.analyse(wall);
        if (a) {
            const Inference inf = infer(&a.value(), r);
            out.insert(QStringLiteral("synthesise"), medianMs(std::max(n, 20), [&] {
                return synthesise(&a.value(), r, inf, GateTable::builtin()).ok();
            }));
        }
        // Disk-cache hit through a fresh engine, as the helper does.
        QTemporaryDir cache;
        EngineOptions o;
        o.cacheDir = cache.path();
        {
            Engine warm(o);
            (void)warm.generate(r);
        }
        out.insert(QStringLiteral("generateCacheHit"), medianMs(n, [&] {
            Engine cold(o);
            return cold.generate(r).ok();
        }));
    }
    {
        Request r;
        r.source = SourceSel::Seed;
        r.seeds = { QStringLiteral("#D98A3A") };
        out.insert(QStringLiteral("generateSeed"), medianMs(std::max(n, 20), [&] {
            Engine e(EngineOptions {});
            return e.generate(r).ok();
        }));
    }
    out.insert(QStringLiteral("iterations"), n);
    out.insert(QStringLiteral("engine"), engineJson());
    const QByteArray bytes = QJsonDocument(out).toJson(QJsonDocument::Compact);
    std::fwrite(bytes.constData(), 1, static_cast<std::size_t>(bytes.size()), stdout);
    std::fputc('\n', stdout);
    return 0;
}
