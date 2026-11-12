pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property real cpuPerc: Services.SystemUsage.cpuPerc
    readonly property real cpuTemp: Services.SystemUsage.cpuTemp
    readonly property real gpuPerc: Services.SystemUsage.gpuPerc
    readonly property real gpuTemp: Services.SystemUsage.gpuTemp
    readonly property real memUsed: Services.SystemUsage.memUsed
    readonly property real memTotal: Services.SystemUsage.memTotal
    readonly property real memPerc: Services.SystemUsage.memPerc
    readonly property real storagePerc: Services.SystemUsage.storagePerc
    readonly property var disks: Services.SystemUsage.disks
}
