import "reloadcover"
import QtQuick
import QtQuick.Window
import Quickshell

// Reload cover harness: the real CoverState (live scheme + shell.json
// under the test's XDG dirs) and the real Slate, in a plain window so it
// renders offscreen without a compositor. Grabs RC_OUT and reports one
// COVER line with what the cover resolved. Motion is frozen so shots are
// deterministic; RC_PRIMARY=0 renders the quiet secondary-screen plate.
ShellRoot {
    id: shell

    readonly property int sw: parseInt(Quickshell.env("RC_W") || "1920")
    readonly property int sh: parseInt(Quickshell.env("RC_H") || "1080")
    readonly property string out: Quickshell.env("RC_OUT") || ""

    CoverState {
        id: live
    }

    Window {
        visible: true
        width: shell.sw
        height: shell.sh
        color: "black"

        Slate {
            id: slate

            anchors.fill: parent
            cover: live.cover
            lang: live.lang
            motion: false
            elapsed: parseInt(Quickshell.env("RC_ELAPSED") || "3")
            primary: Quickshell.env("RC_PRIMARY") !== "0"
            screenName: "DP-1"
        }
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            const report = {
                source: live.cover.source,
                light: live.cover.light,
                highContrast: live.cover.highContrast,
                reducedMotion: live.cover.reducedMotion,
                mascot: live.cover.mascot,
                ground: live.cover.palette.ground,
                signal: live.cover.palette.signal,
                lang: live.lang,
                javi: slate.javiShown,
                sweeping: slate.sweeping,
                w: slate.width,
                h: slate.height
            };
            const done = () => {
                console.log("COVER " + JSON.stringify(report));
                Qt.quit();
            };
            if (shell.out.length > 0)
                slate.grabToImage(res => {
                    res.saveToFile(shell.out);
                    done();
                });
            else
                done();
        }
    }
}
