// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace hornero::chromatic::qml {

// Value type mirroring the RFC 0002 §8.3 request keys. A plain JS object
// with the same keys is accepted everywhere this type is.
class ChromaticRequest {
    Q_GADGET
    QML_VALUE_TYPE(chromaticRequest)

    Q_PROPERTY(QString source MEMBER source)
    Q_PROPERTY(QString path MEMBER path)
    Q_PROPERTY(QStringList seeds MEMBER seeds)
    Q_PROPERTY(QString variant MEMBER variant)
    Q_PROPERTY(QString mode MEMBER mode)
    Q_PROPERTY(QString contrast MEMBER contrast)
    Q_PROPERTY(QString surfaceDepth MEMBER surfaceDepth)
    Q_PROPERTY(QString surfaceTint MEMBER surfaceTint)
    Q_PROPERTY(double chroma MEMBER chroma)
    Q_PROPERTY(double hueShift MEMBER hueShift)
    Q_PROPERTY(QString currentMode MEMBER currentMode)

public:
    QString source = QStringLiteral("wallpaper");
    QString path;
    QStringList seeds;
    QString variant = QStringLiteral("auto");
    QString mode = QStringLiteral("auto");
    QString contrast = QStringLiteral("standard");
    QString surfaceDepth = QStringLiteral("standard");
    QString surfaceTint = QStringLiteral("auto");
    double chroma = 1.0;
    double hueShift = 0.0;
    QString currentMode; // "", "dark" or "light"

    Q_INVOKABLE QVariantMap toObject() const;
    [[nodiscard]] static ChromaticRequest fromObject(const QVariantMap&);
};

} // namespace hornero::chromatic::qml
