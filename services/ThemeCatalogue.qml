pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool loaded: false
    property var themes: []
    property var gtkThemes: []
    property var iconThemes: []
    property bool gtkThemesLoaded: false
    property bool iconThemesLoaded: false
    property bool gtkThemesFailed: false
    property bool iconThemesFailed: false
    readonly property bool appearanceChoicesLoaded: gtkThemesLoaded && iconThemesLoaded
    readonly property bool appearanceChoicesLoading: !appearanceChoicesLoaded
    readonly property bool appearanceChoicesFailed: gtkThemesFailed || iconThemesFailed

    function loadAppearanceChoices(): void {
        if (appearanceChoicesLoading || (appearanceChoicesLoaded && !appearanceChoicesFailed))
            return;
        gtkThemesLoaded = false;
        iconThemesLoaded = false;
        gtkThemesFailed = false;
        iconThemesFailed = false;
        gtkThemes = [];
        iconThemes = [];
        gtkListProc.running = true;
        iconListProc.running = true;
    }

    function _finishAppearanceChoices(exitCode: int, output: string, icons: bool): void {
        if (exitCode === 0) {
            const names = output.split("\n").map(line => line.trim()).filter(line => line.length > 0);
            if (icons) {
                iconThemes = names;
                iconThemesFailed = false;
                iconThemesLoaded = true;
            } else {
                gtkThemes = names;
                gtkThemesFailed = false;
                gtkThemesLoaded = true;
            }
        } else {
            if (icons) {
                iconThemes = [];
                iconThemesFailed = true;
                iconThemesLoaded = true;
            } else {
                gtkThemes = [];
                gtkThemesFailed = true;
                gtkThemesLoaded = true;
            }
        }
    }

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

    // Appearance opens these catalogues lazily and shares the results
    // between theme readiness and the GTK/icon choice sections.
    Process {
        id: gtkListProc
        command: ["horneroctl", "appearance", "gtk", "list"]
        stdout: StdioCollector { id: gtkListOutput }
        onExited: (exitCode, exitStatus) => root._finishAppearanceChoices(exitCode, gtkListOutput.text, false)
    }

    Process {
        id: iconListProc
        command: ["horneroctl", "appearance", "gtk", "icons"]
        stdout: StdioCollector { id: iconListOutput }
        onExited: (exitCode, exitStatus) => root._finishAppearanceChoices(exitCode, iconListOutput.text, true)
    }
}
