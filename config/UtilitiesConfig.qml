import Quickshell.Io

JsonObject {
    property bool enabled: true
    property int maxToasts: 4

    property Sizes sizes: Sizes {}
    property Toasts toasts: Toasts {}
    property Vpn vpn: Vpn {}

    component Sizes: JsonObject {
        property int width: 430
        property int toastWidth: 430
    }

    component Toasts: JsonObject {
        // Routine notices stay out of the way unless the user opts in:
        // errors still toast regardless.
        property bool configLoaded: false
        property bool chargingChanged: true
        property bool dndChanged: true
        property bool audioOutputChanged: true
        property bool audioInputChanged: true
        property bool capsLockChanged: true
        property bool numLockChanged: false
        property bool kbLayoutChanged: true
        property bool kbLimit: true
        property bool vpnChanged: true
        property bool nowPlaying: false
        // Set once the one-shot quiet-routine migration has run, so a
        // later opt-in to a routine toast is never reset.
        property bool routineQuiet: false
    }

    component Vpn: JsonObject {
        property bool enabled: false
        property list<var> provider: ["netbird"]
    }
}
