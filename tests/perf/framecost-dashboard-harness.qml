import qs.modules.dashboard
import Quickshell
import QtQuick

// Frame-cost probe for the dashboard open animation: real
// dashboard Wrapper in a full-screen window, counting
// FrameAnimation ticks over the first 2 s after the drawer is
// asked to open. Run via tests/perf/run-framecost-dashboard.sh.
// Same vsync caveat as the launcher probe; see
// docs/perf-baselines/2026-10-21-cold-start.md.
ShellRoot {
    PersistentProperties {
        id: props
        property bool dashboard: false
    }
    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        Wrapper {
            id: wrap
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visibilities: props
        }
    }
    property int frames: 0
    property double animStart: 0
    FrameAnimation {
        running: true
        onTriggered: {
            frames++;
            if (animStart > 0) {
                const elapsed = Date.now() / 1000 - animStart;
                if (elapsed >= 2.0) {
                    console.info("FRAMECOST frames=" + frames + " windowSec=" + elapsed.toFixed(3) + " avgMs=" + (elapsed * 1000 / frames).toFixed(2) + " height=" + wrap.height);
                    animStart = 0;
                    frames = 0;
                }
            }
        }
    }
    Timer { interval: 2500; running: true; onTriggered: { frames = 0; animStart = Date.now() / 1000; props.dashboard = true; } }
    Timer { interval: 30000; running: true; onTriggered: Qt.quit() }
}
