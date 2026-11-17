pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.components
import qs.components.misc
import qs.config
import qs.services
import qs.modules.instruments as Instruments

// Performance tab (Signal Bezel): instruments, not gauges. A CPU
// oscilloscope with per-core columns, a GPU trace, used/total partitions
// with dimension lines for memory and every disk, network traces and a
// battery meter. Each reads SystemUsage / NetworkUsage / UPower; a sensor
// that reports nothing shows an em dash, never a placeholder number.
Item {
    id: root

    readonly property bool anyCpu: Config.dashboard.performance.showCpu
    readonly property bool anyGpu: Config.dashboard.performance.showGpu && SystemUsage.gpuType !== "NONE"
    readonly property bool anyMem: Config.dashboard.performance.showMemory
    readonly property bool anyStorage: Config.dashboard.performance.showStorage
    readonly property bool anyNet: Config.dashboard.performance.showNetwork
    readonly property bool anyBattery: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
    readonly property bool hasLeft: anyCpu || anyGpu
    readonly property bool hasRight: anyMem || anyStorage || anyNet || anyBattery
    readonly property int windowSeconds: Math.round(cpuBuffer.length * Experience.telemetryIntervalMs / 1000)

    function displayTemp(temp: real): string {
        return String(Math.round(Config.services.useFahrenheitPerformance ? temp * 1.8 + 32 : temp));
    }

    function fmtKib(kib: real): string {
        const f = SystemUsage.formatKib(kib);
        return `${f.value.toFixed(f.value >= 100 ? 0 : 1)} ${f.unit}`;
    }

    function rate(bytes: real): string {
        const f = NetworkUsage.formatBytes(bytes ?? 0);
        return f ? `${f.value.toFixed(1)} ${f.unit}` : "—";
    }

    implicitWidth: 968
    implicitHeight: (hasLeft || hasRight) ? content.implicitHeight : placeholder.implicitHeight

    Ref {
        service: SystemUsage
    }

    Ref {
        service: NetworkUsage
    }

    Instruments.TraceBuffer {
        id: cpuBuffer

        length: 60
    }

    Instruments.TraceBuffer {
        id: gpuBuffer

        length: 60
    }

    Connections {
        target: SystemUsage

        function onSampled(): void {
            cpuBuffer.sample(SystemUsage.cpuPerc);
            if (root.anyGpu)
                gpuBuffer.sample(SystemUsage.gpuPerc);
        }
    }

    Instruments.Frame {
        id: placeholder

        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.hasLeft && !root.hasRight
        implicitWidth: 420
        implicitHeight: 132
        title: qsTr("Performance")

        ColumnLayout {
            anchors.fill: parent
            spacing: Appearance.spacing.small

            StyledText {
                text: qsTr("No instruments enabled")
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true

                text: qsTr("Turn instruments on under Settings, Dashboard.")
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.hasLeft || root.hasRight
        spacing: Appearance.spacing.small

        ColumnLayout {
            Layout.minimumWidth: 560
            Layout.preferredWidth: 560
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignTop
            visible: root.hasLeft
            spacing: Appearance.spacing.small

            // CPU
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyCpu
                implicitHeight: headerHeight + cpuBody.implicitHeight + 16
                channel: "01"
                title: SystemUsage.cpuName ? qsTr("CPU · %1").arg(SystemUsage.cpuName) : qsTr("CPU")
                context: qsTr("%1 s window").arg(root.windowSeconds)

                ColumnLayout {
                    id: cpuBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Instruments.Eyebrow {
                                label: qsTr("Load · 25 %/div")
                            }

                            Instruments.ScopeTrace {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120

                                samples: cpuBuffer.samples
                                persistence: cpuBuffer.persistence
                                window: cpuBuffer.length
                                glow: Experience.glow
                                scanlines: Experience.scanlines

                                Accessible.role: Accessible.StaticText
                                Accessible.name: qsTr("CPU load trace, %1 seconds, now %2%").arg(root.windowSeconds).arg(Math.round(SystemUsage.cpuPerc * 100))
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 120
                            spacing: Appearance.spacing.small

                            Instruments.Readout {
                                Layout.fillWidth: true

                                label: qsTr("Usage")
                                value: String(Math.round(SystemUsage.cpuPerc * 100))
                                unit: "%"
                            }

                            Instruments.Readout {
                                Layout.fillWidth: true

                                label: qsTr("Temp")
                                value: SystemUsage.cpuTempAvailable ? root.displayTemp(SystemUsage.cpuTemp) : ""
                                unit: Config.services.useFahrenheitPerformance ? "°F" : "°C"
                            }
                        }
                    }

                    // One vertical meter per core, in /proc/stat order.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: SystemUsage.cpuCores.length > 0
                        spacing: 6

                        Instruments.Eyebrow {
                            label: qsTr("Cores · %1").arg(SystemUsage.cpuCores.length)
                        }

                        Row {
                            spacing: 6

                            Repeater {
                                model: SystemUsage.cpuCores

                                Column {
                                    id: core

                                    required property real modelData
                                    required property int index

                                    spacing: 4

                                    Accessible.role: Accessible.ProgressBar
                                    Accessible.name: qsTr("Core %1 %2%").arg(core.index).arg(Math.round(core.modelData * 100))

                                    Instruments.SegmentMeter {
                                        vertical: true
                                        count: 12
                                        segmentWidth: 3
                                        segmentLength: 14
                                        gap: 2
                                        value: core.modelData
                                    }

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        mono: true
                                        text: core.index
                                        color: Signal.palette.inkMuted
                                        font.pointSize: Appearance.font.size.small
                                        Accessible.ignored: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // GPU
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyGpu
                implicitHeight: headerHeight + gpuBody.implicitHeight + 16
                channel: "02"
                title: SystemUsage.gpuName ? qsTr("GPU · %1").arg(SystemUsage.gpuName) : qsTr("GPU")
                context: qsTr("%1 s window").arg(root.windowSeconds)

                RowLayout {
                    id: gpuBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Instruments.Eyebrow {
                            label: qsTr("Load · 25 %/div")
                        }

                        Instruments.ScopeTrace {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80

                            samples: gpuBuffer.samples
                            persistence: gpuBuffer.persistence
                            window: gpuBuffer.length
                            traceColor: Signal.palette.cue
                            scanlines: Experience.scanlines

                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("GPU load trace, %1 seconds, now %2%").arg(root.windowSeconds).arg(Math.round(SystemUsage.gpuPerc * 100))
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.minimumWidth: 120
                        Layout.preferredWidth: 120
                        Layout.maximumWidth: 120
                        spacing: Appearance.spacing.small

                        Instruments.Readout {
                            Layout.fillWidth: true

                            label: qsTr("Usage")
                            value: String(Math.round(SystemUsage.gpuPerc * 100))
                            unit: "%"
                        }

                        Instruments.Readout {
                            Layout.fillWidth: true

                            label: qsTr("Temp")
                            value: SystemUsage.gpuTempAvailable ? root.displayTemp(SystemUsage.gpuTemp) : ""
                            unit: Config.services.useFahrenheitPerformance ? "°F" : "°C"
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            visible: root.hasRight
            spacing: Appearance.spacing.small

            // Memory
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyMem
                implicitHeight: headerHeight + memBody.implicitHeight + 16
                channel: "03"
                title: qsTr("Memory")
                context: SystemUsage.memTotal > 0 ? root.fmtKib(SystemUsage.memTotal) : "—"

                ColumnLayout {
                    id: memBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.small

                    Accessible.role: Accessible.ProgressBar
                    Accessible.name: qsTr("Memory %1%").arg(Math.round(SystemUsage.memPerc * 100))

                    Instruments.Partition {
                        Layout.fillWidth: true

                        total: SystemUsage.memTotal
                        used: SystemUsage.memUsed
                        usedLabel: qsTr("%1 used").arg(root.fmtKib(SystemUsage.memUsed))
                    }

                    StyledText {
                        mono: true
                        text: SystemUsage.memTotal > 0 ? qsTr("%1 % in use").arg(Math.round(SystemUsage.memPerc * 100)) : "—"
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }

            // Storage
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyStorage
                implicitHeight: headerHeight + diskBody.implicitHeight + 16
                channel: "04"
                title: qsTr("Storage")
                context: SystemUsage.disks.length === 1 ? qsTr("1 disk") : qsTr("%1 disks").arg(SystemUsage.disks.length)

                ColumnLayout {
                    id: diskBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.normal

                    StyledText {
                        visible: SystemUsage.disks.length === 0
                        text: qsTr("No mounted disks reported")
                        color: Signal.palette.inkMuted
                    }

                    Repeater {
                        model: SystemUsage.disks

                        ColumnLayout {
                            id: disk

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            Accessible.role: Accessible.ProgressBar
                            Accessible.name: qsTr("%1 %2%").arg(disk.modelData.mount).arg(Math.round(disk.modelData.perc * 100))

                            Instruments.Eyebrow {
                                Layout.fillWidth: true

                                label: `${disk.modelData.mount} · ${root.fmtKib(disk.modelData.total)}`
                            }

                            Instruments.Partition {
                                Layout.fillWidth: true

                                total: disk.modelData.total
                                used: disk.modelData.used
                                usedLabel: qsTr("%1 used").arg(root.fmtKib(disk.modelData.used))
                            }
                        }
                    }
                }
            }

            // Network
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyNet
                implicitHeight: headerHeight + netBody.implicitHeight + 16
                channel: "05"
                title: qsTr("Network")
                context: qsTr("%1 samples").arg(NetworkUsage.historyLength)

                ColumnLayout {
                    id: netBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.normal

                    Channel {
                        label: qsTr("Down")
                        history: NetworkUsage.downloadHistory
                        speed: NetworkUsage.downloadSpeed
                    }

                    Channel {
                        label: qsTr("Up")
                        history: NetworkUsage.uploadHistory
                        speed: NetworkUsage.uploadSpeed
                    }
                }
            }

            // Battery
            Instruments.Frame {
                Layout.fillWidth: true

                visible: root.anyBattery
                implicitHeight: headerHeight + batteryBody.implicitHeight + 16
                channel: "06"
                title: qsTr("Battery")
                context: UPower.displayDevice.state === UPowerDeviceState.Charging ? qsTr("charging") : UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? qsTr("full") : ""
                contextColor: UPower.displayDevice.state === UPowerDeviceState.Charging ? Signal.palette.phosphor : Signal.palette.inkMuted

                RowLayout {
                    id: batteryBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Appearance.spacing.normal

                    Accessible.role: Accessible.ProgressBar
                    Accessible.name: qsTr("Battery %1%").arg(Math.round(UPower.displayDevice.percentage * 100))

                    Item {
                        id: batteryBox

                        Layout.fillWidth: true
                        implicitHeight: 12

                        Instruments.SegmentMeter {
                            count: Math.max(8, Math.floor((batteryBox.width + 2) / 5))
                            segmentWidth: 3
                            segmentLength: 12
                            gap: 2
                            value: UPower.displayDevice.percentage
                            // Low charge is the only state worth amber.
                            onColor: UPower.displayDevice.percentage < 0.2 ? Signal.palette.signal : Signal.palette.ink
                        }
                    }

                    StyledText {
                        Layout.preferredWidth: 44

                        horizontalAlignment: Text.AlignRight
                        mono: true
                        text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }
        }
    }

    // One network direction: eyebrow + current rate, trace beneath. The
    // trace autoscales to its own peak (floor 1 KiB/s) so quiet links stay
    // legible; the scale is stated in the eyebrow.
    component Channel: ColumnLayout {
        id: ch

        required property string label
        required property var history
        required property real speed
        readonly property real peak: Math.max(1024, ...ch.history)

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Instruments.Eyebrow {
                label: ch.label
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                mono: true
                text: root.rate(ch.speed)
                font.pointSize: Appearance.font.size.small
            }
        }

        Instruments.ScopeTrace {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            samples: ch.history
            window: NetworkUsage.historyLength
            maxValue: ch.peak
            traceColor: Signal.palette.cue

            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1 rate trace, now %2, scale %3").arg(ch.label).arg(root.rate(ch.speed)).arg(root.rate(ch.peak))
        }

        StyledText {
            mono: true
            text: qsTr("scale 0–%1").arg(root.rate(ch.peak))
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }
    }
}
