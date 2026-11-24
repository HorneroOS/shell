import qs.utils
import Quickshell.Io
import QtQuick

// Restart durability for generic companion instances. CompanionInstances
// stays process-free; this item mirrors CompanionPersist's guarded
// cat + atomic replace and never touches the legacy Javi snapshot.
Item {
    id: root

    readonly property string filePath: Paths.state + "/companion/instances.json"
    property bool primed: false

    FileView {
        id: file

        path: root.filePath
        printErrors: false
        onLoaded: CompanionInstances.prime(file.text())
        onLoadFailed: CompanionInstances.prime("")
    }

    Connections {
        target: CompanionInstances

        function onDirtyChanged(): void {
            if (CompanionInstances.dirty)
                writeTimer.restart();
        }
    }

    Timer {
        id: writeTimer

        interval: 300
        onTriggered: {
            if (!CompanionInstances.dirty)
                return;
            writer.stdin = CompanionInstances.serialize();
            writer.running = true;
        }
    }

    Process {
        id: writer

        running: false
        command: ["/bin/sh", "-c", 'd="$1"; f="$2"; mkdir -p "$d"; tmp="$f.tmp"; cat > "$tmp" && mv "$tmp" "$f"', "hornero-companion-instances", Paths.state + "/companion", root.filePath]
        onExited: code => {
            if (code === 0) {
                CompanionInstances.dirty = false;
                if (CompanionInstances.savePending) {
                    CompanionInstances.savePending = false;
                    CompanionInstances.markDirty();
                }
            }
        }
    }
}
