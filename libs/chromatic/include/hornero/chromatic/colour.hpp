// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — colour maths (RFC 0002 §4).
//
// OKLab / OKLCH after Björn Ottosson, "A perceptual color space for image
// processing" (2020), using the published matrices. WCAG 2.x luminance and
// CIE76 ΔE match HorneroOS/config `signal_theme.py` exactly, so the engine
// and every validator agree on 8-bit colours.
#pragma once

#include <QString>
#include <QStringView>

#include <array>
#include <cstdint>
#include <optional>

namespace hornero::chromatic {

struct Srgb {
    double r = 0, g = 0, b = 0; // 0..1, gamma-encoded
};
struct LinearRgb {
    double r = 0, g = 0, b = 0;
};
struct Oklab {
    double L = 0, a = 0, b = 0;
};
struct Oklch {
    double L = 0, C = 0, h = 0; // h in degrees [0, 360)
};
// An 8-bit sRGB colour: what a `#RRGGBB` string holds.
struct Rgb8 {
    std::uint8_t r = 0, g = 0, b = 0;
    friend bool operator==(const Rgb8&, const Rgb8&) = default;
};

[[nodiscard]] double srgbToLinear(double c) noexcept;
[[nodiscard]] double linearToSrgb(double c) noexcept;
[[nodiscard]] LinearRgb toLinear(Srgb) noexcept;
[[nodiscard]] Srgb toSrgb(LinearRgb) noexcept;

[[nodiscard]] Oklab toOklab(LinearRgb) noexcept;
[[nodiscard]] Oklab toOklab(Srgb) noexcept;
[[nodiscard]] LinearRgb toLinear(Oklab) noexcept;
[[nodiscard]] Srgb toSrgb(Oklab) noexcept;
[[nodiscard]] Oklch toOklch(Oklab) noexcept;
[[nodiscard]] Oklab toOklab(Oklch) noexcept;
[[nodiscard]] LinearRgb toLinear(Oklch) noexcept;

// Python-compatible floored modulo into [0, 360).
[[nodiscard]] double wrapHue(double h) noexcept;
// Signed hue difference a - b in (-180, 180].
[[nodiscard]] double hueDiff(double a, double b) noexcept;

[[nodiscard]] bool inGamut(Oklch, double eps = 1e-6) noexcept;
// Keep L (clamped to 0..1) and h; bisect C over 24 steps until in sRGB.
[[nodiscard]] Oklch gamutMap(Oklch) noexcept;
[[nodiscard]] double maxChroma(double L, double h) noexcept;

// Gamut-mapped, clamped, rounded half-up per channel.
[[nodiscard]] Rgb8 toRgb8(Oklch) noexcept;
[[nodiscard]] Rgb8 toRgb8(Srgb) noexcept;
[[nodiscard]] Srgb toSrgb(Rgb8) noexcept;
[[nodiscard]] QString toHex(Rgb8);
[[nodiscard]] QString toHex(Oklch);
// Accepts "#RRGGBB" or "RRGGBB", any case.
[[nodiscard]] std::optional<Rgb8> parseHex(QStringView);
[[nodiscard]] Oklch toOklch(Rgb8) noexcept;

// WCAG 2.x relative luminance and contrast ratio on 8-bit colours.
[[nodiscard]] double relativeLuminance(Rgb8) noexcept;
[[nodiscard]] double relativeLuminance(Srgb) noexcept;
[[nodiscard]] double contrastRatio(Rgb8, Rgb8) noexcept;
[[nodiscard]] double contrastRatio(Srgb, Srgb) noexcept;
// CIE76 on CIELAB D65, the same formula as config's `delta_e`.
[[nodiscard]] std::array<double, 3> toCieLab(Rgb8) noexcept;
[[nodiscard]] double deltaE76(Rgb8, Rgb8) noexcept;
[[nodiscard]] double deltaEOK(Oklab, Oklab) noexcept;

// Interpolate in OKLab (t = 0 → a, 1 → b), gamut-mapped.
[[nodiscard]] Rgb8 mixOklab(Rgb8 a, Rgb8 b, double t) noexcept;

// sRGB (gamma-space) source-over of `top` with opacity `alpha` on `bottom`,
// rounded to 8 bits like a compositor would.
[[nodiscard]] Rgb8 composite(Rgb8 top, double alpha, Rgb8 bottom) noexcept;

} // namespace hornero::chromatic
