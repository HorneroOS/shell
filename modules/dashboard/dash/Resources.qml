pragma ComponentBehavior: Bound

import qs.components
import qs.components.misc
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// Resources module (Signal Bezel §6): the CPU oscilloscope, one segmented
// meter per channel with its value beside it, and used/total partitions
// with dimension lines for memory and storage. Everything is bound to
// SystemUsage; a source that reports nothing shows an em dash and lit-off
// segments. The scope plots one real sample per telemetry tick.
ColumnLayout {
    id: root

    readonly property int windowSeconds: Math.round(scopeBuffer.length * Experience.telemetryIntervalMs / 1000)
    readonly property string windowLabel: qsTr("%1 s window").arg(windowSeconds)
    readonly property real storageUsed: SystemUsage.disks.reduce((acc, d) => acc + d.used, 0)
    readonly property real storageTotal: SystemUsage.disks.reduce((acc, d) => acc + d.total, 0)

    function fmt(kib: real): string {
        const f = SystemUsage.formatKib(kib);
        return `${f.value.toFixed(f.value >= 100 ? 0 : 1)} ${f.unit}`;
    }

    spacing: Appearance.spacing.normal

    Ref {
        service: SystemUsage
    }

    Instruments.TraceBuffer {
        id: scopeBuffer

        length: 60
    }

    Connections {
        target: SystemUsage

        function onSampled(): void {
            scopeBuffer.sample(SystemUsage.cpuPerc);
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Instruments.Eyebrow {
                label: qsTr("CPU · 25 %/div")
            }

            Instruments.ScopeTrace {
                Layout.fillWidth: true
                Layout.preferredHeight: 96

                samples: scopeBuffer.samples
                persistence: scopeBuffer.persistence
                window: scopeBuffer.length
                maxValue: 1
                glow: Experience.glow
                scanlines: Experience.scanlines

                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("CPU load trace, %1 seconds, now %2%").arg(root.windowSeconds).arg(Math.round(SystemUsage.cpuPerc * 100))
            }
        }

        Instruments.Readout {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 112

            label: qsTr("CPU temp")
            value: SystemUsage.cpuTempAvailable ? String(Math.round(Config.services.useFahrenheitPerformance ? SystemUsage.cpuTemp * 1.8 + 32 : SystemUsage.cpuTemp)) : ""
            unit: Config.services.useFahrenheitPerformance ? "°F" : "°C"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Resource {
            label: qsTr("CPU")
            value: SystemUsage.cpuPerc
        }

        Resource {
            label: qsTr("Memory")
            value: SystemUsage.memPerc
            available: SystemUsage.memTotal > 0
        }

        Resource {
            label: qsTr("Storage")
            value: SystemUsage.storagePerc
            available: root.storageTotal > 0
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Instruments.Eyebrow {
                label: qsTr("Memory \u00b7 %1").arg(SystemUsage.memTotal > 0 ? root.fmt(SystemUsage.memTotal) : "\u2014")
            }

            Instruments.Partition {
                Layout.fillWidth: true

                total: SystemUsage.memTotal
                used: SystemUsage.memUsed
                usedLabel: qsTr("%1 used").arg(root.fmt(SystemUsage.memUsed))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Instruments.Eyebrow {
                label: qsTr("Storage \u00b7 %1").arg(root.storageTotal > 0 ? root.fmt(root.storageTotal) : "\u2014")
            }

            Instruments.Partition {
                Layout.fillWidth: true

                total: root.storageTotal
                used: root.storageUsed
                usedLabel: qsTr("%1 used").arg(root.fmt(root.storageUsed))
            }
        }
    }

    component Resource: RowLayout {
        id: res

        required property string label
        required property real value
        property bool available: true

        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Accessible.role: Accessible.ProgressBar
        Accessible.name: res.available ? qsTr("%1 %2%").arg(res.label).arg(Math.round(res.value * 100)) : qsTr("%1 unavailable").arg(res.label)

        Instruments.Eyebrow {
            Layout.preferredWidth: 80

            label: res.label
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 10

            Instruments.SegmentMeter {
                // Fit whole 3 px segments with 2 px gaps to the row.
                count: Math.max(8, Math.floor((parent.width + 2) / 5))
                segmentWidth: 3
                segmentLength: 10
                gap: 2
                value: res.value
                available: res.available
            }
        }

        StyledText {
            Layout.preferredWidth: 40

            horizontalAlignment: Text.AlignRight
            mono: true
            text: res.available ? Math.round(res.value * 100) + "%" : "—"
            color: res.available ? Signal.palette.ink : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            font.features: {
                "tnum": 1
            }
        }
    }
}
