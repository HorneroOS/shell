import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Current weather next to the clock. Hidden until the
// weather service has data.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property string density: "values"

    visible: Weather.ready
    implicitWidth: visible ? layout.implicitWidth : 0
    implicitHeight: visible ? layout.implicitHeight : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: `${Weather.description} ${Weather.temp}`

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Appearance.spacing.smaller / 2

        Glyph {
            Layout.alignment: Qt.AlignCenter
            name: Weather.icon
            color: root.tone.ink
            font.pointSize: Density.iconPt
        }

        BarText {
            Layout.alignment: Qt.AlignCenter
            visible: root.density === "values" || root.vertical
            text: Weather.temp
            color: root.tone.ink
        }
    }
}
