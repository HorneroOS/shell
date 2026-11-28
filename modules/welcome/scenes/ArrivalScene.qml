pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.motion
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.modules.welcome.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Scene 01 — Arrival: full-bleed atmospheric Argentine landscape (verified
// licensed tier only), subtle Hornero greeting, editorial headline, and
// immediate 3 CTAs (Set up my desktop, Explore Hornero, Start using Hornero).
Item {
    id: root

    property bool windowActive: true

    readonly property var lightWallpaper: ({
            title: qsTr("Golden hour over Quebrada del Condorito"),
            photographer: "Kevin Jones",
            place: qsTr("Córdoba, Argentina"),
            license: "CC BY 2.0",
            path: "/usr/share/hornero/wallpapers/sierras/condorito-sierra-panorama.jpg"
        })
    readonly property var darkWallpaper: ({
            title: qsTr("Buenos Aires after dark"),
            photographer: "Luis Argerich",
            place: qsTr("Buenos Aires, Argentina"),
            license: "CC BY 2.0",
            path: "/usr/share/hornero/wallpapers/buenos-aires-nocturno/buenos-aires-skyline-night.jpg"
        })
    readonly property var activeArt: Signal.light ? lightWallpaper : darkWallpaper

    property real pointerOffsetX: 0
    property real pointerOffsetY: 0

    // Full-bleed verified Argentine photography
    Image {
        id: backdrop

        x: -12 + root.pointerOffsetX
        y: -8 + root.pointerOffsetY
        width: parent.width + 24
        height: parent.height + 16
        source: Qt.resolvedUrl("file://" + root.activeArt.path)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
        Accessible.ignored: true

        Behavior on x {
            MotionAnim { kind: "standard"; speed: "medium" }
        }
        Behavior on y {
            MotionAnim { kind: "standard"; speed: "medium" }
        }
    }

    // Fallback ground when packaged wallpapers aren't installed on host
    Rectangle {
        anchors.fill: parent
        visible: backdrop.status !== Image.Ready
        color: Signal.palette.ground
    }

    // Directional scrim anchored in Signal.palette.ground for >= 7.0:1 text contrast
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Signal.palette.ground, 0.94) }
            GradientStop { position: 0.56; color: Qt.alpha(Signal.palette.ground, 0.84) }
            GradientStop { position: 1.0; color: Qt.alpha(Signal.palette.ground, 0.22) }
        }
    }

    // Pointer parallax capped at +/-10 px X / +/-6 px Y (disabled on reduced motion)
    HoverHandler {
        enabled: Choreography.morph && root.windowActive
        onPointChanged: {
            if (root.width <= 0 || root.height <= 0)
                return;
            const nx = (point.position.x / root.width - 0.5) * 2;
            const ny = (point.position.y / root.height - 0.5) * 2;
            root.pointerOffsetX = Math.max(-10, Math.min(10, -nx * 10));
            root.pointerOffsetY = Math.max(-6, Math.min(6, -ny * 6));
        }
    }

    // Left editorial column
    ColumnLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.large * 2.5
        width: Math.min(540, parent.width * 0.62)
        spacing: Appearance.spacing.large

        // Session readout pill
        StyledRect {
            implicitWidth: readoutRow.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: readoutRow.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.small
            color: Qt.alpha(Signal.palette.panel, 0.88)
            border.width: 1
            border.color: Signal.palette.ruleStrong

            RowLayout {
                id: readoutRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Rectangle {
                    width: 8
                    height: 8
                    radius: width / 2
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("%1 · %2 · v%3")
                        .arg(Compositor.isNiri ? "Niri" : (Compositor.isHyprland ? "Hyprland" : "Wayland"))
                        .arg(Experience.label)
                        .arg(WelcomeModule.State.currentReleaseVersion)
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.ink
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Welcome to Hornero.")
                font.pointSize: Appearance.font.size.display * 0.72
                font.weight: Appearance.font.weight.strong
                color: Signal.palette.ink
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("A new place to call your own.")
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: Appearance.font.weight.medium
                color: Signal.palette.signal
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Take a calm two-minute flight to tune your look, workstation apps, and Javi companion — or jump straight into your desktop anytime.")
                font.pointSize: Appearance.font.size.larger
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }
        }

        // Immediate 3 CTAs
        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            TextButton {
                type: TextButton.Filled
                text: qsTr("Set up my desktop")
                horizontalPadding: Appearance.padding.large
                verticalPadding: Appearance.padding.normal
                onClicked: Welcome.goToScene("personalize")
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("Explore Hornero")
                horizontalPadding: Appearance.padding.large
                verticalPadding: Appearance.padding.normal
                onClicked: Welcome.setMode("explore")
            }

            TextButton {
                type: TextButton.Text
                text: qsTr("Start using Hornero")
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.normal
                onClicked: Welcome.skipToDesktop()
            }
        }
    }

    // Bottom-right Hornero perch + verified attribution chip
    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Appearance.padding.large * 1.5
        anchors.bottomMargin: Appearance.padding.large
        spacing: Appearance.spacing.normal

        AttributionChip {
            visible: backdrop.status === Image.Ready
            artTitle: root.activeArt.title
            photographer: root.activeArt.photographer
            place: root.activeArt.place
            license: root.activeArt.license
        }

        StyledRect {
            implicitWidth: spriteRow.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: spriteRow.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.small
            color: Qt.alpha(Signal.palette.panel, 0.9)
            border.width: 1
            border.color: Signal.palette.ruleStrong
            visible: WelcomeModule.State.mascotEnabled

            RowLayout {
                id: spriteRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                HorneroSprite {
                    pixel: 2
                    force: true
                    pose: root.windowActive ? "perch" : "sleep"
                }

                StyledText {
                    text: qsTr("Javi says hola")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }
        }
    }
}
