import qs.modules.plugins
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Cold-start probe harness (docs/perf-baselines/2026-10-21-cold-start.md):
// loads the plugin host + dashboard cards, prints plugin status after
// 100 ms, and quits. Wall time of the whole process is the measured
// cold start for this surface. Run from a scratch dir with the repo's
// assets/components/config/services/utils/modules linked in.
ShellRoot {
    PluginHost {}
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 900
        implicitHeight: 400
        color: "#14141f"
        PluginDashboardCards {
            anchors.fill: parent
            anchors.margins: 16
        }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: { console.info("COLDSTART status=" + JSON.stringify(Plugins.status())); Qt.callLater(Qt.quit); }
    }
}
