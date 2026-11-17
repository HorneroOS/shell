import qs.components
import qs.services
import qs.config
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Battery status; hidden on machines without a laptop battery. Absent on machines without a laptop
// battery, so layouts can include it unconditionally.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property string density: "values"
    readonly property var device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    readonly property real percent: (device?.percentage ?? 0) * 100
    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: !charging && percent <= 20

    visible: present
    implicitWidth: visible ? layout.implicitWidth : 0
    implicitHeight: visible ? layout.implicitHeight : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Battery %1%").arg(Math.round(percent))

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: Appearance.spacing.smaller / 2

        Glyph {
            Layout.alignment: Qt.AlignCenter
            name: root.charging ? "battery-charging" : root.percent > 80 ? "battery-4" : root.percent > 50 ? "battery-3" : root.percent > 20 ? "battery-2" : "battery-exclamation"
            color: root.low ? root.tone.alert : root.tone.ink
            font.pointSize: Density.iconPt
        }

        BarText {
            Layout.alignment: Qt.AlignCenter
            visible: root.density === "values" && !root.vertical
            text: `${Math.round(root.percent)}%`
            color: root.low ? root.tone.alert : root.tone.ink
        }
    }
}
