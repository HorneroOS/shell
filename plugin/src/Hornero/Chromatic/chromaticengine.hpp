// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include "chromaticjob.hpp"
#include "chromaticrequest.hpp"

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QThreadPool>
#include <QVariant>
#include <QtQmlIntegration/qqmlintegration.h>

#include <atomic>
#include <functional>
#include <memory>

namespace hornero::chromatic {
class Engine;
}

namespace hornero::chromatic::qml {

// In-process engine for previews (RFC 0002 §13.1). Never writes the live
// scheme or any state: horneroctl applies.
class ChromaticEngine : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(QString engineVersion READ engineVersion CONSTANT)
    Q_PROPERTY(int algorithm READ algorithm CONSTANT)
    Q_PROPERTY(QString cacheDir READ cacheDir WRITE setCacheDir NOTIFY cacheDirChanged)

public:
    explicit ChromaticEngine(QObject* parent = nullptr);
    ~ChromaticEngine() override;

    [[nodiscard]] bool available() const { return true; }
    [[nodiscard]] QString engineVersion() const;
    [[nodiscard]] int algorithm() const;
    [[nodiscard]] QString cacheDir() const { return m_cacheDir; }
    void setCacheDir(const QString& dir);

    Q_INVOKABLE hornero::chromatic::qml::ChromaticJob* analyse(const QString& source);
    // `request`: plain JS object (RFC §8.3 keys + "path", "currentMode") or a ChromaticRequest.
    Q_INVOKABLE hornero::chromatic::qml::ChromaticJob* generate(const QVariant& request);
    Q_INVOKABLE double contrast(const QColor& a, const QColor& b) const;
    Q_INVOKABLE QColor ensureContrast(const QColor& fg, const QColor& bg, double minimum) const;
    // OKLab interpolation for palette transitions (t in 0..1).
    Q_INVOKABLE QColor mix(const QColor& a, const QColor& b, double t) const;
    Q_INVOKABLE QVariantList variants() const;
    Q_INVOKABLE hornero::chromatic::qml::ChromaticRequest request() const { return {}; }

signals:
    void cacheDirChanged();

private:
    void rebuildEngine();
    ChromaticJob* startJob(std::function<QVariant(std::atomic_bool& cancelled, QString& code, QString& message)> work);

    QString m_cacheDir;
    std::shared_ptr<hornero::chromatic::Engine> m_engine;
    QThreadPool m_pool;
    QPointer<ChromaticJob> m_generating;
};

} // namespace hornero::chromatic::qml
