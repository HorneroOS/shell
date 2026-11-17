import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "hand-stop"
        title: qsTr("Welcome to Hornero")
        subtitle: qsTr("Your desktop is ready. Open the launcher to start anything, or take the tour below — and switch off automatic opening at the bottom whenever you like.")
    }

    EditionPanel {}

    ActionCard {
        icon: "adjustments-horizontal"
        title: qsTr("Choose a mode")
        description: qsTr("Everyday is the default. Focus, Signal, Studio and Gaming are set in Settings.")
        onActivated: Actions.openControlCenter("experience")
    }

    ActionCard {
        icon: "compass"
        title: qsTr("Take the tour")
        description: qsTr("Eight short sections: navigation, shell, workspaces, look and feel, tools, system and learning.")
        onActivated: Actions.openWelcome("navigate")
    }

    ActionCard {
        icon: "apps"
        title: qsTr("Open the launcher")
        description: qsTr("Every app, action and setting, one key away.")
        shortcutId: "exec-launcher"
        onActivated: Actions.openLauncher()
    }
}
