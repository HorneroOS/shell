import Quickshell.Io

JsonObject {
    property bool enabled: true
    property int hideDelay: 2000
    // Where the OSD sits along the right edge: "top", "center" or "bottom".
    property string align: "center"
    property bool enableBrightness: true
    property bool enableMicrophone: false
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property int sliderWidth: 30
        property int sliderHeight: 150
    }
}
