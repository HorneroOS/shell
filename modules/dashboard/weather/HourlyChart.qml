pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Hourly temperature chart for the dashboard Weather tab (Signal Bezel):
// a `sunken` well holding one straight 1.5 px trace between the forecast's
// own hourly values — no smoothing, no fill — with a square marker and
// value per hour, and the hour and weather glyph underneath; scrolls
// horizontally through the next 24 hours.
//
// Originally inspired by ItsXyzzy/Caelestia-Hourly-Weather (GPL-3.0,
// https://github.com/ItsXyzzy/Caelestia-Hourly-Weather): cubic segments
// with horizontal handles and a gradient under the curve. Hornero
// implementation, reading the same Weather.hourlyForecast entries.
StyledRect {
    id: root

    required property var entries

    readonly property bool fahrenheit: Config.services.useFahrenheit
    readonly property real colW: 60
    readonly property real chartH: 112
    readonly property real padTop: 28
    readonly property real padBottom: 14
    readonly property var temps: root.entries.map(e => root.fahrenheit ? (e.tempF ?? 0) : (e.tempC ?? 0))
    readonly property real lo: root.temps.length > 0 ? Math.min(...root.temps) : 0
    readonly property real hi: root.temps.length > 0 ? Math.max(...root.temps) : 1

    function xAt(i: int): real {
        return root.colW * i + root.colW / 2;
    }

    function yAt(t: real): real {
        const span = Math.max(1, root.hi - root.lo);
        return root.padTop + (1 - (t - root.lo) / span) * (root.chartH - root.padTop - root.padBottom);
    }

    function hourLabel(entry: var, index: int): string {
        if (index === 0)
            return qsTr("Now");
        const h = entry.hour ?? 0;
        if (Config.services.useTwelveHourClock)
            return h === 0 ? "12am" : h < 12 ? h + "am" : h === 12 ? "12pm" : (h - 12) + "pm";
        return String(h).padStart(2, "0") + ":00";
    }

    readonly property string curvePath: {
        const n = root.temps.length;
        if (n < 2)
            return "";
        let d = `M ${root.xAt(0)} ${root.yAt(root.temps[0])}`;
        for (let i = 1; i < n; i++) {
            const x1 = root.xAt(i);
            const y1 = root.yAt(root.temps[i]);
            d += ` L ${x1} ${y1}`;
        }
        return d;
    }

    radius: Appearance.rounding.small
    color: Signal.palette.sunken
    border.width: 1
    border.color: Signal.palette.rule
    implicitHeight: content.height + Appearance.padding.normal * 2

    Accessible.role: Accessible.Chart
    Accessible.name: qsTr("Hourly temperature forecast")

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        contentWidth: content.width
        contentHeight: content.height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: content

            width: root.entries.length * root.colW
            height: root.chartH + labels.implicitHeight

            Shape {
                width: content.width
                height: root.chartH
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: Signal.palette.signal
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.MiterJoin

                    PathSvg {
                        path: root.curvePath
                    }
                }
            }

            Repeater {
                model: root.temps.length

                delegate: Item {
                    id: point

                    required property int index
                    readonly property real temp: root.temps[point.index]
                    readonly property bool emphasised: point.index === 0 || point.temp === root.hi || point.temp === root.lo

                    x: root.xAt(point.index) - root.colW / 2
                    width: root.colW
                    height: root.chartH

                    Rectangle {
                        x: (parent.width - width) / 2
                        y: root.yAt(point.temp) - height / 2
                        width: point.emphasised ? 8 : 6
                        height: width
                        radius: 1
                        color: point.index === 0 ? Signal.palette.signal : Signal.palette.sunken
                        border.width: 1
                        border.color: Signal.palette.signal
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.yAt(point.temp) - height - 8
                        text: Math.round(point.temp) + "°"
                        tabular: true
                        font.pointSize: Appearance.font.size.smaller
                        font.weight: point.emphasised ? 700 : 500
                        color: point.emphasised ? Signal.palette.ink : Signal.palette.inkMuted
                    }
                }
            }

            Row {
                id: labels

                y: root.chartH

                Repeater {
                    model: root.entries

                    delegate: Column {
                        id: cell

                        required property var modelData
                        required property int index

                        width: root.colW
                        spacing: Appearance.spacing.small / 2

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.hourLabel(cell.modelData, cell.index)
                            font.pointSize: Appearance.font.size.smaller
                            font.weight: cell.index === 0 ? 700 : 400
                            color: cell.index === 0 ? Signal.palette.signal : Signal.palette.inkMuted
                        }

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: cell.modelData.icon ?? "cloud"
                            font.pointSize: Appearance.font.size.larger
                            color: Signal.palette.cue
                        }
                    }
                }
            }
        }
    }
}
