import qs.components
import qs.components.misc
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// System telemetry (signal-visual-language §4.1, §6): per metric an eyebrow
// label, an 8-segment meter and the tabular Plex Mono value. Everything is
// bound to SystemUsage; a metric without a source (no CPU sensor, no disk
// reading) is left out instead of showing a made-up number. options.show
// selects metrics: cpu, memory, disk, temp. Density `icons` keeps glyphs
// whose colour carries the level; compact bars drop the meters but keep
// label and value.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property bool compact: false
    property string density: "values"
    property var options: ({})
    // See QuickActions: options arrays need toArray(), not Array.isArray.
    readonly property var show: Config.bar.toArray(options.show ?? ["cpu", "memory", "disk", "temp"])
    // Meters: 80 % of the scale marks the high zone for temperature, 85 %
    // for levels (§6.2). Temperature is read against a 0..100 degC scale.
    readonly property var metrics: [
        {
            id: "cpu",
            icon: "memory",
            label: qsTr("CPU"),
            full: qsTr("CPU"),
            available: true,
            fraction: SystemUsage.cpuPerc,
            warn: 0.75,
            crit: 0.9,
            text: `${Math.round(SystemUsage.cpuPerc * 100)}%`
        },
        {
            id: "memory",
            icon: "cpu-2",
            label: qsTr("MEM"),
            full: qsTr("Memory"),
            available: SystemUsage.memTotal > 0,
            fraction: SystemUsage.memPerc,
            warn: 0.75,
            crit: 0.9,
            text: `${Math.round(SystemUsage.memPerc * 100)}%`
        },
        {
            id: "disk",
            icon: "server",
            label: qsTr("DSK"),
            full: qsTr("Disk"),
            available: SystemUsage.disks.length > 0,
            fraction: SystemUsage.storagePerc,
            warn: 0.75,
            crit: 0.9,
            text: `${Math.round(SystemUsage.storagePerc * 100)}%`
        },
        {
            id: "temp",
            icon: "temperature",
            label: qsTr("TMP"),
            full: qsTr("Temperature"),
            available: SystemUsage.cpuTempAvailable,
            fraction: Math.max(0, Math.min(1, SystemUsage.cpuTemp / 100)),
            warn: 0.7,
            crit: 0.85,
            text: `${Math.round(SystemUsage.cpuTemp)}°`
        }
    ].filter(m => show.includes(m.id) && m.available)

    readonly property bool showMeters: density !== "icons" && !vertical && !compact
    readonly property bool showText: density !== "icons" && !vertical

    // Nothing readable, nothing drawn: the bar drops the whole segment.
    readonly property bool available: metrics.length > 0

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Poll only while a Resources component is on screen.
    Ref {
        service: SystemUsage
    }

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Appearance.spacing.small
        columnSpacing: Appearance.spacing.larger

        Repeater {
            model: root.metrics

            RowLayout {
                id: metric

                required property var modelData
                readonly property bool critical: modelData.fraction >= modelData.crit
                readonly property bool warning: !critical && modelData.fraction >= modelData.warn

                spacing: Appearance.spacing.smaller
                Accessible.role: Accessible.StaticText
                Accessible.name: `${modelData.full} ${modelData.text}`

                Glyph {
                    visible: !root.showText
                    name: metric.modelData.icon
                    color: metric.critical ? root.tone.alert : metric.warning ? root.tone.signal : root.tone.inkMuted
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    visible: root.showText
                    mono: true
                    text: metric.modelData.label
                    color: root.tone.inkMuted
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.88
                }

                Instruments.SegmentMeter {
                    visible: root.showMeters
                    Layout.alignment: Qt.AlignVCenter
                    count: 8
                    segmentWidth: 3
                    segmentLength: 10
                    gap: 2
                    value: metric.modelData.fraction
                    threshold: metric.modelData.warn
                    critical: metric.modelData.crit
                    onColor: root.tone.ink
                    offColor: root.tone.active ? Qt.alpha(root.tone.ink, root.tone.offAlpha) : Signal.palette.rule
                }

                StyledText {
                    id: valueText

                    visible: root.showText
                    Layout.preferredWidth: valueMetrics.width
                    horizontalAlignment: Text.AlignRight
                    mono: true
                    text: metric.modelData.text
                    color: metric.critical ? root.tone.alert : root.tone.ink
                    font.pixelSize: 12
                    font.features: {
                        "tnum": 1
                    }

                    // Fixed width ("100%") so the strip does not jitter.
                    TextMetrics {
                        id: valueMetrics

                        text: "100%"
                        font.family: Appearance.font.family.mono
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
