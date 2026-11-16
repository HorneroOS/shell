pragma ComponentBehavior: Bound

import qs.components
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string icon
    required property string title

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        height: implicitHeight
        spacing: Appearance.spacing.normal

        Glyph {
            Layout.alignment: Qt.AlignHCenter
            name: root.icon
            font.pointSize: Appearance.font.size.extraLarge * 3
            font.bold: true
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            font.pointSize: Appearance.font.size.large
            font.bold: true
        }
    }
}
