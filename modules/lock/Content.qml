import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// Lock composition (Signal Bezel, brand surface): the clock and sign-in
// module sit in the centre; weather and media are quiet footers at the
// lower corners, the notification placeholder on the right. A single 45°
// La Plata diagonal hairline crosses the lower left — the one brand
// ornament permitted by RFC 0001 §2, never inside a control. Telemetry and
// system facts are deliberately absent: a locked screen shows nothing the
// owner has not chosen to share with whoever walks past.
Item {
    id: root

    required property var lock

    // 45° diagonal hairline. It lives only in the strip left of the centre
    // column, so it can never cross the clock or the sign-in module.
    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, (root.width - center.implicitWidth) / 2 - Appearance.padding.large * 2)
        clip: true

        Rectangle {
            width: Math.hypot(root.width, root.height)
            height: 1
            color: Signal.palette.ruleStrong
            opacity: 0.45
            x: -width / 2 + root.height * 0.18
            y: root.height * 0.82
            transformOrigin: Item.Center
            rotation: -45
            antialiasing: true
        }
    }

    Center {
        id: center

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        lock: root.lock
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large * 2
        width: Math.min(360, root.width * 0.24)
        spacing: Appearance.spacing.small

        Instruments.Frame {
            Layout.fillWidth: true
            implicitHeight: weather.implicitHeight + 24
            padding: 12
            visible: Weather.ready

            WeatherInfo {
                id: weather

                anchors.left: parent.left
                anchors.right: parent.right
            }
        }

        Instruments.Frame {
            Layout.fillWidth: true
            implicitHeight: media.implicitHeight + 24
            padding: 12
            visible: media.active

            Media {
                id: media

                anchors.left: parent.left
                anchors.right: parent.right
                lock: root.lock
            }
        }
    }

    Instruments.Frame {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large * 2
        width: Math.min(360, root.width * 0.24)
        height: Config.lock.hideNotifs || Notifs.list.length === 0 ? 128 : Math.min(root.height * 0.5, 420)
        channel: "02"
        title: qsTr("Notifications")

        NotifDock {
            anchors.fill: parent
            lock: root.lock
        }
    }
}
