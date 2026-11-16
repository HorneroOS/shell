import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Active keyboard layout indicator. Read-only indicator.
Item {
    id: root

    property bool vertical

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Keyboard layout %1").arg(Compositor.keyboardLayoutName)

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Appearance.spacing.smaller / 2

        Glyph {
            Layout.alignment: Qt.AlignCenter
            name: "keyboard"
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            text: Compositor.keyboardLayoutShort
            color: Signal.palette.ink
            font.pointSize: Appearance.font.size.smaller
            font.capitalization: Font.AllUppercase
        }
    }
}
