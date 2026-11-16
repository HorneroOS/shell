pragma Singleton

import qs.services as Services
import QtQuick

// Read-only system telemetry from the shell's SystemUsage service
// (provider domain "system"; hold `Subscription { domain: "system" }`
// while a surface shows these values). Fractions are 0–1, temperatures
// °C. Every sensor has an availability flag: when it is false the value
// is meaningless and the surface must render "unavailable", never 0.
QtObject {
    readonly property string cpuName: Services.SystemUsage.cpuName
    readonly property real cpuPerc: Services.SystemUsage.cpuPerc
    // Per-logical-CPU load (0–1) from the same /proc/stat sample.
    readonly property var cores: Services.SystemUsage.cpuCores
    readonly property real cpuTemp: Services.SystemUsage.cpuTemp
    readonly property bool cpuTempAvailable: Services.SystemUsage.cpuTempAvailable

    readonly property bool gpuAvailable: Services.SystemUsage.gpuAvailable
    readonly property string gpuName: Services.SystemUsage.gpuName
    readonly property real gpuPerc: Services.SystemUsage.gpuPerc
    readonly property real gpuTemp: Services.SystemUsage.gpuTemp
    readonly property bool gpuTempAvailable: Services.SystemUsage.gpuTempAvailable

    // KiB.
    readonly property real memUsed: Services.SystemUsage.memUsed
    readonly property real memTotal: Services.SystemUsage.memTotal
    readonly property real memPerc: Services.SystemUsage.memPerc

    readonly property real storagePerc: Services.SystemUsage.storagePerc
    readonly property bool storageAvailable: (Services.SystemUsage.disks?.length ?? 0) > 0
    // [{ mount, used, total, free, perc }] in KiB, one per physical disk.
    readonly property var disks: Services.SystemUsage.disks ? Services.SystemUsage.disks.map(d => Object.assign({}, d)) : []
}
