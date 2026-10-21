import qs.components.controls
import Quickshell
import QtQuick
import QtQuick.Layouts

// AT-SPI runtime probe harness (docs/a11y-audit-2026-10-21.md):
// representative shared controls whose Accessible names must reach
// the AT-SPI tree with correct roles. Run from a scratch dir with
// the repo's assets/components/config/services/utils/modules linked
// in as qs import roots, with QT_ACCESSIBILITY=1 and
// QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1, then walk the tree with
// tests/atspi/probe.py.
ShellRoot {
    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 500
        implicitHeight: 300
        color: "#14141f"
        ColumnLayout {
            anchors.centerIn: parent
            TextButton { text: "Apply appearance changes" }
            IconButton { icon: "close"; accessibleName: "Close Welcome" }
            ToggleRow { label: "Night mode" }
            StyledSlider { accessibleName: "Output volume"; value: 0.5; implicitWidth: 200 }
        }
    }
    Timer { interval: 240000; running: true; onTriggered: Qt.quit() }
}
