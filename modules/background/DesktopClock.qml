pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real scale: Config.background.desktopClock.scale
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur && !Experience.gaming
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Signal.light ? !invertColors : invertColors
    // Over a plate the numerals are plain `ink`; with no plate they sit on
    // the wallpaper and follow the invert switch (with the glyph-only
    // shadow from the clock settings), as before.
    readonly property color safeInk: bgEnabled ? Signal.palette.ink : useLightSet ? Signal.palette.inverse : Signal.palette.ink
    readonly property color safeMuted: bgEnabled ? Signal.palette.inkMuted : safeInk
    readonly property color safeAccent: useLightSet ? Signal.palette.signalWell : Signal.palette.signal

    implicitWidth: layout.implicitWidth + (Appearance.padding.large * 4 * root.scale)
    implicitHeight: layout.implicitHeight + (Appearance.padding.large * 2 * root.scale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopClock.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Signal.palette.shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Appearance.rounding.small
            opacity: Config.background.desktopClock.background.opacity
            color: Signal.palette.base
            border.width: 1
            border.color: Signal.palette.rule

            layer.enabled: root.blurEnabled
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Appearance.spacing.large * root.scale

            // Plex Sans Condensed numerals with a static colon.
            RowLayout {
                spacing: 2

                StyledText {
                    text: Time.hourStr
                    font.family: Appearance.font.family.display
                    font.pointSize: Appearance.font.size.display * root.scale
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    color: root.safeInk
                }

                StyledText {
                    text: ":"
                    font.family: Appearance.font.family.display
                    font.pointSize: Appearance.font.size.display * root.scale
                    font.weight: Font.Medium
                    color: root.safeMuted
                }

                StyledText {
                    text: Time.minuteStr
                    font.family: Appearance.font.family.display
                    font.pointSize: Appearance.font.size.display * root.scale
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    color: root.safeInk
                }

                Loader {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Appearance.padding.large * 1.4 * root.scale

                    active: Config.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledText {
                        text: Time.amPmStr
                        mono: true
                        font.pointSize: Appearance.font.size.normal * root.scale
                        color: root.safeMuted
                    }
                }
            }

            // The accent: a 2 px `signal` rule, square ends.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 2
                Layout.topMargin: Appearance.spacing.larger * root.scale
                Layout.bottomMargin: Appearance.spacing.larger * root.scale
                color: root.safeAccent
            }

            ColumnLayout {
                spacing: 2

                StyledText {
                    text: Time.format("MMMM")
                    mono: true
                    font.capitalization: Font.AllUppercase
                    font.pointSize: Appearance.font.size.normal * root.scale
                    font.letterSpacing: Appearance.font.size.normal * 0.08 * root.scale
                    color: root.safeMuted
                }

                StyledText {
                    text: Time.format("dd")
                    font.family: Appearance.font.family.display
                    font.pointSize: Appearance.font.size.extraLarge * root.scale
                    font.weight: Font.Medium
                    color: root.safeInk
                }

                StyledText {
                    text: Time.format("dddd")
                    mono: true
                    font.capitalization: Font.AllUppercase
                    font.pointSize: Appearance.font.size.small * root.scale
                    font.letterSpacing: Appearance.font.size.small * 0.08 * root.scale
                    color: root.safeMuted
                }
            }
        }
    }

    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.settle
            easing.bezierCurve: Appearance.anim.curves.settle
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.short
        }
    }
}
