import Quickshell.Io

JsonObject {
    property bool recolourLogo: false
    // Privacy default: lock screen shows the notification placeholder,
    // never bodies. Reversible in Settings > Notifications.
    property bool hideNotifs: true
    property bool enableFprint: true
    // Optional 45° La Plata hairline on the lock's lower left. Off by
    // default: without context it reads as a stray rendering line.
    property bool diagonalRule: false
    property int maxFprintTries: 3
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property real heightMult: 0.7
        property real ratio: 16 / 9
        property int centerWidth: 600
    }
}
