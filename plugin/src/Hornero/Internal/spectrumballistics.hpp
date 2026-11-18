#pragma once

// VU ballistics for the Hornero spectrum meter (pure maths, no Qt).
//
// Each band eases toward its target with exponential smoothing,
// alpha = 1 - exp(-dt / tau), using a short attack time constant when the
// level rises and a long decay time constant when it falls. That is real
// VU behaviour: transients light up at once and drain away slowly. A
// peak-hold marker sits at the highest recent level for `peakHoldMs`, then
// falls at a constant rate and never drops below the live level.
//
// `step()` reports whether anything still moves, so the item that owns the
// engine can stop its frame driver once every band and peak has settled.

#include <span>
#include <vector>

namespace hornero::internal::spectrum {

struct BallisticsParams {
    double attackMs = 30.0;     // rise time constant
    double decayMs = 300.0;     // fall time constant
    double peakHoldMs = 600.0;  // how long a peak marker holds
    double peakFallPerSec = 1.6; // full scale per second once the hold ends
    double epsilon = 0.002;     // below this the level snaps to its target
    bool peakHold = true;
    bool animated = true; // false: levels and peaks jump (reduced motion)
};

// 1 - exp(-dt / tau). tau <= 0 means "jump" (alpha 1).
[[nodiscard]] double smoothingAlpha(double dtMs, double tauMs);

// Fit `in` to `bands` values: max-pool when shrinking (a loud band never
// disappears), linear interpolation when growing. Values clamp to [0, 1]
// and NaN reads as 0.
[[nodiscard]] std::vector<double> resample(std::span<const double> in, int bands);

class Ballistics {
public:
    void setParams(const BallisticsParams& params);
    [[nodiscard]] const BallisticsParams& params() const { return m_params; }

    // Sets the targets. The band count follows `targets.size()`; new bands
    // start at 0. Returns true when anything differs from the settled state.
    bool setTargets(std::span<const double> targets);
    void silence(); // every target to 0

    // Advances by `dtMs`. Returns true while anything still moves.
    bool step(double dtMs);
    // Levels jump to their targets and peaks to their levels.
    void snap();

    [[nodiscard]] bool settled() const;
    [[nodiscard]] int bandCount() const { return static_cast<int>(m_targets.size()); }
    [[nodiscard]] const std::vector<double>& targets() const { return m_targets; }
    [[nodiscard]] const std::vector<double>& levels() const { return m_levels; }
    [[nodiscard]] const std::vector<double>& peaks() const { return m_peaks; }

private:
    BallisticsParams m_params;
    std::vector<double> m_targets;
    std::vector<double> m_levels;
    std::vector<double> m_peaks;
    std::vector<double> m_holds; // remaining hold time per band, ms

    void resize(std::size_t n);
};

} // namespace hornero::internal::spectrum
