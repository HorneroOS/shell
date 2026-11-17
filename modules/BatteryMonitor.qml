import qs.config
import qs.modules.companion
import qs.services
import Hornero
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Scope {
    id: root

    readonly property list<var> warnLevels: [...Config.general.battery.warnLevels].sort((a, b) => b.level - a.level)

    Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            if (UPower.onBattery) {
                CompanionReactions.react("charger.unplugged", "shell", "");
                if (Config.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("Charger unplugged"), qsTr("Battery is discharging"), "plug-off");
            } else {
                CompanionReactions.react("charger.plugged", "shell", "");
                Sounds.play("charger", false);
                if (Config.utilities.toasts.chargingChanged)
                    Toaster.toast(qsTr("Charger plugged in"), qsTr("Battery is charging"), "power");
                for (const level of root.warnLevels)
                    level.warned = false;
            }
        }
    }

    Connections {
        target: UPower.displayDevice

        function onPercentageChanged(): void {
            if (!UPower.onBattery)
                return;

            const p = UPower.displayDevice.percentage * 100;
            for (const level of root.warnLevels) {
                if (p <= level.level && !level.warned) {
                    level.warned = true;
                    CompanionReactions.react(level.critical ? "battery.critical" : "battery.low", "shell", "");
                    Sounds.play("battery", false);
                    Toaster.toast(level.title ?? qsTr("Battery warning"), level.message ?? qsTr("Battery level is low"), level.icon ?? "battery-exclamation", level.critical ? Toast.Error : Toast.Warning);
                    // Critical levels also file a durable, DND-aware
                    // notification (shell#224); plain warnings stay
                    // momentary toasts.
                    if (level.critical)
                        Notifs.promoteCritical(level.title ?? qsTr("Battery warning"), level.message ?? qsTr("Battery level is low"), level.icon ?? "battery-exclamation");
                }
            }

            if (!hibernateTimer.running && p <= Config.general.battery.criticalLevel) {
                Toaster.toast(qsTr("Hibernating in 5 seconds"), qsTr("Hibernating to prevent data loss"), "battery-exclamation", Toast.Error);
                Notifs.promoteCritical(qsTr("Hibernating in 5 seconds"), qsTr("Hibernating to prevent data loss"), "battery-exclamation");
                hibernateTimer.start();
            }
        }
    }

    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: Quickshell.execDetached(["systemctl", "hibernate"])
    }
}
