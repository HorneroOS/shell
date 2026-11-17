import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// System telemetry indicator. options.show selects
// metrics: cpu, memory, disk, temp. Values density shows numbers; glyphs
// density shows icons whose colour and weight carry the level.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property string density: "values"
    property var options: ({})
    // See QuickActions: options arrays need toArray(), not Array.isArray.
    readonly property var show: Config.bar.toArray(options.show ?? ["cpu", "memory", "disk", "temp"])
    readonly property var metrics: [
        {
            id: "cpu",
            icon: "memory",
            label: qsTr("CPU"),
            value: SystemUsage.cpuPerc * 100,
            text: `${Math.round(SystemUsage.cpuPerc * 100)}%`
        },
        {
            id: "memory",
            icon: "cpu-2",
            label: qsTr("Memory"),
            value: SystemUsage.memPerc * 100,
            text: `${Math.round(SystemUsage.memPerc * 100)}%`
        },
        {
            id: "disk",
            icon: "server",
            label: qsTr("Disk"),
            value: SystemUsage.storagePerc * 100,
            text: `${Math.round(SystemUsage.storagePerc * 100)}%`
        },
        {
            id: "temp",
            icon: "temperature",
            label: qsTr("Temperature"),
            value: SystemUsage.cpuTemp,
            text: `${Math.round(SystemUsage.cpuTemp)}°`
        }
    ].filter(m => show.includes(m.id))

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
        columnSpacing: Appearance.spacing.normal

        Repeater {
            model: root.metrics

            RowLayout {
                id: metric

                required property var modelData
                // Warning / critical thresholds; temperature in °C.
                readonly property bool critical: modelData.id === "temp" ? modelData.value >= 85 : modelData.value >= 90
                readonly property bool warning: !critical && (modelData.id === "temp" ? modelData.value >= 70 : modelData.value >= 75)

                spacing: Appearance.spacing.smaller / 2
                Accessible.role: Accessible.StaticText
                Accessible.name: `${modelData.label} ${modelData.text}`

                Glyph {
                    name: metric.modelData.icon
                    color: metric.critical ? root.tone.alert : metric.warning ? Signal.palette.phosphor : root.tone.inkMuted
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    visible: root.density === "values" && !root.vertical
                    text: metric.modelData.text
                    color: metric.critical ? root.tone.alert : root.tone.ink
                    font.pointSize: Appearance.font.size.smaller
                    font.family: Appearance.font.family.mono
                }
            }
        }
    }
}
