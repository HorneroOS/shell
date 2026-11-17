// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — wire JSON (helper output, schemaVersion 1; RFC 0002 §5.2, §8.1).
#pragma once

#include "hornero/chromatic/analysis.hpp"
#include "hornero/chromatic/expected.hpp"
#include "hornero/chromatic/solver.hpp"
#include "hornero/chromatic/synth.hpp"

#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>

namespace hornero::chromatic {

// Numbers in output are rounded to 4 decimals so goldens stay readable and
// independent of the last-ulp behaviour of libm.
[[nodiscard]] double round4(double);

[[nodiscard]] QJsonObject engineJson();
[[nodiscard]] QJsonObject toJson(const Analysis&);
// Full fidelity (clusters, grid) for the disk cache; round-trips exactly.
[[nodiscard]] QJsonObject toCacheJson(const Analysis&);
[[nodiscard]] Expected<Analysis> analysisFromCacheJson(const QJsonObject&);
[[nodiscard]] QJsonObject toJson(const Inference&);
[[nodiscard]] QJsonObject toJson(const GateRow&);
[[nodiscard]] QJsonArray toJson(const QList<GateRow>&);
// The live-scheme document (§8.1). `withFingerprint` false omits
// `chromatic.fingerprint`, giving the object the fingerprint is taken over.
[[nodiscard]] QJsonObject schemeJson(const Generated&, bool withFingerprint = true);
[[nodiscard]] QString schemeFingerprint(const Generated&);
// The helper's `generate` document.
[[nodiscard]] QJsonObject toJson(const Generated&);
// Parses a scheme or theme document (palette + terminal [+ mode]) for `validate`.
[[nodiscard]] Expected<Scheme> schemeFromJson(const QJsonObject&);
[[nodiscard]] QByteArray compact(const QJsonObject&);
[[nodiscard]] QString sha256Hex(const QByteArray&);

} // namespace hornero::chromatic
