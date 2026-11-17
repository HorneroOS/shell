// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — inference and Signal role synthesis (RFC 0002 §4.5–§6).
#pragma once

#include "hornero/chromatic/analysis.hpp"
#include "hornero/chromatic/request.hpp"
#include "hornero/chromatic/solver.hpp"

#include <QList>
#include <QMap>
#include <QString>
#include <QStringList>

#include <array>
#include <optional>

namespace hornero::chromatic {

struct Inference {
    Mode mode = Mode::Dark;
    Variant variant = Variant::Balanced;
    Contrast contrast = Contrast::Standard;
    QStringList reasons;
    double confidence = 1.0;
    QString personality;
    QString chromaClass; // grey | soft | rich | intense
    QString temperature; // warm | cool | neutral
    std::optional<Variant> suggestion;
};

// `analysis` is null for seed sources and for house without a wallpaper.
[[nodiscard]] Inference infer(const Analysis* analysis, const Request&);

struct VariantParams {
    double sC = 0, iC = 0, aCmin = 0, aCmax = 0, cueRot = 165, harm = 0, term = 0;
    bool darkOnly = false, highContrast = false, glow = true;
    const char* label = "";
    const char* description = "";
};
// `v` must be concrete (not Auto).
[[nodiscard]] const VariantParams& params(Variant v);

// RFC 0001 §3.1 roles in contract order (+ optional glow last).
[[nodiscard]] const QStringList& signalRoles();
[[nodiscard]] const QStringList& surfaceRoles(); // ground … lifted

struct Scheme {
    QString id = QString::fromLatin1(kThemeId);
    Mode mode = Mode::Dark;
    QMap<QString, QString> palette; // every §3.1 role (+ glow when produced)
    std::array<QString, 16> terminal;
    QMap<QString, double> minSurfaceAlpha;          // sunken, base, panel, raised, lifted
    QMap<QString, QMap<QString, QString>> clearInk; // "light"/"dark" → ink, inkMuted, signal, alert, halo
};

struct Adjustment {
    QString role;
    QString from;
    QString to;
    QString reason;
};

struct Generated {
    Request request;
    std::optional<Analysis> analysis;
    Inference inference;
    Scheme scheme;
    QStringList seeds; // the seed colours actually used (signal, then cue source)
    QString sourceKey; // "sha256:…" or empty
    QList<GateRow> gates;
    QList<Adjustment> adjustments;
    QString fingerprint; // "sha256:…" over the canonical scheme JSON
};

// The solver's lightness-only move for one colour pair (PluginKit
// `Theme.ensureContrast`): moves `fg` away from `bg` (the other way when the
// preferred direction cannot reach) until the ratio is ≥ minimum + margin.
[[nodiscard]] Rgb8 ensureContrast(Rgb8 fg, Rgb8 bg, double minimum, double margin = 0.0);

// Deterministic. Fails with GatesUnreachable only on an engine bug.
[[nodiscard]] Expected<Generated> synthesise(
    const Analysis* analysis, const Request&, const Inference&, const GateTable&);

} // namespace hornero::chromatic
