// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — source identity and decoding (RFC 0002 §4.1, §15).
#pragma once

#include "hornero/chromatic/expected.hpp"

#include <QImage>
#include <QList>
#include <QString>

#include <cstdint>
#include <vector>

namespace hornero::chromatic {

enum class SourceKind { Still, Animated, Video };

struct SourceKey {
    QString canonicalPath;
    qint64 size = 0;
    QString contentDigest; // sha256 of the bytes (> 64 MiB: size + first/last 4 MiB)
    QString digest;        // "sha256:" + sha256(contentDigest ":" algorithm)
};

// Always hashes the file: path, size and mtime are never trusted alone.
[[nodiscard]] Expected<SourceKey> sourceKey(const QString& path);

struct DecodeOptions {
    int maxFrames = 8;
    QString ffmpeg = QStringLiteral("ffmpeg"); // empty: video unsupported
    QString frameCacheDir;                     // where extracted video frames are kept
    qint64 maxPixels = 100'000'000;
    int ffmpegTimeoutMs = 5000;
};

struct FrameSet {
    SourceKind kind = SourceKind::Still;
    QList<QImage> frames; // ≤ 8, ARGB32 (straight alpha), sRGB, longest side ≤ 512
    QString note;
};

[[nodiscard]] bool isVideoPath(const QString& path);
[[nodiscard]] Expected<FrameSet> decode(const QString& path, const DecodeOptions& = {});
// Same, reusing a key the caller already computed (avoids hashing twice).
[[nodiscard]] Expected<FrameSet> decode(const QString& path, const DecodeOptions&, const SourceKey& key);
// Converts any QImage (any format / colour space) into a FrameSet frame.
[[nodiscard]] QImage normaliseFrame(QImage);
// Resolves an ffmpeg executable name/path; empty when unavailable.
[[nodiscard]] QString findFfmpeg(const QString& hint = QStringLiteral("ffmpeg"));

// Linear-light box downscale so the longest side is ≤ maxSide. Pixels with
// alpha < 0.5 are ignored; an output pixel is opaque when at least half of
// its box was opaque. Output is straight-alpha linear RGB.
struct LinearImage {
    int width = 0;
    int height = 0;
    std::vector<double> rgb; // 3 per pixel, linear light
    std::vector<std::uint8_t> valid;
};
[[nodiscard]] LinearImage downscaleLinear(const QImage& argb32, int maxSide);
[[nodiscard]] QImage toImage(const LinearImage&);

} // namespace hornero::chromatic
