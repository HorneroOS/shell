import Quickshell.Io

JsonObject {
    property string logo: ""
    // Shell UI language: "auto" follows the system (LANGUAGE/LC_MESSAGES/
    // LANG), "en" forces English, "es_AR" forces Argentine Spanish.
    // See docs/I18N.md and services/Language.qml.
    property string language: "auto"
    property Apps apps: Apps {}
    property Idle idle: Idle {}
    property Battery battery: Battery {}

    component Apps: JsonObject {
        property list<string> terminal: ["kitty"]
        property list<string> audio: ["pavucontrol"]
        property list<string> playback: ["mpv"]
        property list<string> explorer: ["thunar"]
    }

    component Idle: JsonObject {
        property bool lockBeforeSleep: true
        property bool inhibitWhenAudio: true
        property list<var> timeouts: [
            {
                timeout: 180,
                idleAction: "lock"
            },
            {
                timeout: 300,
                idleAction: "dpms off",
                returnAction: "dpms on"
            },
            {
                timeout: 600,
                idleAction: ["systemctl", "suspend-then-hibernate"]
            }
        ]
    }

    component Battery: JsonObject {
        property list<var> warnLevels: [
            {
                level: 20,
                title: qsTr("Low battery"),
                message: qsTr("You might want to plug in a charger"),
                icon: "battery-2"
            },
            {
                level: 10,
                title: qsTr("Did you see the previous message?"),
                message: qsTr("You should probably plug in a charger <b>now</b>"),
                icon: "battery-1"
            },
            {
                level: 5,
                title: qsTr("Critical battery level"),
                message: qsTr("PLUG THE CHARGER RIGHT NOW!!"),
                icon: "battery-exclamation",
                critical: true
            },
        ]
        property int criticalLevel: 3
    }
}
