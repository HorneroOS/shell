import Quickshell.Io
import QtQuick

JsonObject {
    property string weatherLocation: "" // City or lat,long. Empty keeps weather offline; no IP detection.
    property bool useFahrenheit: false
    property bool useFahrenheitPerformance: false
    property bool useTwelveHourClock: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().includes("a")
    property string gpuType: ""
    property int visualiserBars: 45
    property real audioIncrement: 0.1
    property real brightnessIncrement: 0.1
    property real maxVolume: 1.0
    property bool smartScheme: true
    property string defaultPlayer: "Spotify"
    property list<var> playerAliases: [
        {
            "from": "com.github.th_ch.youtube_music",
            "to": "YT Music"
        }
    ]
}
