pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property Item bar

    readonly property bool barFloating: bar.floating
    readonly property string barPosition: bar.position

    anchors.fill: parent

    StyledRect {
        anchors.fill: parent
        color: Signal.palette.base

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    // Edge line where the frame meets the desktop. The frame fill (`base`)
    // can sit within 1.05:1 of the ground (High Contrast, Night), so the
    // boundary is carried by a stroke, not by the fill difference. Colour is
    // `rule`, or `ruleStrong` under High Contrast (3:1+ on every surface).
    // Width is `border.edgeWidth`; High Contrast never goes below 2 px.
    Rectangle {
        id: edge

        readonly property bool hc: Config.appearance.highContrast
        readonly property int strokeWidth: hc ? Math.max(2, Config.border.edgeWidth) : Config.border.edgeWidth

        visible: strokeWidth > 0
        anchors.fill: parent
        anchors.leftMargin: root.bar.openOn("left") ? 0 : root.bar.marginLeft
        anchors.rightMargin: root.bar.openOn("right") ? 0 : root.bar.marginRight
        anchors.topMargin: root.bar.openOn("top") ? 0 : root.bar.marginTop
        anchors.bottomMargin: root.bar.openOn("bottom") ? 0 : root.bar.marginBottom
        radius: Config.border.rounding
        color: "transparent"
        border.width: strokeWidth
        border.color: hc ? Signal.palette.ruleStrong : Signal.palette.rule
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        // The cutout reaches the screen edge on the bar's edge when the bar
        // floats or is clear, so it sits on the wallpaper instead of a solid
        // frame strip
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: root.bar.openOn("left") ? 0 : root.bar.marginLeft
            anchors.rightMargin: root.bar.openOn("right") ? 0 : root.bar.marginRight
            anchors.topMargin: root.bar.openOn("top") ? 0 : root.bar.marginTop
            anchors.bottomMargin: root.bar.openOn("bottom") ? 0 : root.bar.marginBottom
            radius: Config.border.rounding
        }
    }
}
