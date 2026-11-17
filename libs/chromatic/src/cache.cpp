// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/cache.hpp"

#include "hornero/chromatic/json.hpp"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QTimeZone>

#include <algorithm>
#include <utility>
#include <vector>

namespace hornero::chromatic {

DiskCache::DiskCache(QString dir, qint64 capBytes)
    : m_dir(std::move(dir))
    , m_cap(capBytes) {}

QString DiskCache::defaultDir() {
    QString base = qEnvironmentVariable("XDG_CACHE_HOME");
    if (base.isEmpty() || !QDir::isAbsolutePath(base))
        base = QDir::homePath() + QStringLiteral("/.cache");
    return base + QStringLiteral("/hornero/chromatic");
}

QString DiskCache::analysisPath(const SourceKey& key) const {
    return m_dir + QStringLiteral("/analysis/") + key.digest.mid(7) + QStringLiteral(".json");
}

QString DiskCache::frameDir() const {
    return enabled() ? m_dir + QStringLiteral("/frames") : QString();
}

QString DiskCache::framePath(const SourceKey& key) const {
    return frameDir() + QLatin1Char('/') + key.digest.mid(7) + QStringLiteral(".png");
}

std::optional<Analysis> DiskCache::analysis(const SourceKey& key) const {
    if (!enabled())
        return std::nullopt;
    const QString path = analysisPath(key);
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return std::nullopt;
    const QByteArray bytes = file.readAll();
    file.close();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    const QJsonObject root = doc.object();
    const auto discard = [&path]() -> std::optional<Analysis> {
        QFile::remove(path);
        return std::nullopt;
    };
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return discard();
    auto parsed = analysisFromCacheJson(root.value(QLatin1String("analysis")).toObject());
    if (!parsed || parsed->sourceDigest != key.digest || parsed->digest() != root.value(QLatin1String("digest")).toString())
        return discard();
    // Touch for LRU.
    QFile touch(path);
    if (touch.open(QIODevice::ReadWrite))
        touch.setFileTime(QDateTime::currentDateTimeUtc(), QFileDevice::FileModificationTime);
    return parsed.value();
}

void DiskCache::storeAnalysis(const SourceKey& key, const Analysis& a) const {
    if (!enabled())
        return;
    if (!QDir().mkpath(m_dir + QStringLiteral("/analysis")))
        return;
    QJsonObject root;
    root.insert(QStringLiteral("digest"), a.digest());
    root.insert(QStringLiteral("analysis"), toCacheJson(a));
    QSaveFile file(analysisPath(key));
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(compact(root));
    if (!file.commit())
        return;
    prune();
}

void DiskCache::prune() const {
    if (!enabled() || m_cap <= 0)
        return;
    struct Entry {
        QString path;
        qint64 size;
        qint64 mtime;
    };
    std::vector<Entry> entries;
    qint64 total = 0;
    for (const char* sub : { "/analysis", "/frames" }) {
        QDirIterator it(m_dir + QLatin1String(sub), QDir::Files);
        while (it.hasNext()) {
            const QFileInfo info(it.next());
            entries.push_back({ info.filePath(), info.size(), info.lastModified(QTimeZone::UTC).toMSecsSinceEpoch() });
            total += info.size();
        }
    }
    if (total <= m_cap)
        return;
    std::sort(entries.begin(), entries.end(), [](const Entry& x, const Entry& y) {
        return x.mtime < y.mtime || (x.mtime == y.mtime && x.path < y.path);
    });
    for (const auto& e : entries) {
        if (total <= m_cap)
            break;
        if (QFile::remove(e.path))
            total -= e.size;
    }
}

} // namespace hornero::chromatic
