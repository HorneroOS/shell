import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// System telemetry (legacy context-bar right side). options.show selects
// metrics: cpu, memory, disk, temp. Values density shows numbers; glyphs
// density shows icons whose colour and weight carry the level.
Item {
    id: root

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
            icon: "memory_alt",
            label: qsTr("Memory"),
            value: SystemUsage.memPerc * 100,
            text: `${Math.round(SystemUsage.memPerc * 100)}%`
        },
        {
            id: "disk",
            icon: "hard_drive",
            label: qsTr("Disk"),
            value: SystemUsage.storagePerc * 100,
            text: `${Math.round(SystemUsage.storagePerc * 100)}%`
        },
        {
            id: "temp",
            icon: "device_thermostat",
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

                MaterialIcon {
                    text: metric.modelData.icon
                    color: metric.critical ? Colours.palette.m3error : metric.warning ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    fill: metric.critical || metric.warning ? 1 : 0
                    font.pointSize: Appearance.font.size.normal
                }

                StyledText {
                    visible: root.density === "values" && !root.vertical
                    text: metric.modelData.text
                    color: metric.critical ? Colours.palette.m3error : Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.smaller
                    font.family: Appearance.font.family.mono
                }
            }
        }
    }
}
