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
        color: Colours.palette.m3surface

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
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
