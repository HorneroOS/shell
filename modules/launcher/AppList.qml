pragma ComponentBehavior: Bound

import "items"
import "services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.motion
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

StyledListView {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    readonly property string fileStatus: state === "file" ? Files.status : ""
    readonly property bool fileBusy: state === "file" && Files.busy

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    spacing: 0
    orientation: Qt.Vertical
    // The ai state's single delegate grows with the streamed answer;
    // every other state uses fixed-height rows.
    implicitHeight: state === "ai" ? Math.min(360, Math.max(Config.launcher.sizes.itemHeight, currentItem?.implicitHeight ?? 0)) : (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Appearance.rounding.small
        color: Signal.palette.raised

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }
    }

    state: {
        const text = search.text;
        const prefix = Config.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            // Provider-routed states (shell#250 slice 1): the
            // registry claims calc/win; every other prefixed
            // action keeps its historic state below. No prefix
            // match anywhere still means the default apps flow.
            const providerState = Providers.stateFor(text);
            if (providerState === "calc" || providerState === "win" || providerState === "file" || providerState === "ai")
                return providerState;
            // Plugin-defined providers (surfaces.launcher): any
            // other registered provider id routes to the generic
            // plugin state below, served by Providers.query.
            if (providerState !== "")
                return "plugin";

            for (const action of ["calc", "win", "file", "ai", "appearance", "theme"])
                if (text.startsWith(`${prefix}${action} `))
                    return action === "theme" ? "appearance" : action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state === "file")
            Files.refresh();
        else
            Files.cancel();
        // Leaving the ai route (new query, prefix change) cancels
        // any in-flight inline ask; the singleton keeps only the
        // last partial text in memory.
        if (state !== "ai")
            InlineAsk.cancel("launcher");
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
                model.values: Windows.query(search.text.slice(`${Config.launcher.actionPrefix}win `.length))
                root.delegate: windowItem
            }
        },
        State {
            name: "plugin"

            PropertyChanges {
                model.values: Providers.query(search.text)
                root.delegate: pluginItem
            }
        },
        State {
            name: "file"

            PropertyChanges {
                model.values: Providers.query(search.text)
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
                    duration: Appearance.anim.durations.quick
                    easing.bezierCurve: Appearance.anim.curves.exit
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
                    duration: Appearance.anim.durations.short
                    easing.bezierCurve: Appearance.anim.curves.enter
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

    // Staggered reveal of the visible results when the launcher opens
    // (§11.2 launcher rows: 16 ms apart, at most six). Delegates are not in
    // layout order among the view's children, so rows go by index.
    function revealRows(): void {
        if (!root.visibilities.launcher)
            return;
        const rows = [];
        for (let i = 0; i < Math.min(root.count, Choreography.staggerMaxFine + 2); i++) {
            const it = root.itemAtIndex(i);
            if (it && it.visible)
                rows.push(it);
        }
        rowStagger.playRows(rows);
    }

    Connections {
        target: root.visibilities

        function onLauncherChanged(): void {
            if (root.visibilities.launcher)
                Qt.callLater(root.revealRows);
            else
                rowStagger.stop();
        }
    }

    // The launcher rises from the bottom edge: rows travel up.
    Stagger {
        id: rowStagger

        dx: 0
        dy: -1
        step: Choreography.staggerStepFine
        maxRows: Choreography.staggerMaxFine
    }

    add: Transition {
        enabled: !root.state

        Anim {
            property: "opacity"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            property: "opacity"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            property: "opacity"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            duration: Appearance.anim.durations.short
        }
        Anim {
            property: "opacity"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            property: "opacity"
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
        id: pluginItem

        PluginItem {
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
        id: themeItem

        AppearanceItem {
            list: root
        }
    }
}
