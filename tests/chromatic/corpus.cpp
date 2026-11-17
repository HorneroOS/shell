// SPDX-License-Identifier: MIT
//
// chromatic-corpus <outdir>: draws the synthetic adversarial corpus of
// RFC 0002 §15 so no image blobs live in git. Deterministic: fixed sizes,
// fixed colours, seeded xorshift noise.
#include <QColorSpace>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QImageWriter>
#include <QPainter>
#include <QTextStream>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace {

constexpr int kW = 640;
constexpr int kH = 360;

QString g_out;

bool save(const QImage& img, const char* name, const char* format = "PNG", int quality = 92) {
    QImageWriter w(QDir(g_out).filePath(QString::fromLatin1(name)), format);
    w.setQuality(quality);
    if (!w.write(img)) {
        QTextStream(stderr) << "chromatic-corpus: cannot write " << name << ": " << w.errorString() << '\n';
        return false;
    }
    return true;
}

QImage flat(QRgb c, int w = kW, int h = kH) {
    QImage img(w, h, QImage::Format_ARGB32);
    img.fill(c);
    return img;
}

QColor hsv(double h, double s, double v) {
    return QColor::fromHsvF(static_cast<float>(std::fmod(h, 1.0)), static_cast<float>(s), static_cast<float>(v));
}

QImage hueSweep(int w, int h) {
    QImage img(w, h, QImage::Format_ARGB32);
    for (int x = 0; x < w; ++x) {
        const QRgb c = hsv(static_cast<double>(x) / w, 0.85, 0.9).rgb();
        for (int y = 0; y < h; ++y)
            img.setPixel(x, y, c);
    }
    return img;
}

QImage gradient(QColor a, QColor b, bool vertical = false) {
    QImage img(kW, kH, QImage::Format_ARGB32);
    QPainter p(&img);
    QLinearGradient g(0, 0, vertical ? 0 : kW, vertical ? kH : 0);
    g.setColorAt(0, a);
    g.setColorAt(1, b);
    p.fillRect(img.rect(), g);
    return img;
}

// Minimal GIF89a writer: one global 256-colour palette, one frame per
// colour, LZW emitted as literal 9-bit codes with a clear code every 250.
class GifWriter {
public:
    explicit GifWriter(int w, int h, const std::vector<QRgb>& palette)
        : m_w(w)
        , m_h(h) {
        put("GIF89a");
        le16(w);
        le16(h);
        m_bytes.push_back(static_cast<char>(0xF7)); // global table, 8 bpp, 256 entries
        m_bytes.push_back(0);
        m_bytes.push_back(0);
        for (int i = 0; i < 256; ++i) {
            const QRgb c = i < static_cast<int>(palette.size()) ? palette[static_cast<std::size_t>(i)] : 0;
            m_bytes.push_back(static_cast<char>(qRed(c)));
            m_bytes.push_back(static_cast<char>(qGreen(c)));
            m_bytes.push_back(static_cast<char>(qBlue(c)));
        }
        // NETSCAPE2.0 loop extension.
        const unsigned char loop[] = { 0x21, 0xFF, 0x0B, 'N', 'E', 'T', 'S', 'C', 'A', 'P', 'E', '2', '.', '0', 0x03, 0x01,
            0x00, 0x00, 0x00 };
        m_bytes.insert(m_bytes.end(), reinterpret_cast<const char*>(loop), reinterpret_cast<const char*>(loop) + sizeof loop);
    }

    void frame(std::uint8_t index) {
        const unsigned char gce[] = { 0x21, 0xF9, 0x04, 0x04, 0x0A, 0x00, 0x00, 0x00 };
        m_bytes.insert(m_bytes.end(), reinterpret_cast<const char*>(gce), reinterpret_cast<const char*>(gce) + sizeof gce);
        m_bytes.push_back(0x2C);
        le16(0);
        le16(0);
        le16(m_w);
        le16(m_h);
        m_bytes.push_back(0);
        m_bytes.push_back(8); // LZW minimum code size
        std::vector<char> data;
        std::uint32_t acc = 0;
        int bits = 0;
        const auto code = [&](int c) {
            acc |= static_cast<std::uint32_t>(c) << bits;
            bits += 9;
            while (bits >= 8) {
                data.push_back(static_cast<char>(acc & 0xFF));
                acc >>= 8;
                bits -= 8;
            }
        };
        const int pixels = m_w * m_h;
        for (int i = 0; i < pixels; ++i) {
            if (i % 250 == 0)
                code(256);
            code(index);
        }
        code(257);
        if (bits > 0)
            data.push_back(static_cast<char>(acc & 0xFF));
        for (std::size_t off = 0; off < data.size(); off += 255) {
            const std::size_t n = std::min<std::size_t>(255, data.size() - off);
            m_bytes.push_back(static_cast<char>(n));
            m_bytes.insert(m_bytes.end(), data.begin() + static_cast<std::ptrdiff_t>(off),
                data.begin() + static_cast<std::ptrdiff_t>(off + n));
        }
        m_bytes.push_back(0);
    }

    bool write(const QString& path) {
        m_bytes.push_back(0x3B);
        QFile f(path);
        return f.open(QIODevice::WriteOnly)
            && f.write(m_bytes.data(), static_cast<qint64>(m_bytes.size())) == static_cast<qint64>(m_bytes.size());
    }

private:
    void put(const char* s) {
        while (*s)
            m_bytes.push_back(*s++);
    }
    void le16(int v) {
        m_bytes.push_back(static_cast<char>(v & 0xFF));
        m_bytes.push_back(static_cast<char>((v >> 8) & 0xFF));
    }
    int m_w, m_h;
    std::vector<char> m_bytes;
};

} // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    if (argc != 2) {
        std::fputs("usage: chromatic-corpus <outdir>\n", stderr);
        return 2;
    }
    g_out = QString::fromLocal8Bit(argv[1]);
    if (!QDir().mkpath(g_out))
        return 1;
    bool ok = true;

    ok &= save(flat(qRgb(0, 0, 0)), "black.png");
    ok &= save(flat(qRgb(255, 255, 255)), "white.png");
    ok &= save(flat(qRgb(128, 128, 128)), "grey50.png");

    {
        QImage img(kW, kH, QImage::Format_ARGB32);
        std::uint32_t s = 0x9E3779B9u;
        for (int y = 0; y < kH; ++y)
            for (int x = 0; x < kW; ++x) {
                s ^= s << 13;
                s ^= s >> 17;
                s ^= s << 5;
                img.setPixel(x, y, qRgb(static_cast<int>(s & 0xFF), static_cast<int>((s >> 8) & 0xFF),
                                       static_cast<int>((s >> 16) & 0xFF)));
            }
        ok &= save(img, "noise.png");
    }
    {
        QImage img = flat(qRgb(0x1E, 0x6F, 0xD9));
        QPainter p(&img);
        p.fillRect(kW / 2, 0, kW / 2, kH, QColor(0xD9, 0x86, 0x1E));
        p.end();
        ok &= save(img, "split-complement.png");
    }
    {
        QImage img = flat(qRgb(0x80, 0x80, 0x80));
        QPainter p(&img);
        p.fillRect(300, 160, 27, 26, QColor(0xE0, 0x26, 0x2B)); // 702 px = 0.30 %
        p.end();
        ok &= save(img, "dot-on-grey.png");
    }
    {
        QImage img = flat(qRgb(0x05, 0x05, 0x0A));
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(QPen(QColor(0xFF, 0x2B, 0xD6), 10));
        for (int i = 0; i < 6; ++i)
            p.drawLine(40 + i * 100, 40, 120 + i * 90, 320);
        p.setPen(QPen(QColor(0x22, 0xF0, 0xFF), 8));
        for (int i = 0; i < 5; ++i)
            p.drawLine(0, 60 + i * 60, kW, 30 + i * 70);
        p.end();
        ok &= save(img, "neon-black.png");
    }
    {
        QImage img = gradient(QColor(0xFD, 0xE2, 0xE4), QColor(0xE2, 0xF0, 0xFB));
        QPainter p(&img);
        QLinearGradient g(0, 0, 0, kH);
        g.setColorAt(0, QColor(0xFF, 0xF5, 0xD6, 0));
        g.setColorAt(1, QColor(0xFF, 0xF5, 0xD6, 200));
        p.fillRect(img.rect(), g);
        p.end();
        ok &= save(img, "pastel-highkey.png");
    }
    ok &= save(gradient(QColor(0x5E, 0x4B, 0x3C), QColor(0xB8, 0xA4, 0x88), true), "sepia.png");
    {
        QImage img = flat(qRgb(0xC6, 0x88, 0x63));
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(0xB8, 0x76, 0x55));
        p.drawEllipse(QPointF(220, 180), 160, 120);
        p.setBrush(QColor(0xD9, 0xA0, 0x7E));
        p.drawEllipse(QPointF(470, 150), 110, 90);
        p.setBrush(QColor(0x3B, 0x2A, 0x22));
        p.drawRect(0, 320, kW, 40);
        p.end();
        ok &= save(img, "skin.png");
    }
    {
        QImage img = flat(qRgb(0x6B, 0x6B, 0x2A));
        QPainter p(&img);
        // Olive 60 %, blue 30 %, brick 10 %: comparable shares, so the
        // muddy-olive penalty (RFC §4.4) decides the primary seed.
        p.fillRect(0, 0, kW * 3 / 10, kH, QColor(0x30, 0x60, 0xC0));
        p.fillRect(kW * 3 / 10, 0, kW / 10, kH, QColor(0xC0, 0x40, 0x30));
        p.end();
        ok &= save(img, "muddy-olive.png");
    }
    ok &= save(hueSweep(kW, kH), "hue-sweep.png");
    {
        QImage img = flat(qRgb(0xC0, 0x20, 0x1A));
        QPainter p(&img);
        p.fillRect(0, kH * 8 / 10, kW, kH - kH * 8 / 10, QColor(0x30, 0x30, 0x30));
        p.end();
        ok &= save(img, "red-dominant.png");
    }
    {
        QImage img = flat(qRgb(0x2F, 0xA0, 0x43));
        QPainter p(&img);
        p.fillRect(0, kH * 8 / 10, kW, kH - kH * 8 / 10, QColor(0x20, 0x28, 0x30));
        p.end();
        ok &= save(img, "green-dominant.png");
    }
    {
        QImage img(kW, kH, QImage::Format_ARGB32);
        img.fill(qRgba(0xFF, 0x00, 0x00, 0)); // transparent red: must be ignored
        QPainter p(&img);
        p.fillRect(kW / 2, 0, kW / 2, kH, QColor(0x3A, 0x7F, 0xD9));
        p.end();
        ok &= save(img, "alpha-half.png");
        ok &= save(flat(qRgb(0x3A, 0x7F, 0xD9), kW / 2, kH), "alpha-half-ref.png");
    }
    {
        QImage img(kW, kH, QImage::Format_RGBA64);
        for (int x = 0; x < kW; ++x) {
            const double t = static_cast<double>(x) / (kW - 1);
            const QRgba64 c = QRgba64::fromRgba64(static_cast<quint16>(std::lround(0x1E00 + t * (0xD900 - 0x1E00))),
                static_cast<quint16>(std::lround(0x6F00 + t * (0x8600 - 0x6F00))),
                static_cast<quint16>(std::lround(0xD900 + t * (0x1E00 - 0xD900))), 0xFFFF);
            for (int y = 0; y < kH; ++y)
                img.setPixelColor(x, y, QColor::fromRgba64(c));
        }
        ok &= save(img, "png16.png");
        ok &= save(img.convertToFormat(QImage::Format_ARGB32), "png16-ref8.png");
    }
    {
        const QImage base = gradient(QColor(0x2A, 0x6C, 0xC0), QColor(0xE0, 0x9A, 0x3A));
        ok &= save(base, "jpeg-ref.jpg", "JPEG");
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
        const QImage cmyk = base.convertToFormat(QImage::Format_CMYK8888);
        if (!cmyk.isNull())
            ok &= save(cmyk, "cmyk-jpeg.jpg", "JPEG");
#endif
        QImage p3 = flat(qRgb(0xFF, 0x20, 0x20));
        p3.setColorSpace(QColorSpace(QColorSpace::DisplayP3));
        ok &= save(p3, "p3-jpeg.jpg", "JPEG", 95);
        ok &= save(flat(qRgb(0xFF, 0x20, 0x20)), "p3-untagged.jpg", "JPEG", 95);
        QFile full(QDir(g_out).filePath(QStringLiteral("jpeg-ref.jpg")));
        if (full.open(QIODevice::ReadOnly)) {
            const QByteArray head = full.read(100);
            QFile trunc(QDir(g_out).filePath(QStringLiteral("truncated.jpg")));
            ok &= trunc.open(QIODevice::WriteOnly) && trunc.write(head) == head.size();
        }
    }
    {
        GifWriter gif(160, 90, { qRgb(0xD0, 0x20, 0x20), qRgb(0x20, 0xB0, 0x40), qRgb(0x20, 0x50, 0xD0), qRgb(0x80, 0x80, 0x80) });
        for (std::uint8_t i = 0; i < 4; ++i)
            gif.frame(i);
        ok &= gif.write(QDir(g_out).filePath(QStringLiteral("gif-anim.gif")));
    }
    {
        QImage tiny = flat(qRgb(0x3A, 0x7F, 0xD9), 1, 1);
        ok &= save(tiny, "tiny.png");
        ok &= save(hueSweep(16384, 1), "strip.png");
    }
    {
        QFile empty(QDir(g_out).filePath(QStringLiteral("empty.png")));
        ok &= empty.open(QIODevice::WriteOnly);
    }
    {
        // 4K / 8K bench sources (only drawn when asked: they are large).
        if (qEnvironmentVariableIsSet("CHROMATIC_CORPUS_BENCH")) {
            QImage big = hueSweep(3840, 2160);
            QPainter p(&big);
            p.fillRect(0, 0, 3840, 400, QColor(0x18, 0x1C, 0x24));
            p.end();
            ok &= save(big, "bench-4k.jpg", "JPEG");
            ok &= save(big, "bench-4k.png");
            ok &= save(big.scaled(7680, 4320), "bench-8k.png");
        }
    }
    return ok ? 0 : 1;
}
