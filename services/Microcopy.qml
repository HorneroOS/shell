pragma Singleton

import qs.services
import qs.config
import Quickshell
import QtQuick

// Microcopy (visual language section 17.3): the shell's small spoken
// lines, in two voices. "plain" is the neutral factory phrasing; "cozy" is
// the warm hacker-at-the-workbench voice. Rules for the cosy voice: short
// (at most 48 characters), no exclamation marks, no emoji or kaomoji, no
// pet names, nothing that blames the user, and never the only carrier of
// information (the plain line is the accessible name where it matters).
// Both voices define every key (tests/test_atmosphere.py).
Singleton {
    id: root

    readonly property bool cozy: Atmosphere.tone === "cozy"

    // Time of day, refreshed every five minutes (no per-second timer).
    property int hour: new Date().getHours()
    readonly property string daypart: hour >= 5 && hour < 12 ? "morning" : hour < 18 && hour >= 12 ? "afternoon" : hour >= 18 && hour < 23 ? "evening" : "night"

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.hour = new Date().getHours()
    }

    readonly property var plain: ({
            "launcher.empty": qsTr("No results"),
            "launcher.hint": qsTr("Try a different search"),
            "notifications.empty": qsTr("No notifications"),
            "greeting.morning": qsTr("Good morning"),
            "greeting.afternoon": qsTr("Good afternoon"),
            "greeting.evening": qsTr("Good evening"),
            "greeting.night": qsTr("Good night"),
            "lock.welcome": qsTr("Welcome back"),
            "session.hint": qsTr("Choose what happens next"),
            "undo.applied": qsTr("Applied"),
            "undo.undone": qsTr("Undone"),
            "appearance.now": qsTr("Now using"),
            "appearance.previewing": qsTr("Previewing"),
            "appearance.clickToUse": qsTr("Click to use"),
            "appearance.applying": qsTr("Applying…")
        })

    readonly property var warm: ({
            "launcher.empty": qsTr("Nothing by that name yet"),
            "launcher.hint": qsTr("Try fewer letters, or another word"),
            "notifications.empty": qsTr("All quiet in the nest"),
            "greeting.morning": qsTr("Good morning. The lamp is on"),
            "greeting.afternoon": qsTr("Good afternoon. Tea is warm"),
            "greeting.evening": qsTr("Good evening. Settle in"),
            "greeting.night": qsTr("Late shift. Dim lights, steady hands"),
            "lock.welcome": qsTr("Welcome back. Everything kept its place"),
            "session.hint": qsTr("Rest, restart, or carry on"),
            "undo.applied": qsTr("All set"),
            "undo.undone": qsTr("Put back"),
            "appearance.now": qsTr("Wearing now"),
            "appearance.previewing": qsTr("Trying on"),
            "appearance.clickToUse": qsTr("Click to keep it"),
            "appearance.applying": qsTr("Settling in")
        })

    // `key` -> line in the active voice (falls back to plain).
    function line(key: string): string {
        const table = root.cozy ? root.warm : root.plain;
        return table[key] ?? root.plain[key] ?? key;
    }

    // Always the neutral wording, for accessible names.
    function plainLine(key: string): string {
        return root.plain[key] ?? key;
    }

    readonly property string greeting: line("greeting." + daypart)
}
