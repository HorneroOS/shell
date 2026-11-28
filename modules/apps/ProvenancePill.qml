import qs.components
import qs.services
import qs.config
import QtQuick

// Compact Signal Well pill with semantic tone ("phosphor", "cue", "signal", "alert", "muted").
// Colour is always paired with explicit text (and optional icon), never colour alone.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string tone: "muted"

    readonly property color fillColor: {
        if (tone === "phosphor")
            return Signal.palette.phosphorWell;
        if (tone === "cue")
            return Signal.palette.cueWell;
        if (tone === "signal")
            return Signal.palette.signalWell;
        if (tone === "alert")
            return Signal.palette.alertWell;
        return Signal.palette.sunken;
    }

    readonly property color fgColor: {
        if (tone === "phosphor")
            return Signal.palette.onPhosphorWell;
        if (tone === "cue")
            return Signal.palette.onCueWell;
        if (tone === "signal")
            return Signal.palette.onSignalWell;
        if (tone === "alert")
            return Signal.palette.onAlertWell;
        return Signal.palette.inkMuted;
    }

    readonly property color edgeColor: {
        if (tone === "phosphor")
            return Signal.palette.phosphor;
        if (tone === "cue")
            return Signal.palette.cue;
        if (tone === "signal")
            return Signal.palette.signal;
        if (tone === "alert")
            return Signal.palette.alert;
        return Signal.palette.rule;
    }

    implicitWidth: row.implicitWidth + Appearance.padding.normal
    implicitHeight: Math.max(22, row.implicitHeight + 6)
    radius: Appearance.rounding.small
    color: root.fillColor
    border.width: 1
    border.color: root.edgeColor

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: Appearance.font.size.small
            color: root.fgColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            mono: true
            font.pointSize: Appearance.font.size.small
            color: root.fgColor
        }
    }
}
