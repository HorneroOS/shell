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

    readonly property bool isThemePreview: source === "theme"
    readonly property bool compact: width < 600
    readonly property bool hasRecipe: {
        return !!modeText || !!gtkThemeText || !!iconThemeText || !!gtkPreferText || !!wallpaperLabel || (tags && tags.length > 0);
    }
    readonly property bool showVisualSamples: active && showAdvancedDetails && !compact && (!!gtkThemeText || !!iconThemeText)

    function previewColor(role: string, fallback: color): color {
        const p = root.rootPane.previewPalette;
        if (p && Object.prototype.hasOwnProperty.call(p, role))
            return p[role];
        return fallback;
    }

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

    radius: Appearance.rounding.small
    color: previewColor("panel", Signal.tPalette.panel)

    Item {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal

        GridLayout {
            anchors.fill: parent
            columns: root.compact ? 1 : 2
            rowSpacing: Appearance.spacing.normal
            columnSpacing: Appearance.spacing.normal

            // Wallpaper / visual hero
            StyledClippingRect {
                Layout.preferredWidth: root.compact ? -1 : root.isThemePreview ? 180 : 220
                Layout.preferredHeight: root.compact ? 120 : -1
                Layout.fillWidth: root.compact
                Layout.fillHeight: !root.compact
                radius: Appearance.rounding.small
                color: previewColor("raised", Signal.tPalette.raised)

                Image {
                    id: previewWallpaper
                    anchors.fill: parent
                    source: root.wallpaperPath ? `file://${root.wallpaperPath}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                    Accessible.name: status === Image.Ready
                        ? (root.wallpaperLabel || Strings.wallpaperDisplayName(root.wallpaperPath))
                        : status === Image.Error ? qsTr("Wallpaper unavailable") : qsTr("Loading wallpaper")
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.smaller
                    visible: root.active && previewWallpaper.status !== Image.Ready

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: previewWallpaper.status === Image.Error ? "photo-off" : "wallpaper"
                        font.pointSize: Appearance.font.size.large
                        color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: previewWallpaper.status === Image.Error
                            ? qsTr("Wallpaper unavailable")
                            : root.wallpaperPath ? qsTr("Loading wallpaper") : qsTr("No wallpaper selected")
                        font.pointSize: Appearance.font.size.small
                        color: previewColor("inkMuted", Signal.palette.inkMuted)
                    }
                }

                // Mode badge over wallpaper
                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.small
                    visible: root.active && !!root.modeText
                    radius: Appearance.rounding.small
                    color: Qt.alpha(previewColor("base", Signal.palette.base), 0.88)
                    implicitWidth: modeBadge.implicitWidth + Appearance.padding.small * 2
                    implicitHeight: modeBadge.implicitHeight + Appearance.padding.smaller

                    Row {
                        id: modeBadge
                        anchors.centerIn: parent
                        spacing: 4

                        Glyph {
                            name: root.modeText === "light" ? "sun" : "moon"
                            font.pointSize: Appearance.font.size.small
                            color: previewColor("signal", Signal.palette.signal)
                        }

                        StyledText {
                            text: root.modeLabel(root.modeText)
                            font.pointSize: Appearance.font.size.smaller
                            color: previewColor("ink", Signal.palette.ink)
                        }
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: !root.active
                    name: "eye"
                    font.pointSize: Appearance.font.size.extraLarge
                    color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: !root.compact
                Layout.preferredHeight: root.compact ? 240 : -1
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.titleText || qsTr("Select an option")
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 600
                    color: previewColor("ink", Signal.palette.ink)
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const subtitle = root.subtitleText || qsTr("Preview updates here — click to apply");
                        return root.compact && root.readinessDetails ? `${subtitle} · ${root.readinessDetails}` : subtitle;
                    }
                    color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    visible: root.isThemePreview && !root.compact && !!root.readinessDetails
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Glyph {
                        Layout.alignment: Qt.AlignTop
                        name: "info-circle"
                        font.pointSize: Appearance.font.size.small
                        color: previewColor("phosphor", Signal.palette.phosphor)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.readinessDetails
                        color: previewColor("phosphor", Signal.palette.phosphor)
                        font.pointSize: Appearance.font.size.smaller
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Accessible.name: qsTr("Theme requirements")
                    }
                }

                // Palette swatches
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small


                    Repeater {
                        model: [
                            {
                                role: "signal",
                                fallback: Signal.palette.signal
                            },
                            {
                                role: "cue",
                                fallback: Signal.palette.cue
                            },
                            {
                                role: "phosphor",
                                fallback: Signal.palette.phosphor
                            },
                            {
                                role: "base",
                                fallback: Signal.palette.base
                            },
                            {
                                role: "alert",
                                fallback: Signal.palette.alert
                            }
                        ]

                        delegate: StyledRect {
                            required property var modelData
                            radius: Appearance.rounding.small
                            color: root.previewColor(modelData.role, modelData.fallback)
                            implicitHeight: 22
                            implicitWidth: 22
                            border.width: 1
                            border.color: Qt.alpha(previewColor("ruleStrong", Signal.palette.ruleStrong), 0.25)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: root.isThemePreview && root.showAdvancedDetails && !!root.themeIdText
                        text: root.themeIdText
                        Layout.maximumWidth: 100
                        font.family: root.rootPane.fontFamilyMono
                        font.pointSize: Appearance.font.size.smaller
                        color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                        elide: Text.ElideMiddle
                    }
                }

                // Advanced implementation details stay out of the default
                // preview. The title, description, wallpaper and palette are
                // enough to understand a look; backend names remain available
                // to users who deliberately expand this section.
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.compact && root.showAdvancedDetails
                    Layout.preferredHeight: root.showAdvancedDetails ? (root.compact ? 260 : 360) : 56
                    visible: root.active && root.hasRecipe
                    radius: Appearance.rounding.small
                    color: Qt.alpha(previewColor("raised", Signal.tPalette.raised), 0.65)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.small / 2

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("About this look")
                                font.pointSize: Appearance.font.size.small
                                font.weight: 600
                                color: previewColor("ink", Signal.palette.ink)
                            }

                            TextButton {
                                type: TextButton.Text
                                toggle: true
                                checked: root.showAdvancedDetails
                                text: root.showAdvancedDetails ? qsTr("Hide details") : qsTr("More details")
                                Accessible.name: text
                                onClicked: root.showAdvancedDetails = !root.showAdvancedDetails
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: root.showAdvancedDetails && !root.isThemePreview
                            spacing: Appearance.spacing.smaller

                            PreviewChip {
                                visible: !!root.modeText
                                icon: root.modeText === "light" ? "sun" : "moon"
                                label: qsTr("Mode")
                                value: root.modeLabel(root.modeText)
                            }

                            PreviewChip {
                                visible: !!root.gtkThemeText
                                icon: "device-desktop"
                                label: qsTr("GTK")
                                value: root.gtkThemeText
                            }

                            PreviewChip {
                                visible: !!root.iconThemeText
                                icon: "photo"
                                label: qsTr("Icons")
                                value: root.iconThemeText
                            }

                            PreviewChip {
                                visible: !!root.wallpaperLabel || !!root.wallpaperPath
                                icon: "wallpaper"
                                label: qsTr("Wallpaper")
                                value: root.wallpaperLabel || Strings.wallpaperDisplayName(root.wallpaperPath)
                            }
                        }

                        // Exact recipe for theme packs
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.isThemePreview && root.showAdvancedDetails
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
                                visible: !root.compact
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
                                visible: !root.compact
                                icon: "wallpaper"
                                label: qsTr("Default wallpaper")
                                value: root.wallpaperLabel || Strings.wallpaperDisplayName(root.wallpaperPath) || "—"
                            }

                            RecipeRow {
                                visible: !root.compact && root.wallpaperCount > 0
                                icon: "photo"
                                label: qsTr("Wallpapers in pack")
                                value: String(root.wallpaperCount)
                            }
                        }

                        // Visual samples: GTK thumbnail + icon strip
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Appearance.spacing.small / 2
                            visible: root.showVisualSamples
                            spacing: Appearance.spacing.normal

                            ColumnLayout {
                                spacing: 4
                                visible: !!root.gtkThemeText

                                StyledText {
                                    text: qsTr("GTK")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                                }

                                FallbackImage {
                                    implicitWidth: 88
                                    implicitHeight: 56
                                    candidates: root.showVisualSamples ? root.gtkThumbnailCandidates(root.gtkThemeText) : []
                                    placeholderIcon: "device-desktop"
                                    placeholderText: root.gtkThemeText === "auto" ? qsTr("auto") : qsTr("No thumb")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: !!root.iconThemeText

                                StyledText {
                                    text: qsTr("Icons")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                                }

                                Row {
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
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: root.showAdvancedDetails && !root.compact && root.tags && root.tags.length > 0
                            spacing: Appearance.spacing.smaller

                            Repeater {
                                model: root.tags ?? []

                                delegate: StyledRect {
                                    required property var modelData
                                    radius: Appearance.rounding.small
                                    color: Qt.alpha(previewColor("cueWell", Signal.palette.cueWell), 0.55)
                                    implicitWidth: tagLabel.implicitWidth + Appearance.padding.small * 2
                                    implicitHeight: tagLabel.implicitHeight + Appearance.padding.smaller

                                    StyledText {
                                        id: tagLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pointSize: Appearance.font.size.smaller
                                        color: previewColor("onCueWell", Signal.palette.onCueWell)
                                    }
                                }
                            }
                        }
                    }
                }

                // Show how the theme reads on a real Shell surface instead of
                // leaving the right side of the preview empty when recipe
                // details are collapsed.
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: root.isThemePreview && !root.compact
                    visible: root.active && root.isThemePreview && !root.compact
                    radius: Appearance.rounding.small
                    color: Qt.alpha(previewColor("raised", Signal.tPalette.raised), 0.82)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.small
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            Glyph {
                                name: "dashboard"
                                color: previewColor("signal", Signal.palette.signal)
                                font.pointSize: Appearance.font.size.normal
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Interface sample")
                                font.pointSize: Appearance.font.size.small
                                font.weight: 600
                                color: previewColor("ink", Signal.palette.ink)
                            }
                            StyledRect {
                                radius: Appearance.rounding.small
                                color: previewColor("signalWell", Signal.palette.signalWell)
                                implicitWidth: sampleBadge.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: sampleBadge.implicitHeight + Appearance.padding.smaller
                                StyledText {
                                    id: sampleBadge
                                    anchors.centerIn: parent
                                    text: qsTr("Preview")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: previewColor("onSignalWell", Signal.palette.onSignalWell)
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.small
                            color: previewColor("panel", Signal.tPalette.panel)
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                spacing: Appearance.spacing.small
                                Glyph {
                                    name: "palette"
                                    color: previewColor("signal", Signal.palette.signal)
                                    font.pointSize: Appearance.font.size.normal
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("A desktop that feels like yours")
                                        font.pointSize: Appearance.font.size.small
                                        font.weight: 600
                                        color: previewColor("ink", Signal.palette.ink)
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Surfaces, text, and accents work together.")
                                        font.pointSize: Appearance.font.size.smaller
                                        color: previewColor("inkMuted", Signal.palette.inkMuted)
                                        elide: Text.ElideRight
                                    }
                                }
                                Glyph {
                                    name: "circle-check"
                                    color: previewColor("signal", Signal.palette.signal)
                                    font.pointSize: Appearance.font.size.normal
                                }
                            }
                        }
                    }
                }

                // The custom-appearance typography sandbox is useful for
                // tuning fonts, but it is an advanced preview detail rather
                // than part of the everyday "choose a look" flow.
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.active && root.showAdvancedDetails && !root.isThemePreview && !root.compact
                    radius: Appearance.rounding.small * root.rootPane.roundingScale
                    color: root.rootPane.transparencyEnabled ? Qt.alpha(previewColor("panel", Signal.palette.panel), root.rootPane.transparencyBase) : previewColor("panel", Signal.palette.panel)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(8, Appearance.padding.normal * root.rootPane.paddingScale)
                        spacing: Math.max(4, Appearance.spacing.small * root.rootPane.spacingScale)

                        StyledText {
                            text: qsTr("Typography Preview")
                            font.family: root.rootPane.fontFamilySans
                            font.pointSize: Appearance.font.size.normal * root.rootPane.fontSizeScale
                            font.weight: 600
                            color: previewColor("ink", Signal.palette.ink)
                        }

                        StyledText {
                            text: qsTr("Monospace: 1234 ABCD")
                            font.family: root.rootPane.fontFamilyMono
                            font.pointSize: Appearance.font.size.small * root.rootPane.fontSizeScale
                            color: previewColor("inkMuted", Signal.palette.inkMuted)
                        }

                        StyledText {
                            visible: !!root.modeText
                            text: qsTr("Mode: %1").arg(root.modeLabel(root.modeText))
                            font.pointSize: Appearance.font.size.small
                            color: previewColor("inkMuted", Signal.palette.inkMuted)
                        }
                    }
                }

                // Idle hint
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.active

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("Hover or select a theme, wallpaper, mode, or scheme")
                        color: previewColor("ruleStrong", Signal.palette.ruleStrong)
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }
        }
    }

    component PreviewChip: StyledRect {
        id: chip

        property string icon
        property string label
        property string value

        radius: Appearance.rounding.small
        color: Qt.alpha(previewColor("signalWell", Signal.palette.signalWell), 0.7)
        implicitWidth: chipRow.implicitWidth + Appearance.padding.small * 2
        implicitHeight: chipRow.implicitHeight + Appearance.padding.smaller

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Glyph {
                name: chip.icon
                font.pointSize: Appearance.font.size.small
                color: previewColor("onSignalWell", Signal.palette.onSignalWell)
            }

            StyledText {
                text: `${chip.label}: ${chip.value}`
                font.pointSize: Appearance.font.size.smaller
                color: previewColor("onSignalWell", Signal.palette.onSignalWell)
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
            color: previewColor("signal", Signal.palette.signal)
        }

        StyledText {
            text: row.label
            font.pointSize: Appearance.font.size.small
            color: previewColor("ruleStrong", Signal.palette.ruleStrong)
            Layout.preferredWidth: 120
        }

        StyledText {
            Layout.fillWidth: true
            text: row.value
            font.pointSize: Appearance.font.size.small
            font.weight: 500
            color: previewColor("ink", Signal.palette.ink)
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
        color: Qt.alpha(previewColor("base", Signal.palette.base), 0.55)
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
                color: previewColor("ruleStrong", Signal.palette.ruleStrong)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!thumb.placeholderText
                text: thumb.placeholderText
                font.pointSize: Appearance.font.size.smaller
                color: previewColor("ruleStrong", Signal.palette.ruleStrong)
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
