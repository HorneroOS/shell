// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — gate table and validation (RFC 0002 §4.7, §9.3, §11).
#pragma once

#include "hornero/chromatic/expected.hpp"
#include "hornero/chromatic/request.hpp"

#include <QByteArray>
#include <QList>
#include <QMap>
#include <QPair>
#include <QString>
#include <QStringList>

namespace hornero::chromatic {

struct Scheme;

struct LevelGates {
    QStringList textRoles;
    QStringList textOn;
    double textMin = 4.5;
    QMap<QString, double> textOverrides;
    double onPairsMin = 4.5;
    QList<QPair<QString, QString>> onPairs;
    QStringList boundaryRoles;
    QStringList boundaryOn;
    double boundaryMin = 3.0;
    QStringList focusOn;
    double focusMin = 3.0;

    [[nodiscard]] double textMinFor(const QString& role) const { return textOverrides.value(role, textMin); }
};

struct TerminalGates {
    QString background = QStringLiteral("base");
    QString foreground = QStringLiteral("ink");
    double normalMin = 4.5;
    double brightMin = 3.0;
    double rgyMinDeltaE76 = 10.0;
    double rampMinDeltaE76 = 6.0;
};

struct SeparationGates {
    QList<QPair<QString, QString>> pairs;
    double minDeltaEOK = 0.10;
    double minHueDeg = 25.0;
};

// Loaded from the vendored copy of HorneroOS/config
// `profiles/themes/contrast-gates.json` compiled into the library.
struct GateTable {
    int version = 0;
    QMap<QString, LevelGates> levels; // "standard", "boosted", "maximum"
    TerminalGates terminal;
    double focusOnEverySurfaceMin = 3.0;
    SeparationGates separation;
    double margin = 0.15;

    // `level` must be concrete (Standard/Boosted/Maximum); Auto maps to Standard.
    [[nodiscard]] const LevelGates& level(Contrast) const;

    [[nodiscard]] static const GateTable& builtin();
    [[nodiscard]] static QByteArray builtinJson();
    [[nodiscard]] static Expected<GateTable> fromJson(const QByteArray&);
};

struct GateRow {
    QString label;
    double ratio = 0; // contrast ratio, ΔE76, ΔEOK or degrees, per row kind
    double min = 0;
    bool pass = false;
};

// Every gated pair of `scheme` at `level`. `chromaticExtra` adds the rows
// config applies only to documents carrying a `chromatic` block (focus on
// every surface, accent separation) plus the engine's decorative inkFaint
// floor. Pure: never changes the scheme.
[[nodiscard]] QList<GateRow> validate(const Scheme&, Contrast level, const GateTable&, bool chromaticExtra);
[[nodiscard]] bool allPass(const QList<GateRow>&);

} // namespace hornero::chromatic
