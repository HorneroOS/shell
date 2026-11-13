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

    spacing: Appearance.spacing.small
    orientation: Qt.Vertical
    // The ai state's single delegate grows with the streamed answer;
    // every other state uses fixed-height rows.
    implicitHeight: state === "ai" ? Math.min(360, Math.max(Config.launcher.sizes.itemHeight, currentItem?.implicitHeight ?? 0)) : (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

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

            for (const action of ["calc", "win", "file", "ai", "scheme", "variant", "appearance", "theme"])
                if (text.startsWith(`${prefix}${action} `))
                    return action === "theme" ? "appearance" : action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state !== "file")
            Files.cancel();
        // Leaving the ai route (new query, prefix change) cancels
        // any in-flight inline ask; the singleton keeps only the
        // last partial text in memory.
        if (state !== "ai")
            InlineAsk.cancel();
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
