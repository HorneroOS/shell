pragma ComponentBehavior: Bound

import qs.modules.companion
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Restart durability for generic companion instances, mirroring
// CompanionPersist: FileView primes once, a debounced shell child
// persists through a temp file + atomic rename, and unchanged
// content never spawns a child. The legacy Javi snapshot beside it
// (companion/state.json) is never read or written here.
Scope {
    id: root

    readonly property string filePath: Paths.state + "/companion/instances.json"
    property bool primed: false
    property string lastWritten: ""
    property string flightText: ""

    function writeNow(): void {
        const text = CompanionInstances.serialize();
        if (text === root.lastWritten) {
            if (!writer.running)
                CompanionInstances.clearDirty();
            return;
        }
        if (writer.running)
            return;
        root.flightText = text;
        writer.command = [
            "sh", "-c",
            'mkdir -p "$(dirname "$1")" && tmp="$(mktemp "$(dirname "$1")/.instances.XXXXXX")" && printf "%s" "$2" > "$tmp" && mv -f "$tmp" "$1"',
            "--",
            root.filePath,
            text
        ];
        writer.running = true;
    }

    function prime(text: string): void {
        if (root.primed)
            return;
        root.primed = true;
        CompanionInstances.prime(text);
        root.lastWritten = CompanionInstances.serialize();
        if (text)
            CompanionInstances.clearDirty();
    }

    FileView {
        path: root.filePath
        printErrors: false
        onLoaded: root.prime(text())
        onLoadFailed: root.prime("")
    }

    Connections {
        target: CompanionInstances

        function onDirtyChanged(): void {
            if (CompanionInstances.dirty)
                saveTimer.restart();
        }
    }

    Timer {
        id: saveTimer

        interval: 600
        repeat: false
        onTriggered: root.writeNow()
    }

    Process {
        id: writer

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                console.warn(`[companions] instances snapshot write failed (exit ${exitCode})`);
            } else {
                root.lastWritten = root.flightText;
                CompanionInstances.clearDirty();
            }
            if (CompanionInstances.dirty)
                saveTimer.restart();
        }
    }
}
