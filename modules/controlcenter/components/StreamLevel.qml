pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Level row for one PipeWire node (device or application stream). The
// readout, the segmented meter and the slider all show the node's real
// volume, read from the Pipewire service; the meter is the node's set
// level, not a live signal peak. `available: false` turns every segment
// off and prints "unavailable" instead of 0 %.
Item {
    id: root

    property string name: ""
    property string glyph: "volume"
    property bool available: true
    property real level: 0
    property bool muted: false
    property string sliderName: root.name
    property string muteName: qsTr("Mute %1").arg(root.name)

    signal levelMoved(real value)
    signal muteToggled(bool muted)

    // First visible sibling draws no top hairline.
    readonly property bool isFirst: {
        const siblings = root.parent ? root.parent.children : [];
        for (let i = 0; i < siblings.length; i++) {
            if (siblings[i] === root)
                return true;
            if (siblings[i].visible && siblings[i].implicitHeight > 0)
                return false;
        }
        return true;
    }
    readonly property int percent: Math.round(root.level * 100)

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Appearance.padding.normal * 2

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isFirst
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Glyph {
                name: root.muted ? "volume-off" : root.glyph
                color: root.muted ? Signal.palette.inkMuted : Signal.palette.ink
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.name
                opacity: root.muted ? 0.6 : 1
            }

            Well {
                implicitWidth: readout.implicitWidth + Appearance.padding.large
                implicitHeight: readout.implicitHeight + Appearance.padding.small * 2

                StyledText {
                    id: readout

                    anchors.centerIn: parent
                    mono: true
                    text: !root.available ? qsTr("unavailable") : root.muted ? qsTr("muted") : qsTr("%1 %").arg(root.percent)
                    color: root.available && !root.muted ? Signal.palette.ink : Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    Accessible.ignored: true
                }
            }

            StyledText {
                text: qsTr("Mute")
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }

            StyledSwitch {
                enabled: root.available
                checked: root.muted
                Accessible.role: Accessible.CheckBox
                Accessible.name: root.muteName
                Accessible.checked: root.muted
                onToggled: root.muteToggled(checked)
            }
        }

        SegmentMeter {
            id: meter

            Layout.fillWidth: true
            implicitWidth: 0
            // Fill the row with square segments; count follows the width.
            count: Math.max(8, Math.floor((width + gap) / (segmentThickness + gap)))
            segmentThickness: 6
            segmentLength: 10
            value: root.muted ? 0 : root.level
            available: root.available
            accessibleName: qsTr("Level of %1").arg(root.name)
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: Appearance.padding.normal * 3
            accessibleName: root.sliderName
            enabled: root.available && !root.muted
            value: root.level
            onMoved: root.levelMoved(value)
        }
    }
}
