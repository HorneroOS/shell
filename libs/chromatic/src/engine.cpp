// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/engine.hpp"

#include <QFileInfo>
#include <QMutexLocker>

#include <utility>

namespace hornero::chromatic {

Engine::Engine(EngineOptions options)
    : m_options(std::move(options))
    , m_cache(m_options.cacheDir) {}

Expected<Analysis> Engine::analyse(const QString& path) {
    const auto key = sourceKey(path);
    if (!key)
        return key.error();
    const QString digest = key->digest;
    const bool cacheable = m_options.maxFrames == 8;
    if (cacheable) {
        QMutexLocker lock(&m_mutex);
        for (qsizetype i = 0; i < m_memory.size(); ++i) {
            if (m_memory[i].first == digest) {
                auto hit = m_memory.takeAt(i);
                m_memory.prepend(hit);
                return hit.second;
            }
        }
    }
    std::optional<Analysis> found = cacheable ? m_cache.analysis(key.value()) : std::nullopt;
    if (!found) {
        DecodeOptions opts;
        opts.maxFrames = m_options.maxFrames;
        opts.ffmpeg = m_options.ffmpeg;
        opts.frameCacheDir = m_cache.frameDir();
        auto frames = decode(path, opts);
        if (!frames)
            return frames.error();
        if (frames->frames.isEmpty())
            return Error { Error::SourceUnreadable, QStringLiteral("no decodable frame") };
        Analysis a = chromatic::analyse(frames.value());
        a.sourceDigest = digest;
        if (cacheable)
            m_cache.storeAnalysis(key.value(), a);
        found = std::move(a);
    }
    if (!cacheable)
        return *found;
    QMutexLocker lock(&m_mutex);
    m_memory.prepend({ digest, *found });
    while (m_memory.size() > std::max(1, m_options.memoryEntries))
        m_memory.removeLast();
    return *found;
}

Expected<Generated> Engine::generate(const Request& request, const QString& wallpaperPath) {
    if (auto err = checkRequest(request))
        return *err;
    Request r = request;
    if (r.path.isEmpty() && r.source != SourceSel::Seed)
        r.path = wallpaperPath;
    if (!r.path.isEmpty() && r.source != SourceSel::Seed)
        r.path = QFileInfo(r.path).absoluteFilePath();

    std::optional<Analysis> analysis;
    QStringList notes;
    if (r.source == SourceSel::Image || r.source == SourceSel::Wallpaper) {
        if (r.path.isEmpty())
            return Error { Error::Usage, QStringLiteral("no source image or wallpaper given") };
        auto a = analyse(r.path);
        if (!a)
            return a.error();
        analysis = std::move(a.value());
    } else if (r.source == SourceSel::House && !r.path.isEmpty()) {
        // House only borrows the surface tint; an unreadable wallpaper is not fatal.
        auto a = analyse(r.path);
        if (a)
            analysis = std::move(a.value());
        else
            notes << QStringLiteral("wallpaper unreadable (%1): untinted house").arg(a.error().message);
    }
    const Analysis* ap = analysis ? &*analysis : nullptr;
    Inference inf = infer(ap, r);
    inf.reasons << notes;
    return synthesise(ap, r, inf, GateTable::builtin());
}

} // namespace hornero::chromatic
