import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "apps"
        title: qsTr("Set up your apps")
        subtitle: qsTr("Pick an optional workstation profile to preview and queue curated applications. You can skip this and install apps anytime from Hornero Apps.")
    }

    AppsProfilePanel {}

    ActionCard {
        primary: true
        icon: "apps"
        title: qsTr("Open Hornero Apps")
        description: qsTr("Browse all curated collections, AI tools, verified Flatpaks, and native Arch packages.")
        onActivated: Actions.openApps("discover")
    }
}
