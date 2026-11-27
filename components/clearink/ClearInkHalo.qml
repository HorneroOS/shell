import QtQuick
import Quickshell

// Glyph/text-only halo and soft shadow for Cockpit Clear / clear bars
// (signal-visual-language §12.1): wraps a target item's dilated silhouette
// in a subtle 1 px rim and soft shadow without drawing any background box.
ShaderEffect {
    id: root

    required property Item sourceItem
    required property var tone
    property bool active: false

    readonly property var fx: tone?.effect ?? ({
            enabled: false,
            outlinePx: 0,
            shadowPx: 0,
            alpha: 0,
            shadowAlpha: 0,
            shadowDy: 0,
            pad: 0
        })
    readonly property real pad: root.fx.pad
    property var source: haloSource
    property color haloOnLight: root.tone?.haloOnLight ?? "#0C0F13"
    property color haloOnDark: root.tone?.haloOnDark ?? "#FFFFFF"
    property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
    property real outlinePx: root.fx.outlinePx
    property real shadowPx: root.fx.shadowPx
    property real haloAlpha: root.fx.alpha
    property real shadowAlpha: root.fx.shadowAlpha
    property real shadowDy: root.fx.shadowDy

    visible: root.active && root.sourceItem !== null && root.fx.enabled
    x: -root.pad
    y: -root.pad
    z: -1
    width: (root.sourceItem?.width ?? 0) + root.pad * 2
    height: (root.sourceItem?.height ?? 0) + root.pad * 2
    fragmentShader: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/shaders/clearinkhalo.frag.qsb`)

    ShaderEffectSource {
        id: haloSource

        sourceItem: root.sourceItem
        sourceRect: Qt.rect(-root.pad, -root.pad, root.width, root.height)
        hideSource: false
        live: true
        visible: false
    }
}
