import "weather"
import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight

    readonly property var today: Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null
    readonly property bool isLoading: Weather.locationConfigured && (Weather.loading || (!Weather.ready && !Weather.lastError))
    readonly property bool isError: Weather.locationConfigured && !Weather.loading && !!Weather.lastError && !Weather.ready

    Component.onCompleted: Weather.reload()

    Loader {
        active: !Weather.locationConfigured
        visible: active
        anchors.fill: parent

        sourceComponent: Column {
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Set a location")
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Choose a city in Settings → Dashboard. Weather is offline until then.")
                color: Signal.palette.inkMuted
            }
        }
    }

    // ── Error state ───────────────────────────────────────────────────────────
    Loader {
        active: root.isError
        visible: active
        anchors.fill: parent

        sourceComponent: Column {
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "cloud-off"
                font.pointSize: Appearance.font.size.extraLarge * 2
                color: Signal.palette.alert
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.lastError || qsTr("Weather unavailable")
                color: Signal.palette.ink
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Check network or set a location in Control Center → Dashboard")
                color: Signal.palette.ruleStrong
                font.pointSize: Appearance.font.size.small
            }
        }
    }

    // ── Loading skeleton (shown while weather data is fetching) ───────────────
    Loader {
        active: root.isLoading
        visible: active
        anchors.fill: parent

        sourceComponent: ColumnLayout {
            id: skeleton

            anchors.fill: parent
            spacing: Appearance.spacing.smaller

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }

            // Header skeleton
            RowLayout {
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.large
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                ColumnLayout {
                    spacing: Appearance.spacing.small / 2

                    StyledRect {
                        implicitWidth: 200
                        implicitHeight: Appearance.font.size.extraLarge + 4
                        radius: Appearance.rounding.small
                        color: Signal.tPalette.raised
                    }
                    StyledRect {
                        implicitWidth: 130
                        implicitHeight: Appearance.font.size.small + 4
                        radius: Appearance.rounding.small
                        color: Signal.tPalette.raised
                    }
                }
                Item { Layout.fillWidth: true }

                // Sunrise/sunset skeleton
                Row {
                    spacing: Appearance.spacing.large
                    Repeater {
                        model: 2
                        StyledRect {
                            implicitWidth: 70
                            implicitHeight: 40
                            radius: Appearance.rounding.small
                            color: Signal.tPalette.raised
                        }
                    }
                }
            }

            // Big info row skeleton
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 90
                radius: Appearance.rounding.normal
                color: Signal.tPalette.raised
            }

            // Forecast cards skeleton
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                Layout.leftMargin: Appearance.padding.large
                Layout.rightMargin: Appearance.padding.large
                Repeater {
                    model: 5
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 100
                        radius: Appearance.rounding.normal
                        color: Signal.tPalette.raised
                    }
                }
            }
        }
    }

    // ── Real content (shown when data is ready) ───────────────────────────────

    ColumnLayout {
        id: layout
        visible: Weather.ready

        anchors.fill: parent
        spacing: Appearance.spacing.smaller

        RowLayout {
            Layout.leftMargin: Appearance.padding.large
            Layout.rightMargin: Appearance.padding.large
            Layout.fillWidth: true

            Column {
                spacing: Appearance.spacing.small / 2

                StyledText {
                    text: Weather.city || qsTr("Loading...")
                    font.pointSize: Appearance.font.size.extraLarge
                    font.weight: 600
                    color: Signal.palette.ink
                }

                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: Appearance.spacing.large

                WeatherStat {
                    icon: "sunset"
                    label: "Sunrise"
                    value: Weather.sunrise
                    colour: Signal.palette.phosphor
                }

                WeatherStat {
                    icon: "moon-stars"
                    label: "Sunset"
                    value: Weather.sunset
                    colour: Signal.palette.phosphor
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: bigInfoRow.implicitHeight + Appearance.padding.small * 2

            radius: Appearance.rounding.large * 2
            color: Signal.tPalette.panel

            RowLayout {
                id: bigInfoRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                Glyph {
                    Layout.alignment: Qt.AlignVCenter
                    name: Weather.icon
                    font.pointSize: Appearance.font.size.extraLarge * 3
                    color: Signal.palette.cue
                    animate: true
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Appearance.spacing.small

                    StyledText {
                        text: Weather.temp
                        font.pointSize: Appearance.font.size.extraLarge * 2
                        font.weight: 500
                        color: Signal.palette.signal
                    }

                    StyledText {
                        Layout.leftMargin: Appearance.padding.small
                        text: Weather.description
                        font.pointSize: Appearance.font.size.normal
                        color: Signal.palette.inkMuted
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            DetailCard {
                icon: "droplet"
                label: "Humidity"
                value: Weather.humidity + "%"
                colour: Signal.palette.cue
            }
            DetailCard {
                icon: "temperature"
                label: "Feels Like"
                value: Weather.feelsLike
                colour: Signal.palette.signal
            }
            DetailCard {
                icon: "wind"
                label: "Wind"
                value: Weather.windSpeed ? Weather.windSpeed + " km/h" : "--"
                colour: Signal.palette.phosphor
            }
        }

        // ── Hourly forecast (next 24h) ────────────────────────────────────────
        StyledText {
            Layout.topMargin: Appearance.spacing.normal
            Layout.leftMargin: Appearance.padding.normal
            visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
            text: qsTr("Hourly forecast")
            font.pointSize: Appearance.font.size.normal
            font.weight: 600
            color: Signal.palette.ink
        }

        HourlyChart {
            Layout.fillWidth: true
            visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 1
            entries: Weather.hourlyForecast ? Weather.hourlyForecast.slice(0, 24) : []
        }

        StyledText {
            Layout.topMargin: Appearance.spacing.normal
            Layout.leftMargin: Appearance.padding.normal
            visible: forecastRepeater.count > 0
            text: qsTr("7-day forecast")
            font.pointSize: Appearance.font.size.normal
            font.weight: 600
            color: Signal.palette.ink
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller
            visible: forecastRepeater.count > 0

            Repeater {
                id: forecastRepeater

                model: Weather.forecast

                StyledRect {
                    id: forecastItem

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: forecastItemColumn.implicitHeight + Appearance.padding.normal * 2

                    radius: Appearance.rounding.normal
                    color: Signal.tPalette.panel

                    ColumnLayout {
                        id: forecastItemColumn

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: forecastItem.index === 0 ? qsTr("Today") : new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 600
                            color: Signal.palette.signal
                        }

                        StyledText {
                            Layout.topMargin: -Appearance.spacing.small / 2
                            Layout.alignment: Qt.AlignHCenter
                            text: new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }

                        Glyph {
                            Layout.alignment: Qt.AlignHCenter
                            name: forecastItem.modelData.icon
                            font.pointSize: Appearance.font.size.extraLarge
                            color: Signal.palette.cue
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Config.services.useFahrenheit ? forecastItem.modelData.maxTempF + "°" + " / " + forecastItem.modelData.minTempF + "°" : forecastItem.modelData.maxTempC + "°" + " / " + forecastItem.modelData.minTempC + "°"
                            font.weight: 600
                            color: Signal.palette.phosphor
                        }
                    }
                }
            }
        }

        // Data attribution (required by the Open-Meteo and OpenStreetMap
        // licences) as a quiet footer. StyledText, not MarkdownText: Qt
        // ignores linkColor for Markdown, which rendered default-blue links.
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            Layout.leftMargin: Appearance.padding.normal
            textFormat: Text.StyledText
            text: qsTr("Weather: <a href=\"https://open-meteo.com/\">Open-Meteo</a> · Geocoding: <a href=\"https://www.openstreetmap.org/copyright\">© OpenStreetMap contributors</a>")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            linkColor: Signal.palette.inkMuted
            onLinkActivated: link => Quickshell.execDetached(["app2unit", "-O", "--", link])
        }
    }

    component DetailCard: StyledRect {
        id: detailRoot

        property string icon
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Appearance.rounding.small
        color: Signal.tPalette.panel

        Row {
            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            Glyph {
                name: detailRoot.icon
                color: detailRoot.colour
                font.pointSize: Appearance.font.size.large
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: detailRoot.label
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    horizontalAlignment: Text.AlignLeft
                }
                StyledText {
                    text: detailRoot.value
                    font.weight: 600
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    component WeatherStat: Row {
        id: weatherStat

        property string icon
        property string label
        property string value
        property color colour

        spacing: Appearance.spacing.small

        Glyph {
            name: weatherStat.icon
            font.pointSize: Appearance.font.size.extraLarge
            color: weatherStat.colour
        }

        Column {
            StyledText {
                text: weatherStat.label
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
            }
            StyledText {
                text: weatherStat.value
                font.pointSize: Appearance.font.size.small
                font.weight: 600
                color: Signal.palette.ink
            }
        }
    }
}
