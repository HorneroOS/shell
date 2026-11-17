// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — generation request (RFC 0002 §6–§8.3).
#pragma once

#include "hornero/chromatic/expected.hpp"

#include <QByteArray>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>

#include <optional>

namespace hornero::chromatic {

inline constexpr int kAlgorithm = 1;
inline constexpr int kSchemaVersion = 1;
inline constexpr const char* kEngineName = "hornero-chromatic";
inline constexpr const char* kEngineVersion = "1.0.0";
inline constexpr const char* kThemeId = "hornero-chromatic";

enum class Variant { Auto, Balanced, Vibrant, Expressive, Faithful, Muted, Monochrome, HighContrast, Neon };
enum class Mode { Auto, Dark, Light };
enum class Contrast { Auto, Standard, Boosted, Maximum };
enum class Depth { Standard, Deep };
enum class SourceSel { Wallpaper, Image, Seed, House };

// Stable wire names ("high-contrast", "surfaceDepth" values, …).
[[nodiscard]] QString name(Variant);
[[nodiscard]] QString name(Mode);
[[nodiscard]] QString name(Contrast);
[[nodiscard]] QString name(Depth);
[[nodiscard]] QString name(SourceSel);
[[nodiscard]] std::optional<Variant> parseVariant(const QString&);
[[nodiscard]] std::optional<Mode> parseMode(const QString&);
[[nodiscard]] std::optional<Contrast> parseContrast(const QString&);
[[nodiscard]] std::optional<Depth> parseDepth(const QString&);
[[nodiscard]] std::optional<SourceSel> parseSource(const QString&);

// The eight concrete variants, in gallery order.
[[nodiscard]] const QList<Variant>& concreteVariants();

struct Request {
    SourceSel source = SourceSel::Wallpaper;
    QString path;      // image/wallpaper source, or house tint wallpaper
    QStringList seeds; // ≤ 2 normalised "#RRGGBB"
    Variant variant = Variant::Auto;
    Mode mode = Mode::Auto;
    Contrast contrast = Contrast::Standard;
    Depth depth = Depth::Standard;
    double chroma = 1.0;   // 0.5..1.5
    double hueShift = 0.0; // -180..180
    std::optional<Mode> currentMode; // hysteresis input only

    // Wire object (RFC §5.2 `request`). `withPath` false drops the path,
    // as stored inside the scheme's `chromatic` block.
    [[nodiscard]] QJsonObject toJson(bool withPath = true) const;
    // Sorted keys, fixed `%.4f` floats; the path is never part of the key.
    [[nodiscard]] QByteArray canonicalJson() const;
};

// Accepts the RFC §8.3 keys plus "path" and "currentMode"; unknown keys are
// ignored (shell.json carries "follow", "perMode", … too).
[[nodiscard]] Expected<Request> requestFromJson(const QJsonObject&);
// Range/shape checks shared by every front end.
[[nodiscard]] std::optional<Error> checkRequest(const Request&);

} // namespace hornero::chromatic
