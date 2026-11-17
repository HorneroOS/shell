// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/source.hpp"

#include "hornero/chromatic/colour.hpp"
#include "hornero/chromatic/request.hpp"

#include <QColorSpace>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QProcess>
#include <QStandardPaths>
#include <QTemporaryDir>

#include <algorithm>
#include <array>
#include <cmath>
#include <optional>

namespace hornero::chromatic {

namespace {

constexpr qint64 kWholeFileLimit = 64LL << 20;
constexpr qint64 kEdgeBytes = 4LL << 20;
constexpr int kDecodeSide = 512;
// Animated sources are decoded sequentially up to the last sampled frame, so
// the work is bounded in decoded pixels and frames, never by the file alone.
constexpr int kMaxScannedFrames = 4096;

const std::array<double, 256>& linearLut() {
    static const std::array<double, 256> lut = [] {
        std::array<double, 256> t {};
        for (std::size_t i = 0; i < 256; ++i)
            t[i] = srgbToLinear(static_cast<double>(i) / 255.0);
        return t;
    }();
    return lut;
}

Error unreadable(const QString& message) {
    return Error { Error::SourceUnreadable, message };
}

QString digestOf(const QString& contentDigest) {
    const QByteArray key = contentDigest.toLatin1() + ':' + QByteArray::number(kAlgorithm);
    return QStringLiteral("sha256:")
        + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha256).toHex());
}

QImage scaledToDecodeSide(const QImage& img) {
    if (std::max(img.width(), img.height()) <= kDecodeSide)
        return img;
    return toImage(downscaleLinear(img, kDecodeSide));
}

Expected<QImage> extractVideoFrame(const QString& path, const SourceKey& key, const DecodeOptions& opts) {
    const QString ffmpeg = findFfmpeg(opts.ffmpeg);
    if (ffmpeg.isEmpty())
        return unreadable(QStringLiteral("video source needs ffmpeg, which is not installed"));
    QString cached;
    if (!opts.frameCacheDir.isEmpty()) {
        QDir().mkpath(opts.frameCacheDir);
        cached = QDir(opts.frameCacheDir).filePath(key.digest.mid(7) + QStringLiteral(".png"));
        QImage hit(cached);
        if (!hit.isNull())
            return hit;
    }
    // Without a frame cache the frame goes into a private (0700, unpredictable)
    // directory: a fixed name in the shared temp dir lets another local user
    // plant a symlink that `ffmpeg -y` would write through.
    std::optional<QTemporaryDir> scratch;
    QString target;
    if (cached.isEmpty()) {
        scratch.emplace(QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation))
                            .filePath(QStringLiteral("hornero-chromatic-XXXXXX")));
        if (!scratch->isValid())
            return unreadable(QStringLiteral("could not create a private scratch directory for ffmpeg"));
        target = scratch->filePath(QStringLiteral("frame.png"));
    } else {
        target = cached + QStringLiteral(".part.png");
    }
    // One frame at 1 s, or at 0 when the video is shorter.
    for (const char* at : { "1", "0" }) {
        QFile::remove(target);
        QProcess proc;
        proc.setProcessChannelMode(QProcess::SeparateChannels);
        proc.start(ffmpeg,
            { QStringLiteral("-nostdin"), QStringLiteral("-v"), QStringLiteral("error"),
                // The source is untrusted: never let a container pull in network or other protocols.
                QStringLiteral("-protocol_whitelist"), QStringLiteral("file"), QStringLiteral("-ss"),
                QString::fromLatin1(at), QStringLiteral("-i"), path, QStringLiteral("-frames:v"), QStringLiteral("1"),
                QStringLiteral("-vf"),
                QStringLiteral("scale=w=%1:h=%1:force_original_aspect_ratio=decrease").arg(kDecodeSide),
                QStringLiteral("-f"), QStringLiteral("image2"), QStringLiteral("-y"), target });
        if (!proc.waitForStarted(opts.ffmpegTimeoutMs))
            return unreadable(QStringLiteral("could not start ffmpeg"));
        if (!proc.waitForFinished(opts.ffmpegTimeoutMs)) {
            proc.kill();
            proc.waitForFinished(1000);
            QFile::remove(target);
            return unreadable(QStringLiteral("ffmpeg timed out extracting a frame"));
        }
        QImage frame(target);
        if (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0 && !frame.isNull()) {
            if (!cached.isEmpty()) {
                QFile::remove(cached);
                QFile::rename(target, cached);
            } else {
                QFile::remove(target);
            }
            return frame;
        }
    }
    QFile::remove(target);
    return unreadable(QStringLiteral("ffmpeg could not decode a frame from the video"));
}

} // namespace

Expected<SourceKey> sourceKey(const QString& path) {
    QFileInfo info(path);
    if (!info.exists() || !info.isFile())
        return unreadable(QStringLiteral("no such file: %1").arg(path));
    QFile file(info.absoluteFilePath());
    if (!file.open(QIODevice::ReadOnly))
        return unreadable(QStringLiteral("cannot open %1").arg(path));
    SourceKey key;
    key.canonicalPath = info.canonicalFilePath();
    key.size = file.size();
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (key.size > kWholeFileLimit) {
        hash.addData(QByteArray::number(key.size));
        hash.addData(file.read(kEdgeBytes));
        file.seek(key.size - kEdgeBytes);
        hash.addData(file.read(kEdgeBytes));
    } else if (!hash.addData(&file)) {
        return unreadable(QStringLiteral("cannot read %1").arg(path));
    }
    key.contentDigest = QString::fromLatin1(hash.result().toHex());
    key.digest = digestOf(key.contentDigest);
    return key;
}

bool isVideoPath(const QString& path) {
    static const QStringList kVideo { QStringLiteral("mp4"), QStringLiteral("mkv"), QStringLiteral("webm"),
        QStringLiteral("mov"), QStringLiteral("avi") };
    return kVideo.contains(QFileInfo(path).suffix().toLower());
}

QString findFfmpeg(const QString& hint) {
    if (hint.isEmpty())
        return {};
    if (hint.contains(QLatin1Char('/')))
        return QFileInfo(hint).isExecutable() ? hint : QString();
    return QStandardPaths::findExecutable(hint);
}

QImage normaliseFrame(QImage img) {
    if (img.isNull())
        return img;
    const QColorSpace cs = img.colorSpace();
    if (cs.isValid() && cs != QColorSpace(QColorSpace::SRgb)) {
        // CMYK and other models convert through the embedded profile too.
        img = img.convertedToColorSpace(QColorSpace(QColorSpace::SRgb), QImage::Format_ARGB32);
        if (img.isNull())
            return img;
    }
    if (img.format() != QImage::Format_ARGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);
    img.setColorSpace(QColorSpace());
    return scaledToDecodeSide(img);
}

Expected<FrameSet> decode(const QString& path, const DecodeOptions& opts) {
    const auto key = sourceKey(path);
    if (!key)
        return key.error();
    return decode(path, opts, key.value());
}

Expected<FrameSet> decode(const QString& path, const DecodeOptions& opts, const SourceKey& key) {
    FrameSet set;
    if (isVideoPath(path)) {
        auto frame = extractVideoFrame(path, key, opts);
        if (!frame)
            return frame.error();
        set.kind = SourceKind::Video;
        set.frames.append(normaliseFrame(frame.value()));
        set.note = QStringLiteral("one video frame");
        if (set.frames.first().isNull())
            return unreadable(QStringLiteral("video frame could not be converted"));
        return set;
    }

    QImageReader reader(path);
    reader.setAutoTransform(true);
    reader.setDecideFormatFromContent(true);
    if (!reader.canRead())
        return unreadable(QStringLiteral("unsupported or unreadable image: %1").arg(reader.errorString()));
    const QSize size = reader.size();
    if (size.isValid() && static_cast<qint64>(size.width()) * size.height() > opts.maxPixels)
        return unreadable(QStringLiteral("image exceeds %1 pixels").arg(opts.maxPixels));
    const int count = reader.imageCount();
    const bool animated = reader.supportsAnimation() && count > 1;
    const auto readOne = [&reader, &size]() -> QImage {
        if (size.isValid() && reader.supportsOption(QImageIOHandler::ScaledSize)
            && std::max(size.width(), size.height()) > kDecodeSide) {
            const double f = static_cast<double>(kDecodeSide) / std::max(size.width(), size.height());
            reader.setScaledSize(QSize(std::max(1, static_cast<int>(std::lround(size.width() * f))),
                std::max(1, static_cast<int>(std::lround(size.height() * f)))));
        }
        return reader.read();
    };
    if (!animated) {
        QImage img = readOne();
        if (img.isNull())
            return unreadable(QStringLiteral("could not decode image: %1").arg(reader.errorString()));
        if (static_cast<qint64>(img.width()) * img.height() > opts.maxPixels)
            return unreadable(QStringLiteral("image exceeds %1 pixels").arg(opts.maxPixels));
        set.kind = reader.supportsAnimation() && count <= 0 ? SourceKind::Animated : SourceKind::Still;
        if (set.kind == SourceKind::Animated)
            set.note = QStringLiteral("frame count unknown: first frame only");
        set.frames.append(normaliseFrame(img));
        if (set.frames.first().isNull())
            return unreadable(QStringLiteral("image could not be converted to sRGB"));
        return set;
    }
    set.kind = SourceKind::Animated;
    // Frames are decoded in order up to the last sampled one, so only the
    // first `reachable` frames are candidates (deterministic: the content
    // key still maps to one analysis).
    const qint64 perFrame = size.isValid() ? std::max<qint64>(1, static_cast<qint64>(size.width()) * size.height()) : 1;
    const int reachable = static_cast<int>(
        std::max<qint64>(1, std::min<qint64>({ count, kMaxScannedFrames, opts.maxDecodedPixels / perFrame })));
    const int n = std::min(std::max(1, opts.maxFrames), reachable);
    QList<int> wanted;
    for (int i = 0; i < n; ++i)
        wanted << static_cast<int>((static_cast<qint64>(i) * reachable) / n);
    int index = 0;
    qint64 decoded = 0;
    for (int target : wanted) {
        QImage img;
        while (index <= target) {
            img = reader.read();
            if (img.isNull())
                return unreadable(QStringLiteral("animation frame %1 failed to decode").arg(index));
            decoded += static_cast<qint64>(img.width()) * img.height();
            ++index;
        }
        QImage frame = normaliseFrame(img);
        if (frame.isNull())
            return unreadable(QStringLiteral("animation frame %1 could not be converted").arg(target));
        set.frames.append(frame);
        if (decoded > opts.maxDecodedPixels)
            break; // frames were larger than announced: keep what we have
    }
    set.note = reachable < count ? QStringLiteral("%1 of the first %2 of %3 frames").arg(set.frames.size()).arg(reachable).arg(count)
                                 : QStringLiteral("%1 of %2 frames").arg(set.frames.size()).arg(count);
    return set;
}

LinearImage downscaleLinear(const QImage& src, int maxSide) {
    LinearImage out;
    if (src.isNull())
        return out;
    const QImage img = src.format() == QImage::Format_ARGB32 ? src : src.convertToFormat(QImage::Format_ARGB32);
    const int sw = img.width();
    const int sh = img.height();
    const double f = std::min(1.0, static_cast<double>(maxSide) / std::max(sw, sh));
    const int dw = std::max(1, static_cast<int>(std::lround(sw * f)));
    const int dh = std::max(1, static_cast<int>(std::lround(sh * f)));
    out.width = dw;
    out.height = dh;
    const auto cells = static_cast<std::size_t>(dw) * static_cast<std::size_t>(dh);
    std::vector<double> acc(cells * 3, 0.0);
    std::vector<std::uint32_t> opaque(cells, 0);
    std::vector<std::uint32_t> total(cells, 0);
    std::vector<int> colOf(static_cast<std::size_t>(sw));
    for (int x = 0; x < sw; ++x)
        colOf[static_cast<std::size_t>(x)] = static_cast<int>((static_cast<qint64>(x) * dw) / sw);
    const auto& lut = linearLut();
    for (int y = 0; y < sh; ++y) {
        const auto row = static_cast<std::size_t>((static_cast<qint64>(y) * dh) / sh);
        const auto* line = reinterpret_cast<const QRgb*>(img.constScanLine(y));
        for (int x = 0; x < sw; ++x) {
            const std::size_t cell = row * static_cast<std::size_t>(dw) + static_cast<std::size_t>(colOf[static_cast<std::size_t>(x)]);
            const QRgb p = line[x];
            ++total[cell];
            if (qAlpha(p) < 128)
                continue;
            ++opaque[cell];
            acc[cell * 3] += lut[static_cast<std::size_t>(qRed(p))];
            acc[cell * 3 + 1] += lut[static_cast<std::size_t>(qGreen(p))];
            acc[cell * 3 + 2] += lut[static_cast<std::size_t>(qBlue(p))];
        }
    }
    out.rgb.assign(cells * 3, 0.0);
    out.valid.assign(cells, 0);
    for (std::size_t c = 0; c < cells; ++c) {
        if (opaque[c] == 0 || opaque[c] * 2 < total[c])
            continue;
        out.valid[c] = 1;
        for (std::size_t k = 0; k < 3; ++k)
            out.rgb[c * 3 + k] = acc[c * 3 + k] / opaque[c];
    }
    return out;
}

QImage toImage(const LinearImage& lin) {
    QImage img(lin.width, lin.height, QImage::Format_ARGB32);
    if (img.isNull())
        return img;
    for (int y = 0; y < lin.height; ++y) {
        auto* line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < lin.width; ++x) {
            const std::size_t c = static_cast<std::size_t>(y) * static_cast<std::size_t>(lin.width) + static_cast<std::size_t>(x);
            if (!lin.valid[c]) {
                line[x] = qRgba(0, 0, 0, 0);
                continue;
            }
            const Rgb8 v = toRgb8(toSrgb(LinearRgb { lin.rgb[c * 3], lin.rgb[c * 3 + 1], lin.rgb[c * 3 + 2] }));
            line[x] = qRgba(v.r, v.g, v.b, 255);
        }
    }
    return img;
}

} // namespace hornero::chromatic
