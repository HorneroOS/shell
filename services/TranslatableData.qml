import QtQuick

// English UI text that lives in plain JS tables (experience.js, deck.js),
// which tests run under node and so cannot call qsTr(). Marking the
// strings here puts them in the catalog; the views show them through
// qsTr(value), and the translator finds them by source text
// (docs/I18N.md). Never instantiated.
QtObject {
    readonly property list<string> strings: [
        QT_TR_NOOP("Maximum space, quiet motion, notifications held."),
        QT_TR_NOOP("Balanced default: Cockpit, standard motion, values on the bar."),
        QT_TR_NOOP("Immersive: desktop instruments, labelled telemetry at 2 Hz, glow and scanlines."),
        QT_TR_NOOP("Out of the way: no motion or glow, notifications queued, polling paused under fullscreen."),
        QT_TR_NOOP("Audio first: stable canvas, standard motion, no glow; a deliberate switch in applies the reversible PipeWire Low Latency profile."),
        QT_TR_NOOP("System Insight"),
        QT_TR_NOOP("Network Scope"),
        QT_TR_NOOP("Audio Deck"),
        QT_TR_NOOP("Calendar"),
        QT_TR_NOOP("Agenda"),
        QT_TR_NOOP("Moon Phase"),
        QT_TR_NOOP("Everything"),
        QT_TR_NOOP("Cozy corner"),
        QT_TR_NOOP("Kawaii night"),
        QT_TR_NOOP("System monitor"),
        QT_TR_NOOP("Time and sky"),
        QT_TR_NOOP("System Insight only")
    ]
}
