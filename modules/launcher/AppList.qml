pragma ComponentBehavior: Bound

import "items"
import "services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

StyledListView {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    // File provider (shell#250 slice 2): bounded, on-demand find over
    // the XDG user dirs — no indexing daemon, capped results, and the
    // query is passed as a single -iname pattern with quotes stripped.
    property list<string> fileResults: []
    property string fileStatus: ""

    function runFileSearch(): void {
        const q = search.text.slice(`${Config.launcher.actionPrefix}file `.length).trim().replace(/['"\\]/g, "");
        if (q.length < 2) {
            fileResults = [];
            fileStatus = q.length === 0 ? "" : qsTr("Type at least 2 characters");
            return;
        }
        fileStatus = qsTr("Searching…");
        const home = Quickshell.env("HOME");
        const dirs = ["Documents", "Downloads", "Desktop", "Pictures", "Music", "Videos"].map(d => `${home}/${d}`).join(" ");
        fileProc.command = ["sh", "-c", `find ${dirs} -maxdepth 4 -type f -iname '*${q}*' 2>/dev/null | head -50`];
        fileProc.running = true;
    }

    Process {
        id: fileProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                fileProc.out += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Only touch fileResults: the file state's PropertyChanges
            // binding publishes it to the model. Assigning model.values
            // here too broke that binding and the list fell back to
            // empty a frame later (observed live: count 1 -> 0).
            root.fileResults = fileProc.out.split("\n").map(s => s.trim()).filter(s => s.length > 0);
            root.fileStatus = root.fileResults.length === 0 ? qsTr("No files found") : "";
            fileProc.out = "";
        }
    }

    Timer {
        id: fileDebounce

        interval: 250
        onTriggered: root.runFileSearch()
    }

    spacing: Appearance.spacing.small
    orientation: Qt.Vertical
    implicitHeight: (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Appearance.rounding.normal
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    state: {
        const text = search.text;
        const prefix = Config.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "win", "file", "ai", "scheme", "variant", "appearance", "theme"])
                if (text.startsWith(`${prefix}${action} `))
                    return action === "theme" ? "appearance" : action;

            return "actions";
        }

        return "apps";
    }

    Connections {
        target: root.search

        function onTextChanged(): void {
            if (root.state === "file")
                fileDebounce.restart();
        }
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
        if (state === "appearance")
            Themes.reload();
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                model.values: Apps.search(search.text)
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                model.values: Actions.query(search.text)
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                model.values: [0]
                root.delegate: calcItem
            }
        },
        State {
            name: "win"

            PropertyChanges {
                model.values: {
                    const q = search.text.slice(`${Config.launcher.actionPrefix}win `.length).toLowerCase();
                    return Hypr.toplevels.values.filter(w => !q || (w.title ?? "").toLowerCase().includes(q) || (w.lastIpcObject.class ?? "").toLowerCase().includes(q));
                }
                root.delegate: windowItem
            }
        },
        State {
            name: "file"

            PropertyChanges {
                model.values: root.fileResults
                root.delegate: fileItem
            }
        },
        State {
            name: "ai"

            PropertyChanges {
                model.values: [0]
                root.delegate: aiItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                model.values: Schemes.query(search.text)
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                model.values: M3Variants.query(search.text)
                root.delegate: variantItem
            }
        },
        State {
            name: "appearance"

            PropertyChanges {
                model.values: Themes.query(search.text)
                root.delegate: themeItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
            }
            // Only the delegate swaps at the animation midpoint. The
            // model values must stay a live binding: a PropertyAction
            // on "values" re-applies the state-entry snapshot and
            // wiped asynchronously-filled providers (the >file results
            // arrived, then vanished a frame later — live-verified).
            PropertyAction {
                targets: [root]
                properties: "delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            duration: Appearance.anim.durations.small
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: windowItem

        WindowItem {
            list: root
        }
    }

    Component {
        id: fileItem

        FileItem {
            list: root
        }
    }

    Component {
        id: aiItem

        AiItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Component {
        id: themeItem

        AppearanceItem {
            list: root
        }
    }
}
