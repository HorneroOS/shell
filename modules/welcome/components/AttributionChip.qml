pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Photographer & license provenance chip for verified Argentine wallpapers.
StyledRect {
    id: root

    property string artTitle: ""
    property string photographer: ""
    property string place: ""
    property string license: ""

    visible: artTitle !== "" || photographer !== ""
    implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: chipRow.implicitHeight + Appearance.padding.small * 2
    radius: Appearance.rounding.small
    color: Qt.alpha(Signal.palette.panel, 0.88)
    border.width: 1
    border.color: Signal.palette.ruleStrong

    RowLayout {
        id: chipRow

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Glyph {
            name: "photo"
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.signal
        }

        StyledText {
            text: root.place !== ""
                ? qsTr("%1 · %2 · %3").arg(root.artTitle).arg(root.photographer).arg(root.license)
                : qsTr("%1 · %2").arg(root.artTitle).arg(root.license)
            mono: true
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.ink
        }
    }
}
