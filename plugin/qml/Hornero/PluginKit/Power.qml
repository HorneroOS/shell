pragma Singleton

import Quickshell.Services.UPower
import QtQuick

// Battery and power state from UPower (provider domain "power",
// event-driven). `hasBattery` is false on desktops: show the battery
// instrument as unavailable (or hide it), never as 0 %.
QtObject {
    readonly property var _device: UPower.displayDevice
    readonly property bool hasBattery: _device !== null && _device !== undefined && (_device.isPresent ?? false) && (_device.isLaptopBattery ?? false)
    readonly property int percentage: Math.max(0, Math.min(100, Math.round((_device?.percentage ?? 0) * 100)))
    readonly property bool charging: _device?.state === UPowerDeviceState.Charging || _device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property string stateText: !hasBattery ? "" : _device.state === UPowerDeviceState.Charging ? "charging" : _device.state === UPowerDeviceState.FullyCharged ? "fully-charged" : _device.state === UPowerDeviceState.Discharging ? "discharging" : _device.state === UPowerDeviceState.PendingCharge ? "pending-charge" : ""
    // Seconds; 0 when UPower has no estimate.
    readonly property real timeToEmpty: hasBattery ? (_device.timeToEmpty ?? 0) : 0
    readonly property real timeToFull: hasBattery ? (_device.timeToFull ?? 0) : 0
    // Watts (positive while discharging on most firmware); 0 = unknown.
    readonly property real energyRate: hasBattery ? Math.abs(_device.changeRate ?? 0) : 0
    // Battery health (capacity vs design, 0–100) when the firmware
    // reports it; check healthAvailable first.
    readonly property bool healthAvailable: hasBattery && (_device.healthSupported ?? false)
    readonly property int health: healthAvailable ? Math.round(_device.healthPercentage ?? 0) : 0
    // Power profile ("power-saver" | "balanced" | "performance" | "").
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : PowerProfiles.profile === PowerProfile.Balanced ? "balanced" : ""
}
