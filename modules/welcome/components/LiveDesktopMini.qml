pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Miniature live desktop preview canvas reflecting active Signal.palette.*,
// previewed wallpaper, and shell bar topology in real time.
StyledRect {
    id: root

    property string wallpaperSource: ""
    property string layoutPreset: "cockpit"
    property string themeName: ""

    readonly property bool isLeftRail: layoutPreset.indexOf("left") !== -1
    readonly property bool isRightRail: layoutPreset.indexOf("right") !== -1
    readonly property bool isBottomDock: layoutPreset.indexOf("bottom") !== -1
    readonly property bool isClear: layoutPreset.indexOf("clear") !== -1

    radius: Appearance.rounding.normal
    color: Signal.palette.ground
    border.width: 1
    border.color: Signal.palette.ruleStrong
    clip: true

    // Wallpaper layer
    Image {
        id: bgImg

        anchors.fill: parent
        source: root.wallpaperSource !== "" ? Qt.resolvedUrl("file://" + root.wallpaperSource) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
        Accessible.ignored: true
    }

    // Fallback subtle surface grid when wallpaper image isn't mounted
    Rectangle {
        anchors.fill: parent
        visible: bgImg.status !== Image.Ready
        gradient: Gradient {
            GradientStop { position: 0.0; color: Signal.palette.ground }
            GradientStop { position: 1.0; color: Signal.palette.base }
        }
    }

    // Simulated shell bar topology
    StyledRect {
        id: miniBar

        readonly property int thickness: 18

        x: root.isRightRail ? parent.width - thickness - 6 : 6
        y: root.isBottomDock ? parent.height - thickness - 6 : 6
        width: (root.isLeftRail || root.isRightRail) ? thickness : parent.width - 12
        height: (root.isLeftRail || root.isRightRail) ? parent.height - 12 : thickness
        radius: Appearance.rounding.small
        color: root.isClear ? Qt.alpha(Signal.palette.panel, 0.65) : Signal.palette.panel
        border.width: 1
        border.color: Signal.palette.rule

        Row {
            visible: !root.isLeftRail && !root.isRightRail
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 6
            spacing: 4

            Rectangle { width: 8; height: 8; radius: 2; color: Signal.palette.signal }
            Rectangle { width: 16; height: 6; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Signal.palette.inkMuted }
            Rectangle { width: 10; height: 6; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Signal.palette.ruleStrong }
        }

        Column {
            visible: root.isLeftRail || root.isRightRail
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            spacing: 4

            Rectangle { width: 8; height: 8; radius: 2; color: Signal.palette.signal }
            Rectangle { width: 8; height: 14; radius: 2; color: Signal.palette.inkMuted }
            Rectangle { width: 8; height: 10; radius: 2; color: Signal.palette.ruleStrong }
        }
    }

    // Simulated foreground editorial window using live Signal tokens
    StyledRect {
        id: miniWindow

        readonly property int insetLeft: root.isLeftRail ? 32 : 18
        readonly property int insetRight: root.isRightRail ? 32 : 18
        readonly property int insetTop: (!root.isLeftRail && !root.isRightRail && !root.isBottomDock) ? 32 : 18
        readonly property int insetBottom: root.isBottomDock ? 32 : 18

        anchors.fill: parent
        anchors.leftMargin: insetLeft
        anchors.rightMargin: insetRight
        anchors.topMargin: insetTop
        anchors.bottomMargin: insetBottom
        radius: Appearance.rounding.small
        color: Signal.palette.base
        border.width: 1
        border.color: Signal.palette.ruleStrong

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle { width: 8; height: 8; radius: 4; color: Signal.palette.signal }
                StyledText {
                    Layout.fillWidth: true
                    text: root.themeName !== "" ? root.themeName : qsTr("Signal Canvas")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
                StyledText {
                    text: root.layoutPreset
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }

            Hairline {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.spacing.small

                StyledRect {
                    Layout.preferredWidth: 132
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: Signal.palette.panel
                    border.width: 1
                    border.color: Signal.palette.rule

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle { width: parent.width * 0.8; height: 6; radius: 2; color: Signal.palette.signal }
                        Rectangle { width: parent.width * 0.65; height: 5; radius: 2; color: Signal.palette.inkMuted }
                        Rectangle { width: parent.width * 0.72; height: 5; radius: 2; color: Signal.palette.ruleStrong }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: Signal.palette.raised
                    border.width: 1
                    border.color: Signal.palette.rule

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle { Layout.preferredWidth: 72; Layout.preferredHeight: 8; radius: 2; color: Signal.palette.ink }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 2; color: Signal.palette.inkMuted }
                        Rectangle { Layout.preferredWidth: 96; Layout.preferredHeight: 5; radius: 2; color: Signal.palette.cue }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            spacing: 6
                            Rectangle { width: 42; height: 14; radius: 3; color: Signal.palette.signal }
                            Rectangle { width: 34; height: 14; radius: 3; color: Signal.palette.phosphorWell; border.width: 1; border.color: Signal.palette.phosphor }
                        }
                    }
                }
            }
        }
    }
}
