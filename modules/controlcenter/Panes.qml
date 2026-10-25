pragma ComponentBehavior: Bound

import "bluetooth"
import "network"
import "audio"
import "appearance"
import "taskbar"
import "launcher"
import "dashboard"
import "system"
import "updates"
import "power"
import "terminal"
import "vpn"
import "notifications"
import "osd"
import qs.components
import qs.services
import qs.config
import qs.modules.controlcenter
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

ClippingRectangle {
    id: root

    required property Session session

    readonly property bool initialOpeningComplete: layout.initialOpeningComplete

    color: "transparent"
    clip: true
    focus: false
    activeFocusOnTab: false

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: function (mouse) {
            root.focus = true;
            mouse.accepted = false;
        }
    }

    Connections {
        target: root.session

        function onActiveIndexChanged(): void {
            root.focus = true;
        }
    }

    Item {
        id: layout

        // Keep every page exactly one viewport tall so translating the stack
        // by activeIndex cannot expose a neighbouring pane's contents.
        width: root.width
        height: root.height * PaneRegistry.count
        y: -root.session.activeIndex * root.height

        property bool initialOpeningComplete: false

        Timer {
            id: initialOpeningTimer
            // Short gate so the first pane can mount before rapid tab switches.
            interval: Appearance.anim.durations.small
            running: true
            onTriggered: layout.initialOpeningComplete = true
        }

        Repeater {
            model: PaneRegistry.count

            Pane {
                required property int index
                paneIndex: index
                componentPath: PaneRegistry.getByIndex(index).component
                x: 0
                y: index * root.height
                width: root.width
                height: root.height
            }
        }

        Behavior on y {
            Anim {
                // Snappier pane switches — long slides feel like input lag.
                duration: Appearance.anim.durations.small
            }
        }
    }

    component Pane: Item {
        id: pane

        required property int paneIndex
        required property string componentPath

        implicitWidth: root.width
        implicitHeight: root.height

        function updateActive(): void {
            const diff = Math.abs(root.session.activeIndex - pane.paneIndex);
            const isActivePane = diff === 0;
            const warmIndex = PaneRegistry.getIndexByLabel(root.session.warmLabel || "");
            const isWarm = warmIndex >= 0 && pane.paneIndex === warmIndex;

            // Keep only the active pane, its immediate neighbours, and a hovered
            // (prefetched) pane. Never keep every visited pane alive; it made
            // the page stack grow and y-animation feel increasingly sluggish.
            let shouldBeActive = false;
            if (!layout.initialOpeningComplete)
                shouldBeActive = isActivePane;
            else
                shouldBeActive = isActivePane || diff <= 1 || isWarm;

            loader.active = shouldBeActive;
        }

        Loader {
            id: loader

            anchors.fill: parent
            clip: false
            active: false
            asynchronous: true

            Component.onCompleted: Qt.callLater(pane.updateActive)

            onActiveChanged: {
                if (active && !item) {
                    loader.setSource(pane.componentPath, {
                        "session": root.session
                    });
                }
            }
        }

        Connections {
            target: root.session
            function onActiveIndexChanged(): void {
                pane.updateActive();
            }
            function onWarmLabelChanged(): void {
                pane.updateActive();
            }
        }

        Connections {
            target: layout
            function onInitialOpeningCompleteChanged(): void {
                pane.updateActive();
            }
        }
    }
}
