import "modules/notifications" as N
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.config

// Notification physics harness (signal-visual-language §11.2): the real
// popup stack (modules/notifications/Content.qml + Notification.qml) fed
// with real Notifs.Notif objects. A scripted timeline exercises the
// timeout line (drain, freeze while held, resume), throws in both swipe
// directions, a timed-out fade, critical cards and the reduced / off
// motion levels. Frames go to NP_OUT/<step>.png; one NOTIF line reports
// every probe.
ShellRoot {
    id: shell

    readonly property string outDir: Quickshell.env("NP_OUT") || ""
    property var probes: ({})
    property var made: ({})
    property real t0: 0

    function make(key: string, props: var): var {
        const n = Notifs.harnessNotifComp.createObject(shell, Object.assign({
            popup: true,
            appName: "Harness",
            summary: key,
            body: "Physics probe card " + key,
            expireTimeout: 6000
        }, props));
        shell.made[key] = n;
        Notifs.list = [n].concat(Notifs.list);
        return n;
    }

    function cardOf(n: var): Item {
        function walk(item) {
            for (let i = 0; i < item.children.length; i++) {
                const c = item.children[i];
                if (!c)
                    continue;
                if ("drain" in c && "tickShown" in c && c.modelData === n)
                    return c;
                const r = walk(c);
                if (r)
                    return r;
            }
            return null;
        }
        return walk(stage);
    }

    function look(key: string): var {
        const n = shell.made[key];
        const c = n ? shell.cardOf(n) : null;
        if (!c)
            return {key: key, card: false, popup: n ? n.popup : null};
        const p = c.mapToItem(stage, 0, 0);
        return {key: key, card: true, popup: n.popup, x: c.x, y: p.y, opacity: c.opacity, drain: c.drain, tick: c.tickShown, held: n.held, left: n.remainingMs()};
    }

    function probe(name: string, keys: var): void {
        shell.probes[name] = {t: Date.now() - shell.t0, cards: keys.map(k => shell.look(k))};
    }

    function shot(name: string): void {
        if (shell.outDir)
            stage.grabToImage(r => r.saveToFile(shell.outDir + "/" + name + ".png"));
    }

    // Records x/opacity of `key` and y of `sibling` every 30 ms for `ms`.
    function film(name: string, key: string, sibling: string, ms: int): void {
        const frames = [];
        const start = Date.now();
        filmTimer.task = () => {
            frames.push({t: Date.now() - start, a: shell.look(key), s: sibling ? shell.look(sibling) : null});
            if (Date.now() - start >= ms) {
                filmTimer.stop();
                shell.probes[name] = frames;
            }
        };
        filmTimer.start();
    }

    PersistentProperties {
        id: vis

        property bool osd
        property bool session
        reloadableId: "npHarnessVis"
    }

    Window {
        id: win

        visible: true
        width: 520
        height: 640
        color: "#10131a"

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#1d2433"
            }

            N.Content {
                visibilities: vis
                panels: null
            }
        }
    }

    Timer {
        id: filmTimer

        property var task: null

        interval: 30
        repeat: true
        onTriggered: task()
    }

    // [delay ms after the previous step, action]
    readonly property var steps: [
        [1500, () => {
            shell.t0 = Date.now();
            shell.make("crit", {urgency: NotificationUrgency.Critical, summary: "Battery critical"});
            shell.make("b", {});
            shell.make("a", {});
        }],
        [3000, () => {
            shell.probe("midway", ["a", "b", "crit"]);
            shell.shot("01-drain-midway");
            shell.made.a.hold(stage);
            shell.probe("held0", ["a"]);
        }],
        [1000, () => {
            shell.probe("held1", ["a", "b"]);
            shell.shot("02-a-held-b-running");
            shell.made.a.release(stage);
        }],
        [600, () => {
            shell.probe("released", ["a"]);
            shell.made.a.hold(stage);
            const c = shell.cardOf(shell.made.a);
            c.x = 160;
            shell.shot("03-a-dragged-right");
        }],
        [300, () => {
            shell.made.a.release(stage);
            shell.made.a.popup = false;
            shell.film("throwRight", "a", "b", 420);
        }],
        [120, () => shell.shot("04-a-thrown-right-mid")],
        [600, () => {
            shell.made.b.hold(stage);
            shell.cardOf(shell.made.b).x = -150;
        }],
        [300, () => {
            shell.made.b.release(stage);
            shell.made.b.popup = false;
            shell.film("throwLeft", "b", "crit", 420);
        }],
        [120, () => shell.shot("05-b-thrown-left-mid")],
        [600, () => {
            shell.make("short", {expireTimeout: 700});
        }],
        [650, () => shell.film("timeout", "short", "crit", 300)],
        [900, () => {
            shell.probe("afterTimeout", ["short", "crit"]);
            Appearance.anim.level = "reduced";
            shell.make("red", {});
        }],
        [700, () => {
            shell.cardOf(shell.made.red).x = 160;
        }],
        [300, () => {
            shell.made.red.popup = false;
            shell.film("throwReduced", "red", "", 300);
        }],
        [600, () => {
            Appearance.anim.level = "standard";
            Config.appearance.reducedMotion = true;
            shell.make("off", {expireTimeout: 4000});
        }],
        [1100, () => {
            shell.probe("offDrain", ["off", "crit"]);
            shell.shot("06-motion-off-stepped-line");
            shell.cardOf(shell.made.off).x = 160;
            shell.made.off.popup = false;
            shell.film("throwOff", "off", "", 200);
        }],
        [500, () => {
            Config.appearance.reducedMotion = false;
            Config.notifs.timeoutTick = false;
            shell.make("notick", {});
        }],
        [600, () => {
            shell.probe("noTick", ["notick", "crit"]);
            shell.shot("07-tick-disabled");
        }],
        [300, () => {
            console.log("NOTIF " + JSON.stringify(shell.probes));
            Qt.quit();
        }]
    ]
    property int stepIndex: 0

    Timer {
        id: runner

        running: true
        interval: shell.steps[0][0]
        onTriggered: {
            shell.steps[shell.stepIndex][1]();
            shell.stepIndex++;
            if (shell.stepIndex < shell.steps.length) {
                interval = shell.steps[shell.stepIndex][0];
                restart();
            }
        }
    }
}
