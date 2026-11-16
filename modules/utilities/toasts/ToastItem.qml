import qs.components
import qs.components.effects
import qs.services
import qs.config
import Hornero
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property Toast modelData

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + Appearance.padding.smaller * 2

    radius: Appearance.rounding.normal
    color: {
        if (root.modelData.type === Toast.Success)
            return Signal.palette.phosphorWell;
        if (root.modelData.type === Toast.Warning)
            return Signal.palette.cue;
        if (root.modelData.type === Toast.Error)
            return Signal.palette.alertWell;
        return Signal.palette.base;
    }

    border.width: 1
    border.color: {
        let colour = Signal.palette.rule;
        if (root.modelData.type === Toast.Success)
            colour = Signal.palette.phosphor;
        if (root.modelData.type === Toast.Warning)
            colour = Signal.palette.cueWell;
        if (root.modelData.type === Toast.Error)
            colour = Signal.palette.alert;
        return Qt.alpha(colour, 0.3);
    }

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 3
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.smaller
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        spacing: Appearance.spacing.normal

        StyledRect {
            radius: Appearance.rounding.normal
            color: {
                if (root.modelData.type === Toast.Success)
                    return Signal.palette.phosphor;
                if (root.modelData.type === Toast.Warning)
                    return Signal.palette.cueWell;
                if (root.modelData.type === Toast.Error)
                    return Signal.palette.alert;
                return Signal.palette.raised;
            }

            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Appearance.padding.smaller * 2

            Glyph {
                id: icon

                anchors.centerIn: parent
                name: root.modelData.icon
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Signal.palette.onPhosphor;
                    if (root.modelData.type === Toast.Warning)
                        return Signal.palette.onCueWell;
                    if (root.modelData.type === Toast.Error)
                        return Signal.palette.onAlert;
                    return Signal.palette.inkMuted;
                }
                font.pointSize: Math.round(Appearance.font.size.large * 1.2)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: title

                Layout.fillWidth: true
                text: root.modelData.title
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Signal.palette.onPhosphorWell;
                    if (root.modelData.type === Toast.Warning)
                        return Signal.palette.onCue;
                    if (root.modelData.type === Toast.Error)
                        return Signal.palette.onAlertWell;
                    return Signal.palette.ink;
                }
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: root.modelData.message
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Signal.palette.onPhosphorWell;
                    if (root.modelData.type === Toast.Warning)
                        return Signal.palette.onCue;
                    if (root.modelData.type === Toast.Error)
                        return Signal.palette.onAlertWell;
                    return Signal.palette.ink;
                }
                opacity: 0.8
                elide: Text.ElideRight
            }
        }
    }

    Behavior on border.color {
        CAnim {}
    }
}
