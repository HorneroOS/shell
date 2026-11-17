import ".."
import "../components"
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// Width of the bar popups. Each row has a Reset to the factory width.
SectionContainer {
    id: root

    Layout.fillWidth: true
    alignTop: true

    Eyebrow {
        label: qsTr("Popup sizes")
        color: Signal.palette.ink
    }

    SizeSlider {
        target: Config.bar.sizes
        key: "trayMenuWidth"
        label: qsTr("Tray menu width")
        from: 200
        to: 600
        defaultValue: 300
        stepSize: 10
    }
    SizeSlider {
        target: Config.bar.sizes
        key: "batteryWidth"
        label: qsTr("Battery popup width")
        from: 200
        to: 500
        defaultValue: 250
        stepSize: 10
    }
    SizeSlider {
        target: Config.bar.sizes
        key: "networkWidth"
        label: qsTr("Network popup width")
        from: 240
        to: 640
        defaultValue: 320
        stepSize: 10
    }
    SizeSlider {
        target: Config.bar.sizes
        key: "kbLayoutWidth"
        label: qsTr("Keyboard layout popup width")
        from: 240
        to: 640
        defaultValue: 320
        stepSize: 10
    }
    SizeSlider {
        target: Config.bar.sizes
        key: "windowPreviewSize"
        label: qsTr("Window preview size")
        from: 200
        to: 800
        defaultValue: 400
        stepSize: 20
    }
}
