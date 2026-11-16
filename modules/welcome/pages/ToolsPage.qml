import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "tools"
        title: qsTr("Tools")
        subtitle: qsTr("Small utilities, exactly where you expect them.")
    }

    ActionCard {
        icon: "screenshot"
        title: qsTr("Screenshot")
        description: qsTr("Capture a screen, a window or a selection.")
        shortcutId: "exec-screenshooter"
        interactive: false
    }

    ActionCard {
        icon: "clipboard"
        title: qsTr("Clipboard history")
        description: qsTr("Everything you copied, searchable.")
        shortcutId: "exec-clipboard"
        interactive: false
    }

    ActionCard {
        icon: "power"
        title: qsTr("Power menu")
        description: qsTr("Suspend, reboot or shut down without leaving the keyboard.")
        shortcutId: "exec-power-menu"
        interactive: false
    }

    ActionCard {
        icon: "apps"
        title: qsTr("Utilities drawer")
        description: qsTr("Timers, converters and quick tools from the bar.")
        onActivated: Actions.openUtilities()
    }
}
