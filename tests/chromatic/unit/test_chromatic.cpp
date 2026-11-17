// SPDX-License-Identifier: MIT
// QtTest unit suite for libs/chromatic (ctest: chromatic-unit).
#include "hornero/chromatic/cache.hpp"
#include "hornero/chromatic/engine.hpp"
#include "hornero/chromatic/json.hpp"

#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

#include <cmath>

using namespace hornero::chromatic;
using namespace Qt::StringLiterals;

class ChromaticUnit : public QObject {
    Q_OBJECT

private:
    static QImage twoColour() {
        QImage img(200, 100, QImage::Format_ARGB32);
        img.fill(qRgb(0x1E, 0x6F, 0xD9));
        QPainter p(&img);
        p.fillRect(100, 0, 100, 100, QColor(0xD9, 0x86, 0x1E));
        return img;
    }

private slots:
    void oklabReferenceValues() {
        // Ottosson's published values for sRGB white and pure red.
        const Oklab white = toOklab(Srgb { 1, 1, 1 });
        QVERIFY(std::abs(white.L - 1.0) < 1e-4);
        QVERIFY(std::abs(white.a) < 1e-4 && std::abs(white.b) < 1e-4);
        const Oklch red = toOklch(toOklab(Srgb { 1, 0, 0 }));
        QVERIFY(std::abs(red.L - 0.62796) < 1e-3);
        QVERIFY(std::abs(red.C - 0.25768) < 1e-3);
        QVERIFY(std::abs(red.h - 29.234) < 0.05);
    }

    void hexRoundTrip() {
        for (const char* hex : { "#000000", "#FFFFFF", "#D98A3A", "#1E6FD9", "#808080", "#0C0F13" }) {
            const auto c = parseHex(QString::fromLatin1(hex));
            QVERIFY(c);
            QCOMPARE(toHex(*c), QString::fromLatin1(hex));
            QCOMPARE(toHex(toOklch(*c)), QString::fromLatin1(hex));
        }
        QVERIFY(!parseHex(u"#12345"));
        QVERIFY(!parseHex(u"#GG0000"));
        QCOMPARE(toHex(*parseHex(u"abcdef")), QStringLiteral("#ABCDEF"));
    }

    void wcagMatchesConfig() {
        const Rgb8 black {}, white { 255, 255, 255 };
        QVERIFY(std::abs(contrastRatio(black, white) - 21.0) < 1e-9);
        // signal_theme.py: contrast("#ECE6DA", "#15181C")
        const double r = contrastRatio(*parseHex(u"#ECE6DA"), *parseHex(u"#15181C"));
        QVERIFY(r > 14.0 && r < 16.0);
        QVERIFY(std::abs(deltaE76(white, white)) < 1e-12);
        QVERIFY(deltaE76(black, white) > 99.0);
    }

    void gamutMapKeepsLightnessAndHue() {
        const Oklch wild { 0.7, 0.4, 145 };
        QVERIFY(!inGamut(wild));
        const Oklch m = gamutMap(wild);
        QVERIFY(inGamut(m));
        QVERIFY(std::abs(m.L - 0.7) < 1e-12 && std::abs(m.h - 145) < 1e-12);
        QVERIFY(m.C < 0.4 && m.C > 0.1);
    }

    void gateTableParses() {
        const GateTable& t = GateTable::builtin();
        QCOMPARE(t.version, 1);
        QCOMPARE(t.level(Contrast::Standard).textMin, 4.5);
        QCOMPARE(t.level(Contrast::Boosted).textMinFor(QStringLiteral("ink")), 7.0);
        QCOMPARE(t.level(Contrast::Boosted).textMinFor(QStringLiteral("cue")), 4.5);
        QCOMPARE(t.level(Contrast::Maximum).textMin, 7.0);
        QCOMPARE(t.level(Contrast::Maximum).onPairs.size(), 10);
        QCOMPARE(t.margin, 0.15);
    }

    void seedSchemePassesEveryLevel() {
        for (Variant v : concreteVariants()) {
            for (Mode m : { Mode::Dark, Mode::Light }) {
                for (Contrast c : { Contrast::Standard, Contrast::Boosted, Contrast::Maximum }) {
                    Request r;
                    r.source = SourceSel::Seed;
                    r.seeds = { QStringLiteral("#D98A3A") };
                    r.variant = v;
                    r.mode = m;
                    r.contrast = c;
                    Engine e;
                    const auto g = e.generate(r);
                    QVERIFY2(g.ok(), qPrintable(g.ok() ? QString() : g.error().message));
                    QCOMPARE(g->scheme.palette.size(), signalRoles().size() + (g->scheme.palette.contains(u"glow"_s) ? 1 : 0));
                    QVERIFY(allPass(g->gates));
                }
            }
        }
    }

    void deterministic() {
        Request r;
        r.source = SourceSel::Seed;
        r.seeds = { QStringLiteral("#3A7FD9"), QStringLiteral("#D9861E") };
        Engine a, b;
        QCOMPARE(compact(toJson(a.generate(r).value())), compact(toJson(b.generate(r).value())));
    }

    void ensureContrastMovesLightnessOnly() {
        const Rgb8 bg = *parseHex(u"#1B1E22");
        const Rgb8 fg = *parseHex(u"#3A4A8A");
        const Rgb8 out = ensureContrast(fg, bg, 4.5);
        QVERIFY(contrastRatio(out, bg) >= 4.5);
        QVERIFY(std::abs(hueDiff(toOklch(out).h, toOklch(fg).h)) < 3.0);
    }

    void quantiserFindsTwoColours() {
        FrameSet set;
        set.frames = { twoColour() };
        const Analysis a = analyse(set);
        QVERIFY(a.clusters.size() >= 2);
        QVERIFY(a.clusters.size() <= 16);
        QVERIFY(a.seeds.size() >= 2);
        QVERIFY(std::abs(hueDiff(a.seeds[0].lch.h, a.seeds[1].lch.h)) > 50.0);
        QCOMPARE(analyse(set).digest(), a.digest());
    }

    void transparentPixelsIgnored() {
        QImage img(100, 100, QImage::Format_ARGB32);
        img.fill(qRgba(255, 0, 0, 0));
        QPainter p(&img);
        p.fillRect(50, 0, 50, 100, QColor(0x3A, 0x7F, 0xD9));
        p.end();
        FrameSet set;
        set.frames = { img };
        const Analysis a = analyse(set);
        QVERIFY(!a.seeds.isEmpty());
        QVERIFY(std::abs(hueDiff(a.seeds[0].lch.h, toOklch(*parseHex(u"#3A7FD9")).h)) < 3.0);
    }

    void cacheRoundTripAndCorruption() {
        QTemporaryDir dir;
        const QString file = dir.filePath(QStringLiteral("two.png"));
        QVERIFY(twoColour().save(file));
        const auto key = sourceKey(file);
        QVERIFY(key);
        DiskCache cache(dir.filePath(QStringLiteral("cache")));
        FrameSet set;
        set.frames = { twoColour() };
        Analysis a = analyse(set);
        a.sourceDigest = key->digest;
        cache.storeAnalysis(key.value(), a);
        const auto hit = cache.analysis(key.value());
        QVERIFY(hit);
        QCOMPARE(hit->digest(), a.digest());
        // Corrupt the entry: it is deleted and reported as a miss.
        const QString entry = dir.filePath(QStringLiteral("cache/analysis/")) + key->digest.mid(7) + QStringLiteral(".json");
        QFile f(entry);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
        f.write("{\"digest\":\"sha256:00\",\"analysis\":{}}");
        f.close();
        QVERIFY(!cache.analysis(key.value()));
        QVERIFY(!QFile::exists(entry));
    }

    void unreadableSources() {
        QTemporaryDir dir;
        const QString empty = dir.filePath(QStringLiteral("empty.png"));
        QFile f(empty);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.close();
        Engine e;
        const auto r1 = e.analyse(empty);
        QVERIFY(!r1.ok());
        QCOMPARE(r1.error().code, Error::SourceUnreadable);
        const auto r2 = e.analyse(dir.filePath(QStringLiteral("missing.png")));
        QVERIFY(!r2.ok());
        QCOMPARE(r2.error().code, Error::SourceUnreadable);
        // Random bytes with an image extension never crash.
        QFile junk(dir.filePath(QStringLiteral("junk.jpg")));
        QVERIFY(junk.open(QIODevice::WriteOnly));
        QByteArray bytes(4096, '\0');
        quint32 s = 12345;
        for (auto& b : bytes) {
            s = s * 1664525u + 1013904223u;
            b = static_cast<char>(s >> 24);
        }
        bytes.prepend("\xFF\xD8\xFF\xE0");
        junk.write(bytes);
        junk.close();
        QVERIFY(!e.analyse(junk.fileName()).ok());
    }

    // An animation with many frames is sampled from the frames the decode
    // budget can reach, deterministically, instead of decoding all of them.
    void animatedDecodeIsBudgeted() {
        QTemporaryDir dir;
        // 8x8 GIF, 40 identical frames (one hand-encoded 27-byte frame, repeated).
        QByteArray gif = QByteArray::fromHex("47494638396108000800800000000000ffffff21ff0b4e45545343415045322e300301000000");
        const QByteArray frame = QByteArray::fromHex("21f90400010000002c0000000008000800000206848fa9cbed5d00");
        for (int i = 0; i < 40; ++i)
            gif += frame;
        gif += ';';
        const QString path = dir.filePath(QStringLiteral("many.gif"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(gif);
        f.close();

        DecodeOptions open;
        const auto all = decode(path, open);
        QVERIFY(all.ok());
        QCOMPARE(all->frames.size(), 8);
        QVERIFY(all->note.contains(u"8 of 40 frames"_s));

        DecodeOptions capped;
        capped.maxDecodedPixels = 8 * 8 * 10; // ten frames' worth
        const auto cut = decode(path, capped);
        QVERIFY(cut.ok());
        QCOMPARE(cut->frames.size(), 8);
        QVERIFY2(cut->note.contains(u"first 10 of 40"_s), qPrintable(cut->note));
        const auto again = decode(path, capped);
        QVERIFY(again.ok() && again->note == cut->note);

        capped.maxDecodedPixels = 1; // still yields one frame
        const auto one = decode(path, capped);
        QVERIFY(one.ok());
        QCOMPARE(one->frames.size(), 1);
    }

    // Without a frame cache ffmpeg writes into a private directory, never a
    // predictable name in the shared temp dir, and may only read local files.
    void ffmpegScratchIsPrivate() {
        QTemporaryDir dir;
        const QString video = dir.filePath(QStringLiteral("clip.mp4"));
        QFile v(video);
        QVERIFY(v.open(QIODevice::WriteOnly));
        v.write("not a real video");
        v.close();
        const QString still = dir.filePath(QStringLiteral("frame.png"));
        QVERIFY(twoColour().save(still));
        const QString argsFile = dir.filePath(QStringLiteral("args.txt"));
        const QString fake = dir.filePath(QStringLiteral("fake-ffmpeg"));
        QFile script(fake);
        QVERIFY(script.open(QIODevice::WriteOnly));
        script.write("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$FAKE_FFMPEG_ARGS\"\nfor a; do last=$a; done\ncp \"$FAKE_FFMPEG_FRAME\" \"$last\"\n");
        script.close();
        QVERIFY(script.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
        qputenv("FAKE_FFMPEG_ARGS", argsFile.toLocal8Bit());
        qputenv("FAKE_FFMPEG_FRAME", still.toLocal8Bit());

        DecodeOptions opts;
        opts.ffmpeg = fake;
        const auto r = decode(video, opts);
        QVERIFY2(r.ok(), r.ok() ? "" : qPrintable(r.error().message));
        QCOMPARE(r->kind, SourceKind::Video);

        QFile rec(argsFile);
        QVERIFY(rec.open(QIODevice::ReadOnly));
        const QStringList argv = QString::fromLocal8Bit(rec.readAll()).split(u'\n', Qt::SkipEmptyParts);
        const qsizetype wl = argv.indexOf(u"-protocol_whitelist"_s);
        QVERIFY(wl >= 0 && wl + 1 < argv.size());
        QCOMPARE(argv.at(wl + 1), u"file"_s);
        QVERIFY(wl < argv.indexOf(u"-i"_s));
        const QFileInfo target(argv.last());
        QVERIFY2(!target.fileName().startsWith(u"hornero-chromatic-"_s), "frame must not use a predictable temp name");
        const QFileInfo parent(target.absolutePath());
        QVERIFY(parent.fileName().startsWith(u"hornero-chromatic-"_s));
        QVERIFY(parent.absolutePath() == QFileInfo(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).absoluteFilePath());
        // The scratch directory is gone again once the frame was read.
        QVERIFY(!parent.exists());
    }

    void requestParsing() {
        const auto r = requestFromJson(QJsonObject { { u"source"_s, u"image:/tmp/x.png"_s }, { u"variant"_s, u"high-contrast"_s },
            { u"chroma"_s, 1.2 }, { u"follow"_s, u"auto"_s } });
        QVERIFY(r);
        QCOMPARE(r->source, SourceSel::Image);
        QCOMPARE(r->path, u"/tmp/x.png"_s);
        QCOMPARE(r->variant, Variant::HighContrast);
        QVERIFY(!requestFromJson(QJsonObject { { u"chroma"_s, 3.0 } }).ok());
        QVERIFY(!requestFromJson(QJsonObject { { u"variant"_s, u"tonal"_s } }).ok());
        QVERIFY(!requestFromJson(QJsonObject { { u"source"_s, u"seed"_s } }).ok());
    }
};

QTEST_GUILESS_MAIN(ChromaticUnit)
#include "test_chromatic.moc"
