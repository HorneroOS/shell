import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Hornero
import QtQuick
import QtQuick.Layouts

// Toast as a status line (Signal Bezel §7.1): a `panel` module with a
// 2 px status edge and a mono status word, so the kind never relies on
// colour alone. Success `phosphor`, warning `signal`, error `alert`,
// information `cue`.
StyledRect {
    id: root

    required property Toast modelData
    readonly property color tone: {
        if (root.modelData.type === Toast.Success)
            return Signal.palette.phosphor;
        if (root.modelData.type === Toast.Warning)
            return Signal.palette.signal;
        if (root.modelData.type === Toast.Error)
            return Signal.palette.alert;
        return Signal.palette.cue;
    }
    readonly property string word: {
        if (root.modelData.type === Toast.Success)
            return qsTr("Done");
        if (root.modelData.type === Toast.Warning)
            return qsTr("Warning");
        if (root.modelData.type === Toast.Error)
            return qsTr("Error");
        return qsTr("Note");
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + 20

    radius: Appearance.rounding.small
    color: Signal.palette.panel
    border.width: 1
    border.color: root.modelData.type === Toast.Error ? root.tone : Signal.palette.rule

    Accessible.role: Accessible.AlertMessage
    Accessible.name: `${root.word}: ${root.modelData.title}`
    Accessible.description: root.modelData.message

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 2
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.tone
    }

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

        Glyph {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            name: root.modelData.icon
            color: root.tone
            size: Appearance.font.size.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData.title
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Instruments.Eyebrow {
                    label: root.word
                    color: root.tone
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                textFormat: Text.StyledText
                text: root.modelData.message
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.smaller
                elide: Text.ElideRight
            }
        }
    }

    Behavior on border.color {
        CAnim {}
    }
}
