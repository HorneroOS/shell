pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts
import "./sections"
import "../../../services/chromatic.js" as Colour
import "../../../services/chromaticcli.js" as Cli

// Appearance preview (docs/APPEARANCE-PANE.md). One banner says which of
// three states it is in: "Now using" (what is applied), "Previewing" (what
// you point at or focus; nothing is applied until you click) or "Applying".
// Below it, the same sample desktop Chromatic uses (bar, popout, launcher,
// notification, terminal colours), drawn only from the previewed palette,
// and measured WCAG contrast for that palette. The recipe (GTK, icons,
// wallpaper pack) is one click away under Details.
StyledRect {
    id: root

    required property bool active
    required property string source
    required property string titleText
    required property string subtitleText
    property string readinessDetails: ""
    required property string modeText
    required property string wallpaperPath
    required property var rootPane

    property string gtkThemeText: ""
    property string iconThemeText: ""
    property string gtkPreferText: ""
    property string wallpaperLabel: ""
    property string themeIdText: ""
    property var tags: []
    property int wallpaperCount: 0
    property bool showAdvancedDetails: false
    // "now" | "previewing" | "applying" (AppearancePane.previewState).
    property string previewState: "now"
    property bool hoverEnabled: true

    readonly property bool isThemePreview: source === "theme"
    readonly property bool hasRecipe: {
        return !!modeText || !!gtkThemeText || !!iconThemeText || !!gtkPreferText || !!wallpaperLabel || (tags && tags.length > 0);
    }
    readonly property bool showVisualSamples: active && showAdvancedDetails && (!!gtkThemeText || !!iconThemeText)

    function modeLabel(mode: string): string {
        return mode === "light" ? qsTr("Light") : qsTr("Dark");
    }

    function gtkColorSchemeLabel(value: string): string {
        switch ((value || "").toLowerCase()) {
        case "follow":
            return qsTr("Follow theme mode");
        case "default":
        case "auto":
            return qsTr("Auto (apps decide)");
        case "prefer-light":
        case "light":
            return qsTr("Prefer light");
        case "prefer-dark":
        case "dark":
            return qsTr("Prefer dark");
        default:
            return value || "—";
        }
    }

    function gtkColorSchemeIcon(value: string): string {
        switch ((value || "").toLowerCase()) {
        case "follow":
            return "refresh";
        case "default":
        case "auto":
            return "contrast";
        case "prefer-light":
        case "light":
            return "sun";
        default:
            return "moon";
        }
    }

    function gtkThumbnailCandidates(theme: string): var {
        if (!theme || theme === "auto")
            return [];
        const home = Paths.home;
        const data = Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`;
        return [
            `/usr/share/themes/${theme}/gtk-3.0/thumbnail.png`,
            `/usr/share/themes/${theme}/cinnamon/thumbnail.png`,
            `/usr/share/themes/${theme}/metacity-1/thumbnail.png`,
            `${data}/themes/${theme}/gtk-3.0/thumbnail.png`,
            `${data}/themes/${theme}/cinnamon/thumbnail.png`,
            `${home}/.themes/${theme}/gtk-3.0/thumbnail.png`
        ];
    }

    function iconSampleCandidates(theme: string, name: string): var {
        if (!theme || !name)
            return [];
        const home = Paths.home;
        const data = Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`;
        const roots = [`/usr/share/icons/${theme}`, `${data}/icons/${theme}`, `${home}/.icons/${theme}`];
        // Prefer common layouts first (Numix/Papirus size/cat, Adwaita scalable, Breeze cat/size).
        const rels = [
            `48/apps/${name}.svg`, `48/places/${name}.svg`, `48/categories/${name}.svg`,
            `48x48/apps/${name}.svg`, `48x48/places/${name}.svg`,
            `scalable/apps/${name}.svg`, `scalable/places/${name}.svg`, `scalable/categories/${name}.svg`,
            `32/apps/${name}.svg`, `32/places/${name}.svg`,
            `apps/64/${name}.svg`, `places/64/${name}.svg`, `categories/64/${name}.svg`,
            `apps/48/${name}.svg`, `places/48/${name}.svg`,
            `48/apps/${name}.png`, `48/places/${name}.png`, `scalable/places/${name}.png`
        ];
        const out = [];
        for (let r = 0; r < roots.length; r++) {
            for (let i = 0; i < rels.length; i++)
                out.push(`${roots[r]}/${rels[i]}`);
        }
        return out;
    }

    // Complete flat role map for the specimen: the previewed palette over
    // the applied roles (a registry listing may carry only a partial
    // swatch), plus term0..term15.
    // A Chromatic style pointed at in the gallery is shown on the whole
    // desktop; the specimen shows that same scheme.
    readonly property string hoverStyle: ChromaticPreview.hoveredVariant
    readonly property var hoverScheme: hoverStyle !== "" ? (ChromaticPreview.variantSchemes[hoverStyle] ?? null) : null
    readonly property string shownTitle: hoverScheme ? qsTr("Chromatic · %1").arg(Cli.styleLabel(hoverStyle)) : titleText

    readonly property var flat: {
        const out = {};
        const p = root.hoverScheme ? Colour.flatten(root.hoverScheme) : (root.rootPane.previewPalette ?? {});
        const live = root.rootPane.liveColors();
        for (const role of Signal.roles) {
            const v = p[role] ?? live[role];
            if (v)
                out[role] = String(v).toUpperCase();
        }
        out.glow = String(p.glow ?? out.signal ?? "");
        const term = !root.hoverScheme && (root.rootPane.previewTerminal ?? []).length === 16 ? root.rootPane.previewTerminal : root.rootPane.liveTerminal();
        for (let i = 0; i < 16; i++) {
            const t = p[`term${i}`] ?? term[i];
            if (t)
                out[`term${i}`] = String(t).toUpperCase();
        }
        return out;
    }
    readonly property bool previewLight: hoverScheme ? hoverScheme.mode === "light" : modeText ? modeText === "light" : Signal.light

    // WCAG checks on the previewed palette, measured, never assumed: body
    // text needs 4.5:1, accents and controls 3:1 (WCAG 1.4.3 / 1.4.11).
    readonly property var checks: {
        const f = root.flat;
        const rows = [
            {"label": qsTr("Text"), "fg": f.ink, "bg": f.ground, "min": 4.5},
            {"label": qsTr("Muted text"), "fg": f.inkMuted, "bg": f.panel, "min": 4.5},
            {"label": qsTr("Accent"), "fg": f.signal, "bg": f.ground, "min": 3},
            {"label": qsTr("On accent"), "fg": f.onSignalWell, "bg": f.signalWell, "min": 4.5}
        ];
        const out = [];
        for (const r of rows) {
            if (!r.fg || !r.bg)
                continue;
            const ratio = Colour.contrast(r.fg, r.bg);
            out.push({"label": r.label, "ratio": ratio, "pass": ratio >= r.min, "min": r.min, "fg": r.fg, "bg": r.bg});
        }
        return out;
    }

    readonly property string bannerState: previewState
    readonly property string bannerText: {
        const name = shownTitle || qsTr("your desktop");
        if (previewState === "applying")
            return qsTr("%1 %2").arg(Microcopy.line("appearance.applying")).arg(name);
        if (previewState === "previewing")
            return qsTr("%1 · %2").arg(Microcopy.line("appearance.previewing")).arg(name);
        return qsTr("%1 · %2").arg(Microcopy.line("appearance.now")).arg(name);
    }
    readonly property string bannerHint: {
        if (previewState === "previewing")
            return root.hoverStyle !== "" ? qsTr("Shown on your whole desktop while you point at it. Click to use it; move away to go back.") : qsTr("Nothing has changed yet. %1; move away to go back.").arg(Microcopy.line("appearance.clickToUse"));
        if (previewState === "applying")
            return qsTr("Your choice is being applied. Undo appears when it is done.");
        return hoverEnabled ? qsTr("Point at any theme, wallpaper or colour option to preview it here.") : qsTr("Click any theme, wallpaper or colour option to use it.");
    }

    radius: Appearance.rounding.small
    color: Signal.layer(Signal.palette.raised, 1)
    border.width: 1
    border.color: previewState === "previewing" ? Signal.palette.cue : Signal.palette.rule

    Behavior on border.color {
        enabled: !Appearance.anim.reduced
        ColorAnimation {
            duration: Appearance.anim.durations.short
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.normal

        // ---- state banner: Now using / Previewing / Applying ------------
        StyledRect {
            id: banner

            readonly property string bannerState: root.bannerState
            readonly property string bannerText: root.bannerText

            objectName: "previewBanner"
            Layout.fillWidth: true
            implicitHeight: bannerRow.implicitHeight + Appearance.padding.small * 2
            radius: Config.appearance.cozyChips ? Appearance.rounding.normal : Appearance.rounding.small
            color: root.previewState === "previewing" ? Signal.palette.cueWell : root.previewState === "applying" ? Signal.palette.signalWell : Signal.layer(Signal.palette.panel, 1)
            Accessible.role: Accessible.StaticText
            Accessible.name: `${root.bannerText}. ${root.bannerHint}`

            RowLayout {
                id: bannerRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.padding.normal
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph {
                    name: root.previewState === "previewing" ? "eye" : root.previewState === "applying" ? "loader-2" : "circle-check"
                    font.pointSize: Appearance.font.size.normal
                    color: root.previewState === "previewing" ? Signal.palette.onCueWell : root.previewState === "applying" ? Signal.palette.onSignalWell : Signal.palette.signal
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.bannerText
                        font.pointSize: Appearance.font.size.normal
                        font.weight: Appearance.font.weight.strong
                        color: root.previewState === "previewing" ? Signal.palette.onCueWell : root.previewState === "applying" ? Signal.palette.onSignalWell : Signal.palette.ink
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.bannerHint
                        font.pointSize: Appearance.font.size.small
                        color: root.previewState === "previewing" ? Signal.palette.onCueWell : root.previewState === "applying" ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ---- the honest specimen: bar, popout, launcher, notification,
        // terminal colours, drawn only from the previewed palette ----------
        ChromaticSpecimenBoard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280
            palette: root.flat
            light: root.previewLight
            wallpaper: root.wallpaperPath
        }

        // ---- measured contrast -----------------------------------------
        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small
            Accessible.role: Accessible.List
            Accessible.name: qsTr("Contrast checks")

            Repeater {
                model: root.checks

                StyledRect {
                    id: check

                    required property var modelData

                    radius: Appearance.rounding.small
                    color: check.modelData.pass ? Signal.layer(Signal.palette.panel, 1) : Signal.palette.alertWell
                    border.width: 1
                    border.color: check.modelData.pass ? Signal.palette.rule : Signal.palette.alert
                    implicitWidth: checkRow.implicitWidth + Appearance.padding.small * 2
                    implicitHeight: checkRow.implicitHeight + Appearance.padding.smaller * 2
                    Accessible.role: Accessible.ListItem
                    Accessible.name: check.modelData.pass ? qsTr("%1 contrast %2 to 1, passes %3 to 1").arg(check.modelData.label).arg(check.modelData.ratio.toFixed(1)).arg(check.modelData.min) : qsTr("%1 contrast %2 to 1, below %3 to 1").arg(check.modelData.label).arg(check.modelData.ratio.toFixed(1)).arg(check.modelData.min)

                    Row {
                        id: checkRow

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.smaller

                        // The pair itself: foreground letter on its background.
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 3 // fixed: 18 px contrast sample tile, not a theme corner
                            color: check.modelData.bg
                            border.width: 1
                            border.color: Signal.palette.rule
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "Aa"
                                font.pixelSize: 9 // fixed: "Aa" glyph sized to the 18 px sample tile
                                font.bold: true
                                color: check.modelData.fg
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: check.modelData.label
                            font.pointSize: Appearance.font.size.smaller
                            color: check.modelData.pass ? Signal.palette.inkMuted : Signal.palette.onAlertWell
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            mono: true
                            text: `${check.modelData.ratio.toFixed(1)}:1`
                            font.pointSize: Appearance.font.size.smaller
                            color: check.modelData.pass ? Signal.palette.ink : Signal.palette.onAlertWell
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: check.modelData.pass ? "check" : "alert-triangle"
                            font.pointSize: Appearance.font.size.smaller
                            color: check.modelData.pass ? Signal.palette.phosphor : Signal.palette.onAlertWell
                        }
                    }
                }
            }
        }

        // ---- what it is ------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.shownTitle || qsTr("Your desktop")
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Appearance.font.weight.strong
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (root.hoverScheme)
                            return [Cli.styleDescription(root.hoverStyle), root.modeLabel(root.previewLight ? "light" : "dark")].filter(t => !!t).join(" · ");
                        const parts = [root.subtitleText];
                        if (root.modeText)
                            parts.push(root.modeLabel(root.modeText));
                        if (root.wallpaperPath.startsWith("/"))
                            parts.push(Strings.wallpaperDisplayName(root.wallpaperLabel || root.wallpaperPath));
                        return parts.filter(t => !!t).join(" · ");
                    }
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.isThemePreview && !!root.readinessDetails
                    text: root.readinessDetails
                    color: Signal.palette.phosphor
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Accessible.name: qsTr("Theme requirements")
                }
            }

            TextButton {
                visible: root.active && root.hasRecipe
                type: TextButton.Text
                toggle: true
                checked: root.showAdvancedDetails
                text: root.showAdvancedDetails ? qsTr("Hide details") : qsTr("Details")
                Accessible.name: root.showAdvancedDetails ? qsTr("Hide the theme recipe") : qsTr("Show the theme recipe: GTK, icons, wallpaper")
                onClicked: root.showAdvancedDetails = !root.showAdvancedDetails
            }
        }

        // ---- recipe (advanced, opt-in) -----------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.active && root.showAdvancedDetails
            spacing: 2

            RecipeRow {
                icon: root.modeText === "light" ? "sun" : "moon"
                label: qsTr("Theme mode")
                value: root.modeLabel(root.modeText)
            }

            RecipeRow {
                icon: "device-desktop"
                label: qsTr("GTK theme")
                value: root.gtkThemeText || "—"
            }

            RecipeRow {
                icon: root.gtkColorSchemeIcon(root.gtkPreferText)
                label: qsTr("GTK color scheme")
                value: root.gtkColorSchemeLabel(root.gtkPreferText)
            }

            RecipeRow {
                icon: "photo"
                label: qsTr("Icon theme")
                value: root.iconThemeText || "—"
            }

            RecipeRow {
                visible: root.wallpaperPath.startsWith("/")
                icon: "wallpaper"
                label: qsTr("Wallpaper")
                value: Strings.wallpaperDisplayName(root.wallpaperLabel || root.wallpaperPath)
            }

            RecipeRow {
                visible: root.wallpaperCount > 0
                icon: "photo"
                label: qsTr("Wallpapers in pack")
                value: String(root.wallpaperCount)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small / 2
                visible: root.showVisualSamples
                spacing: Appearance.spacing.normal

                FallbackImage {
                    visible: !!root.gtkThemeText
                    implicitWidth: 88
                    implicitHeight: 56
                    candidates: root.showVisualSamples ? root.gtkThumbnailCandidates(root.gtkThemeText) : []
                    placeholderIcon: "device-desktop"
                    placeholderText: root.gtkThemeText === "auto" ? qsTr("auto") : qsTr("No thumb")
                }

                Row {
                    visible: !!root.iconThemeText
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: ["folder", "user-home", "firefox", "terminal", "system-file-manager", "applications-system"]

                        delegate: FallbackImage {
                            required property string modelData
                            implicitWidth: 28
                            implicitHeight: 28
                            candidates: root.showVisualSamples ? root.iconSampleCandidates(root.iconThemeText, modelData) : []
                            placeholderIcon: ""
                            hideWhenMissing: true
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.tags && root.tags.length > 0
                spacing: Appearance.spacing.smaller

                Repeater {
                    model: root.tags ?? []

                    delegate: StyledRect {
                        required property var modelData
                        radius: Appearance.rounding.small
                        color: Signal.palette.signalWell
                        implicitWidth: tagLabel.implicitWidth + Appearance.padding.small * 2
                        implicitHeight: tagLabel.implicitHeight + Appearance.padding.smaller

                        StyledText {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.onSignalWell
                        }
                    }
                }
            }
        }
    }

    component RecipeRow: RowLayout {
        id: row

        property string icon
        property string label
        property string value

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Glyph {
            name: row.icon
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.signal
        }

        StyledText {
            text: row.label
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.ruleStrong
            Layout.preferredWidth: 120
        }

        StyledText {
            Layout.fillWidth: true
            text: row.value
            font.pointSize: Appearance.font.size.small
            font.weight: Appearance.font.weight.medium
            color: Signal.palette.ink
            elide: Text.ElideMiddle
        }
    }

    // Tries candidate file paths until one loads; optional placeholder when none do.
    component FallbackImage: StyledRect {
        id: thumb

        property var candidates: []
        property string placeholderIcon: "photo"
        property string placeholderText: ""
        property bool hideWhenMissing: false

        property int candidateIndex: 0
        property bool loaded: false
        property bool exhausted: false

        radius: Appearance.rounding.small
        color: Qt.alpha(Signal.palette.base, 0.55)
        visible: !(hideWhenMissing && exhausted && !loaded)
        clip: true

        onCandidatesChanged: {
            candidateIndex = 0;
            loaded = false;
            exhausted = !candidates || candidates.length === 0;
            img.source = (!exhausted && candidates[0]) ? `file://${candidates[0]}` : "";
        }

        Image {
            id: img
            anchors.fill: parent
            anchors.margins: loaded ? 0 : Appearance.padding.smaller
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: thumb.loaded
            sourceSize.width: thumb.implicitWidth * 2
            sourceSize.height: thumb.implicitHeight * 2

            onStatusChanged: {
                if (status === Image.Ready) {
                    thumb.loaded = true;
                    thumb.exhausted = false;
                    return;
                }
                if (status === Image.Error || status === Image.Null) {
                    const next = thumb.candidateIndex + 1;
                    if (thumb.candidates && next < thumb.candidates.length) {
                        thumb.candidateIndex = next;
                        img.source = `file://${thumb.candidates[next]}`;
                    } else {
                        thumb.loaded = false;
                        thumb.exhausted = true;
                        img.source = "";
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            visible: !thumb.loaded && !thumb.hideWhenMissing

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!thumb.placeholderIcon
                name: thumb.placeholderIcon
                font.pointSize: Appearance.font.size.normal
                color: Signal.palette.ruleStrong
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!thumb.placeholderText
                text: thumb.placeholderText
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.ruleStrong
            }
        }

        Component.onCompleted: {
            if (candidates && candidates.length > 0)
                img.source = `file://${candidates[0]}`;
            else
                exhausted = true;
        }
    }
}
