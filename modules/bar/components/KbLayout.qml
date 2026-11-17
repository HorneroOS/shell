import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Active keyboard layout indicator. Read-only indicator.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

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
            color: root.tone.ink
            font.pointSize: Density.iconPt
        }

        BarText {
            Layout.alignment: Qt.AlignCenter
            role: "label"
            text: Density.clean ? Compositor.keyboardLayoutShort.toLowerCase() : Compositor.keyboardLayoutShort
            color: root.tone.ink
            font.capitalization: Density.clean ? Font.MixedCase : Font.AllUppercase
        }
    }
}
