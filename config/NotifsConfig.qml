import Quickshell.Io

JsonObject {
    property bool expire: true
    property int defaultExpireTimeout: 5000
    property real clearThreshold: 0.3
    property int expandThreshold: 20
    property bool actionOnClick: false
    property int groupPreviewNum: 3
    // Where popups appear along the top edge: "right", "center" or "left".
    property string align: "right"
    property bool openExpanded: false // Show the notifichation in expanded state when opening
    // Timeout line (Signal visual language §11.2): a 2 px `signal` line on
    // each expiring popup that drains with its timeout and freezes on hover.
    property bool timeoutTick: true
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property int width: 400
        property int image: 41
        property int badge: 20
    }
}
