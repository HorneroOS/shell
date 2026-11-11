pragma ComponentBehavior: Bound

import QtQuick

// Weighted idle acting (visual reboot). One single-shot timer, re-armed
// with a randomized interval per activity level. It only ever fires
// while the companion is idle/visible/unsuppressed (the host binds
// `active`), only picks animations the loaded manifest actually
// ships, and never interrupts task states (idle-first rule).
Item {
    id: root

    property bool active: false
    property string activityLevel: "normal" // calm | normal | lively
    property string skin: "default"
    property bool wanderEnabled: false
    property bool nestEnabled: true
    property int nestStage: 0
    property bool canDoze: true

    signal triggered(string animation)
    signal relocate()

    // [animation, weight] — blink/look dominate; flights are rare and
    // gated by wanderEnabled; carry only while the nest is unfinished.
    readonly property var table: [
        ["blink", 28],
        ["look", 17],
        ["preen", 13],
        ["stretch", 12],
        ["hop", 10],
        ["greet", 6],
        ["sleep", 5],
        ["work", 4],
        ["__relocate", 5]
    ]

    function intervalBand(): var {
        switch (root.activityLevel) {
        case "calm":
            return [20000, 40000];
        case "lively":
            return [4000, 10000];
        default:
            return [8000, 20000];
        }
    }

    function rearm(): void {
        const band = root.intervalBand();
        idleTimer.interval = Math.round(band[0] + Math.random() * (band[1] - band[0]));
        if (root.active)
            idleTimer.restart();
    }

    function pick(): string {
        let total = 0;
        const options = [];
        for (const row of root.table) {
            const name = row[0];
            if (name === "__relocate" && !root.wanderEnabled)
                continue;
            if (name === "sleep" && !root.canDoze)
                continue;
            if (name === "work" && (!root.nestEnabled || root.nestStage >= 4))
                continue;
            if (name !== "__relocate" && !Companion.hasAnimation(root.skin, name))
                continue;
            options.push(row);
            total += row[1];
        }
        if (options.length === 0 || total <= 0)
            return "";
        let roll = Math.random() * total;
        for (const row of options) {
            roll -= row[1];
            if (roll <= 0)
                return row[0];
        }
        return options[options.length - 1][0];
    }

    Timer {
        id: idleTimer

        interval: 12000
        repeat: false
        running: root.active

        onTriggered: {
            const next = root.pick();
            if (next === "__relocate")
                root.relocate();
            else if (next !== "")
                root.triggered(next);
            root.rearm();
        }
    }

    onActiveChanged: {
        if (root.active)
            root.rearm();
    }
    onActivityLevelChanged: root.rearm()
}
