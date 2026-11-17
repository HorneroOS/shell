// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QVariant>
#include <QtQmlIntegration/qqmlintegration.h>

#include <atomic>
#include <memory>

namespace hornero::chromatic::qml {

// One asynchronous engine call. Owned by ChromaticEngine and deleted after
// it finishes, fails or is cancelled. A cancelled job never emits.
class ChromaticJob : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("ChromaticJob instances come from ChromaticEngine.analyse()/generate()")

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit ChromaticJob(QObject* parent = nullptr);

    [[nodiscard]] bool running() const { return m_running; }
    [[nodiscard]] bool cancelled() const { return m_cancelled->load(); }
    [[nodiscard]] std::shared_ptr<std::atomic_bool> cancelFlag() const { return m_cancelled; }

    Q_INVOKABLE void cancel();

    // Called on the GUI thread by the engine.
    void complete(const QVariant& result);
    void fail(const QString& code, const QString& message);

signals:
    void runningChanged();
    void finished(const QVariant& result);
    void failed(const QString& code, const QString& message);

private:
    void stop();
    bool m_running = true;
    std::shared_ptr<std::atomic_bool> m_cancelled = std::make_shared<std::atomic_bool>(false);
};

} // namespace hornero::chromatic::qml
