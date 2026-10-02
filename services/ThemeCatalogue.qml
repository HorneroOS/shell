pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool loaded: false
    property var themes: []

    readonly property var _builtIns: [
        {
            id: "hornero-dark",
            name: "Hornero Dark",
            description: "Default dark theme with rose accent",
            darkMode: true,
            schemeType: "tonal-spot",
            tags: ["hornero", "dark", "builtin"]
        },
        {
            id: "hornero-light",
            name: "Hornero Light",
            description: "Default light theme with rose accent",
            darkMode: false,
            schemeType: "tonal-spot",
            tags: ["hornero", "light", "builtin"]
        }
    ]

    function _withBuiltIns(items: var): var {
        const actual = Array.isArray(items) ? items.filter(item => item && typeof item.id === "string") : [];
        const builtIns = _builtIns.map(fallback => {
            for (let i = 0; i < actual.length; i++) {
                if (actual[i].id === fallback.id)
                    return actual[i];
            }
            return fallback;
        });
        return builtIns.concat(actual.filter(item => item.id !== "hornero-dark" && item.id !== "hornero-light"));
    }

    function themeById(id: string): var {
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].id === id)
                return themes[i];
        }
        return null;
    }

    function reload(): void {
        loaded = false;
        loadProc.running = true;
    }

    Component.onCompleted: reload()

    Process {
        id: loadProc
        command: ["horneroctl", "appearance", "theme", "list", "--full"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = root._withBuiltIns(JSON.parse(text));
                } catch (e) {
                    console.warn("ThemeCatalogue: failed to parse theme list:", e);
                    root.themes = root._withBuiltIns([]);
                }
                root.loaded = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (!root.loaded) {
                console.warn("ThemeCatalogue: horneroctl theme list failed", exitCode);
                root.themes = root._withBuiltIns([]);
                root.loaded = true;
            }
        }
    }
}
