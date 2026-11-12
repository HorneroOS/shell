pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property bool ready: Services.Weather.ready
    readonly property bool locationConfigured: Services.Weather.locationConfigured
    readonly property string temp: Services.Weather.temp
    readonly property string description: Services.Weather.description
    readonly property int humidity: Services.Weather.humidity
    readonly property real windSpeed: Services.Weather.windSpeed
    readonly property string sunrise: Services.Weather.sunrise
    readonly property string sunset: Services.Weather.sunset
    readonly property string lastError: Services.Weather.lastError
    readonly property var forecast: Services.Weather.forecast ? Services.Weather.forecast.map(f => Object.assign({}, f)) : []
}
