#include "spectrumballistics.hpp"

#include <algorithm>
#include <cmath>

namespace hornero::internal::spectrum {

namespace {

double clamp01(double v) {
    if (!std::isfinite(v)) {
        return 0.0;
    }
    return std::clamp(v, 0.0, 1.0);
}

bool near(double a, double b, double eps) {
    return std::abs(a - b) <= eps;
}

} // namespace

double smoothingAlpha(double dtMs, double tauMs) {
    if (tauMs <= 0.0) {
        return 1.0;
    }
    if (dtMs <= 0.0) {
        return 0.0;
    }
    return 1.0 - std::exp(-dtMs / tauMs);
}

std::vector<double> resample(std::span<const double> in, int bands) {
    if (bands <= 0) {
        return {};
    }
    const auto n = static_cast<std::size_t>(bands);
    std::vector<double> out(n, 0.0);
    if (in.empty()) {
        return out;
    }
    if (in.size() == n) {
        std::transform(in.begin(), in.end(), out.begin(), clamp01);
        return out;
    }
    if (in.size() > n) {
        // Max-pool: band i covers source [i * k, (i + 1) * k).
        const double k = static_cast<double>(in.size()) / static_cast<double>(n);
        for (std::size_t i = 0; i < n; ++i) {
            const auto from = static_cast<std::size_t>(std::floor(static_cast<double>(i) * k));
            auto to = static_cast<std::size_t>(std::ceil(static_cast<double>(i + 1) * k));
            to = std::clamp(to, from + 1, in.size());
            double m = 0.0;
            for (std::size_t j = from; j < to; ++j) {
                m = std::max(m, clamp01(in[j]));
            }
            out[i] = m;
        }
        return out;
    }
    // Grow: sample the source polyline at evenly spaced positions.
    if (in.size() == 1) {
        std::fill(out.begin(), out.end(), clamp01(in[0]));
        return out;
    }
    const double span = static_cast<double>(in.size() - 1);
    for (std::size_t i = 0; i < n; ++i) {
        const double pos = n == 1 ? 0.0 : static_cast<double>(i) * span / static_cast<double>(n - 1);
        const auto lo = static_cast<std::size_t>(std::floor(pos));
        const std::size_t hi = std::min(lo + 1, in.size() - 1);
        const double f = pos - static_cast<double>(lo);
        out[i] = clamp01(in[lo]) * (1.0 - f) + clamp01(in[hi]) * f;
    }
    return out;
}

void Ballistics::setParams(const BallisticsParams& params) {
    m_params = params;
    m_params.attackMs = std::max(0.0, m_params.attackMs);
    m_params.decayMs = std::max(0.0, m_params.decayMs);
    m_params.peakHoldMs = std::max(0.0, m_params.peakHoldMs);
    m_params.peakFallPerSec = std::max(0.0, m_params.peakFallPerSec);
    m_params.epsilon = std::clamp(m_params.epsilon, 1e-6, 0.1);
    if (!m_params.animated) {
        snap();
    }
}

void Ballistics::resize(std::size_t n) {
    m_targets.resize(n, 0.0);
    m_levels.resize(n, 0.0);
    m_peaks.resize(n, 0.0);
    m_holds.resize(n, m_params.peakHoldMs);
}

bool Ballistics::setTargets(std::span<const double> targets) {
    if (targets.size() != m_targets.size()) {
        resize(targets.size());
    }
    for (std::size_t i = 0; i < targets.size(); ++i) {
        m_targets[i] = clamp01(targets[i]);
    }
    if (!m_params.animated) {
        snap();
    }
    return !settled();
}

void Ballistics::silence() {
    std::fill(m_targets.begin(), m_targets.end(), 0.0);
    if (!m_params.animated) {
        snap();
    }
}

void Ballistics::snap() {
    m_levels = m_targets;
    m_peaks = m_targets;
    std::fill(m_holds.begin(), m_holds.end(), m_params.peakHoldMs);
}

bool Ballistics::step(double dtMs) {
    if (!m_params.animated) {
        snap();
        return false;
    }
    dtMs = std::max(0.0, dtMs);
    const double eps = m_params.epsilon;
    const double rise = smoothingAlpha(dtMs, m_params.attackMs);
    const double fall = smoothingAlpha(dtMs, m_params.decayMs);
    const double peakDrop = m_params.peakFallPerSec * dtMs / 1000.0;

    bool moving = false;
    for (std::size_t i = 0; i < m_targets.size(); ++i) {
        const double target = m_targets[i];
        double level = m_levels[i];
        const double delta = target - level;
        if (std::abs(delta) <= eps) {
            level = target;
        } else {
            level += delta * (delta > 0.0 ? rise : fall);
        }
        m_levels[i] = level;

        double peak = m_peaks[i];
        if (!m_params.peakHold || level >= peak) {
            // The live level reaches the marker: it rides along and the
            // hold restarts from here.
            peak = level;
            m_holds[i] = m_params.peakHoldMs;
        } else if (m_holds[i] > 0.0) {
            m_holds[i] = std::max(0.0, m_holds[i] - dtMs);
        } else {
            peak -= peakDrop;
            if (peak <= level + eps) {
                peak = level;
                m_holds[i] = m_params.peakHoldMs;
            }
        }
        m_peaks[i] = peak;

        if (!near(level, target, 0.0) || !near(peak, level, 0.0)) {
            moving = true;
        }
    }
    return moving;
}

bool Ballistics::settled() const {
    for (std::size_t i = 0; i < m_targets.size(); ++i) {
        if (!near(m_levels[i], m_targets[i], 0.0) || !near(m_peaks[i], m_levels[i], 0.0)) {
            return false;
        }
    }
    return true;
}

} // namespace hornero::internal::spectrum
