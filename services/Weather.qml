pragma Singleton

import qs.config
import qs.utils
import Hornero
import Quickshell
import QtQuick

Singleton {
    id: root

    property string city
    property string loc
    property var cc
    property list<var> forecast
    property list<var> hourlyForecast
    property string lastError: ""
    property bool loading: false

    readonly property bool locationConfigured: !!(Config.services.weatherLocation || "").trim()
    property int _requestGeneration: 0
    readonly property bool ready: locationConfigured && !!cc && forecast.length > 0
    readonly property string icon: cc ? Icons.getWeatherIcon(String(cc.weatherCode)) : "cloud_alert"
    readonly property string description: {
        if (!locationConfigured)
            return qsTr("Set a location");
        if (cc?.weatherDesc)
            return cc.weatherDesc;
        if (loading)
            return qsTr("Loading…");
        if (lastError)
            return qsTr("Weather unavailable");
        return qsTr("No weather");
    }
    readonly property string temp: {
        if (!cc)
            return loading ? "…" : "--";
        return Config.services.useFahrenheit ? `${cc.tempF}°F` : `${cc.tempC}°C`;
    }
    readonly property string feelsLike: {
        if (!cc)
            return "--";
        return Config.services.useFahrenheit ? `${cc.feelsLikeF}°F` : `${cc.feelsLikeC}°C`;
    }
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), Config.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), Config.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"

    readonly property var cachedCities: new Map()

    // Empty location is an offline state. Opening any weather view or
    // refreshing it must never infer consent to send an IP/location.
    function reload(): void {
        _requestGeneration++;
        const configLocation = (Config.services.weatherLocation || "").trim();
        lastError = "";
        cc = null;
        forecast = [];
        hourlyForecast = [];
        city = "";
        loc = "";
        loading = !!configLocation;
        if (!configLocation)
            return;

        if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
            _setLocation(configLocation, "");
            fetchCityFromCoords(configLocation);
        } else {
            fetchCoordsFromCity(configLocation);
        }
    }

    // A cleared/changed location invalidates every outstanding callback.
    // A late city lookup must not restart requests after consent is removed.
    function request(url: string, onSuccess: var, onError: var): void {
        if (!locationConfigured)
            return;
        const generation = _requestGeneration;
        const location = Config.services.weatherLocation;
        Requests.get(url, text => {
            if (generation === _requestGeneration && locationConfigured && location === Config.services.weatherLocation)
                onSuccess(text);
        }, error => {
            if (generation === _requestGeneration && locationConfigured && location === Config.services.weatherLocation)
                onError(error);
        });
    }

    function _setLocation(coords: string, cityName: string): void {
        if (cityName)
            city = cityName;
        if (loc === coords) {
            // Same coords: onLocChanged will not fire — refresh explicitly.
            fetchWeatherData();
            return;
        }
        loc = coords;
    }

    function fetchCityFromCoords(coords: string): void {
        if (cachedCities.has(coords)) {
            city = cachedCities.get(coords);
            return;
        }

        const [lat, lon] = coords.split(",");
        // Nominatim requires a UA in theory; Qt may send one. Falls back to Unknown City.
        const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=geocodejson`;
        request(url, text => {
            try {
                const geo = JSON.parse(text).features?.[0]?.properties?.geocoding;
                if (geo) {
                    const geoCity = geo.type === "city" ? geo.name : (geo.city || geo.name || geo.state);
                    city = geoCity || "Unknown City";
                    cachedCities.set(coords, city);
                } else {
                    city = "Unknown City";
                }
            } catch (e) {
                city = "Unknown City";
            }
        }, err => {
            console.warn("Weather: reverse geocode failed", err);
            city = city || "Unknown City";
        });
    }

    function fetchCoordsFromCity(cityName: string): void {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&language=en&format=json`;

        request(url, text => {
            try {
                const json = JSON.parse(text);
                if (json.results && json.results.length > 0) {
                    const result = json.results[0];
                    city = result.name;
                    _setLocation(`${result.latitude},${result.longitude}`, result.name);
                } else {
                    loading = false;
                    lastError = qsTr("Location not found");
                    console.warn("Weather: no geocoding results for", cityName);
                }
            } catch (e) {
                loading = false;
                lastError = qsTr("Location lookup failed");
            }
        }, err => {
            loading = false;
            lastError = qsTr("Location lookup failed");
            console.warn("Weather: city geocode failed", err);
        });
    }

    function fetchWeatherData(): void {
        const url = getWeatherUrl();
        if (url === "") {
            loading = false;
            return;
        }

        loading = true;
        request(url, text => {
            try {
                const json = JSON.parse(text);
                if (!json.current || !json.daily) {
                    loading = false;
                    lastError = qsTr("Invalid weather response");
                    return;
                }

                cc = {
                    weatherCode: json.current.weather_code,
                    weatherDesc: getWeatherCondition(json.current.weather_code),
                    tempC: Math.round(json.current.temperature_2m),
                    tempF: Math.round(toFahrenheit(json.current.temperature_2m)),
                    feelsLikeC: Math.round(json.current.apparent_temperature),
                    feelsLikeF: Math.round(toFahrenheit(json.current.apparent_temperature)),
                    humidity: json.current.relative_humidity_2m,
                    windSpeed: json.current.wind_speed_10m,
                    isDay: json.current.is_day,
                    sunrise: json.daily.sunrise[0],
                    sunset: json.daily.sunset[0]
                };

                const forecastList = [];
                for (let i = 0; i < json.daily.time.length; i++)
                    forecastList.push({
                        date: json.daily.time[i],
                        maxTempC: Math.round(json.daily.temperature_2m_max[i]),
                        maxTempF: Math.round(toFahrenheit(json.daily.temperature_2m_max[i])),
                        minTempC: Math.round(json.daily.temperature_2m_min[i]),
                        minTempF: Math.round(toFahrenheit(json.daily.temperature_2m_min[i])),
                        weatherCode: json.daily.weather_code[i],
                        icon: Icons.getWeatherIcon(String(json.daily.weather_code[i]))
                    });
                forecast = forecastList;

                const hourlyList = [];
                const now = new Date();
                for (let i = 0; i < json.hourly.time.length; i++) {
                    const time = new Date(json.hourly.time[i]);
                    if (time < now)
                        continue;

                    hourlyList.push({
                        timestamp: json.hourly.time[i],
                        hour: time.getHours(),
                        tempC: Math.round(json.hourly.temperature_2m[i]),
                        tempF: Math.round(toFahrenheit(json.hourly.temperature_2m[i])),
                        weatherCode: json.hourly.weather_code[i],
                        icon: Icons.getWeatherIcon(String(json.hourly.weather_code[i]))
                    });
                }
                hourlyForecast = hourlyList;
                lastError = "";
                loading = false;
            } catch (e) {
                loading = false;
                lastError = qsTr("Weather parse failed");
                console.warn("Weather: parse failed", e);
            }
        }, err => {
            loading = false;
            lastError = qsTr("Weather request failed");
            console.warn("Weather: forecast request failed", err);
        });
    }

    function toFahrenheit(celcius: real): real {
        return celcius * 9 / 5 + 32;
    }

    function getWeatherUrl(): string {
        if (!loc || loc.indexOf(",") === -1)
            return "";

        const [lat, lon] = loc.split(",");
        const baseUrl = "https://api.open-meteo.com/v1/forecast";
        const params = ["latitude=" + lat, "longitude=" + lon, "hourly=weather_code,temperature_2m", "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset", "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m", "timezone=auto", "forecast_days=7"];

        return baseUrl + "?" + params.join("&");
    }

    function getWeatherCondition(code: var): string {
        const key = String(code);
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[key] || "Unknown";
    }

    onLocChanged: fetchWeatherData()

    Connections {
        target: Config.services
        function onWeatherLocationChanged(): void {
            root.reload();
        }
    }

    Timer {
        interval: 3600000
        running: root.locationConfigured
        repeat: true
        onTriggered: root.reload()
    }

    Component.onCompleted: reload()
}
