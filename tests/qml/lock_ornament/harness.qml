import "modules/lock" as Lock
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services

// Lock ornament harness: the real lock composition (modules/lock/Content.qml,
// real Center + footers) at a real output size, with the inert Pam stub
// (tests/atspi/lockstub/Pam.qml) staged in place of modules/lock/Pam.qml —
// never a real WlSessionLock. Each scene is grabbed to LO_OUT/<scene>.png and
// reported on one LOCKORN line. LO_W/LO_H pick the output size.
ShellRoot {
    id: shell

    readonly property int sw: parseInt(Quickshell.env("LO_W") || "1920")
    readonly property int sh: parseInt(Quickshell.env("LO_H") || "1080")
    readonly property string outDir: Quickshell.env("LO_OUT") || ""

    // `ornament` is only applied on trees that have the setting, so the
    // harness also renders an unfixed checkout (its default look).
    readonly property var scenes: [
        {name: "default"},
        {name: "ornament-on", ornament: true},
        {name: "ornament-on-hc", ornament: true, hc: true}
    ]
    property int index: -1
    property var results: []

    QtObject {
        id: stubLock

        property var screen: ({height: shell.sh, width: shell.sw})
        property bool unlocking: false
        property Lock.Pam pam: Lock.Pam {}
    }

    function applyScene(s: var): void {
        if ("diagonalRule" in Config.lock)
            Config.lock.diagonalRule = !!s.ornament;
        Config.appearance.highContrast = !!s.hc;
    }

    function next(): void {
        shell.index++;
        if (shell.index >= shell.scenes.length) {
            console.info("LOCKORN " + JSON.stringify({w: shell.sw, h: shell.sh, scenes: shell.results}));
            Qt.quit();
            return;
        }
        shell.applyScene(shell.scenes[shell.index]);
        settle.restart();
    }

    Timer {
        id: settle

        // Long enough for the content fade-in and the clock reveal.
        interval: 2500
        onTriggered: {
            const s = shell.scenes[shell.index];
            stage.grabToImage(r => {
                const path = shell.outDir + "/" + s.name + ".png";
                r.saveToFile(path);
                shell.results.push({name: s.name, png: path, hasSetting: "diagonalRule" in Config.lock});
                shell.next();
            });
        }
    }

    Window {
        visible: true
        width: shell.sw
        height: shell.sh
        color: "#000000"

        Item {
            id: stage

            anchors.fill: parent

            // Stand-in for LockSurface's `ground` scrim (the wallpaper is
            // blurred under it on the host; a flat ground keeps the probe
            // deterministic).
            Rectangle {
                anchors.fill: parent
                color: Signal.palette.ground
            }

            Lock.Content {
                anchors.fill: parent
                lock: stubLock
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: shell.next()
    }

    Timer {
        interval: 60000
        running: true
        onTriggered: {
            console.warn("LOCKORN timeout");
            Qt.quit();
        }
    }
}
