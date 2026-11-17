pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.services
import qs.config
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Lock surface: blurred wallpaper under a `ground` scrim, then the Bezel
// composition. Show = the background fades in, content follows (the clock
// carries its own one-time reveal). Unlock = everything fades out with
// `exit`; no spin, no scale morph. With high contrast the wallpaper is
// dropped for solid `ground`.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    color: Signal.palette.ground

    Connections {
        target: root.lock

        function onUnlock(): void {
            unlockAnim.start();
        }
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: content
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.short
                easing.bezierCurve: Appearance.anim.curves.exit
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.long
                easing.bezierCurve: Appearance.anim.curves.exit
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    Anim {
        id: initAnim

        running: true
        target: background
        property: "opacity"
        to: 1
        duration: Appearance.anim.durations.long
    }

    Anim {
        running: true
        target: content
        property: "opacity"
        to: 1
        duration: Appearance.anim.durations.medium
        easing.bezierCurve: Appearance.anim.curves.enter
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        CachingImage {
            anchors.fill: parent
            visible: !Config.appearance.highContrast
            path: Wallpapers.current

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                blurMultiplier: 1
            }
        }

        // Text sits on this scrim, not on the wallpaper: the clock and
        // sign-in module keep AA contrast over any image.
        Rectangle {
            anchors.fill: parent
            color: Signal.palette.ground
            // The user's lock transparency slider sets the scrim, clamped so
            // the clock and sign-in text keep AA contrast over any wallpaper.
            opacity: Config.appearance.highContrast ? 1 : Math.max(0.6, Signal.elementAlpha("lock"))
        }
    }

    Content {
        id: content

        anchors.fill: parent
        lock: root
        opacity: 0
    }
}
