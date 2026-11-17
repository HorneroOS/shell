// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — content-keyed disk cache (RFC 0002 §15).
//
// Layout under the cache dir:
//   analysis/<digest>.json  {digest, analysis}  (self-verifying)
//   frames/<digest>.png     extracted video frames
// Palettes are not cached on disk: synthesis from a cached analysis is
// cheaper than reading and verifying a stored palette. The cache is never
// required: a disabled or broken cache gives the same result.
#pragma once

#include "hornero/chromatic/analysis.hpp"
#include "hornero/chromatic/source.hpp"

#include <QString>

#include <optional>

namespace hornero::chromatic {

class DiskCache {
public:
    explicit DiskCache(QString dir, qint64 capBytes = 64LL << 20);

    [[nodiscard]] bool enabled() const { return !m_dir.isEmpty(); }
    [[nodiscard]] QString dir() const { return m_dir; }
    // Verifies the embedded digest; deletes corrupt or stale entries.
    [[nodiscard]] std::optional<Analysis> analysis(const SourceKey&) const;
    // Atomic (temp file + rename); prunes afterwards.
    void storeAnalysis(const SourceKey&, const Analysis&) const;
    [[nodiscard]] QString frameDir() const;
    [[nodiscard]] QString framePath(const SourceKey&) const;
    // LRU by mtime down to the size cap.
    void prune() const;

    // $XDG_CACHE_HOME/hornero/chromatic (or ~/.cache/hornero/chromatic).
    [[nodiscard]] static QString defaultDir();

private:
    [[nodiscard]] QString analysisPath(const SourceKey&) const;
    QString m_dir;
    qint64 m_cap;
};

} // namespace hornero::chromatic
