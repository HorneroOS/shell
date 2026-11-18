pragma ComponentBehavior: Bound

import ".."
import "../../components"
import "../../../launcher/services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromatic.js" as Colour
import "../../../../services/chromaticcli.js" as Cli

// Appearance > Chromatic (RFC 0002 §13.3). A candidate palette is built by
// the helper from the wallpaper (or an image, a colour, the Signal house
// palette) and shown on a sample desktop. There is no Apply button
// (docs/CONTROL-CENTER-APPLY.md): choosing a source, variant or look applies
// it (once the controls are quiet) with an "Applied · Undo" strip, and
// hovering or focusing a variant tile only previews it. Applying goes
// through `horneroctl appearance chromatic apply` only.
CollapsibleSection {
    id: root

    required property var previewController
    required property var session

    readonly property var req: ChromaticPreview.request
    readonly property var result: ChromaticPreview.result
    readonly property var flat: root.result ? Colour.flatten(root.result.scheme) : ({})
    readonly property bool active: Config.appearance.theme === "hornero-chromatic"
    readonly property var infer: root.result ? root.result.inference : null

    title: qsTr("Chromatic")
    description: qsTr("Dynamic colour: build the desktop palette from your wallpaper, an image or one colour. Pick a source, then a variant; point at a variant to preview it on the whole desktop.")
    showBackground: true

    Component.onCompleted: {
        ChromaticPreview.probe();
        ChromaticPreview.reset();
    }
    // Leaving the section never leaves a candidate on the live shell.
    Component.onDestruction: ChromaticPreview.previewLive(false)
    // Escape ends a hover/focus preview and puts the real palette back.
    Keys.onEscapePressed: event => {
        if (ChromaticPreview.hoveredVariant !== "" || ChromaticPreview.live) {
            ChromaticPreview.endHover("");
            ChromaticPreview.previewLive(false);
            event.accepted = true;
        }
    }

    function labelFor(list: var, id: string): string {
        for (const e of list) {
            if (e.id === id)
                return e.label;
        }
        return id;
    }

    // ---- honest states ------------------------------------------------
    StyledRect {
        visible: Config.appearance.highContrast
        Layout.fillWidth: true
        implicitHeight: hcText.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.small
        color: Signal.palette.cueWell

        StyledText {
            id: hcText

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            wrapMode: Text.WordWrap
            text: qsTr("High contrast is on, so the protected high-contrast palette is shown. You can still prepare a Chromatic palette; it shows once High contrast is off.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.onCueWell
        }
    }

    StyledRect {
        visible: ChromaticPreview.hasError
        Layout.fillWidth: true
        implicitHeight: errCol.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.small
        color: ChromaticPreview.errorCode === "no-source" ? Signal.palette.signalWell : Signal.palette.alertWell
        Accessible.role: Accessible.AlertMessage
        Accessible.name: ChromaticPreview.errorTitle
        Accessible.description: ChromaticPreview.errorDetail

        ColumnLayout {
            id: errCol

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: 2

            StyledText {
                text: ChromaticPreview.errorTitle
                font.weight: Appearance.font.weight.strong
                color: ChromaticPreview.errorCode === "no-source" ? Signal.palette.onSignalWell : Signal.palette.onAlertWell
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: ChromaticPreview.errorDetail
                font.pointSize: Appearance.font.size.small
                color: ChromaticPreview.errorCode === "no-source" ? Signal.palette.onSignalWell : Signal.palette.onAlertWell
            }
        }
    }

    SwitchRow {
        label: qsTr("Use Chromatic colours")
        checked: root.active
        onToggled: checked => {
            if (checked)
                ChromaticPreview.enable();
            else
                ChromaticPreview.turnOff();
        }
    }

    StyledText {
        // The applied theme, not a variant shown while pointing at a tile.
        readonly property string appliedId: Signal.previewing && Signal._snapshot ? (Signal._snapshot.id ?? "") : Signal.themeId
        readonly property string themeName: Themes.themeById(appliedId)?.name ?? appliedId
        readonly property string fallbackName: {
            const id = Config.appearance.chromatic.fallback[Signal.themeMode] ?? "";
            return Themes.themeById(id)?.name ?? id;
        }

        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        text: root.active ? qsTr("In use. Every choice below applies as you make it; Undo puts the previous palette back.") : qsTr("Off: you are using %1. Turning Chromatic on, or choosing anything below, switches to it; turning it off returns to %2.").arg(themeName || "-").arg(fallbackName || "-")
    }

    // ---- source -------------------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        Eyebrow {
            label: qsTr("Source")
        }

        ChromaticSourceRow {
            Layout.fillWidth: true
            request: root.req
            wallpaper: ChromaticPreview.wallpaper
            seeds: root.result?.analysis?.seeds ?? []
            onSourceChosen: (kind, value) => ChromaticPreview.setSource(kind, value)
            onSeedChosen: hex => ChromaticPreview.setSource("seed", [hex])
        }
    }

    // ---- variant ------------------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        Eyebrow {
            label: qsTr("Variant")
        }

        ChromaticVariantGallery {
            Layout.fillWidth: true
            current: root.req.variant
            resolved: root.infer?.variant ?? ""
            onChosen: v => ChromaticPreview.set("variant", v)
        }
    }

    // ---- look ---------------------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        Eyebrow {
            label: qsTr("Look")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.preferredWidth: 90
                text: qsTr("Mode")
            }

            SegmentedControl {
                accessibleName: qsTr("Mode")
                model: [qsTr("Auto"), qsTr("Dark"), qsTr("Light")]
                currentIndex: Math.max(0, Cli.MODES.indexOf(root.req.mode))
                onActivated: i => ChromaticPreview.set("mode", Cli.MODES[i])
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.preferredWidth: 90
                text: qsTr("Contrast")
            }

            SegmentedControl {
                accessibleName: qsTr("Contrast")
                model: [qsTr("Auto"), qsTr("Standard"), qsTr("Boosted"), qsTr("Maximum")]
                currentIndex: Math.max(0, Cli.CONTRASTS.indexOf(root.req.contrast))
                onActivated: i => ChromaticPreview.set("contrast", Cli.CONTRASTS[i])
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.preferredWidth: 90
                text: qsTr("Surfaces")
            }

            SegmentedControl {
                accessibleName: qsTr("Surface depth")
                model: [qsTr("Standard"), qsTr("Deep")]
                currentIndex: Math.max(0, Cli.DEPTHS.indexOf(root.req.surfaceDepth))
                onActivated: i => ChromaticPreview.set("surfaceDepth", Cli.DEPTHS[i])
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Colour intensity")
            value: root.req.chroma * 100
            from: 50
            to: 150
            suffix: "%"
            validator: IntValidator {
                bottom: 50
                top: 150
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)
            onValueModified: v => ChromaticPreview.set("chroma", v / 100)
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Hue shift")
            value: root.req.hueShift
            from: -180
            to: 180
            suffix: "°"
            validator: IntValidator {
                bottom: -180
                top: 180
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)
            onValueModified: v => ChromaticPreview.set("hueShift", Math.round(v))
        }
    }

    // ---- the candidate being built, with its contrast gates ------------
    Eyebrow {
        visible: !!root.result
        label: qsTr("Candidate")
    }

    ChromaticSpecimenBoard {
        visible: !!root.result
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        palette: root.flat
        light: root.result ? root.result.scheme.mode === "light" : false
        wallpaper: root.req.source === "image" ? root.req.path : (root.req.source === "wallpaper" ? ChromaticPreview.wallpaper : "")
        minSurfaceAlpha: root.result ? (root.result.scheme.minSurfaceAlpha ?? ({})) : ({})
        opacity: ChromaticPreview.busy ? 0.6 : 1
    }

    StyledText {
        visible: ChromaticPreview.busy
        text: qsTr("Building palette…")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
    }

    ChromaticGateReport {
        Layout.fillWidth: true
        gates: root.result ? root.result.gates : null
        adjustments: root.result ? root.result.adjustments : []
    }

    // ---- smart inference ----------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.small

        Eyebrow {
            label: qsTr("What Hornero inferred")
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.infer
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            text: qsTr("Nothing to infer yet.")
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!root.infer
            wrapMode: Text.WordWrap
            font.weight: Appearance.font.weight.medium
            text: root.infer ? root.infer.personality : ""
        }

        Repeater {
            model: Cli.inferenceRows(root.infer, root.req)

            RowLayout {
                id: infRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Appearance.spacing.normal
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.overridden ? qsTr("%1: you chose %2; Hornero would pick %3").arg(modelData.label).arg(modelData.chosen).arg(modelData.inferred) : qsTr("%1: %2").arg(modelData.label).arg(modelData.inferred)

                StyledText {
                    Layout.preferredWidth: 80
                    text: infRow.modelData.label
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }

                StyledText {
                    Layout.fillWidth: true
                    mono: true
                    text: infRow.modelData.overridden ? qsTr("%1 (you chose %2)").arg(infRow.modelData.inferred).arg(infRow.modelData.chosen) : infRow.modelData.inferred
                    font.pointSize: Appearance.font.size.smaller
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!root.infer && (root.infer.reasons?.length ?? 0) > 0
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            text: root.infer ? root.infer.reasons.join(" · ") : ""
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!root.infer?.suggestion
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.signal
            text: qsTr("Suggestion: %1 suits this image. It is never applied automatically.").arg(root.infer?.suggestion ?? "")
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            text: qsTr("Every choice below overrides what was inferred. Leave a setting on Auto to follow the image.")
        }
    }

    // ---- per-mode and follow -------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        Eyebrow {
            label: qsTr("Per mode and wallpaper changes")
        }

        Repeater {
            model: [{"mode": "dark", "label": qsTr("Dark mode prefers")}, {"mode": "light", "label": qsTr("Light mode prefers")}]

            RowLayout {
                id: pm

                required property var modelData
                readonly property var ids: ["auto", "balanced", "vibrant", "expressive", "muted"]

                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.preferredWidth: 130
                    text: pm.modelData.label
                }

                SegmentedControl {
                    accessibleName: pm.modelData.label
                    model: [qsTr("Auto"), qsTr("Balanced"), qsTr("Vibrant"), qsTr("Expressive"), qsTr("Muted")]
                    currentIndex: Math.max(0, pm.ids.indexOf(Config.appearance.chromatic.perMode[pm.modelData.mode].variant))
                    onActivated: i => {
                        Config.appearance.chromatic.perMode[pm.modelData.mode].variant = pm.ids[i];
                        Config.save();
                        ChromaticPreview.regenerate();
                    }
                }
            }
        }

        SwitchRow {
            label: qsTr("Recolour automatically when the wallpaper changes")
            checked: Config.appearance.chromatic.follow === "auto"
            onToggled: checked => {
                Config.appearance.chromatic.follow = checked ? "auto" : "off";
                Config.save();
            }
        }

        SwitchRow {
            label: qsTr("Smooth palette transitions")
            checked: Config.appearance.chromatic.transition === "smooth"
            onToggled: checked => {
                Config.appearance.chromatic.transition = checked ? "smooth" : "instant";
                Config.save();
            }
        }
    }

    // ---- actions ------------------------------------------------------
    StyledText {
        visible: ChromaticPreview.applyError !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Signal.palette.alert
        text: qsTr("Could not apply: %1").arg(ChromaticPreview.applyError)
        Accessible.role: Accessible.AlertMessage
    }

    StyledText {
        visible: ChromaticPreview.notice !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        text: ChromaticPreview.notice
        Accessible.role: Accessible.StaticText
    }

    StyledText {
        visible: ChromaticPreview.applying
        text: qsTr("Applying…")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        Accessible.role: Accessible.StaticText
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        TextButton {
            text: qsTr("Previous palette")
            type: TextButton.Text
            onClicked: ChromaticPreview.rollback()
        }
    }

    // ---- saved palettes -----------------------------------------------
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        Eyebrow {
            label: qsTr("Save this palette")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledTextField {
                id: saveName

                Layout.fillWidth: true
                placeholderText: qsTr("Name this palette")
                Accessible.name: qsTr("Palette name")
                onAccepted: saveBtn.clicked()
            }

            TextButton {
                id: saveBtn

                text: qsTr("Save")
                type: TextButton.Tonal
                disabled: !root.result
                onClicked: {
                    ChromaticPreview.saveAs("", saveName.text);
                    saveName.text = "";
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            text: qsTr("Saving keeps the palette in use as a theme: it is listed under Themes, Your palettes, where pointing previews it and a click uses it (with Undo). To remove one, delete its folder under hornero/themes in your data directory.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledTextField {
                id: ioPath

                Layout.fillWidth: true
                placeholderText: qsTr("/path/to/palette.json")
                Accessible.name: qsTr("Palette file path")
            }

            TextButton {
                text: qsTr("Export")
                type: TextButton.Tonal
                onClicked: ChromaticPreview.exportTo(ioPath.text)
            }

            TextButton {
                text: qsTr("Import")
                type: TextButton.Tonal
                onClicked: ChromaticPreview.importFrom(ioPath.text)
            }
        }
    }

    Connections {
        target: ChromaticPreview

        function onSavedPalettesChanged(): void {
            Themes.reload();
        }
    }
}
