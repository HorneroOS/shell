import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Current weather next to the clock. Hidden until the
// weather service has data.
Item {
    id: root

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

        MaterialIcon {
            Layout.alignment: Qt.AlignCenter
            text: Weather.icon
            color: Colours.palette.m3secondary
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.alignment: Qt.AlignCenter
            visible: root.density === "values" || root.vertical
            text: Weather.temp
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.smaller
        }
    }
}
