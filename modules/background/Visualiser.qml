pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Hornero.Services
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property Item shellBar: Visibilities.bars.get(screen) ?? null
    readonly property int frameInset: Config.border.frameEnabled ? Config.border.thickness : 0
    readonly property int barSpacing: Appearance.spacing.small * Config.background.visualiser.spacing
    readonly property bool shouldBeActive: Config.background.visualiser.enabled && (!Config.background.visualiser.autoHide || Compositor.hasOnlyFloatingWindowsOnScreen(screen))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0

    Loader {
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                Item {
                    id: content

                    anchors.fill: parent
                    anchors.leftMargin: (root.shellBar?.marginLeft ?? root.frameInset) + (Config.bar.positionFor(root.screen.name) === "left" ? root.barSpacing : 0)
                    anchors.rightMargin: (root.shellBar?.marginRight ?? root.frameInset) + (Config.bar.positionFor(root.screen.name) === "right" ? root.barSpacing : 0)
                    anchors.topMargin: (root.shellBar?.marginTop ?? root.frameInset) + (Config.bar.positionFor(root.screen.name) === "top" ? root.barSpacing : 0)
                    anchors.bottomMargin: (root.shellBar?.marginBottom ?? root.frameInset) + (Config.bar.positionFor(root.screen.name) === "bottom" ? root.barSpacing : 0)

                    Side {
                        content: content
                    }
                    Side {
                        content: content
                        isRight: true
                    }

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                    Behavior on anchors.rightMargin {
                        Anim {}
                    }
                    Behavior on anchors.topMargin {
                        Anim {}
                    }
                    Behavior on anchors.bottomMargin {
                        Anim {}
                    }
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }

    // One flat `phosphor` column per cava band (VU convention, Signal
    // Bezel §6.2): square tops, no gradient, level read from the real audio
    // spectrum, low frequencies toward the centre. One scene-graph item per
    // side; it sleeps once the bands settle. The Experience glow budget does
    // not apply here.
    component Side: Instruments.Spectrum {
        required property Item content
        property bool isRight

        x: isRight ? content.width * 0.6 : 0
        y: content.height - height
        width: content.width * 0.4
        height: content.height * 0.4

        values: Audio.cava.values
        reversed: !isRight
        segment: 0
        bandGap: root.barSpacing
        peakHold: false
        hotThreshold: 2
        onColor: Qt.alpha(Signal.palette.phosphor, 0.6)
    }
}
