import qs.modules.welcome
import ".."

PageView {
    PageHeader {
        icon: "raven"
        title: qsTr("Javi, your assistant")
        subtitle: qsTr("El Hornero: a sidekick that can chat, look at your system, and help — always asking first.")
    }

    ActionCard {
        icon: "chat"
        title: qsTr("Chat with Javi")
        description: qsTr("Ask anything: updates, disk, themes. Javi reads the system through horneroctl and answers in the chat panel, streaming live.")
        interactive: false
    }

    ActionCard {
        icon: "mic"
        title: qsTr("Talk, don't type")
        description: qsTr("Hold a voice note from the mic button: Hermes transcribes it and treats it as your message.")
        interactive: false
    }

    ActionCard {
        icon: "attach_file"
        title: qsTr("Attach files")
        description: qsTr("Screenshots, logs and notes can ride along. Secret-looking files (keys, .env) are refused before anything is sent.")
        interactive: false
    }

    ActionCard {
        icon: "approval"
        title: qsTr("Nothing changes without your OK")
        description: qsTr("When Javi wants to change something, the chat shows exactly what and waits. Approve or deny — it is never auto-answered.")
        interactive: false
    }

    ActionCard {
        icon: "settings"
        title: qsTr("Make Javi yours")
        description: qsTr("Skin, size, streaming and history live in Control Center › Javi. Hermes is optional, local-only (loopback), and off unless you enable it.")
        onActivated: Actions.openControlCenter("companion")
    }
}
