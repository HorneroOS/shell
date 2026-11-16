pragma Singleton

import qs.config
import qs.services
import qs.utils
import Hornero.Models
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    readonly property string wallpaperPointerPath: Paths.wallpaperPointer
    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property string colorFilter: ""

    function setWallpaper(path: string): void {
        actualCurrent = path;
        ThemePipeline.setWallpaper(path);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;
    }

    function stopPreview(): void {
        showPreview = false;
    }

    function reloadWallpaperPath(): void {
        resolveProc.running = true;
    }

    /** Raw pointer file content; avoids empty UI if the wallpaper query fails (env/PATH). */
    function applyPointerFromFileView(pointerReadout: string): void {
        let t = pointerReadout.trim();
        if (!t.length) {
            actualCurrent = "";
            return;
        }
        // Normalize file:// URIs written by some tools / drag-drop paths.
        if (t.startsWith("file://"))
            t = Paths.toLocalFile(t) || t.replace(/^file:\/\//, "");
        // Reject self-referential pointer corruption (pointer path written into itself).
        if (t === root.wallpaperPointerPath || t === Paths.wallpaperPointer)
            return;
        actualCurrent = t;
    }

    // User wallpapers remain writable and separate from the package; factory
    // art is read from its system-owned path. Present both in one catalogue.
    list: wallpapers.entries.concat(factoryWallpapers.entries)
    key: "relativePath"
    useFuzzy: Config.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }
    }

    // Native current-wallpaper read; FileView pointer fallback below.
    Process {
        id: resolveProc

        command: ["horneroctl", "wallpaper", "current"]
        running: false
        stdout: StdioCollector { id: resolveOutput }
        onExited: (exitCode, exitStatus) => {
            // `wallpaper current` reports the unconfigured case with a
            // non-zero exit. Never treat its diagnostic text as an image
            // path; preserve the FileView pointer fallback when available.
            if (exitCode === 0) {
                const path = resolveOutput.text.trim();
                if (path.length > 0)
                    root.actualCurrent = path;
            }
        }
    }

    FileView {
        path: root.wallpaperPointerPath
        watchChanges: true
        onFileChanged: {
            root.applyPointerFromFileView(text());
            reloadWallpaperPath();
        }
        onLoaded: {
            root.applyPointerFromFileView(text());
            reloadWallpaperPath();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.applyPointerFromFileView("");
                reloadWallpaperPath();
            }
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
    }

    FileSystemModel {
        id: factoryWallpapers

        recursive: true
        path: Paths.systemWallsdir
        filter: FileSystemModel.Files
    }

    Component.onCompleted: Qt.callLater(() => reloadWallpaperPath())

}
