pragma Singleton

import QtQuick

// Canonical Settings destinations and their user-facing discovery metadata.
// `id` and `label` remain stable route keys for IPC, Welcome, and Session;
// `title`, `category`, and `keywords` describe how people find them.
QtObject {
    id: root

    readonly property list<QtObject> categories: [
        QtObject { readonly property string id: "connectivity"; readonly property string title: qsTr("Connectivity") },
        QtObject { readonly property string id: "personalization"; readonly property string title: qsTr("Personalization") },
        QtObject { readonly property string id: "sound-alerts"; readonly property string title: qsTr("Sound & alerts") },
        QtObject { readonly property string id: "system"; readonly property string title: qsTr("System") }
    ]

    readonly property list<QtObject> panes: [
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string title: qsTr("Network")
            readonly property string icon: "router"
            readonly property string component: "network/NetworkingPane.qml"
            readonly property string category: "connectivity"
            readonly property string description: qsTr("Wi-Fi, wired networks, and connections")
            readonly property list<string> keywords: ["wifi", "wi-fi", "ethernet", "internet", "wireless"]
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string title: qsTr("Bluetooth")
            readonly property string icon: "settings_bluetooth"
            readonly property string component: "bluetooth/BtPane.qml"
            readonly property string category: "connectivity"
            readonly property string description: qsTr("Pair and manage nearby devices")
            readonly property list<string> keywords: ["pair", "headphones", "mouse", "keyboard", "devices"]
        },
        QtObject {
            readonly property string id: "vpn"
            readonly property string label: "vpn"
            readonly property string title: "VPN"
            readonly property string icon: "vpn_key"
            readonly property string component: "vpn/VpnPane.qml"
            readonly property string category: "connectivity"
            readonly property string description: qsTr("Manage private network connections")
            readonly property list<string> keywords: ["virtual private network", "wireguard", "netbird", "tunnel"]
        },
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string title: qsTr("Appearance")
            readonly property string icon: "palette"
            readonly property string component: "appearance/AppearancePane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Themes, colors, wallpaper, and visual effects")
            readonly property list<string> keywords: ["theme", "wallpaper", "dark mode", "light mode", "color", "font", "transparency", "motion"]
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string title: qsTr("Bars")
            readonly property string icon: "task_alt"
            readonly property string component: "taskbar/TaskbarPane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Configure desktop bars and panels")
            readonly property list<string> keywords: ["taskbar", "panel", "rail", "dock", "island", "status bar"]
        },
        QtObject {
            readonly property string id: "layout"
            readonly property string label: "layout"
            readonly property string title: qsTr("Layout")
            readonly property string icon: "dashboard_customize"
            readonly property string component: "layout/LayoutPane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Arrange bars and desktop surfaces")
            readonly property list<string> keywords: ["preset", "topology", "position", "screen layout"]
        },
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string title: qsTr("Launcher")
            readonly property string icon: "apps"
            readonly property string component: "launcher/LauncherPane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Choose how search and app launch work")
            readonly property list<string> keywords: ["search", "applications", "shortcuts"]
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string title: qsTr("Dashboard")
            readonly property string icon: "dashboard"
            readonly property string component: "dashboard/DashboardPane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Choose dashboard content and behavior")
            readonly property list<string> keywords: ["weather", "location", "widgets", "desktop"]
        },
        QtObject {
            readonly property string id: "companion"
            readonly property string label: "companion"
            readonly property string title: qsTr("Companion")
            readonly property string icon: "raven"
            readonly property string component: "companion/CompanionPane.qml"
            readonly property string category: "personalization"
            readonly property string description: qsTr("Configure the Hornero desktop companion")
            readonly property list<string> keywords: ["mascot", "pet", "character"]
        },
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string title: qsTr("Audio")
            readonly property string icon: "volume_up"
            readonly property string component: "audio/AudioPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Choose devices and adjust sound")
            readonly property list<string> keywords: ["volume", "microphone", "speaker", "output", "input"]
        },
        QtObject {
            readonly property string id: "notifications"
            readonly property string label: "notifications"
            readonly property string title: qsTr("Notifications")
            readonly property string icon: "notifications"
            readonly property string component: "notifications/NotificationsPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Choose when and how notifications appear")
            readonly property list<string> keywords: ["history", "do not disturb", "dnd", "quiet", "alerts"]
        },
        QtObject {
            readonly property string id: "osd"
            readonly property string label: "osd"
            readonly property string title: qsTr("On-screen display")
            readonly property string icon: "tune"
            readonly property string component: "osd/OsdPane.qml"
            readonly property string category: "sound-alerts"
            readonly property string description: qsTr("Configure on-screen volume and brightness feedback")
            readonly property list<string> keywords: ["osd", "volume popup", "brightness popup", "feedback"]
        },
        QtObject {
            readonly property string id: "system"
            readonly property string label: "system"
            readonly property string title: qsTr("System")
            readonly property string icon: "build"
            readonly property string component: "system/SystemPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("System information and diagnostics")
            readonly property list<string> keywords: ["about", "hardware", "diagnostics", "version"]
        },
        QtObject {
            readonly property string id: "updates"
            readonly property string label: "updates"
            readonly property string title: qsTr("Updates")
            readonly property string icon: "system_update"
            readonly property string component: "updates/UpdatesPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("Review available system updates")
            readonly property list<string> keywords: ["upgrade", "packages", "maintenance"]
        },
        QtObject {
            readonly property string id: "power"
            readonly property string label: "power"
            readonly property string title: qsTr("Power")
            readonly property string icon: "power_settings_new"
            readonly property string component: "power/PowerPane.qml"
            readonly property string category: "system"
            readonly property string description: qsTr("Battery and power behavior")
            readonly property list<string> keywords: ["battery", "sleep", "suspend", "shutdown"]
        }
    ]

    // Searchable controls that deserve a direct destination. Keep these
    // labels and aliases here beside the pane routes; search never scrapes
    // QML or exposes implementation-only control names.
    readonly property list<QtObject> searchTargets: [
        QtObject { readonly property string id: "themes"; readonly property string title: qsTr("Themes"); readonly property string pane: "appearance"; readonly property string section: "themes"; readonly property string icon: "palette"; readonly property string keywords: "theme look style hornero pampa catppuccin" },
        QtObject { readonly property string id: "dark-mode"; readonly property string title: qsTr("Light and dark mode"); readonly property string pane: "appearance"; readonly property string section: "themeMode"; readonly property string icon: "dark_mode"; readonly property string keywords: "dark light mode brightness" },
        QtObject { readonly property string id: "colors"; readonly property string title: qsTr("Wallpaper colors"); readonly property string pane: "appearance"; readonly property string section: "colorScheme"; readonly property string icon: "colorize"; readonly property string keywords: "dynamic accent palette color scheme wallpaper" },
        QtObject { readonly property string id: "generation"; readonly property string title: qsTr("Color generation"); readonly property string pane: "appearance"; readonly property string section: "colorVariant"; readonly property string icon: "auto_awesome"; readonly property string keywords: "material algorithm vibrant expressive fidelity" },
        QtObject { readonly property string id: "gtk"; readonly property string title: qsTr("GTK apps"); readonly property string pane: "appearance"; readonly property string section: "gtkTheme"; readonly property string icon: "web_asset"; readonly property string keywords: "gtk theme applications manual override" },
        QtObject { readonly property string id: "icons"; readonly property string title: qsTr("Icon theme"); readonly property string pane: "appearance"; readonly property string section: "iconTheme"; readonly property string icon: "insert_emoticon"; readonly property string keywords: "icons papirus numix" },
        QtObject { readonly property string id: "fonts"; readonly property string title: qsTr("Fonts"); readonly property string pane: "appearance"; readonly property string section: "fonts"; readonly property string icon: "text_fields"; readonly property string keywords: "font typography typeface" },
        QtObject { readonly property string id: "motion"; readonly property string title: qsTr("Motion and animation"); readonly property string pane: "appearance"; readonly property string section: "animations"; readonly property string icon: "motion_photos_on"; readonly property string keywords: "reduce motion disable animations accessibility" },
        QtObject { readonly property string id: "scale"; readonly property string title: qsTr("Interface size"); readonly property string pane: "appearance"; readonly property string section: "scales"; readonly property string icon: "zoom_in"; readonly property string keywords: "scale sizing density text size" },
        QtObject { readonly property string id: "transparency"; readonly property string title: qsTr("Transparency"); readonly property string pane: "appearance"; readonly property string section: "transparency"; readonly property string icon: "opacity"; readonly property string keywords: "blur opacity glass launcher notifications" },
        QtObject { readonly property string id: "wallpaper"; readonly property string title: qsTr("Wallpaper and background"); readonly property string pane: "appearance"; readonly property string section: "background"; readonly property string icon: "wallpaper"; readonly property string keywords: "desktop image background clock" },
        QtObject { readonly property string id: "notification-history"; readonly property string title: qsTr("Notification history"); readonly property string pane: "notifications"; readonly property string section: ""; readonly property string icon: "history"; readonly property string keywords: "alerts previous notifications" }
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
