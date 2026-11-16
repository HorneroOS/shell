import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var lock

    spacing: Appearance.spacing.large * 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: weather.implicitHeight

            topLeftRadius: Appearance.rounding.large
            radius: Appearance.rounding.small
            color: Signal.tPalette.panel

            WeatherInfo {
                id: weather

                rootHeight: root.height
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Appearance.rounding.small
            color: Signal.tPalette.panel

            Fetch {}
        }

        StyledClippingRect {
            Layout.fillWidth: true
            implicitHeight: media.implicitHeight

            bottomLeftRadius: Appearance.rounding.large
            radius: Appearance.rounding.small
            color: Signal.tPalette.panel

            Media {
                id: media

                lock: root.lock
            }
        }
    }

    Center {
        lock: root.lock
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: resources.implicitHeight

            topRightRadius: Appearance.rounding.large
            radius: Appearance.rounding.small
            color: Signal.tPalette.panel

            Resources {
                id: resources
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            bottomRightRadius: Appearance.rounding.large
            radius: Appearance.rounding.small
            color: Signal.tPalette.panel

            NotifDock {
                lock: root.lock
            }
        }
    }
}
