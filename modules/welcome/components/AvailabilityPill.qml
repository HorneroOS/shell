pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// Honest capability / availability indicator pill.
StyledRect {
    id: root

    property string availability: "supported"
    property bool available: true

    readonly property string labelText: {
        if (!available)
            return qsTr("Unavailable");
        if (availability === "optional")
            return qsTr("Optional");
        if (availability === "edition-dependent")
            return qsTr("Edition-dependent");
        if (availability === "probe-only")
            return qsTr("Read-only probe");
        if (availability === "preview")
            return qsTr("Preview");
        return qsTr("Supported");
    }

    readonly property color fillColour: {
        if (!available)
            return Signal.palette.alertWell;
        if (availability === "supported")
            return Signal.palette.phosphorWell;
        if (availability === "optional")
            return Signal.palette.cueWell;
        return Signal.palette.signalWell;
    }

    readonly property color inkColour: {
        if (!available)
            return Signal.palette.onAlertWell;
        if (availability === "supported")
            return Signal.palette.onPhosphorWell;
        if (availability === "optional")
            return Signal.palette.onCueWell;
        return Signal.palette.onSignalWell;
    }

    readonly property color borderColour: {
        if (!available)
            return Signal.palette.alert;
        if (availability === "supported")
            return Signal.palette.phosphor;
        if (availability === "optional")
            return Signal.palette.cue;
        return Signal.palette.signal;
    }

    implicitWidth: pillLabel.implicitWidth + Appearance.padding.normal
    implicitHeight: pillLabel.implicitHeight + 6
    radius: Appearance.rounding.small
    color: root.fillColour
    border.width: 1
    border.color: root.borderColour

    StyledText {
        id: pillLabel

        anchors.centerIn: parent
        text: root.labelText
        mono: true
        font.pointSize: Appearance.font.size.small
        color: root.inkColour
    }
}
