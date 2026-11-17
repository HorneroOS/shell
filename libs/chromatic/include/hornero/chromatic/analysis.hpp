// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — image statistics, clustering and seeds (RFC 0002 §4.2–§4.4).
#pragma once

#include "hornero/chromatic/colour.hpp"
#include "hornero/chromatic/source.hpp"

#include <QByteArray>
#include <QList>
#include <QString>

#include <optional>

namespace hornero::chromatic {

struct Cluster {
    Oklab lab;
    double share = 0;
};

struct Seed {
    QString hex;
    Oklch lch;
    double share = 0;
    double score = 0;
};

struct BandStats {
    double meanL = 0;
    double stdL = 0;
};

struct Analysis {
    int algorithm = 0;
    QString sourceDigest; // "sha256:…" (SourceKey.digest) or empty for in-memory frames
    SourceKind kind = SourceKind::Still;
    double meanL = 0, Lmin = 0, Lmax = 0, L5 = 0, L50 = 0, L95 = 0, stdL = 0; // band-weighted
    double meanC = 0, C90 = 0, C95 = 0, hueEntropy = 0, detail = 0;
    // Share of pixel mass lighter than 0.6 whose chroma exceeds 0.18 (neon test).
    double brightC95 = 0;
    BandStats top, bottom;
    QList<Cluster> clusters; // ≤ 16, share-desc, ties by L, a, b
    QList<Seed> seeds;       // ≤ 5 ranked
    std::optional<double> neutralHue;
    // Chroma-weighted mean hue of pixels with C > 0.005 (achromatic fallback).
    std::optional<double> weakHue;
    bool achromatic = false;
    QByteArray lumaGrid; // 96×54 × (mean, std) as uint8 pairs, row-major
    QString note;        // decode note (e.g. "video frame at 1 s")

    [[nodiscard]] QString digest() const; // sha256 of canonical JSON
};

inline constexpr int kGridCols = 96;
inline constexpr int kGridRows = 54;

// Pure and deterministic for a given frame set.
[[nodiscard]] Analysis analyse(const FrameSet&);

} // namespace hornero::chromatic
