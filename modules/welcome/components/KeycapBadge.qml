pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// Tactile physical keycap cluster rendered in IBM Plex Mono.
Row {
    id: root

    property string combo: ""
    property bool highlighted: false

    readonly property var parts: {
        const raw = (root.combo ?? "").trim();
        if (raw === "")
            return [];
        return raw.split(/\s*\+\s*/).filter(p => p.length > 0);
    }

    spacing: 4
    visible: root.parts.length > 0

    Repeater {
        model: root.parts

        delegate: StyledRect {
            required property string modelData

            implicitWidth: keyLabel.implicitWidth + 14
            implicitHeight: keyLabel.implicitHeight + 6
            radius: Appearance.rounding.small
            color: root.highlighted ? Signal.palette.signalWell : Signal.palette.lifted
            border.width: 1
            border.color: root.highlighted ? Signal.palette.signal : Signal.palette.ruleStrong

            StyledText {
                id: keyLabel

                anchors.centerIn: parent
                text: parent.modelData
                mono: true
                font.pointSize: Appearance.font.size.small
                font.weight: Appearance.font.weight.strong
                color: root.highlighted ? Signal.palette.onSignalWell : Signal.palette.ink
            }
        }
    }
}
