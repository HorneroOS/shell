pragma Singleton

import qs.config
import Quickshell
import QtQuick

// Motion-level resolution and the shared choreography timings (RFC 0001
// §3.6, Signal visual language §11). Every animated surface reads its
// durations and switches from here, so one level change re-times the
// whole shell and no surface carries its own numbers.
//
// Levels (visual language §11.3):
//   full      Signal mode       everything
//   standard  Everyday, Studio  everything (same timings as full)
//   reduced   Focus, low power  no morph, no stagger; 4 px travel + fade
//   off       Gaming, reduced   instant; opacity fades capped at 90 ms
//
// The level itself lives in Appearance.anim (set by services/Experience
// from the active experience mode); appearance.reducedMotion and the
// system preference force `off` there, as the RFC requires.
Singleton {
    id: root

    readonly property string level: Appearance.anim.effectiveLevel

    // Feature switches.
    readonly property bool morph: level === "full" || level === "standard"
    readonly property bool stagger: morph
    readonly property bool travel: level !== "off"
    readonly property bool animated: level !== "off"

    // User duration scale (appearance.anim.durations.scale).
    readonly property real _scale: Math.max(0, Appearance.anim.durations.scale)

    function _ms(base: real): int {
        return animated ? Math.round(base * _scale) : 0;
    }

    // Spatial durations (0 when off).
    readonly property int quick: _ms(90)
    readonly property int brief: _ms(160)
    readonly property int medium: _ms(240)
    readonly property int extended: _ms(360)
    readonly property int scan: _ms(480)
    readonly property int settle: morph ? _ms(320) : 0
    readonly property int settleFast: morph ? _ms(220) : 0
    // Opacity cross-fades survive every level, capped at 90 ms when off.
    readonly property int fade: animated ? Math.round(90 * _scale) : 90
    readonly property int fadeIn: animated ? _ms(160) : 90

    // Scan-in (RFC §3.6): clip from the anchor edge plus travel and fade.
    readonly property real scanTravel: travel ? 4 : 0
    readonly property real exitTravel: travel ? 4 : 0
    readonly property int staggerStep: stagger ? _ms(24) : 0
    readonly property int staggerStart: stagger ? _ms(60) : 0
    readonly property int staggerMax: 8

    // Hover intent (RFC §4 rule 6). Timing of intent, not of motion: it
    // stays the same at every level.
    readonly property int hoverOpenDelay: 120
    readonly property int hoverCloseGrace: 240

    readonly property var curves: Appearance.anim.curves

    // Frame duration for an anchored surface opening. Hover opens use the
    // quicker settle without stagger (visual language §11.1 rule 6).
    function frameDuration(hover: bool): int {
        return hover ? settleFast : settle;
    }

    function frameCurve(hover: bool): var {
        return hover ? curves.settleFast : curves.settle;
    }

    // Row `index` start delay for a staggered reveal (at most eight rows
    // stagger; later rows start with the eighth).
    function rowDelay(index: int): int {
        if (!stagger)
            return 0;
        return staggerStart + Math.min(Math.max(0, index), staggerMax - 1) * staggerStep;
    }
}
