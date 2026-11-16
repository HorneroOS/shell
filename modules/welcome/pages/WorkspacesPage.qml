import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "dashboard"
        title: qsTr("Workspaces")
        subtitle: qsTr("One workspace per task. The keys never change, in every session.")
    }

    ActionCard {
        icon: "square-number-1"
        title: qsTr("Switch workspace")
        description: qsTr("Jump straight to any numbered workspace.")
        shortcutId: "workspace:1"
        interactive: false
    }

    ActionCard {
        icon: "arrows-move"
        title: qsTr("Send a window")
        description: qsTr("Move the focused window to a workspace, following it yourself.")
        shortcutId: "movetoworkspace:1"
        interactive: false
    }

    ActionCard {
        icon: "pin"
        title: qsTr("Scratchpad")
        description: qsTr("Park a window off-grid and summon it over any workspace.")
        shortcutId: "togglespecialworkspace:magic"
        interactive: false
    }
}
