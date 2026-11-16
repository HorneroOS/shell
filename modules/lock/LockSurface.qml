pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.services
import qs.config
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    color: "transparent"

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
                target: lockContent
                properties: "implicitWidth,implicitHeight"
                to: lockContent.size
                duration: Appearance.anim.durations.settle
                easing.bezierCurve: Appearance.anim.curves.settle
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: content
                property: "scale"
                to: 0
                duration: Appearance.anim.durations.settle
                easing.bezierCurve: Appearance.anim.curves.settle
            }
            Anim {
                target: content
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.short
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: Appearance.anim.durations.long
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.long
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Appearance.anim.durations.short
                }
                Anim {
                    target: lockContent
                    property: "opacity"
                    to: 0
                }
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: background
            property: "opacity"
            to: 1
            duration: Appearance.anim.durations.long
        }
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    duration: Appearance.anim.durations.settleFast
                    easing.bezierCurve: Appearance.anim.curves.settleFast
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Appearance.anim.durations.settleFast
                    easing.bezierCurve: Appearance.anim.curves.exit
                }
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing.bezierCurve: Appearance.anim.curves.enter
                }
                Anim {
                    target: lockIcon
                    property: "opacity"
                    to: 0
                }
                Anim {
                    target: content
                    property: "opacity"
                    to: 1
                }
                Anim {
                    target: content
                    property: "scale"
                    to: 1
                    duration: Appearance.anim.durations.settle
                    easing.bezierCurve: Appearance.anim.curves.settle
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: Appearance.rounding.large * 1.5
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult * Config.lock.sizes.ratio
                    duration: Appearance.anim.durations.settle
                    easing.bezierCurve: Appearance.anim.curves.settle
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult
                    duration: Appearance.anim.durations.settle
                    easing.bezierCurve: Appearance.anim.curves.settle
                }
            }
        }
    }

    CachingImage {
        id: background

        anchors.fill: parent
        path: Wallpapers.current
        opacity: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Appearance.padding.large * 4
        readonly property int radius: size / 4 * Appearance.rounding.scale

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        rotation: 180
        scale: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Signal.palette.base
            radius: parent.radius
            opacity: Signal.elementAlpha("lock")

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Signal.palette.shadow, 0.7)
            }
        }

        Glyph {
            id: lockIcon

            anchors.centerIn: parent
            name: "lock"
            font.pointSize: Appearance.font.size.extraLarge * 4
            font.bold: true
            rotation: 180
        }

        Content {
            id: content

            anchors.centerIn: parent
            width: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult * Config.lock.sizes.ratio - Appearance.padding.large * 2
            height: (root.screen?.height ?? 0) * Config.lock.sizes.heightMult - Appearance.padding.large * 2

            lock: root
            opacity: 0
            scale: 0
        }
    }
}
