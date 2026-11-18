import "modules"
import "modules/dashboard" as Dashboard
import QtQuick
import QtQuick.Window
import Quickshell
import qs.components.filedialog
import qs.components.motion
import qs.services
import qs.config

// Offscreen dashboard harness (rack rhythm, signal-visual-language §7.1):
// the real dashboard surface (modules/dashboard/Content.qml, home tab) on
// a logical screen. Spacing/padding scales come from the seeded shell.json.
// Env: DS_W/DS_H (logical screen), DS_OUT (png). Prints one DASH line with
// the surface size, the home grid gaps and every text that paints outside
// its instrument frame or the screen.
ShellRoot {
    id: shell

    readonly property int sw: parseInt(Quickshell.env("DS_W") || "1366")
    readonly property int sh: parseInt(Quickshell.env("DS_H") || "768")

    function frameOf(item) {
        for (let p = item.parent; p; p = p.parent)
            if ("headerHeight" in p && "channel" in p)
                return p;
        return null;
    }

    function walk(item, out, frames, grids) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (!c || !c.visible || c.opacity <= 0)
                continue;
            if ("headerHeight" in c && "channel" in c)
                frames.push(c);
            if ("rowSpacing" in c && "columnSpacing" in c && "columns" in c)
                grids.push([c.rowSpacing, c.columnSpacing]);
            if ("contentWidth" in c && "text" in c && "elide" in c && String(c.text).length > 0) {
                const f = shell.frameOf(c);
                const host = f ?? content;
                const p = c.mapToItem(host, 0, 0);
                const right = p.x + Math.min(c.width > 0 ? c.width : c.contentWidth, c.contentWidth);
                const bottom = p.y + c.contentHeight;
                if (p.x < -0.5 || p.y < -0.5 || right > host.width + 0.5 || bottom > host.height + 0.5)
                    out.push({text: String(c.text).slice(0, 40), x: p.x, y: p.y, right: right, bottom: bottom, w: host.width, h: host.height, frame: f ? f.title : ""});
            }
            shell.walk(c, out, frames, grids);
        }
    }

    PersistentProperties {
        id: vis

        property bool dashboard: true
        reloadableId: "dashHarnessVis"
    }

    PersistentProperties {
        id: dashState

        property int currentTab: 0
        property date currentDate: new Date()
        reloadableId: "dashHarnessState"
    }

    FileDialog {
        id: picker
    }

    Window {
        id: win

        visible: true
        width: shell.sw
        height: shell.sh
        color: "#10131a"

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#10131a"
            }

            Rectangle {
                x: content.x - 1
                y: content.y - 1
                width: content.width + 2
                height: content.height + 2
                color: Signal.palette.surface
                border.color: Signal.palette.rule
            }

            Dashboard.Content {
                id: content

                x: Math.round((shell.sw - width) / 2)
                y: 0
                width: implicitWidth
                height: implicitHeight
                visibilities: vis
                state: dashState
                facePicker: picker
            }
        }
    }

    function findNamed(item, name) {
        if (item.objectName === name)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const r = shell.findNamed(item.children[i], name);
            if (r)
                return r;
        }
        return null;
    }

    // DS_MODE=motion: reopen the dashboard and sample the frames' opacity
    // and travel at fixed times (staggered reveal), then switch tab 0 -> 3
    // and sample the on-air indicator (leading/trailing stretch).
    readonly property string mode: Quickshell.env("DS_MODE") || "layout"
    property var frames: []
    property var samples: []
    property var indicatorSamples: []
    property real t0: 0
    property real restWidth: 0
    readonly property var marks: [0, 40, 90, 140, 200, 320, 600]

    function sampleFrames(label) {
        shell.samples.push({t: label, opacity: shell.frames.map(f => Math.round(f.opacity * 100) / 100), shift: shell.frames.map(f => f.transform.length ? Math.round(f.transform[0].y * 10) / 10 : 0)});
    }

    Timer {
        id: motionStart

        interval: 2600
        running: shell.mode === "motion"
        onTriggered: {
            const issues = [], frames = [], grids = [];
            shell.walk(content, issues, frames, grids);
            shell.frames = frames.filter(f => f.title !== "Playback");
            vis.dashboard = false;
            Qt.callLater(() => {
                vis.dashboard = true;
                shell.t0 = Date.now();
                sampler.idx = 0;
                sampler.restart();
            });
        }
    }

    Timer {
        id: sampler

        property int idx: 0

        interval: 5
        repeat: true
        onTriggered: {
            const el = Date.now() - shell.t0;
            if (sampler.idx < shell.marks.length && el >= shell.marks[sampler.idx]) {
                shell.sampleFrames(shell.marks[sampler.idx]);
                const out = Quickshell.env("DS_OUT");
                if (out)
                    stage.grabToImage(r => r.saveToFile(out.replace(".png", `-open-${String(el).padStart(4, "0")}ms.png`)));
                sampler.idx++;
            }
            if (sampler.idx >= shell.marks.length) {
                sampler.stop();
                const ind = shell.findNamed(content, "onAirIndicator");
                shell.restWidth = ind ? ind.width : -1;
                dashState.currentTab = 3;
                shell.t0 = Date.now();
                indSampler.idx = 0;
                indSampler.restart();
            }
        }
    }

    Timer {
        id: indSampler

        property int idx: 0
        readonly property var marks: [0, 60, 110, 160, 600]

        interval: 5
        repeat: true
        onTriggered: {
            const el = Date.now() - shell.t0;
            const ind = shell.findNamed(content, "onAirIndicator");
            if (indSampler.idx < marks.length && el >= marks[indSampler.idx]) {
                shell.indicatorSamples.push(ind ? {t: marks[indSampler.idx], x: Math.round(ind.x), width: Math.round(ind.width)} : {t: marks[indSampler.idx], x: -1, width: -1});
                const out = Quickshell.env("DS_OUT");
                if (out)
                    stage.grabToImage(r => r.saveToFile(out.replace(".png", `-tab-${String(el).padStart(4, "0")}ms.png`)));
                indSampler.idx++;
            }
            if (indSampler.idx >= marks.length) {
                indSampler.stop();
                console.log("DASHMOTION " + JSON.stringify({
                    level: Appearance.anim.effectiveLevel, style: Appearance.anim.curves.style,
                    trailRatio: Choreography.trailRatio, restWidth: shell.restWidth,
                    frames: shell.frames.map(f => f.title || "calendar"), samples: shell.samples, indicator: shell.indicatorSamples
                }));
                Qt.callLater(Qt.quit);
            }
        }
    }

    Timer {
        interval: 2600
        running: shell.mode === "layout"
        onTriggered: {
            const issues = [], frames = [], grids = [];
            shell.walk(content, issues, frames, grids);
            const report = {
                sw: shell.sw, sh: shell.sh,
                spacingScale: Config.appearance.spacing.scale, paddingScale: Config.appearance.padding.scale,
                size: [content.implicitWidth, content.implicitHeight],
                fits: content.implicitWidth <= shell.sw && content.implicitHeight <= shell.sh,
                frames: frames.length, frameSizes: frames.map(f => [f.title || f.channel || "?", Math.round(f.width), Math.round(f.height), Math.round(f.implicitHeight)]), grids: grids, issues: issues
            };
            console.log("DASH " + JSON.stringify(report));
            const out = Quickshell.env("DS_OUT");
            if (out)
                stage.grabToImage(r => { r.saveToFile(out); Qt.quit(); });
            else
                Qt.quit();
        }
    }
}
