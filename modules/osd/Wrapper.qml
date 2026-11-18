pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property var visibilities
    property bool hovered
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: visibilities.osd && Config.osd.enabled && !(visibilities.utilities && Config.utilities.enabled)

    property real volume
    property bool muted
    property real sourceVolume
    property bool sourceMuted
    property real brightness

    // Which channel changed last: "out", "mic" or "bri" (Content draws
    // only this one).
    property string channel: "out"

    function show(channel: string): void {
        root.channel = channel;
        visibilities.osd = true;
        timer.restart();
    }

    Component.onCompleted: {
        volume = Audio.volume;
        muted = Audio.muted;
        sourceVolume = Audio.sourceVolume;
        sourceMuted = Audio.sourceMuted;
        brightness = root.monitor?.brightness ?? 0;
    }

    visible: width > 0
    implicitWidth: 0

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            content.retained = true;
    }
    onWidthChanged: {
        if (width <= 0 && !shouldBeActive)
            content.retained = false;
    }
    implicitHeight: content.implicitHeight

    states: State {
        name: "visible"
        when: root.shouldBeActive

        PropertyChanges {
            root.implicitWidth: content.implicitWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
                easing.bezierCurve: Appearance.anim.curves.settle
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    ]

    Connections {
        target: Audio

        function onMutedChanged(): void {
            root.show("out");
            root.muted = Audio.muted;
        }

        function onVolumeChanged(): void {
            root.show("out");
            root.volume = Audio.volume;
        }

        function onSourceMutedChanged(): void {
            root.show("mic");
            root.sourceMuted = Audio.sourceMuted;
        }

        function onSourceVolumeChanged(): void {
            root.show("mic");
            root.sourceVolume = Audio.sourceVolume;
        }
    }

    Connections {
        target: root.monitor

        function onBrightnessChanged(): void {
            root.show("bri");
            root.brightness = root.monitor?.brightness ?? 0;
        }
    }

    Timer {
        id: timer

        interval: Config.osd.hideDelay
        onTriggered: {
            if (!root.hovered)
                root.visibilities.osd = false;
        }
    }

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        // Spring pop-in animation on the content
        opacity: root.shouldBeActive ? 1 : 0
        scale: root.shouldBeActive ? 1 : 0.88

        // Opacity never overshoots (§11): enter, not settle.
        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.enter
            }
        }

        Behavior on scale {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settle
            }
        }

        // Kept alive until the collapse animation reaches zero width. Written
        // imperatively: binding `active` to `root.visible` (width > 0) closes
        // a loop through implicitWidth -> content.implicitWidth -> active.
        property bool retained: false
        active: root.shouldBeActive || retained

        sourceComponent: Content {
            monitor: root.monitor
            visibilities: root.visibilities
            volume: root.volume
            muted: root.muted
            sourceVolume: root.sourceVolume
            sourceMuted: root.sourceMuted
            brightness: root.brightness
            channel: root.channel
        }
    }
}
