import qs.components
import qs.components.placement
import qs.components.motion
import qs.services
import qs.config
import Quickshell
import QtQuick

// Anchored-surface probe (docs/INTERACTION.md): a top bar with four
// triggers and one AnchoredSurface with three eight-row pages, driven
// through open -> switch (morph) -> switch -> close cycles. Prints:
//   ANCHORED latency kind=<open|switch> ms=<request -> next frameSwapped>
//   ANCHORED interval maxMs=<worst frame interval while animating>
//   ANCHORED done cycles=<n>
// Run via tests/perf/run-anchored-surface.sh, which also collects the
// scene-graph render timings (QSG_RENDER_TIMING). Development-host
// measurement only; never published as an estimate.
ShellRoot {
    id: shell

    property int cycle: 0
    property int step: 0
    property int page: 0
    property double requestedAt: 0
    property string requestKind: ""
    property real maxInterval: 0
    readonly property int cycles: 12

    PanelWindow {
        id: win

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            color: Signal.palette.base

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 120
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    id: triggers

                    model: 4

                    Rectangle {
                        required property int index

                        width: 32
                        height: 28
                        color: Signal.palette.raised
                    }
                }
            }
        }

        AnchoredSurface {
            id: surface

            readonly property int page: shell.page

            anchorItem: triggers.itemAt(page)
            owner: ({
                    edge: "top",
                    style: "attached",
                    thickness: 36,
                    margin: 0,
                    floating: false,
                    clear: false
                })
            ownerItem: bar
            reserved: ({
                    top: 36
                })
            devicePixelRatio: win.screen?.devicePixelRatio ?? 1
            key: `page${page}`
            preferredWidth: pages.itemAt(page)?.preferredWidth ?? 0
            preferredHeight: pages.itemAt(page)?.preferredHeight ?? 0

            Repeater {
                id: pages

                model: 3

                SurfacePage {
                    id: pg

                    required property int index

                    surface: surface
                    pageKey: `page${index}`
                    current: surface.open && surface.page === index
                    sourceComponent: Column {
                        spacing: 12

                        Repeater {
                            model: 8

                            StyledText {
                                required property int index

                                text: `Row ${index + 1} of page ${pg.index + 1}`
                                width: 240 + pg.index * 60
                                height: 32
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: win.contentItem.Window.window

            function onFrameSwapped(): void {
                if (shell.requestedAt > 0) {
                    console.info(`ANCHORED latency kind=${shell.requestKind} ms=${(Date.now() - shell.requestedAt).toFixed(1)}`);
                    shell.requestedAt = 0;
                }
            }
        }
    }

    FrameAnimation {
        running: surface.animating
        onTriggered: shell.maxInterval = Math.max(shell.maxInterval, frameTime * 1000)
    }

    function request(kind: string): void {
        shell.requestKind = kind;
        shell.requestedAt = Date.now();
    }

    // 0: open page0, 1: switch page1, 2: switch page2, 3: close
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            const phase = shell.step % 4;
            if (phase === 0) {
                shell.page = 0;
                shell.request("open");
                surface.open = true;
            } else if (phase === 3) {
                surface.open = false;
            } else {
                shell.request("switch");
                shell.page = phase;
            }
            shell.step++;
            if (phase === 3) {
                shell.cycle++;
                if (shell.cycle >= shell.cycles) {
                    console.info(`ANCHORED interval maxMs=${shell.maxInterval.toFixed(2)} level=${Choreography.level}`);
                    console.info(`ANCHORED done cycles=${shell.cycle}`);
                    stop();
                    Qt.callLater(Qt.quit);
                }
            }
        }
    }
}
