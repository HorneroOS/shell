// SPDX-License-Identifier: GPL-3.0-only
#include "chromaticrequest.hpp"

namespace hornero::chromatic::qml {

QVariantMap ChromaticRequest::toObject() const {
    QVariantMap m;
    m.insert(QStringLiteral("source"), source);
    if (!path.isEmpty())
        m.insert(QStringLiteral("path"), path);
    m.insert(QStringLiteral("seeds"), seeds);
    m.insert(QStringLiteral("variant"), variant);
    m.insert(QStringLiteral("mode"), mode);
    m.insert(QStringLiteral("contrast"), contrast);
    m.insert(QStringLiteral("surfaceDepth"), surfaceDepth);
    if (!surfaceTint.isEmpty() && surfaceTint != QLatin1String("auto"))
        m.insert(QStringLiteral("surfaceTint"), surfaceTint);
    m.insert(QStringLiteral("chroma"), chroma);
    m.insert(QStringLiteral("hueShift"), hueShift);
    if (!currentMode.isEmpty())
        m.insert(QStringLiteral("currentMode"), currentMode);
    return m;
}

ChromaticRequest ChromaticRequest::fromObject(const QVariantMap& m) {
    ChromaticRequest r;
    r.source = m.value(QStringLiteral("source"), r.source).toString();
    r.path = m.value(QStringLiteral("path")).toString();
    r.seeds = m.value(QStringLiteral("seeds")).toStringList();
    r.variant = m.value(QStringLiteral("variant"), r.variant).toString();
    r.mode = m.value(QStringLiteral("mode"), r.mode).toString();
    r.contrast = m.value(QStringLiteral("contrast"), r.contrast).toString();
    r.surfaceDepth = m.value(QStringLiteral("surfaceDepth"), r.surfaceDepth).toString();
    r.surfaceTint = m.value(QStringLiteral("surfaceTint"), r.surfaceTint).toString();
    r.chroma = m.value(QStringLiteral("chroma"), r.chroma).toDouble();
    r.hueShift = m.value(QStringLiteral("hueShift"), r.hueShift).toDouble();
    r.currentMode = m.value(QStringLiteral("currentMode")).toString();
    return r;
}

} // namespace hornero::chromatic::qml
