import QtQuick
import Hornero.PluginKit

// Instrumentation example (RFC 0001 §5b): a desktop widget built only
// from PluginKit instruments over the shared providers. Every value is
// real telemetry; an unavailable sensor renders as unavailable.
Item {
    id: root

    property int hostAvailableWidth: 420
    property int hostAvailableHeight: 220
    readonly property string widgetContext: `${Math.round(Telemetry.windowSize * Providers.refreshIntervalMs("system") / 1000)} S WINDOW`

    implicitWidth: 420
    implicitHeight: 220

    // Leases keep the shared providers live while the widget is loaded.
    Subscription {
        domain: "system"
    }

    Column {
        width: root.hostAvailableWidth
        spacing: Theme.spacing.normal

        UiScope {
            width: parent.width
            height: Math.max(100, root.hostAvailableHeight - 72)
            label: "CPU · 10 %/DIV"
            samples: Telemetry.window("cpu")
            previous: Telemetry.previousWindow("cpu")
        }

        UiMeterRow {
            width: parent.width
            label: "Mem"
            value: System.memPerc
            valueText: `${Math.round(System.memPerc * 100)} %`
        }

        UiMeterRow {
            width: parent.width
            label: "Temp"
            available: System.cpuTempAvailable
            value: System.cpuTemp / 100
            threshold: 0.8
            valueText: `${Math.round(System.cpuTemp)} °C`
        }
    }
}
