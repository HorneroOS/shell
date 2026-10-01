import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Active keyboard layout (legacy context-bar). Read-only indicator.
Item {
    id: root

    property bool vertical

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Keyboard layout %1").arg(Hypr.kbLayoutFull)

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Appearance.spacing.smaller / 2

        MaterialIcon {
            Layout.alignment: Qt.AlignCenter
            text: "keyboard"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            text: Hypr.kbLayout
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.smaller
            font.capitalization: Font.AllUppercase
        }
    }
}
