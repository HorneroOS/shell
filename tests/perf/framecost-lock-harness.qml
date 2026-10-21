import qs.modules.lock
import Quickshell
import QtQuick

// Frame-cost probe for the lock content: real Center + InputField
// with the inert Pam stub (tests/atspi/lockstub/Pam.qml) staged by
// run-framecost-lock.sh — never a real WlSessionLock. Counts
// FrameAnimation ticks over the first 3 s of initial render.
// Same vsync caveat as the other probes; see
// docs/perf-baselines/2026-10-21-cold-start.md.
ShellRoot {
    QtObject {
        id: stubLock
        property var screen: null
        property bool unlocking: false
        property Pam pam: Pam {}
    }
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 900
        implicitHeight: 700
        color: "#14141f"
        Center {
            anchors.centerIn: parent
            lock: stubLock
        }
    }
    property int frames: 0
    property double animStart: Date.now() / 1000
    FrameAnimation {
        running: true
        onTriggered: {
            frames++;
            const elapsed = Date.now() / 1000 - animStart;
            if (elapsed >= 3.0) {
                console.info("FRAMECOST frames=" + frames + " windowSec=" + elapsed.toFixed(3) + " avgMs=" + (elapsed * 1000 / frames).toFixed(2));
                animStart = Date.now() / 1000 + 1e9;
            }
        }
    }
    Timer { interval: 30000; running: true; onTriggered: Qt.quit() }
}
