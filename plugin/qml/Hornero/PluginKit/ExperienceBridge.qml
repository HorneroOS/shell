pragma Singleton

import qs.services
import QtQuick

// Internal: the host's experience mode (RFC 0001 §5a) as PluginKit sees
// it. services/Experience.qml is the single owner of the mode and of its
// derived motion, glow, density and telemetry fields; this bridge only
// forwards them, so extensions and native surfaces always agree.
QtObject {
    readonly property string mode: Experience.mode
    readonly property string density: Experience.density
    readonly property bool glow: Experience.glow
    readonly property bool scanlines: Experience.scanlines
    readonly property int telemetryIntervalMs: Experience.telemetryIntervalMs
    readonly property bool telemetryPaused: Experience.telemetryPaused
    readonly property int glowLimit: Experience.glowLimit
    readonly property int glowHeld: Experience.glowHeld

    function acquireGlow(owner: var, reserve: int): bool {
        return Experience.acquireGlow(owner, reserve);
    }

    function releaseGlow(owner: var): void {
        Experience.releaseGlow(owner);
    }
}
