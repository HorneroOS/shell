// SPDX-License-Identifier: GPL-3.0-only
#include "hornero/chromatic/colour.hpp"
#include "hornero/chromatic/expected.hpp"

#include <algorithm>
#include <cmath>
#include <numbers>

namespace hornero::chromatic {

namespace {

constexpr double kDegToRad = std::numbers::pi / 180.0;
constexpr double kRadToDeg = 180.0 / std::numbers::pi;

double clamp01(double v) noexcept {
    return std::min(std::max(v, 0.0), 1.0);
}

std::uint8_t quantise(double encoded) noexcept {
    // Round half up; the input is already clamped to 0..1.
    return static_cast<std::uint8_t>(std::floor(clamp01(encoded) * 255.0 + 0.5));
}

int hexDigit(QChar c) noexcept {
    const char16_t u = c.unicode();
    if (u >= u'0' && u <= u'9')
        return u - u'0';
    if (u >= u'a' && u <= u'f')
        return u - u'a' + 10;
    if (u >= u'A' && u <= u'F')
        return u - u'A' + 10;
    return -1;
}

double cieF(double t) noexcept {
    // Same expression as config's to_lab (pow, not cbrt, for bit parity).
    return t > 0.008856 ? std::pow(t, 1.0 / 3.0) : 7.787 * t + 16.0 / 116.0;
}

} // namespace

QString Error::codeName() const {
    switch (code) {
    case Usage:
        return QStringLiteral("usage");
    case SourceUnreadable:
        return QStringLiteral("source-unreadable");
    case GatesUnreachable:
        return QStringLiteral("gates-unreachable");
    case Internal:
        break;
    }
    return QStringLiteral("internal");
}

double srgbToLinear(double c) noexcept {
    return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4);
}

double linearToSrgb(double c) noexcept {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * std::pow(c, 1.0 / 2.4) - 0.055;
}

LinearRgb toLinear(Srgb c) noexcept {
    return { srgbToLinear(c.r), srgbToLinear(c.g), srgbToLinear(c.b) };
}

Srgb toSrgb(LinearRgb c) noexcept {
    return { linearToSrgb(c.r), linearToSrgb(c.g), linearToSrgb(c.b) };
}

Oklab toOklab(LinearRgb c) noexcept {
    const double l = std::cbrt(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b);
    const double m = std::cbrt(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b);
    const double s = std::cbrt(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
    return {
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    };
}

Oklab toOklab(Srgb c) noexcept {
    return toOklab(toLinear(c));
}

LinearRgb toLinear(Oklab c) noexcept {
    const double l_ = c.L + 0.3963377774 * c.a + 0.2158037573 * c.b;
    const double m_ = c.L - 0.1055613458 * c.a - 0.0638541728 * c.b;
    const double s_ = c.L - 0.0894841775 * c.a - 1.2914855480 * c.b;
    // pow(x, 3) rather than x*x*x keeps bit parity with the reference model.
    const double l = std::pow(l_, 3.0);
    const double m = std::pow(m_, 3.0);
    const double s = std::pow(s_, 3.0);
    return {
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    };
}

Srgb toSrgb(Oklab c) noexcept {
    return toSrgb(toLinear(c));
}

Oklch toOklch(Oklab c) noexcept {
    const double C = std::hypot(c.a, c.b);
    return { c.L, C, wrapHue(std::atan2(c.b, c.a) * kRadToDeg) };
}

Oklab toOklab(Oklch c) noexcept {
    const double hr = c.h * kDegToRad;
    return { c.L, c.C * std::cos(hr), c.C * std::sin(hr) };
}

LinearRgb toLinear(Oklch c) noexcept {
    return toLinear(toOklab(c));
}

double wrapHue(double h) noexcept {
    double r = std::fmod(h, 360.0);
    if (r < 0.0)
        r += 360.0;
    if (r >= 360.0)
        r -= 360.0;
    return r;
}

double hueDiff(double a, double b) noexcept {
    const double d = wrapHue(a - b);
    return d > 180.0 ? d - 360.0 : d;
}

bool inGamut(Oklch c, double eps) noexcept {
    const LinearRgb x = toLinear(c);
    const auto ok = [eps](double v) { return -eps <= v && v <= 1.0 + eps; };
    return ok(x.r) && ok(x.g) && ok(x.b);
}

Oklch gamutMap(Oklch c) noexcept {
    c.L = clamp01(c.L);
    if (inGamut(c))
        return c;
    double lo = 0.0;
    double hi = c.C;
    for (int i = 0; i < 24; ++i) {
        const double mid = (lo + hi) / 2.0;
        if (inGamut({ c.L, mid, c.h }))
            lo = mid;
        else
            hi = mid;
    }
    return { c.L, lo, c.h };
}

double maxChroma(double L, double h) noexcept {
    return gamutMap({ L, 0.5, h }).C;
}

Rgb8 toRgb8(Oklch c) noexcept {
    const LinearRgb x = toLinear(gamutMap(c));
    return { quantise(linearToSrgb(clamp01(x.r))), quantise(linearToSrgb(clamp01(x.g))),
        quantise(linearToSrgb(clamp01(x.b))) };
}

Rgb8 toRgb8(Srgb c) noexcept {
    return { quantise(c.r), quantise(c.g), quantise(c.b) };
}

Srgb toSrgb(Rgb8 c) noexcept {
    return { c.r / 255.0, c.g / 255.0, c.b / 255.0 };
}

QString toHex(Rgb8 c) {
    static constexpr char kDigits[] = "0123456789ABCDEF";
    QString out(7, QLatin1Char('#'));
    const std::uint8_t channels[3] = { c.r, c.g, c.b };
    for (int i = 0; i < 3; ++i) {
        out[1 + 2 * i] = QLatin1Char(kDigits[channels[i] >> 4]);
        out[2 + 2 * i] = QLatin1Char(kDigits[channels[i] & 0xF]);
    }
    return out;
}

QString toHex(Oklch c) {
    return toHex(toRgb8(c));
}

std::optional<Rgb8> parseHex(QStringView text) {
    if (text.startsWith(QLatin1Char('#')))
        text = text.mid(1);
    if (text.size() != 6)
        return std::nullopt;
    std::uint8_t v[3] = { 0, 0, 0 };
    for (qsizetype i = 0; i < 3; ++i) {
        const int hi = hexDigit(text[2 * i]);
        const int lo = hexDigit(text[2 * i + 1]);
        if (hi < 0 || lo < 0)
            return std::nullopt;
        v[i] = static_cast<std::uint8_t>(hi * 16 + lo);
    }
    return Rgb8 { v[0], v[1], v[2] };
}

Oklch toOklch(Rgb8 c) noexcept {
    return toOklch(toOklab(toSrgb(c)));
}

double relativeLuminance(Srgb c) noexcept {
    const LinearRgb x = toLinear(c);
    return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b;
}

double relativeLuminance(Rgb8 c) noexcept {
    return relativeLuminance(toSrgb(c));
}

double contrastRatio(Srgb a, Srgb b) noexcept {
    const double la = relativeLuminance(a);
    const double lb = relativeLuminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

double contrastRatio(Rgb8 a, Rgb8 b) noexcept {
    return contrastRatio(toSrgb(a), toSrgb(b));
}

std::array<double, 3> toCieLab(Rgb8 c) noexcept {
    const LinearRgb x = toLinear(toSrgb(c));
    const double X = (x.r * 0.4124 + x.g * 0.3576 + x.b * 0.1805) / 0.95047;
    const double Y = x.r * 0.2126 + x.g * 0.7152 + x.b * 0.0722;
    const double Z = (x.r * 0.0193 + x.g * 0.1192 + x.b * 0.9505) / 1.08883;
    const double fx = cieF(X);
    const double fy = cieF(Y);
    const double fz = cieF(Z);
    return { 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz) };
}

double deltaE76(Rgb8 a, Rgb8 b) noexcept {
    const auto x = toCieLab(a);
    const auto y = toCieLab(b);
    return std::hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]);
}

double deltaEOK(Oklab a, Oklab b) noexcept {
    return std::hypot(a.L - b.L, a.a - b.a, a.b - b.b);
}

Rgb8 mixOklab(Rgb8 a, Rgb8 b, double t) noexcept {
    const double u = clamp01(t);
    const Oklab x = toOklab(toSrgb(a));
    const Oklab y = toOklab(toSrgb(b));
    return toRgb8(toOklch(Oklab { x.L + (y.L - x.L) * u, x.a + (y.a - x.a) * u, x.b + (y.b - x.b) * u }));
}

Rgb8 composite(Rgb8 top, double alpha, Rgb8 bottom) noexcept {
    const double a = clamp01(alpha);
    const Srgb t = toSrgb(top);
    const Srgb u = toSrgb(bottom);
    return toRgb8(Srgb { a * t.r + (1.0 - a) * u.r, a * t.g + (1.0 - a) * u.g, a * t.b + (1.0 - a) * u.b });
}

} // namespace hornero::chromatic
