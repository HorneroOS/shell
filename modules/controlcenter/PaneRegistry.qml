pragma Singleton

import QtQuick

// Canonical Settings destinations and their user-facing discovery metadata.
// `id` and `label` remain stable route keys for IPC, Welcome, and Session;
// `title`, `category`, and `keywords` describe how people find them.
QtObject {
    id: root

    readonly property list<QtObject> categories: [
        QtObject { readonly property string id: "connections"; readonly property string title: qsTr("Connections") },
        QtObject { readonly property string id: "look"; readonly property string title: qsTr("Look & feel") },
        QtObject { readonly property string id: "desktop"; readonly property string title: qsTr("Desktop") },
        QtObject { readonly property string id: "sound-alerts"; readonly property string title: qsTr("Sound & alerts") },
        QtObject { readonly property string id: "devices"; readonly property string title: qsTr("Devices") },
        QtObject { readonly property string id: "apps"; readonly property string title: qsTr("Apps & assistants") },
        QtObject { readonly property string id: "system"; readonly property string title: qsTr("System") }
    ]

    readonly property list<QtObject> panes: [
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string title: qsTr("Network")
            readonly property string icon: "router"
            readonly property string component: "network/NetworkingPane.qml"
            readonly property string category: "connections"
            readonly property string description: qsTr("Wi-Fi, wired networks, and connections")
            readonly property list<string> keywords: ["wifi", "wi-fi", "ethernet", "internet", "wireless"]
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string title: qsTr("Bluetooth")
            readonly property string icon: "bluetooth"
            readonly property string component: "bluetooth/BtPane.qml"
            readonly property string category: "connections"
            readonly property string description: qsTr("Pair and manage nearby devices")
            readonly property list<string> keywords: ["pair", "headphones", "mouse", "keyboard", "devices"]
        },
        QtObject {
            readonly property string id: "vpn"
            readonly property string label: "vpn"
            readonly property string title: "VPN"
            readonly property string icon: "key"
            readonly property string component: "vpn/VpnPane.qml"
            readonly property string category: "connections"
            readonly property string description: qsTr("Manage private network connections")
            readonly property list<string> keywords: ["virtual private network", "wireguard", "netbird", "tunnel"]
        },
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string title: qsTr("Appearance")
            readonly property string icon: "palette"
            readonly property string component: "appearance/AppearancePane.qml"
            readonly property string category: "look"
            readonly property string description: qsTr("Themes, colors, wallpaper, and visual effects")
            readonly property list<string> keywords: ["theme", "wallpaper", "dark mode", "light mode", "color", "font", "transparency", "motion"]
        },
        QtObject {
            readonly property string id: "nightlight"
            readonly property string label: "nightlight"
            readonly property string title: qsTr("Night Light")
            readonly property string icon: "moon"
            readonly property string component: "nightlight/NightLightPane.qml"
            readonly property string category: "look"
            readonly property string description: qsTr("Warm the display for the night")
            readonly property list<string> keywords: ["night light", "night mode", "warm", "temperature", "redshift", "gammastep", "eye strain"]
        },
        QtObject {
            readonly property string id: "accessibility"
            readonly property string label: "accessibility"
            readonly property string title: qsTr("Accessibility")
            readonly property string icon: "accessible"
            readonly property string component: "accessibility/AccessibilityPane.qml"
            readonly property string category: "look"
            readonly property string description: qsTr("Text size, motion and transparency for comfortable use")
            readonly property list<string> keywords: ["accessibility", "text size", "font", "motion", "reduce motion", "vision", "a11y"]
        },
        QtObject {
            readonly property string id: "experience"
            readonly property string label: "experience"
            readonly property string title: qsTr("Experience")
            readonly property string icon: "wave-sine"
            readonly property string component: "experience/ExperiencePane.qml"
            readonly property string category: "look"
            readonly property string description: qsTr("Experience modes: Focus, Everyday, Signal, Gaming, Studio")
            readonly property list<string> keywords: ["experience", "mode", "modes", "focus", "everyday", "signal", "immersive", "gaming", "studio", "glow", "density", "telemetry"]
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string title: qsTr("Bars")
            readonly property string icon: "layout-sidebar"
            readonly property string component: "taskbar/TaskbarPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Configure desktop bars and panels")
            readonly property list<string> keywords: ["taskbar", "panel", "rail", "dock", "island", "status bar"]
        },
        QtObject {
            readonly property string id: "layout"
            readonly property string label: "layout"
            readonly property string title: qsTr("Layout")
            readonly property string icon: "layout-dashboard"
            readonly property string component: "layout/LayoutPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Arrange bars and desktop surfaces")
            readonly property list<string> keywords: ["preset", "topology", "position", "screen layout"]
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string title: qsTr("Dashboard")
            readonly property string icon: "dashboard"
            readonly property string component: "dashboard/DashboardPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Choose dashboard content and behavior")
            readonly property list<string> keywords: ["weather", "location", "widgets", "desktop"]
        },
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string title: qsTr("Launcher")
            readonly property string icon: "apps"
            readonly property string component: "launcher/LauncherPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Choose how search and app launch work")
            readonly property list<string> keywords: ["search", "applications", "shortcuts"]
        },
        QtObject {
            readonly property string id: "windows"
            readonly property string label: "windows"
            readonly property string title: qsTr("Windows")
            readonly property string icon: "app-window"
            readonly property string component: "windows/WindowsPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Window gaps, borders, focus and rules")
            readonly property list<string> keywords: ["windows", "gaps", "border", "rounding", "geometry", "tiling", "focus", "float", "rules"]
        },
        QtObject {
            readonly property string id: "lockscreen"
            readonly property string label: "lockscreen"
            readonly property string title: qsTr("Lock screen")
            readonly property string icon: "lock"
            readonly property string component: "lockscreen/LockScreenPane.qml"
            readonly property string category: "desktop"
            readonly property string description: qsTr("Lock screen privacy, fingerprint and idle locking")
            readonly property list<string> keywords: ["lock", "fingerprint", "privacy", "idle", "sleep"]
        },
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string title: qsTr("Audio")
            readonly property string icon: "volume"
            readonly property string component: "audio/AudioPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Choose devices and adjust sound")
            readonly property list<string> keywords: ["volume", "microphone", "speaker", "output", "input"]
        },
        QtObject {
            readonly property string id: "notifications"
            readonly property string label: "notifications"
            readonly property string title: qsTr("Notifications")
            readonly property string icon: "bell"
            readonly property string component: "notifications/NotificationsPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Choose when and how notifications appear")
            readonly property list<string> keywords: ["history", "do not disturb", "dnd", "quiet", "alerts"]
        },
        QtObject {
            readonly property string id: "osd"
            readonly property string label: "osd"
            readonly property string title: qsTr("On-screen display")
            readonly property string icon: "adjustments-horizontal"
            readonly property string component: "osd/OsdPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Configure on-screen volume and brightness feedback")
            readonly property list<string> keywords: ["osd", "volume popup", "brightness popup", "feedback"]
        },
        QtObject {
            readonly property string id: "displays"
            readonly property string label: "displays"
            readonly property string title: qsTr("Displays")
            readonly property string icon: "device-desktop"
            readonly property string component: "displays/DisplaysPane.qml"
            readonly property string category: "devices"
            readonly property string description: qsTr("Connected displays and arrangement")
            readonly property list<string> keywords: ["display", "monitor", "screen", "arrangement", "mirror", "extend", "brightness", "layout", "animations"]
        },
        QtObject {
            readonly property string id: "input"
            readonly property string label: "input"
            readonly property string title: qsTr("Input")
            readonly property string icon: "keyboard"
            readonly property string component: "input/InputPane.qml"
            readonly property string category: "devices"
            readonly property string description: qsTr("Keyboard layout and input settings")
            readonly property list<string> keywords: ["input", "keyboard", "layout", "keybindings", "mouse", "touchpad", "restore", "cursor"]
        },
        QtObject {
            readonly property string id: "keybinds"
            readonly property string label: "keybinds"
            readonly property string title: qsTr("Keybinds")
            readonly property string icon: "command"
            readonly property string component: "keybinds/KeybindsPane.qml"
            readonly property string category: "devices"
            readonly property string description: qsTr("View and search session keybindings")
            readonly property list<string> keywords: ["keybinds", "shortcuts", "hotkeys", "keyboard", "bindings"]
        },
        QtObject {
            readonly property string id: "power"
            readonly property string label: "power"
            readonly property string title: qsTr("Power")
            readonly property string icon: "power"
            readonly property string component: "power/PowerPane.qml"
            readonly property string category: "devices"
            readonly property string description: qsTr("Battery and power behavior")
            readonly property list<string> keywords: ["battery", "sleep", "suspend", "shutdown"]
        },
        QtObject {
            readonly property string id: "capture"
            readonly property string label: "capture"
            readonly property string title: qsTr("Capture")
            readonly property string icon: "camera"
            readonly property string component: "capture/CapturePane.qml"
            readonly property string category: "devices"
            readonly property string description: qsTr("Screenshots, screen recording, and capture backends")
            readonly property list<string> keywords: ["screenshot", "screen recording", "recorder", "capture", "clipboard"]
        },
        QtObject {
            readonly property string id: "companion"
            readonly property string label: "companion"
            readonly property string title: qsTr("Javi")
            readonly property string icon: "feather"
            readonly property string component: "companion/CompanionPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Configure the Hornero desktop companion")
            readonly property list<string> keywords: ["mascot", "pet", "character"]
        },
        QtObject {
            readonly property string id: "agents"
            readonly property string label: "agents"
            readonly property string title: qsTr("Agent Center")
            readonly property string icon: "robot"
            readonly property string component: "agents/AgentCenterPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Coding agents on this machine and Javi assistant state")
            readonly property list<string> keywords: ["agent", "agents", "javi", "assistant", "coding"]
        },
        QtObject {
            readonly property string id: "studio"
            readonly property string label: "studio"
            readonly property string title: qsTr("Studio")
            readonly property string icon: "movie"
            readonly property string component: "studio/StudioPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Creative workloads and applications")
            readonly property list<string> keywords: ["studio", "creative", "workloads", "audio", "video", "streaming"]
        },
        QtObject {
            readonly property string id: "gaming"
            readonly property string label: "gaming"
            readonly property string title: qsTr("Gaming")
            readonly property string icon: "device-gamepad-2"
            readonly property string component: "gaming/GamingPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Gaming readiness, profiles, and gaming mode")
            readonly property list<string> keywords: ["gaming", "games", "steam", "proton", "gamescope", "gamemode", "controllers"]
        },
        QtObject {
            readonly property string id: "terminal"
            readonly property string label: "terminal"
            readonly property string title: qsTr("Terminal")
            readonly property string icon: "terminal"
            readonly property string component: "terminal/TerminalPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Choose the terminal used by Hornero and integrated launch actions")
            readonly property list<string> keywords: ["kitty", "alacritty", "ghostty", "default app", "console"]
        },
        QtObject {
            readonly property string id: "extensions"
            readonly property string label: "extensions"
            readonly property string title: qsTr("Extensions")
            readonly property string icon: "puzzle"
            readonly property string component: "extensions/ExtensionsPane.qml"
            readonly property string category: "apps"
            readonly property string description: qsTr("Community plugins and their load state")
            readonly property list<string> keywords: ["plugins", "addons", "community"]
        },
        QtObject {
            readonly property string id: "system"
            readonly property string label: "system"
            readonly property string title: qsTr("System")
            readonly property string icon: "info-circle"
            readonly property string component: "system/SystemPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("System information and diagnostics")
            readonly property list<string> keywords: ["about", "hardware", "diagnostics", "version", "doctor", "logs"]
        },
        QtObject {
            readonly property string id: "updates"
            readonly property string label: "updates"
            readonly property string title: qsTr("Updates")
            readonly property string icon: "device-mobile-down"
            readonly property string component: "updates/UpdatesPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("Review available system updates")
            readonly property list<string> keywords: ["upgrade", "packages", "maintenance", "dependencies", "snapshots", "backup"]
        },
        QtObject {
            readonly property string id: "session"
            readonly property string label: "session"
            readonly property string title: qsTr("Session")
            readonly property string icon: "logout"
            readonly property string component: "session/SessionPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("Session menu behavior and keybinds")
            readonly property list<string> keywords: ["session", "power menu", "logout", "vim", "drag"]
        }
    ]

    // Searchable controls that deserve a direct destination. Keep these
    // labels and aliases here beside the pane routes; search never scrapes
    // QML or exposes implementation-only control names.
    readonly property list<QtObject> searchTargets: [
        QtObject { readonly property string id: "chromatic"; readonly property string title: qsTr("Chromatic dynamic colour"); readonly property string pane: "appearance"; readonly property string section: "chromatic"; readonly property string icon: "palette"; readonly property string keywords: "chromatic dynamic wallpaper colour color palette accent variant auto recolor follow" },
        QtObject { readonly property string id: "themes"; readonly property string title: qsTr("Themes"); readonly property string pane: "appearance"; readonly property string section: "themes"; readonly property string icon: "palette"; readonly property string keywords: "theme look style hornero pampa catppuccin" },
        QtObject { readonly property string id: "edit-palette"; readonly property string title: qsTr("Edit palette"); readonly property string pane: "appearance"; readonly property string section: "themeEditor"; readonly property string icon: "palette"; readonly property string keywords: "custom theme colour color accent edit duplicate rename save reset palette roles" },
        QtObject { readonly property string id: "dark-mode"; readonly property string title: qsTr("Signal Day and Night themes"); readonly property string pane: "appearance"; readonly property string section: "themes"; readonly property string icon: "moon"; readonly property string keywords: "dark light mode brightness" },
        QtObject { readonly property string id: "gtk"; readonly property string title: qsTr("GTK apps"); readonly property string pane: "appearance"; readonly property string section: "gtkTheme"; readonly property string icon: "app-window"; readonly property string keywords: "gtk theme applications manual override" },
        QtObject { readonly property string id: "icons"; readonly property string title: qsTr("Icon theme"); readonly property string pane: "appearance"; readonly property string section: "iconTheme"; readonly property string icon: "mood-smile"; readonly property string keywords: "icons papirus numix" },
        QtObject { readonly property string id: "fonts"; readonly property string title: qsTr("Fonts"); readonly property string pane: "appearance"; readonly property string section: "fonts"; readonly property string icon: "typography"; readonly property string keywords: "font typography typeface" },
        QtObject { readonly property string id: "motion"; readonly property string title: qsTr("Motion and animation"); readonly property string pane: "appearance"; readonly property string section: "animations"; readonly property string icon: "player-record"; readonly property string keywords: "reduce motion disable animations accessibility" },
        QtObject { readonly property string id: "experience-modes"; readonly property string title: qsTr("Experience modes"); readonly property string pane: "experience"; readonly property string section: ""; readonly property string icon: "wave-sine"; readonly property string keywords: "focus everyday signal immersive gaming studio mode glow density" },
        QtObject { readonly property string id: "scale"; readonly property string title: qsTr("Interface size"); readonly property string pane: "appearance"; readonly property string section: "scales"; readonly property string icon: "zoom-in"; readonly property string keywords: "scale sizing density text size" },
        QtObject { readonly property string id: "transparency"; readonly property string title: qsTr("Transparency"); readonly property string pane: "appearance"; readonly property string section: "transparency"; readonly property string icon: "opacity"; readonly property string keywords: "blur opacity glass launcher notifications" },
        QtObject { readonly property string id: "launcher-sizes"; readonly property string title: qsTr("Launcher size"); readonly property string pane: "launcher"; readonly property string section: ""; readonly property string icon: "zoom-in"; readonly property string keywords: "launcher item width height wallpaper tile size bigger smaller" },
        QtObject { readonly property string id: "notification-sizes"; readonly property string title: qsTr("Notification and toast size"); readonly property string pane: "notifications"; readonly property string section: ""; readonly property string icon: "zoom-in"; readonly property string keywords: "notification toast width image size notification centre sidebar wider narrower" },
        QtObject { readonly property string id: "session-size"; readonly property string title: qsTr("Power menu button size"); readonly property string pane: "session"; readonly property string section: ""; readonly property string icon: "zoom-in"; readonly property string keywords: "session power menu button size" },
        QtObject { readonly property string id: "lock-size"; readonly property string title: qsTr("Lock screen panel width"); readonly property string pane: "lockscreen"; readonly property string section: ""; readonly property string icon: "zoom-in"; readonly property string keywords: "lock screen panel width size" },
        QtObject { readonly property string id: "look"; readonly property string title: qsTr("Look: Cozy, glow, softness"); readonly property string pane: "appearance"; readonly property string section: "look"; readonly property string icon: "mood-smile"; readonly property string keywords: "bold light weight thin motion bouncy snappy curve easing look cozy kawaii soft rounded corners glow intensity warm friendly preset reset factory" },
        QtObject { readonly property string id: "sounds"; readonly property string title: qsTr("Event sounds"); readonly property string pane: "notifications"; readonly property string section: ""; readonly property string icon: "bell"; readonly property string keywords: "sound sounds chime beep audio volume notification battery charger theme mute" },
        QtObject { readonly property string id: "wallpaper"; readonly property string title: qsTr("Wallpaper and background"); readonly property string pane: "appearance"; readonly property string section: "background"; readonly property string icon: "wallpaper"; readonly property string keywords: "desktop image background clock" },
        QtObject { readonly property string id: "notification-history"; readonly property string title: qsTr("Notification history"); readonly property string pane: "notifications"; readonly property string section: ""; readonly property string icon: "history"; readonly property string keywords: "alerts previous notifications" },
        QtObject { readonly property string id: "appearance-health"; readonly property string title: qsTr("Appearance health & sync"); readonly property string pane: "appearance"; readonly property string section: "health"; readonly property string icon: "heart-plus"; readonly property string keywords: "doctor sync palette consistency gtk" },
        QtObject { readonly property string id: "brightness"; readonly property string title: qsTr("Brightness"); readonly property string pane: "displays"; readonly property string section: ""; readonly property string icon: "brightness-half"; readonly property string keywords: "brightness backlight display dim" },
        QtObject { readonly property string id: "compositor-layout"; readonly property string title: qsTr("Compositor layout & animations"); readonly property string pane: "displays"; readonly property string section: ""; readonly property string icon: "keyframes"; readonly property string keywords: "hyprland layout scrolling dwindle master animation profile" },
        QtObject { readonly property string id: "input-restore"; readonly property string title: qsTr("Restore input defaults"); readonly property string pane: "input"; readonly property string section: ""; readonly property string icon: "reload"; readonly property string keywords: "restore defaults keyboard pointer cursor reset" },
        QtObject { readonly property string id: "diagnostics"; readonly property string title: qsTr("Diagnostics"); readonly property string pane: "system"; readonly property string section: ""; readonly property string icon: "stethoscope"; readonly property string keywords: "doctor diagnostics logs config validate health" },
        QtObject { readonly property string id: "dependencies-recovery"; readonly property string title: qsTr("Dependencies & recovery"); readonly property string pane: "updates"; readonly property string section: ""; readonly property string icon: "tools"; readonly property string keywords: "dependencies snapshots restore backup schedule deps" }
    ]

    readonly property int count: panes.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < panes.length; i++)
            result.push(panes[i].label);
        return result;
    }

    function panesForCategory(categoryId: string): list<QtObject> {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].category === categoryId)
                result.push(panes[i]);
        }
        return result;
    }

    function categoryTitle(categoryId: string): string {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === categoryId)
                return categories[i].title;
        }
        return "";
    }

    function getByIndex(index: int): QtObject {
        return index >= 0 && index < panes.length ? panes[index] : null;
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].label === label)
                return i;
        }
        return -1;
    }

    function getByLabel(label: string): QtObject {
        return getByIndex(getIndexByLabel(label));
    }

    function getById(id: string): QtObject {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id)
                return panes[i];
        }
        return null;
    }
}
