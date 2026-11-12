pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property real downloadSpeed: Services.NetworkUsage.downloadSpeed
    readonly property real uploadSpeed: Services.NetworkUsage.uploadSpeed
    readonly property real downloadTotal: Services.NetworkUsage.downloadTotal
    readonly property real uploadTotal: Services.NetworkUsage.uploadTotal
}
