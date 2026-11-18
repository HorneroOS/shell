pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromaticcli.js" as Cli
import "../../../../services/chromatic.js" as Colour
import ".."

// Variant chooser (RFC 0002 §6): Auto plus the eight variants, each with
// an honest one-line description. A tile is a radio: arrows move, Space or
// Enter choose. `resolved` marks the variant the engine actually used.
ColumnLayout {
    id: root

    // "auto" or a variant id.
    property string current: "auto"
    property string resolved: ""

    signal chosen(string variant)

    spacing: Appearance.spacing.small
    Accessible.role: Accessible.RadioButton
    Accessible.name: qsTr("Variant")

    // Palettes are only computed while the gallery exists.
    Component.onCompleted: {
        ChromaticPreview.variantPreviewsWanted = true;
    }
    Component.onDestruction: {
        ChromaticPreview.endHover("");
        ChromaticPreview.variantPreviewsWanted = false;
    }

    // chromaticcli.js stays plain JS (node-tested): its variant labels and
    // descriptions are marked here and shown through qsTr() (docs/I18N.md).
    readonly property list<string> translatableVariants: [
        QT_TR_NOOP("Balanced"),
        QT_TR_NOOP("Signal Night or Day re-hued to the wallpaper. Quiet surfaces, one confident accent."),
        QT_TR_NOOP("Vibrant"),
        QT_TR_NOOP("Stronger accents and lightly tinted chrome. Best on colourful images."),
        QT_TR_NOOP("Expressive"),
        QT_TR_NOOP("A second accent hue from the image when it has one; more varied status colours."),
        QT_TR_NOOP("Faithful"),
        QT_TR_NOOP("The image's own dominant colour becomes the accent when it passes the contrast gates."),
        QT_TR_NOOP("Muted"),
        QT_TR_NOOP("Near-neutral chrome with soft accents. Calm; hue is a whisper."),
        QT_TR_NOOP("Monochrome"),
        QT_TR_NOOP("Neutral chrome and ink; accents hint at the seed hue. Status colours keep their meaning."),
        QT_TR_NOOP("High contrast"),
        QT_TR_NOOP("Maximum gates (7:1), deeper ground, brighter ink, no glow, no translucency. A look, not the accessibility switch."),
        QT_TR_NOOP("Neon"),
        QT_TR_NOOP("Dark only. Saturated complementary accents and glow. Never chosen automatically.")
    ]

    readonly property var tiles: [{
            "id": "auto",
            "label": qsTr("Auto"),
            "description": qsTr("Let Hornero pick from the image: Balanced, Vibrant, Expressive or Muted. Never Neon, Faithful, Monochrome or High contrast.")
        }].concat(Cli.VARIANTS)

    // The scheme a tile shows: the variant's own engine result for the
    // current source, or (Auto) the one Hornero actually resolved to.
    function schemeFor(id: string): var {
        const key = id === "auto" ? resolved : id;
        if (key && ChromaticPreview.variantSchemes[key])
            return ChromaticPreview.variantSchemes[key];
        return id === "auto" && ChromaticPreview.result ? ChromaticPreview.result.scheme : null;
    }

    function failedFor(id: string): bool {
        return id !== "auto" && ChromaticPreview.variantFailed[id] === true;
    }

    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(3, Math.floor(width / 190)))
        columnSpacing: Appearance.spacing.small
        rowSpacing: Appearance.spacing.small

        Repeater {
            model: root.tiles

            PaletteOption {
                id: tile

                required property var modelData
                required property int index

                readonly property var scheme: root.schemeFor(modelData.id)
                readonly property bool unavailable: root.failedFor(modelData.id)
                readonly property var flat: scheme ? Colour.flatten(scheme) : ({})

                Layout.fillWidth: true
                Layout.fillHeight: true
                title: qsTr(modelData.label)
                note: unavailable ? qsTr("No preview: this variant is not available for the current source and mode.") : qsTr(modelData.description)
                badge: root.resolved === modelData.id ? qsTr("in use") : ""
                selected: root.current === modelData.id
                tabStop: index === 0 || selected
                pending: !scheme && !unavailable
                palette: flat
                paletteLabel: scheme ? qsTr("Palette preview: ground %1, accent %2").arg(flat.ground ?? "").arg(flat.signal ?? "") : ""
                // Previews on the live desktop while pointed at or focused,
                // unless the user turned hover previews off.
                onPreviewStarted: {
                    if (Config.controlCenter.appearanceHoverPreview)
                        ChromaticPreview.hoverVariant(modelData.id === "auto" ? root.resolved : modelData.id);
                }
                onPreviewEnded: ChromaticPreview.endHover(modelData.id === "auto" ? root.resolved : modelData.id)
                onActivated: root.chosen(modelData.id)
                onStep: direction => root.chosen(root.tiles[(index + direction + root.tiles.length) % root.tiles.length].id)
            }
        }
    }
}
