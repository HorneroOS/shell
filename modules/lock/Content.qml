import qs.components
import qs.components.atmosphere
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// Lock composition (Signal Bezel, brand surface): the clock and sign-in
// module sit in the centre; weather and media are quiet footers at the
// lower corners, the notification placeholder on the right. An optional
// 45° La Plata diagonal hairline (lock.diagonalRule, off by default) may
// cross the lower left — the one brand ornament permitted by RFC 0001 §2,
// never inside a control. Telemetry and
// system facts are deliberately absent: a locked screen shows nothing the
// owner has not chosen to share with whoever walks past.
Item {
    id: root

    required property var lock

    AtmosphereTexture {}

    // Optional 45° diagonal hairline (Control Center › Lock screen). Off by
    // default: drawn from the screen corner and cut by a clip edge it read
    // as a stray rendering line on real outputs (host report, 1.3.0). When
    // on it is a finite segment in the strip left of the centre column —
    // so it can never cross the clock or the sign-in module — that fades
    // out at both ends instead of touching the corner or stopping mid-air.
    Loader {
        id: ornament

        readonly property real strip: Math.max(0, (root.width - center.implicitWidth) / 2 - Appearance.padding.large * 2)

        anchors.fill: parent
        active: Config.lock.diagonalRule && strip > 120

        sourceComponent: Item {
            id: rule

            // Segment from 20 % to 95 % of the strip along x + y = height.
            readonly property real x0: ornament.strip * 0.2
            readonly property real x1: ornament.strip * 0.95
            readonly property real mid: (x0 + x1) / 2

            Rectangle {
                width: (rule.x1 - rule.x0) * Math.SQRT2
                height: 1
                x: rule.mid - width / 2
                y: root.height - rule.mid - height / 2
                transformOrigin: Item.Center
                rotation: -45
                antialiasing: true
                opacity: Config.appearance.highContrast ? 0.8 : 0.45

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Qt.alpha(Signal.palette.ruleStrong, 0)
                    }
                    GradientStop {
                        position: 0.3
                        color: Signal.palette.ruleStrong
                    }
                    GradientStop {
                        position: 0.7
                        color: Signal.palette.ruleStrong
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Signal.palette.ruleStrong, 0)
                    }
                }
            }
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

    AtmosphereLayer {
        lampOrigin: "bottomLeft"
        lampReach: 1.1
    }
}
