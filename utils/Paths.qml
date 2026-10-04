pragma Singleton

import qs.config
import Hornero
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`
    readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`

    // Hornero owns one user namespace. System catalogues are read separately
    // from XDG_DATA_DIRS and never receive user state or writes.
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`

    readonly property string data: `${dataHome}/hornero`
    readonly property string state: `${stateHome}/hornero`
    readonly property string cache: `${cacheHome}/hornero`
    readonly property string config: `${configHome}/hornero`
    readonly property string wallpaperPointer: `${state}/wallpaper/path`
    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notifimagecache: `${imagecache}/notifs`
    readonly property string wallsdir: Quickshell.env("HORNERO_WALLPAPERS_DIR") || absolutePath(Config.paths.wallpaperDir)
    readonly property string recsdir: Quickshell.env("HORNERO_RECORDINGS_DIR") || `${videos}/Recordings`
    readonly property string libdir: Quickshell.env("HORNERO_LIB_DIR") || "/usr/share/hornero/lib/hornero"

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        const expanded = path.replace(/~|(\$({?)HOME(}?))+/, home);
        if (expanded.startsWith("/"))
            return expanded;
        if (expanded.startsWith("file://"))
            return CUtils.toLocalFile(expanded);
        return toLocalFile(expanded);
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
