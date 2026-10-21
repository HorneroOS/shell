import qs.modules.controlcenter
import Quickshell
import QtQuick

// Frame-cost probe for Control Center initial render: the real
// ControlCenter item in a full-screen window, counting
// FrameAnimation ticks over the first 3 s (initial pane build,
// not a steady-state animation). Run via
// tests/perf/run-framecost-controlcenter.sh. Same vsync caveat
// as the other probes; see
// docs/perf-baselines/2026-10-21-cold-start.md.
ShellRoot {
    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#14141f"
        ControlCenter {
            anchors.centerIn: parent
            screen: win.screen
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
