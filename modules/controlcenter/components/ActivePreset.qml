import qs.services
import Quickshell.Io
import QtQuick

// The layout preset the catalogue marks active, read from
// `horneroctl shell preset list --full` (bare command name,
// docs/INTEGRATION.md). `available` is false when horneroctl cannot answer;
// `preset` is null when the live bars match no catalogue preset (a custom
// arrangement), so callers never show a stale or invented name.
Item {
    id: root

    property bool available: false
    property var preset: null
    property int count: 0

    visible: false

    function reload(): void {
        if (!listProc.running)
            listProc.running = true;
    }

    Component.onCompleted: root.reload()

    Process {
        id: listProc

        command: ["horneroctl", "shell", "preset", "list", "--full"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    if (!Array.isArray(list))
                        throw new Error("expected a JSON array");
                    root.count = list.length;
                    root.preset = list.find(p => p.active) ?? null;
                    root.available = true;
                } catch (e) {
                    root.count = 0;
                    root.preset = null;
                    root.available = false;
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.count = 0;
                root.preset = null;
                root.available = false;
            }
        }
    }
}
