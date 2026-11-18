import qs.services
import qs.components.motion
import Hornero.Internal
import QtQuick

// Spectrum meter (Signal Bezel §6.2): one scene-graph item for every band,
// square-topped `phosphor` segments, the hot zone in `signal`, and a thin
// `signal` peak-hold tick per band. VU ballistics (fast attack, slow decay,
// peak hold then fall) run in C++ and the item sleeps once nothing moves,
// so a silent or paused spectrum costs no frames. With motion off the
// levels jump and there is no frame clock at all.
//
// `values` takes the raw spectrum (e.g. Audio.cava.values, 0..1 per band);
// `bands` resamples it (0 keeps the source band count); `active: false`
// drains the meter to zero (no player, paused).
SpectrumMeter {
    onColor: Signal.palette.phosphor
    hotColor: Signal.palette.signal
    peakColor: Signal.palette.signal
    offColor: "transparent"
    animated: Choreography.animated

    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Audio spectrum")
}
