import qs.modules.launcher
import Quickshell
import QtQuick

// Frame-cost probe for the launcher open animation: real
// Wrapper -> Content -> ContentList -> AppList chain in a
// full-screen window, counting FrameAnimation ticks over the
// first 2 s after the drawer is asked to open. Run via
// tests/perf/run-framecost.sh. Vsync-bound displays report the
// refresh interval; this bounds, but does not isolate, GPU/CPU
// frame cost. See docs/perf-baselines/2026-10-21-cold-start.md.
ShellRoot {
    PersistentProperties {
        id: props
        property bool launcher: false
    }
    Item {
        id: panelsStub
        property Item dashboard: Item { property real nonAnimHeight: 0 }
    }
    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        Item {
            anchors.fill: parent
            anchors.leftMargin: 64
            anchors.topMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
            Wrapper {
                id: wrap
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                screen: win.screen
                visibilities: props
                panels: panelsStub
            }
        }
    }
    property int frames: 0
    property double animStart: 0
    FrameAnimation {
        id: fa
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
    Timer { interval: 1500; running: true; onTriggered: { frames = 0; animStart = Date.now() / 1000; props.launcher = true; } }
    Timer { interval: 30000; running: true; onTriggered: Qt.quit() }
}
