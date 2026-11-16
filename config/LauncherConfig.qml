import Quickshell.Io

JsonObject {
    property bool enabled: true
    property bool showOnHover: false
    property int maxShown: 7
    property int maxWallpapers: 9 // Warning: even numbers look bad
    property string specialPrefix: "@"
    property string actionPrefix: ">"
    property bool enableDangerousActions: false // Allow actions that can cause losing data, like shutdown, reboot and logout
    property int dragThreshold: 50
    property bool vimKeybinds: false
    property list<string> favouriteApps: []
    property list<string> hiddenApps: []
    property UseFuzzy useFuzzy: UseFuzzy {}
    property Sizes sizes: Sizes {}

    component UseFuzzy: JsonObject {
        property bool apps: false
        property bool actions: false
        property bool wallpapers: false
    }

    component Sizes: JsonObject {
        property int itemWidth: 600
        property int itemHeight: 57
        property int wallpaperWidth: 280
        property int wallpaperHeight: 200
    }

    property list<var> actions: [
        {
            name: "Welcome",
            icon: "hand-stop",
            description: "Open the Hornero Welcome Center",
            // Explicit "start": the welcome IPC handler requires its
            // page argument (open with no args is rejected).
            command: ["quickshell", "ipc", "call", "welcome", "open", "start"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Ask Hornero",
            icon: "feather",
            description: "Ask the Hornero assistant (needs horneroctl assistant enable)",
            command: ["autocomplete", "ai"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Windows",
            icon: "app-window",
            description: "Switch to an open window",
            command: ["autocomplete", "win"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Files",
            icon: "folder-open",
            description: "Find files in your home folders",
            command: ["autocomplete", "file"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Calculator",
            icon: "calculator",
            description: "Do simple math equations (powered by Qalc)",
            command: ["autocomplete", "calc"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Wallpaper",
            icon: "photo",
            description: "Change the current wallpaper",
            command: ["autocomplete", "wallpaper"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Themes",
            icon: "brush",
            description: "Apply a desktop theme pack",
            command: ["autocomplete", "theme"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Layout",
            icon: "layout-dashboard",
            description: "Change the shell bar layout",
            command: ["layoutpicker"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Transparency",
            icon: "opacity",
            description: "Change shell transparency",
            command: ["autocomplete", "transparency"],
            enabled: false,
            dangerous: false
        },
        {
            name: "Random",
            icon: "dice-5",
            description: "Switch to a random wallpaper",
            command: ["sh", "-c", "f=\"$(find -L \"$HOME/Pictures/Wallpapers\" -type f | shuf -n 1)\"; [ -n \"$f\" ] && horneroctl wallpaper set --yes \"$f\""],
            enabled: true,
            dangerous: false
        },
        {
            name: "Light",
            icon: "sun",
            description: "Switch to Hornero Signal Day",
            command: ["theme", "hornero-signal-day"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Dark",
            icon: "moon",
            description: "Switch to Hornero Signal Night",
            command: ["theme", "hornero-signal-night"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Shutdown",
            icon: "power",
            description: "Shutdown the system",
            command: ["systemctl", "poweroff"],
            enabled: true,
            dangerous: true
        },
        {
            name: "Reboot",
            icon: "refresh",
            description: "Reboot the system",
            command: ["systemctl", "reboot"],
            enabled: true,
            dangerous: true
        },
        {
            name: "Logout",
            icon: "logout",
            description: "Log out of the current session",
            command: ["loginctl", "terminate-user", ""],
            enabled: true,
            dangerous: true
        },
        {
            name: "Lock",
            icon: "lock",
            description: "Lock the current session",
            command: ["loginctl", "lock-session"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Sleep",
            icon: "moon-stars",
            description: "Suspend then hibernate",
            command: ["systemctl", "suspend-then-hibernate"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Settings",
            icon: "settings",
            description: "Configure the shell",
            command: ["horneroctl", "config", "gui"],
            enabled: true,
            dangerous: false
        }
    ]
}
