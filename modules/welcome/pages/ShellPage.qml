import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "terminal"
        title: qsTr("Shell")
        subtitle: qsTr("A terminal is always one key away, in the workspace where you need it.")
    }

    ActionCard {
        icon: "terminal"
        title: qsTr("Open a terminal")
        description: qsTr("Your configured terminal, ready in the current workspace.")
        shortcutId: "app-terminalemulator"
        onActivated: Actions.openTerminal()
    }

    ActionCard {
        icon: "terminal"
        title: qsTr("Yazi in the configured terminal")
        description: qsTr("Browse files in a separate window with the terminal you selected.")
        shortcutId: "exec-terminal-file"
        interactive: false
    }
}
