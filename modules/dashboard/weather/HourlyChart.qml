pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Hourly temperature chart for the dashboard Weather tab: a smooth curve
// with a fading fill, a dot and value per hour, and the hour and weather
// icon underneath; scrolls horizontally through the next 24 hours.
//
// Design inspired by ItsXyzzy/Caelestia-Hourly-Weather (GPL-3.0,
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
            const x0 = root.xAt(i - 1);
            const y0 = root.yAt(root.temps[i - 1]);
            const x1 = root.xAt(i);
            const y1 = root.yAt(root.temps[i]);
            const cx = (x0 + x1) / 2;
            d += ` C ${cx} ${y0}, ${cx} ${y1}, ${x1} ${y1}`;
        }
        return d;
    }

    radius: Appearance.rounding.large
    color: Colours.tPalette.m3surfaceContainer
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
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: 0
                        y2: root.chartH

                        GradientStop {
                            position: 0
                            color: Qt.alpha(Colours.palette.m3primary, 0.26)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Colours.palette.m3primary, 0)
                        }
                    }

                    PathSvg {
                        path: root.curvePath ? `${root.curvePath} L ${root.xAt(root.temps.length - 1)} ${root.chartH} L ${root.xAt(0)} ${root.chartH} Z` : ""
                    }
                }
            }

            Shape {
                width: content.width
                height: root.chartH
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 3
                    strokeColor: Colours.palette.m3primary
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

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
                        width: point.emphasised ? 10 : 7
                        height: width
                        radius: width / 2
                        color: point.index === 0 ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
                        border.width: 2
                        border.color: Colours.palette.m3primary
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.yAt(point.temp) - height - 8
                        text: Math.round(point.temp) + "°"
                        font.pointSize: Appearance.font.size.smaller
                        font.weight: point.emphasised ? 700 : 500
                        color: point.emphasised ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
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
                            color: cell.index === 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.icon ?? "cloud"
                            font.pointSize: Appearance.font.size.larger
                            color: Colours.palette.m3secondary
                        }
                    }
                }
            }
        }
    }
}
