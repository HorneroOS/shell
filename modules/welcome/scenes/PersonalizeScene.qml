pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.welcome
import qs.modules.welcome.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 02 — Personalize ("Make It Yours"): split live-canvas studio.
// Left 44%: Dark/Light/High-Contrast themes + Argentine Originals, licensed
// Argentine wallpapers, Chromatic accents, bar layouts, Motion toggle.
// Right 56%: Live miniature desktop stage + Reversible Preview transaction strip.
Item {
    id: root

    property bool windowActive: true

    readonly property var polarityChoices: [
        { id: "hornero-signal-night", label: qsTr("Signal Night"), icon: "moon" },
        { id: "hornero-signal-day", label: qsTr("Signal Day"), icon: "sun" },
        { id: "hornero-signal-contrast", label: qsTr("High Contrast"), icon: "contrast" }
    ]

    readonly property var curatedThemes: [
        { id: "hornero-signal-night", label: qsTr("Blue-Hour Night") },
        { id: "hornero-signal-day", label: qsTr("White Ceramic Day") },
        { id: "hornero-signal-contrast", label: qsTr("AAA Contrast") },
        { id: "jacaranda", label: qsTr("Jacarandá") },
        { id: "glaciar", label: qsTr("Glaciar") },
        { id: "ceibo", label: qsTr("Ceibo") }
    ]

    readonly property var licensedWallpapers: [
        { id: "buenos-aires-nocturno", title: qsTr("Buenos Aires Night"), credit: "Luis Argerich · CC BY 2.0", path: "/usr/share/hornero/wallpapers/buenos-aires-nocturno/buenos-aires-skyline-night.jpg" },
        { id: "fin-del-mundo", title: qsTr("Beagle Channel"), credit: "RAYANDBEE · CC BY 2.0", path: "/usr/share/hornero/wallpapers/fin-del-mundo/beagle-channel-ship-dusk.jpg" },
        { id: "sierras", title: qsTr("Quebrada del Condorito"), credit: "Kevin Jones · CC BY 2.0", path: "/usr/share/hornero/wallpapers/sierras/condorito-sierra-panorama.jpg" },
        { id: "hornero-signal-night", title: qsTr("Signal Night Grid"), credit: "HorneroOS · MIT", path: "/usr/share/hornero/wallpapers/hornero-signal-night/signal-grid-night.png" },
        { id: "hornero-signal-day", title: qsTr("Signal Day Grid"), credit: "HorneroOS · MIT", path: "/usr/share/hornero/wallpapers/hornero-signal-day/signal-grid-day.png" }
    ]

    readonly property var layoutChoices: [
        { id: "hornero-left", label: qsTr("Hornero Left"), icon: "layout-sidebar" },
        { id: "hornero-right", label: qsTr("Hornero Right"), icon: "layout-sidebar-right" },
        { id: "cockpit", label: qsTr("Cockpit"), icon: "layout-rows" },
        { id: "cockpit-clear", label: qsTr("Clear"), icon: "blur" }
    ]

    readonly property var chromaticVariants: [
        { id: "balanced", label: qsTr("Balanced") },
        { id: "vibrant", label: qsTr("Vibrant") },
        { id: "muted", label: qsTr("Muted") }
    ]

    readonly property string activeThemeId: (PreviewTransaction.staged && PreviewTransaction.staged.themeId) || Signal.themeId || Config.appearance.theme
    readonly property string activeWallpaperPath: (PreviewTransaction.staged && PreviewTransaction.staged.wallpaperPath) || Wallpapers.current || ""
    readonly property string activeLayoutPreset: (PreviewTransaction.staged && PreviewTransaction.staged.layoutPreset) || PreviewTransaction.currentLayoutPreset || "cockpit"

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.large

        // Left 44% tactile personalization controls
        StyledFlickable {
            id: leftFlick

            Layout.preferredWidth: parent.width * 0.44
            Layout.fillHeight: true
            flickableDirection: Flickable.VerticalFlick
            contentHeight: leftCol.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: leftFlick
            }

            ColumnLayout {
                id: leftCol

                width: parent.width - Appearance.padding.small
                spacing: Appearance.spacing.normal

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: qsTr("MAKE IT YOURS")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.signal
                    }

                    StyledText {
                        text: qsTr("Surface, light, and geometry")
                        font.pointSize: Appearance.font.size.extraLarge * 0.78
                        font.weight: Appearance.font.weight.strong
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Everything previews live on your desktop. Apply to keep, or Revert anytime.")
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }

                // Theme Polarity + High Contrast
                StyledText {
                    text: qsTr("Polarity & contrast")
                    font.weight: Appearance.font.weight.strong
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.polarityChoices

                        delegate: ToggleButton {
                            required property var modelData

                            toggled: modelData.id === "hornero-signal-contrast"
                                ? Config.appearance.highContrast
                                : (!Config.appearance.highContrast && root.activeThemeId === modelData.id)
                            icon: modelData.icon
                            label: modelData.label
                            accent: "signal"
                            horizontalPadding: Appearance.padding.normal
                            verticalPadding: Appearance.padding.small
                            onClicked: {
                                if (modelData.id === "hornero-signal-contrast") {
                                    Actions.setHighContrast(!Config.appearance.highContrast);
                                } else {
                                    if (Config.appearance.highContrast)
                                        Actions.setHighContrast(false);
                                    PreviewTransaction.previewTheme(modelData.id);
                                }
                            }
                        }
                    }
                }

                // Argentine Originals & Signal Palettes
                StyledText {
                    text: qsTr("Palettes & Argentine Originals")
                    font.weight: Appearance.font.weight.strong
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.curatedThemes

                        delegate: TextButton {
                            required property var modelData

                            type: root.activeThemeId === modelData.id ? TextButton.Filled : TextButton.Tonal
                            text: modelData.label
                            horizontalPadding: Appearance.padding.normal
                            verticalPadding: Appearance.padding.small
                            onClicked: PreviewTransaction.previewTheme(modelData.id)
                        }
                    }
                }

                // Chromatic live accents
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Chromatic accent")
                        font.weight: Appearance.font.weight.strong
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: root.chromaticVariants

                        delegate: TextButton {
                            required property var modelData

                            type: TextButton.Tonal
                            text: modelData.label
                            horizontalPadding: Appearance.padding.small
                            verticalPadding: Appearance.padding.small
                            onClicked: PreviewTransaction.previewChromaticVariant(modelData.id)
                        }
                    }
                }

                // Licensed Argentine wallpapers
                StyledText {
                    text: qsTr("Licensed Argentine landscapes")
                    font.weight: Appearance.font.weight.strong
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.licensedWallpapers

                        delegate: StyledRect {
                            id: wallRow

                            required property var modelData

                            readonly property bool selected: root.activeWallpaperPath === modelData.path

                            Layout.fillWidth: true
                            implicitHeight: wallInner.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.small
                            color: selected ? Signal.palette.signalWell : Signal.palette.panel
                            border.width: 1
                            border.color: selected ? Signal.palette.signal : Signal.palette.rule

                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.title
                            Accessible.checked: selected

                            Interactive {
                                color: wallRow.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                                onClicked: PreviewTransaction.previewWallpaper(wallRow.modelData.path)
                            }

                            RowLayout {
                                id: wallInner

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                Glyph {
                                    name: wallRow.selected ? "circle-check" : "photo"
                                    color: wallRow.selected ? Signal.palette.onSignalWell : Signal.palette.signal
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        text: wallRow.modelData.title
                                        font.weight: wallRow.selected ? Appearance.font.weight.strong : Appearance.font.weight.regular
                                        color: wallRow.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                                    }

                                    StyledText {
                                        text: wallRow.modelData.credit
                                        mono: true
                                        font.pointSize: Appearance.font.size.small
                                        color: wallRow.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                                    }
                                }
                            }
                        }
                    }
                }

                // Bar layouts
                StyledText {
                    text: qsTr("Shell bar layout")
                    font.weight: Appearance.font.weight.strong
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: root.layoutChoices

                        delegate: ToggleButton {
                            required property var modelData

                            toggled: root.activeLayoutPreset === modelData.id
                            icon: modelData.icon
                            label: modelData.label
                            accent: "cue"
                            horizontalPadding: Appearance.padding.normal
                            verticalPadding: Appearance.padding.small
                            onClicked: PreviewTransaction.previewLayout(modelData.id)
                        }
                    }
                }

                // Motion preference
                SwitchRow {
                    Layout.fillWidth: true
                    label: qsTr("Reduced motion")
                    checked: Config.appearance.reducedMotion
                    onToggled: checked => Actions.setReducedMotion(checked)
                }
            }
        }

        // Right 56% live desktop mini-canvas + preview transaction bar
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            LiveDesktopMini {
                Layout.fillWidth: true
                Layout.fillHeight: true
                wallpaperSource: root.activeWallpaperPath
                layoutPreset: root.activeLayoutPreset
                themeName: root.activeThemeId
            }

            PreviewTxBar {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Need deeper palette or font tuning later? Appearance settings are one click away.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    type: TextButton.Tonal
                    text: qsTr("Open Layout Picker")
                    onClicked: Actions.openLayoutPicker()
                }
            }
        }
    }
}
