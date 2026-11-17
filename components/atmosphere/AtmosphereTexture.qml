import qs.services
import qs.config
import Quickshell
import QtQuick

// Film grain and optional scanlines (visual language section 17). Drop it
// as the FIRST child of a surface so the texture sits behind the content:
// text and glyphs stay crisp, only the surface itself is textured. Strength
// comes from Atmosphere.levels (user knobs, hard-capped); it never takes
// input and is hidden from assistive tech.
Item {
    id: root

    property bool grain: true
    property bool scanlines: true

    readonly property var lv: Atmosphere.levels

    anchors.fill: parent
    enabled: false
    clip: true
    visible: Atmosphere.active && width > 0 && height > 0
    Accessible.ignored: true

    Image {
        anchors.fill: parent
        visible: root.grain && root.lv.grain > 0
        source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/atmosphere/grain.png`)
        fillMode: Image.Tile
        smooth: false
        opacity: root.lv.grain
        asynchronous: true
    }

    // Faint horizontal lines, off unless the user raises the strength.
    Image {
        anchors.fill: parent
        visible: root.scanlines && root.lv.scanlines > 0
        source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/atmosphere/scanlines.png`)
        fillMode: Image.Tile
        smooth: false
        opacity: root.lv.scanlines / 0.06
        asynchronous: true
    }
}
