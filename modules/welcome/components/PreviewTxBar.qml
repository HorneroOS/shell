pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.welcome
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Persistent non-blocking Reversible Live Preview transaction strip.
// Appears whenever PreviewTransaction.dirty is true so users can Apply or Revert
// theme, wallpaper, and layout changes without destructive surprises.
StyledRect {
    id: root

    visible: PreviewTransaction.active && PreviewTransaction.dirty
    Layout.fillWidth: true
    implicitHeight: barRow.implicitHeight + Appearance.padding.normal * 2
    radius: Appearance.rounding.small
    color: Signal.palette.signalWell
    border.width: 1
    border.color: Signal.palette.signal

    RowLayout {
        id: barRow

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        anchors.topMargin: Appearance.padding.normal
        anchors.bottomMargin: Appearance.padding.normal
        spacing: Appearance.spacing.normal

        Rectangle {
            width: 8
            height: 8
            radius: width / 2
            color: Signal.palette.signal
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: PreviewTransaction.lastStatus !== "" ? PreviewTransaction.lastStatus : qsTr("Live preview active")
                font.weight: Appearance.font.weight.strong
                color: Signal.palette.onSignalWell
            }

            StyledText {
                text: qsTr("Changes apply live on your desktop. Revert restores your previous look safely.")
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.onSignalWell
                elide: Text.ElideRight
            }
        }

        TextButton {
            type: TextButton.Tonal
            text: qsTr("Revert")
            disabled: PreviewTransaction.applying
            onClicked: PreviewTransaction.revert()
        }

        TextButton {
            type: TextButton.Filled
            text: PreviewTransaction.applying ? qsTr("Applying…") : qsTr("Apply & Keep")
            disabled: PreviewTransaction.applying
            onClicked: PreviewTransaction.apply()
        }
    }
}
