import "weather"
import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Quickshell
import QtQuick
import QtQuick.Layouts

// Weather tab (Signal Bezel): current conditions as readouts, the next 24
// hours as a chart, then a seven-day row of fixed cells. Every state is a
// plain statement — no location, loading, error — never a placeholder
// forecast and no skeleton pulse.
Item {
    id: root

    implicitWidth: 968
    implicitHeight: Weather.ready ? layout.implicitHeight : notice.implicitHeight

    readonly property bool isLoading: Weather.locationConfigured && (Weather.loading || (!Weather.ready && !Weather.lastError))
    readonly property bool isError: Weather.locationConfigured && !Weather.loading && !!Weather.lastError && !Weather.ready

    Component.onCompleted: Weather.reload()

    // Not-ready states share one frame.
    Instruments.Frame {
        id: notice

        anchors.left: parent.left
        anchors.right: parent.right
        visible: !Weather.ready
        implicitHeight: headerHeight + noticeBody.implicitHeight + 16
        channel: "01"
        title: qsTr("Weather")
        context: root.isLoading ? qsTr("loading") : root.isError ? qsTr("error") : qsTr("no location")
        contextColor: root.isError ? Signal.palette.alert : Signal.palette.inkMuted

        RowLayout {
            id: noticeBody

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.large

            Glyph {
                name: root.isError ? "cloud-off" : "cloud-exclamation"
                color: root.isError ? Signal.palette.alert : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.display * 0.8
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    text: root.isLoading ? qsTr("Loading forecast") : root.isError ? (Weather.lastError || qsTr("Weather unavailable")) : qsTr("Set a location")
                    font.pointSize: Appearance.font.size.large
                }

                StyledText {
                    Layout.fillWidth: true

                    text: root.isLoading ? qsTr("Waiting for the weather service.") : root.isError ? qsTr("Check the network connection, or choose another city in Settings, Dashboard.") : qsTr("Choose a city in Settings, Dashboard. Weather is off until then.")
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        visible: Weather.ready
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Instruments.Frame {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                implicitHeight: headerHeight + nowBody.implicitHeight + 16
                channel: "01"
                title: qsTr("Now")
                context: Weather.city

                RowLayout {
                    id: nowBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.large

                    Glyph {
                        name: Weather.icon
                        color: Signal.palette.cue
                        font.pointSize: Appearance.font.size.display
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: Weather.temp
                            font.family: Appearance.font.family.display
                            font.weight: Font.Medium
                            font.pointSize: Appearance.font.size.display * 0.85
                        }

                        StyledText {
                            Layout.fillWidth: true

                            text: Weather.description
                            color: Signal.palette.inkMuted
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Instruments.Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: headerHeight + condBody.implicitHeight + 16
                channel: "02"
                title: qsTr("Conditions")
                context: new Date().toLocaleDateString(Qt.locale(), "ddd d MMM")

                GridLayout {
                    id: condBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    columns: 3
                    columnSpacing: Appearance.spacing.normal
                    rowSpacing: Appearance.spacing.normal

                    Instruments.Readout {
                        Layout.fillWidth: true
                        label: qsTr("Humidity")
                        value: String(Weather.humidity)
                        unit: "%"
                    }

                    Instruments.Readout {
                        Layout.fillWidth: true
                        label: qsTr("Feels like")
                        value: Weather.feelsLike
                    }

                    Instruments.Readout {
                        Layout.fillWidth: true
                        label: qsTr("Wind")
                        value: Weather.windSpeed ? String(Weather.windSpeed) : ""
                        unit: "km/h"
                    }

                    Instruments.Readout {
                        Layout.fillWidth: true
                        label: qsTr("Sunrise")
                        value: Weather.sunrise
                    }

                    Instruments.Readout {
                        Layout.fillWidth: true
                        label: qsTr("Sunset")
                        value: Weather.sunset
                    }
                }
            }
        }

        Instruments.Frame {
            Layout.fillWidth: true
            visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 1
            implicitHeight: headerHeight + hourly.implicitHeight + 16
            channel: "03"
            title: qsTr("Hourly forecast")
            context: qsTr("next 24 h")

            HourlyChart {
                id: hourly

                anchors.left: parent.left
                anchors.right: parent.right
                entries: Weather.hourlyForecast ? Weather.hourlyForecast.slice(0, 24) : []
            }
        }

        Instruments.Frame {
            Layout.fillWidth: true
            visible: forecastRepeater.count > 0
            implicitHeight: headerHeight + forecastRow.implicitHeight + 16
            channel: "04"
            title: qsTr("7-day forecast")

            RowLayout {
                id: forecastRow

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Appearance.spacing.small

                Repeater {
                    id: forecastRepeater

                    model: Weather.forecast

                    Rectangle {
                        id: forecastItem

                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: forecastItemColumn.implicitHeight + Appearance.padding.normal * 2

                        radius: Appearance.rounding.small
                        color: forecastItem.index === 0 ? Signal.palette.raised : "transparent"
                        border.width: 1
                        border.color: Signal.palette.rule

                        // Today is marked by fill and the on-air bar, not
                        // by colour alone.
                        OnAirBar {
                            edge: "top"
                            active: forecastItem.index === 0
                        }

                        ColumnLayout {
                            id: forecastItemColumn

                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                mono: true
                                text: forecastItem.index === 0 ? qsTr("Today") : new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                                font.pointSize: Appearance.font.size.small
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: Appearance.font.size.small * 0.08
                                color: forecastItem.index === 0 ? Signal.palette.ink : Signal.palette.inkMuted
                            }

                            StyledText {
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
                                mono: true
                                text: Config.services.useFahrenheit ? forecastItem.modelData.maxTempF + "° / " + forecastItem.modelData.minTempF + "°" : forecastItem.modelData.maxTempC + "° / " + forecastItem.modelData.minTempC + "°"
                                font.pointSize: Appearance.font.size.small
                            }
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
            textFormat: Text.StyledText
            text: qsTr("Weather: <a href=\"https://open-meteo.com/\">Open-Meteo</a> · Geocoding: <a href=\"https://www.openstreetmap.org/copyright\">© OpenStreetMap contributors</a>")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            linkColor: Signal.palette.inkMuted
            onLinkActivated: link => Quickshell.execDetached(["app2unit", "-O", "--", link])
        }
    }
}
