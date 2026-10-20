import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "tune"
        title: qsTr("Control Center")
        subtitle: qsTr("Everything configurable lives in one place — and it is all searchable.")
    }

    ActionCard {
        icon: "search"
        title: qsTr("Search any setting")
        description: qsTr("The Control Center search jumps straight to a setting: try “gtk”, “sleep” or “vpn”. Every pane and section is indexed.")
        onActivated: Actions.openControlCenter("appearance")
    }

    ActionCard {
        icon: "palette"
        title: qsTr("Personalization")
        description: qsTr("Appearance and Hornero themes, bars and layout, launcher, dashboard — and Javi, your companion.")
        onActivated: Actions.openControlCenter("appearance")
    }

    ActionCard {
        icon: "wifi"
        title: qsTr("Connectivity & sound")
        description: qsTr("Network, Bluetooth and VPN; audio, notifications and on-screen displays.")
        onActivated: Actions.openControlCenter("network")
    }

    ActionCard {
        icon: "settings"
        title: qsTr("System")
        description: qsTr("System info, extensions and plugins, updates, terminal and power — including lock screen and session behavior.")
        onActivated: Actions.openControlCenter("system")
    }

    ActionCard {
        icon: "accessibility"
        title: qsTr("Comfort first")
        description: qsTr("Text size, calmer motion and transparency live under Accessibility — Javi honors them too.")
        onActivated: Actions.openControlCenter("accessibility")
    }

    ActionCard {
        icon: "extension"
        title: qsTr("Extensions & plugins")
        description: qsTr("Community plugins and their widgets are managed in Extensions. Plugins run as your user — enable only ones you trust.")
        onActivated: Actions.openControlCenter("extensions")
    }

    ActionCard {
        icon: "restart_alt"
        title: qsTr("Changes apply instantly")
        description: qsTr("Most settings take effect as you toggle them, with no restart and no config files to edit by hand.")
        interactive: false
    }
}
