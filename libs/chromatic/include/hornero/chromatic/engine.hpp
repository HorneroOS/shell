// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — engine facade: analyse + generate + cache.
#pragma once

#include "hornero/chromatic/analysis.hpp"
#include "hornero/chromatic/cache.hpp"
#include "hornero/chromatic/request.hpp"
#include "hornero/chromatic/source.hpp"
#include "hornero/chromatic/synth.hpp"

#include <QList>
#include <QMutex>
#include <QPair>
#include <QString>

namespace hornero::chromatic {

struct EngineOptions {
    QString cacheDir;                          // empty = no disk cache
    QString ffmpeg = QStringLiteral("ffmpeg"); // empty = video unsupported
    int threads = 1;                           // results never depend on it
    int memoryEntries = 8;                     // in-memory analysis LRU
    int maxFrames = 8;                         // other values bypass every cache
};

class Engine {
public:
    explicit Engine(EngineOptions = {});

    // Thread-safe.
    [[nodiscard]] Expected<Analysis> analyse(const QString& path);
    // `wallpaperPath` is used when the request has no path of its own
    // (source wallpaper, or house tinted by the wallpaper).
    [[nodiscard]] Expected<Generated> generate(const Request&, const QString& wallpaperPath = {});
    [[nodiscard]] const EngineOptions& options() const { return m_options; }

private:
    EngineOptions m_options;
    DiskCache m_cache;
    QMutex m_mutex;
    QList<QPair<QString, Analysis>> m_memory; // most recent first
};

} // namespace hornero::chromatic
