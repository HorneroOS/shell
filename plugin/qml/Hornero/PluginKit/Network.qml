pragma Singleton

import qs.services as Services
import QtQuick

// Read-only network throughput from the shell's NetworkUsage service
// (provider domain "network"). Speeds are bytes per second, totals bytes
// since the provider started. Link state comes from the shell's Network
// service (event-driven).
QtObject {
    readonly property real downloadSpeed: Services.NetworkUsage.downloadSpeed
    readonly property real uploadSpeed: Services.NetworkUsage.uploadSpeed
    readonly property real downloadTotal: Services.NetworkUsage.downloadTotal
    readonly property real uploadTotal: Services.NetworkUsage.uploadTotal

    readonly property bool wifi: Services.Network.active !== null && Services.Network.active !== undefined
    readonly property bool wired: Services.Network.activeEthernet !== null && Services.Network.activeEthernet !== undefined
    readonly property bool connected: wifi || wired
    // SSID of the active Wi-Fi link; "" otherwise. Personal data: show
    // it only where the person expects it (a network popover), never on
    // an always-visible desktop widget by default.
    readonly property string ssid: Services.Network.active?.ssid ?? ""
    // Wi-Fi signal strength 0–100, or -1 when not on Wi-Fi.
    readonly property int signalStrength: Services.Network.active?.strength ?? -1

    // "1.4 MB/s" style formatting shared with native surfaces.
    function formatRate(bytesPerSecond: real): string {
        const f = Services.NetworkUsage.formatBytes(bytesPerSecond);
        return `${f.value.toFixed(f.value < 10 ? 1 : 0)} ${f.unit}`;
    }
}
