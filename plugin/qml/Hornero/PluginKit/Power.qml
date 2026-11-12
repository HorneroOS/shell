pragma Singleton

import Quickshell.Services.UPower
import QtQuick

QtObject {
    // Mirrors modules/bar/components/Battery.qml: the display device is a
    // laptop battery only when present and flagged as one; percentage is
    // a 0-1 fraction on the device and an int percent here.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice !== undefined && (UPower.displayDevice.isPresent ?? false) && (UPower.displayDevice.isLaptopBattery ?? false)
    readonly property int percentage: Math.max(0, Math.min(100, Math.round((UPower.displayDevice?.percentage ?? 0) * 100)))
    readonly property bool charging: UPower.displayDevice?.state === UPowerDeviceState.Charging || UPower.displayDevice?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property string stateText: !hasBattery ? "" : UPower.displayDevice.state === UPowerDeviceState.Charging ? "charging" : UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? "fully-charged" : UPower.displayDevice.state === UPowerDeviceState.Discharging ? "discharging" : UPower.displayDevice.state === UPowerDeviceState.PendingCharge ? "pending-charge" : ""
}
