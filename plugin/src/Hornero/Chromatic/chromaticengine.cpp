// SPDX-License-Identifier: GPL-3.0-only
#include "chromaticengine.hpp"

#include "hornero/chromatic/engine.hpp"
#include "hornero/chromatic/json.hpp"

#include <QJsonObject>
#include <QQmlEngine>
#include <QUrl>

#include <algorithm>
#include <functional>

namespace hornero::chromatic::qml {

namespace {

Rgb8 rgb8(const QColor& c) {
    const QColor s = c.toRgb();
    return { static_cast<std::uint8_t>(s.red()), static_cast<std::uint8_t>(s.green()),
        static_cast<std::uint8_t>(s.blue()) };
}

QColor qcolor(Rgb8 c, const QColor& alphaFrom) {
    QColor out(c.r, c.g, c.b);
    out.setAlphaF(alphaFrom.alphaF());
    return out;
}

} // namespace

ChromaticEngine::ChromaticEngine(QObject* parent)
    : QObject(parent)
    , m_cacheDir(DiskCache::defaultDir()) {
    m_pool.setMaxThreadCount(2);
    rebuildEngine();
}

ChromaticEngine::~ChromaticEngine() {
    m_pool.clear();
    m_pool.waitForDone();
}

QString ChromaticEngine::engineVersion() const {
    return QStringLiteral("%1+a%2").arg(QString::fromLatin1(kEngineVersion)).arg(kAlgorithm);
}

int ChromaticEngine::algorithm() const {
    return kAlgorithm;
}

void ChromaticEngine::setCacheDir(const QString& dir) {
    if (dir == m_cacheDir)
        return;
    m_cacheDir = dir;
    rebuildEngine();
    emit cacheDirChanged();
}

void ChromaticEngine::rebuildEngine() {
    EngineOptions o;
    o.cacheDir = m_cacheDir;
    // Jobs already running keep their own reference to the old engine.
    m_engine = std::make_shared<Engine>(o);
}

ChromaticJob* ChromaticEngine::startJob(
    std::function<QVariant(std::atomic_bool& cancelled, QString& code, QString& message)> work) {
    auto* job = new ChromaticJob(this);
    QQmlEngine::setObjectOwnership(job, QQmlEngine::CppOwnership);
    QPointer<ChromaticJob> guard(job);
    auto flag = job->cancelFlag();
    m_pool.start([this, guard, flag, work = std::move(work)]() {
        if (flag->load())
            return;
        QString code;
        QString message;
        const QVariant result = work(*flag, code, message);
        if (flag->load())
            return;
        QMetaObject::invokeMethod(
            this,
            [guard, result, code, message]() {
                if (!guard)
                    return;
                if (code.isEmpty())
                    guard->complete(result);
                else
                    guard->fail(code, message);
            },
            Qt::QueuedConnection);
    });
    return job;
}

ChromaticJob* ChromaticEngine::analyse(const QString& source) {
    auto engine = m_engine;
    QString path = source;
    if (path.startsWith(QLatin1String("file://")))
        path = QUrl(path).toLocalFile();
    return startJob([engine, path](std::atomic_bool&, QString& code, QString& message) -> QVariant {
        const auto a = engine->analyse(path);
        if (!a) {
            code = a.error().codeName();
            message = a.error().message;
            return {};
        }
        Request r;
        r.source = SourceSel::Image;
        r.path = path;
        QJsonObject doc { { QStringLiteral("schemaVersion"), kSchemaVersion },
            { QStringLiteral("engine"), engineJson() }, { QStringLiteral("analysis"), toJson(a.value()) },
            { QStringLiteral("inference"), toJson(infer(&a.value(), r)) } };
        return doc.toVariantMap();
    });
}

ChromaticJob* ChromaticEngine::generate(const QVariant& requestValue) {
    QVariantMap map;
    if (requestValue.canConvert<ChromaticRequest>() && requestValue.metaType() == QMetaType::fromType<ChromaticRequest>())
        map = requestValue.value<ChromaticRequest>().toObject();
    else
        map = requestValue.toMap();
    QString path = map.value(QStringLiteral("path")).toString();
    if (path.startsWith(QLatin1String("file://")))
        map.insert(QStringLiteral("path"), QUrl(path).toLocalFile());
    // At most one generate in flight: a new one cancels the previous.
    if (m_generating)
        m_generating->cancel();
    auto engine = m_engine;
    const QJsonObject json = QJsonObject::fromVariantMap(map);
    ChromaticJob* job = startJob([engine, json](std::atomic_bool&, QString& code, QString& message) -> QVariant {
        const auto req = requestFromJson(json);
        if (!req) {
            code = req.error().codeName();
            message = req.error().message;
            return {};
        }
        const auto g = engine->generate(req.value());
        if (!g) {
            code = g.error().codeName();
            message = g.error().message;
            return {};
        }
        return toJson(g.value()).toVariantMap();
    });
    m_generating = job;
    return job;
}

double ChromaticEngine::contrast(const QColor& a, const QColor& b) const {
    return contrastRatio(rgb8(a), rgb8(b));
}

QColor ChromaticEngine::ensureContrast(const QColor& fg, const QColor& bg, double minimum) const {
    return qcolor(hornero::chromatic::ensureContrast(rgb8(fg), rgb8(bg), minimum), fg);
}

QColor ChromaticEngine::mix(const QColor& a, const QColor& b, double t) const {
    QColor out = qcolor(mixOklab(rgb8(a), rgb8(b), t), a);
    out.setAlphaF(a.alphaF() + (b.alphaF() - a.alphaF()) * static_cast<float>(std::clamp(t, 0.0, 1.0)));
    return out;
}

QVariantList ChromaticEngine::variants() const {
    QVariantList out;
    for (Variant v : concreteVariants()) {
        const VariantParams& p = params(v);
        out.append(QVariantMap { { QStringLiteral("id"), name(v) }, { QStringLiteral("label"), QString::fromUtf8(p.label) },
            { QStringLiteral("description"), QString::fromUtf8(p.description) },
            { QStringLiteral("darkOnly"), p.darkOnly } });
    }
    return out;
}

} // namespace hornero::chromatic::qml
