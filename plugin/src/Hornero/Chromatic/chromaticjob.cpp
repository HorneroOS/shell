// SPDX-License-Identifier: GPL-3.0-only
#include "chromaticjob.hpp"

namespace hornero::chromatic::qml {

ChromaticJob::ChromaticJob(QObject* parent)
    : QObject(parent) {}

void ChromaticJob::cancel() {
    if (!m_running)
        return;
    m_cancelled->store(true);
    stop();
}

void ChromaticJob::stop() {
    m_running = false;
    emit runningChanged();
    deleteLater();
}

void ChromaticJob::complete(const QVariant& result) {
    if (!m_running || cancelled())
        return;
    m_running = false;
    emit runningChanged();
    emit finished(result);
    deleteLater();
}

void ChromaticJob::fail(const QString& code, const QString& message) {
    if (!m_running || cancelled())
        return;
    m_running = false;
    emit runningChanged();
    emit failed(code, message);
    deleteLater();
}

} // namespace hornero::chromatic::qml
