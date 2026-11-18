pragma ComponentBehavior: Bound

import "bargeometry.js" as Geo
import qs.components
import qs.components.controls
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Bar size and shape controls for the Bars pane. Every value a layout
// ships is a default, not a verdict: thickness, margin, style, density and
// edge per bar, and the cell size, content scale, density, radius, gap and
// padding for all bars. Changes are written to the live config and the real
// bars move at once (that is the preview); the strip below shows the bar to
// scale. "Reset" returns to the active layout preset's own values.
ColumnLayout {
    id: root

    // The active catalogue preset name ("" when the layout is custom).
    property string presetName: ""
    property int barIndex: 0

    readonly property var bars: Array.from(Config.bar.bars)
    readonly property var bar: root.bars[Math.min(root.barIndex, root.bars.length - 1)] ?? null
    readonly property var preset: presetFile.preset
    readonly property var presetGlobals: Geo.presetGlobals(root.preset)

    function edgeTitle(edge: string): string {
        return edge === "top" ? qsTr("Top bar") : edge === "bottom" ? qsTr("Bottom bar") : edge === "left" ? qsTr("Left bar") : qsTr("Right bar");
    }

    function commitBars(next: var): void {
        Config.bar.bars = next;
        Config.save();
    }

    function setField(field: string, value: var): void {
        root.commitBars(Geo.setBarField(root.bars, root.barIndex, field, value));
    }

    function resetBar(): void {
        root.commitBars(Geo.resetBar(root.bars, root.barIndex, root.preset));
    }

    function setSize(name: string, value: real): void {
        Config.bar.sizes[name] = Geo.clamp(name, value);
        Config.save();
    }

    function setActiveInset(value: real): void {
        Config.bar.workspaces.activeInset = Geo.clamp("activeInset", value);
        Config.save();
    }

    function setScale(group: string, value: real): void {
        Config.appearance[group].scale = Geo.clamp(group + "Scale", value);
        Config.save();
    }

    function resetGlobals(): void {
        const g = root.presetGlobals;
        Config.bar.sizes.innerWidth = g.innerWidth;
        Config.bar.sizes.islandInset = g.islandInset;
        Config.bar.workspaces.activeInset = g.activeInset;
        Config.bar.sizes.contentScale = g.contentScale;
        Config.bar.sizes.iconScale = g.iconScale;
        Config.bar.sizes.textScale = g.textScale;
        Config.bar.sizes.itemSpacing = g.itemSpacing;
        Config.bar.sizes.textWeight = g.textWeight;
        Config.bar.typeface = g.typeface;
        Config.bar.sizes.densityScale = g.densityScale;
        Config.bar.sizes.autoDensity = true;
        Config.appearance.rounding.scale = g.roundingScale;
        Config.appearance.spacing.scale = g.spacingScale;
        Config.appearance.padding.scale = g.paddingScale;
        Config.save();
    }

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    // The preset's own JSON, shipped with the shell (presets/<name>.json).
    FileView {
        id: presetFile

        property var preset: {
            try {
                return root.presetName.length > 0 && text().length > 0 ? JSON.parse(text()) : null;
            } catch (e) {
                return null;
            }
        }

        path: root.presetName.length > 0 ? `${Quickshell.shellDir}/presets/${root.presetName}.json` : ""
        blockLoading: true
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Size & shape")
        font.pointSize: Appearance.font.size.normal
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Every layout ships a tuned default. Change any of it here; the bars on your screen follow while you drag. Reset returns to what the current layout ships.")
        wrapMode: Text.WordWrap
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.smaller
    }

    Flow {
        Layout.fillWidth: true
        visible: root.bars.length > 1
        spacing: Appearance.spacing.small

        Repeater {
            model: root.bars.length

            TextButton {
                required property int index

                text: root.edgeTitle(root.bars[index]?.edge ?? "")
                toggle: true
                checked: root.barIndex === index
                type: TextButton.Tonal
                onClicked: root.barIndex = index
            }
        }
    }

    // To-scale preview of the selected bar on a 16:9 reference screen.
    Rectangle {
        id: preview

        readonly property real refW: 192
        readonly property real refH: 108
        readonly property bool vertical: root.bar ? (root.bar.edge === "left" || root.bar.edge === "right") : false
        // Reference screen is 1920x1080; one preview px is 10 screen px.
        readonly property real th: (root.bar ? root.bar.thickness : 0) / 10
        readonly property real gap: root.bar && root.bar.style !== "attached" ? root.bar.margin / 10 : 0

        visible: root.bar !== null
        Layout.preferredWidth: refW + 2
        Layout.preferredHeight: refH + 2
        color: Signal.palette.sunken
        border.width: 1
        border.color: Signal.palette.rule
        Accessible.role: Accessible.Graphic
        Accessible.name: qsTr("Preview of the %1, %2 px thick").arg(root.bar?.edge ?? "").arg(root.bar?.thickness ?? 0)

        Rectangle {
            readonly property string edge: root.bar?.edge ?? "top"

            color: Signal.palette.signal
            opacity: 0.85
            x: edge === "right" ? preview.refW - width - preview.gap + 1 : preview.gap + 1
            y: edge === "bottom" ? preview.refH - height - preview.gap + 1 : preview.gap + 1
            width: preview.vertical ? preview.th : preview.refW - preview.gap * 2
            height: preview.vertical ? preview.refH - preview.gap * 2 : preview.th
            radius: root.bar && root.bar.style !== "attached" ? 1 : 0
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.bar !== null
        spacing: Appearance.spacing.small

        SpinBoxRow {
            label: qsTr("Thickness (px)")
            value: root.bar?.thickness ?? Geo.LIMITS.thickness.fallback
            min: Geo.LIMITS.thickness.min
            max: Geo.LIMITS.thickness.max
            step: Geo.LIMITS.thickness.step
            onValueModified: value => root.setField("thickness", value)
        }

        SpinBoxRow {
            label: qsTr("Gap to screen edge (px)")
            value: root.bar?.margin ?? Geo.LIMITS.margin.fallback
            min: Geo.LIMITS.margin.min
            max: Geo.LIMITS.margin.max
            step: Geo.LIMITS.margin.step
            onValueModified: value => root.setField("margin", value)
        }

        SpinBoxRow {
            label: qsTr("Corner radius (px, -1 = style default)")
            value: root.bar?.radius ?? Geo.LIMITS.radius.fallback
            min: Geo.LIMITS.radius.min
            max: Geo.LIMITS.radius.max
            step: Geo.LIMITS.radius.step
            onValueModified: value => root.setField("radius", value)
        }

        StyledText {
            text: qsTr("Style")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
        }

        SegmentedControl {
            accessibleName: qsTr("Bar style")
            model: Geo.STYLES.map(s => s.charAt(0).toUpperCase() + s.slice(1))
            currentIndex: Math.max(0, Geo.STYLES.indexOf(root.bar?.style ?? "attached"))
            onActivated: index => root.setField("style", Geo.STYLES[index])
        }

        StyledText {
            text: qsTr("Edge")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
        }

        SegmentedControl {
            accessibleName: qsTr("Bar edge")
            model: Geo.EDGES.map(s => s.charAt(0).toUpperCase() + s.slice(1))
            currentIndex: Math.max(0, Geo.EDGES.indexOf(root.bar?.edge ?? "top"))
            onActivated: index => root.setField("edge", Geo.EDGES[index])
        }

        StyledText {
            text: qsTr("Values show numbers beside glyphs; Glyphs keeps icons only.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
        }

        SegmentedControl {
            accessibleName: qsTr("Bar density")
            model: [qsTr("Values"), qsTr("Glyphs")]
            currentIndex: root.bar?.density === "glyphs" ? 1 : 0
            onActivated: index => root.setField("density", Geo.DENSITIES[index])
        }

        TextButton {
            text: qsTr("Reset this bar")
            type: TextButton.Tonal
            Accessible.name: qsTr("Reset thickness, gap, style and density of this bar to the layout default")
            onClicked: root.resetBar()
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("All bars")
        font.pointSize: Appearance.font.size.normal
    }

    SpinBoxRow {
        label: qsTr("Cell size (px)")
        value: Config.bar.sizes.innerWidth
        min: Geo.LIMITS.innerWidth.min
        max: Geo.LIMITS.innerWidth.max
        step: Geo.LIMITS.innerWidth.step
        onValueModified: value => root.setSize("innerWidth", value)
    }

    SpinBoxRow {
        label: qsTr("Island inset (px)")
        value: Config.bar.sizes.islandInset
        min: Geo.LIMITS.islandInset.min
        max: Geo.LIMITS.islandInset.max
        step: Geo.LIMITS.islandInset.step
        onValueModified: value => root.setSize("islandInset", value)
    }

    SpinBoxRow {
        label: qsTr("Active workspace inset (px)")
        value: Config.bar.workspaces.activeInset
        min: Geo.LIMITS.activeInset.min
        max: Geo.LIMITS.activeInset.max
        step: Geo.LIMITS.activeInset.step
        onValueModified: value => root.setActiveInset(value)
    }

    SpinBoxRow {
        label: qsTr("Icon and label size (%)")
        value: Math.round(Config.bar.sizes.contentScale * 100)
        min: Geo.LIMITS.contentScale.min * 100
        max: Geo.LIMITS.contentScale.max * 100
        step: 5
        onValueModified: value => root.setSize("contentScale", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Icon size (%)")
        value: Math.round(Config.bar.sizes.iconScale * 100)
        min: Geo.LIMITS.iconScale.min * 100
        max: Geo.LIMITS.iconScale.max * 100
        step: 5
        onValueModified: value => root.setSize("iconScale", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Text size (%)")
        value: Math.round(Config.bar.sizes.textScale * 100)
        min: Geo.LIMITS.textScale.min * 100
        max: Geo.LIMITS.textScale.max * 100
        step: 5
        onValueModified: value => root.setSize("textScale", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Text weight")
        value: Config.bar.sizes.textWeight
        min: Geo.LIMITS.textWeight.min
        max: Geo.LIMITS.textWeight.max
        step: Geo.LIMITS.textWeight.step
        onValueModified: value => root.setSize("textWeight", value)
    }

    SpinBoxRow {
        label: qsTr("Space between items (%)")
        value: Math.round(Config.bar.sizes.itemSpacing * 100)
        min: Geo.LIMITS.itemSpacing.min * 100
        max: Geo.LIMITS.itemSpacing.max * 100
        step: 5
        onValueModified: value => root.setSize("itemSpacing", value / 100)
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Text face")
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.inkMuted
    }

    SegmentedControl {
        accessibleName: qsTr("Text face of bar values and labels")
        model: [qsTr("Mono (Signal)"), qsTr("Sans (clean)")]
        currentIndex: Config.bar.typeface === "sans" ? 1 : 0
        onActivated: index => {
            Config.bar.typeface = index === 1 ? "sans" : "mono";
            Config.save();
        }
    }

    SpinBoxRow {
        label: qsTr("Density (%)")
        value: Math.round(Config.bar.sizes.densityScale * 100)
        min: Geo.LIMITS.densityScale.min * 100
        max: Geo.LIMITS.densityScale.max * 100
        step: 5
        onValueModified: value => root.setSize("densityScale", value / 100)
    }

    SwitchRow {
        label: qsTr("Follow screen height")
        checked: Config.bar.sizes.autoDensity
        onToggled: checked => {
            Config.bar.sizes.autoDensity = checked;
            Config.save();
        }
    }

    SpinBoxRow {
        label: qsTr("Corner radius (%)")
        value: Math.round(Config.appearance.rounding.scale * 100)
        min: Geo.LIMITS.roundingScale.min * 100
        max: Geo.LIMITS.roundingScale.max * 100
        step: 10
        onValueModified: value => root.setScale("rounding", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Gap between items (%)")
        value: Math.round(Config.appearance.spacing.scale * 100)
        min: Geo.LIMITS.spacingScale.min * 100
        max: Geo.LIMITS.spacingScale.max * 100
        step: 5
        onValueModified: value => root.setScale("spacing", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Padding (%)")
        value: Math.round(Config.appearance.padding.scale * 100)
        min: Geo.LIMITS.paddingScale.min * 100
        max: Geo.LIMITS.paddingScale.max * 100
        step: 5
        onValueModified: value => root.setScale("padding", value / 100)
    }

    TextButton {
        text: qsTr("Reset all sizes")
        type: TextButton.Tonal
        Accessible.name: qsTr("Reset cell size, scales, text face, radius, gap and padding to the layout default")
        onClicked: root.resetGlobals()
    }
}
