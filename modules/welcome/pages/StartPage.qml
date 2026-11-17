import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "hand-stop"
        title: qsTr("Welcome to Hornero")
        subtitle: qsTr("Your desktop is ready. Take the short tour, or open the launcher to start anything. You can switch off automatic opening at the bottom whenever you like.")
    }

    ActionCard {
        primary: true
        icon: "compass"
        title: qsTr("Take the tour")
        description: qsTr("Eight short sections: navigation, shell, workspaces, look and feel, tools, system and learning.")
        onActivated: Actions.openWelcome("navigate")
    }

    EditionPanel {}

    ActionCard {
        icon: "apps"
        title: qsTr("Open the launcher")
        description: qsTr("Every app, action and setting, one key away.")
        shortcutId: "exec-launcher"
        onActivated: Actions.openLauncher()
    }

    ActionCard {
        icon: "adjustments-horizontal"
        title: qsTr("Choose a mode")
        description: qsTr("Everyday is the default. Focus, Signal, Studio and Gaming are set in Settings.")
        onActivated: Actions.openControlCenter("experience")
    }
}
