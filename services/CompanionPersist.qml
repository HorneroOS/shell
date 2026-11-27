pragma ComponentBehavior: Bound

import qs.modules.companion
import Quickshell
import Quickshell.Io
import QtQuick

// Companion restart-durability worker: owns the on-disk snapshot at
// CompanionStore.stateFilePath so the store itself never spawns
// processes (see CompanionStore header for the two-layer design).
//
// - Load: FileView reads the snapshot once; the first load (or load
//   failure on a fresh machine) wins and primes the clean marker.
// - Writes: when the store flags dirty, a debounced single-shot timer
//   serializes and persists through one shell child (mkdir plus
//   temp-file atomic rename). Unchanged content never spawns a child.
// - Races: a write before the first load marks the live state current
//   (adoptCurrent) so the late load cannot clobber real interaction.
Scope {
    id: root

    property bool primed: false
    property string lastWritten: ""
    property string flightText: ""

    function writeNow(): void {
        const text = CompanionStore.serialize();
        if (text === root.lastWritten) {
            // A matching marker is only trustworthy when no older write
            // is still in flight.
            if (!writer.running)
                CompanionStore.clearDirty();
            return;
        }
        // Live state wins over the still-pending first load.
        CompanionStore.adoptCurrent();
        if (writer.running) {
            // A write is already in flight with older content; it will
            // re-arm the timer on exit when new dirt arrives.
            return;
        }
        root.flightText = text;
        writer.command = [
            "sh", "-c",
            'mkdir -p "$(dirname "$1")" && tmp="$(mktemp "$(dirname "$1")/.state.XXXXXX")" && printf "%s" "$2" > "$tmp" && mv -f "$tmp" "$1"',
            "--",
            CompanionStore.stateFilePath,
            text
        ];
        writer.running = true;
    }

    function prime(text: string): void {
        if (root.primed)
            return;
        root.primed = true;
        CompanionStore.restore(text);
        root.lastWritten = CompanionStore.serialize();
        CompanionStore.clearDirty();
    }

    Connections {
        target: CompanionStore
        function onDirtyChanged(): void {
            if (CompanionStore.dirty)
                saveTimer.restart();
        }
    }

    // Debounced single-shot writer: zero steady-state cost.
    Timer {
        id: saveTimer
        interval: 1500
        repeat: false
        onTriggered: root.writeNow()
    }

    Process {
        id: writer

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                console.warn(`[companion] state snapshot write failed (exit ${exitCode})`);
            } else {
                root.lastWritten = root.flightText;
                CompanionStore.clearDirty();
            }
            // Dirt that arrived mid-flight needs another pass.
            if (CompanionStore.dirty)
                saveTimer.restart();
        }
    }

    FileView {
        path: CompanionStore.stateFilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.prime(text())
        onLoadFailed: root.prime("")
    }
}
