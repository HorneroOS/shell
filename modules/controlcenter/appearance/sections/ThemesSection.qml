pragma ComponentBehavior: Bound

import ".."
import "../../../launcher/services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.images
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromatic.js" as Colour

CollapsibleSection {
    id: sectionRoot

    required property var previewController
    required property var session

    title: qsTr("Themes")
    description: qsTr("Curated looks and your saved palettes. Point at one to preview it, click to use it; Undo is right above.")
    showBackground: true

    property string selectedThemeId: ""

    // Grouped as the headings read: Hornero Originals, Your palettes,
    // then other installed looks.
    function groupOf(theme: var): string {
        return theme.collection === "hornero-originals" ? "hornero-originals" : theme.collection === "user" ? "user" : "other";
    }
    readonly property var orderedThemes: {
        const list = Themes.list ?? [];
        return list.filter(t => groupOf(t) === "hornero-originals").concat(list.filter(t => groupOf(t) === "user"), list.filter(t => groupOf(t) === "other"));
    }

    Component.onCompleted: {
        Themes.reload();
        ThemeCatalogue.loadAppearanceChoices();
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small / 2

        StyledRect {
            id: customLookNotice

            // Chromatic is a reserved dynamic theme with no catalogue entry, and
            // saved palettes are catalogue themes of the `user` collection:
            // neither is ever a missing pack.
            readonly property bool savedThemeMissing: !!Signal.themeId && Signal.themeId !== "hornero-chromatic" && !Themes.themeById(Signal.themeId)
            visible: ThemeCatalogue.loaded && Signal.themeStateReady && Signal.themeId !== "hornero-chromatic" && (!Signal.themeId || savedThemeMissing)
            Layout.fillWidth: true
            implicitHeight: customLookRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Qt.alpha(Signal.tPalette.signalWell, 0.38)

            RowLayout {
                id: customLookRow
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph {
                    name: "palette"
                    color: Signal.palette.signal
                    font.pointSize: Appearance.font.size.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: customLookNotice.savedThemeMissing
                            ? qsTr("Saved theme is unavailable")
                            : qsTr("Custom appearance")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: Appearance.font.weight.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: customLookNotice.savedThemeMissing
                            ? qsTr("The saved theme pack is no longer installed. Your current look is kept; choose an available theme below to restore a curated look.")
                            : qsTr("Your current colors and app styling are a custom combination. Choose a theme below to switch to a curated look.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Repeater {
            model: sectionRoot.orderedThemes

            delegate: ColumnLayout {
                id: themeItem

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 0

                // Applied theme (the live shell's pre-preview identity while a
                // Chromatic style is shown on the desktop).
                readonly property string appliedId: Signal.previewing && Signal._snapshot ? (Signal._snapshot.id ?? "") : Signal.themeId
                readonly property bool isCurrent: Signal.themeStateReady && !!appliedId && modelData.id === appliedId
                readonly property bool isApplying: ThemePipeline.busy && modelData.id === previewController.pendingThemeId && !isCurrent
                readonly property bool isPreviewed: !isCurrent && !isApplying && previewController.previewSource === "theme" && previewController.previewThemeId === modelData.id && previewController.previewState === "previewing"
                readonly property bool isExpanded: modelData.id === sectionRoot.selectedThemeId
                readonly property string collectionId: sectionRoot.groupOf(modelData)
                readonly property bool showCollectionHeading: index === 0 || collectionId !== sectionRoot.groupOf(sectionRoot.orderedThemes[index - 1] ?? ({}))
                readonly property bool missingGtkTheme: ThemeCatalogue.gtkThemesLoaded && !ThemeCatalogue.gtkThemesFailed && !!modelData.gtkTheme && modelData.gtkTheme !== "auto" && ThemeCatalogue.gtkThemes.indexOf(modelData.gtkTheme) < 0
                readonly property bool missingIconTheme: ThemeCatalogue.iconThemesLoaded && !ThemeCatalogue.iconThemesFailed && !!modelData.iconTheme && ThemeCatalogue.iconThemes.indexOf(modelData.iconTheme) < 0
                readonly property bool gtkAvailabilityUnknown: ThemeCatalogue.gtkThemesFailed
                readonly property bool iconAvailabilityUnknown: ThemeCatalogue.iconThemesFailed
                readonly property bool missingWallpaper: !Signal.isBuiltInTheme(modelData.id) && !modelData.colorOnly && !Themes.hasAvailableWallpaper(modelData) && !Wallpapers.actualCurrent
                readonly property bool missingCurrentWallpaper: !Signal.isBuiltInTheme(modelData.id) && modelData.colorOnly && !Themes.hasAvailableWallpaper(modelData) && !Wallpapers.actualCurrent
                readonly property bool appearanceChoicesLoading: ThemeCatalogue.appearanceChoicesLoading
                readonly property bool appearanceChoicesUnknown: gtkAvailabilityUnknown || iconAvailabilityUnknown
                readonly property bool hasUnavailableStyle: missingGtkTheme || missingIconTheme || appearanceChoicesUnknown
                readonly property bool cannotApply: appearanceChoicesLoading || hasUnavailableStyle || missingWallpaper || missingCurrentWallpaper
                readonly property bool hasReadinessNotice: appearanceChoicesLoading || hasUnavailableStyle || missingWallpaper || missingCurrentWallpaper
                readonly property string readinessText: {
                    if (appearanceChoicesLoading)
                        return qsTr("Checking installed styles…")
                    if (missingWallpaper || missingCurrentWallpaper)
                        return qsTr("Choose a wallpaper before applying")
                    if (gtkAvailabilityUnknown && iconAvailabilityUnknown)
                        return qsTr("Couldn't verify GTK and icon styles")
                    if (gtkAvailabilityUnknown)
                        return qsTr("Couldn't verify the GTK style")
                    if (iconAvailabilityUnknown)
                        return qsTr("Couldn't verify the icon style")
                    if (missingGtkTheme && missingIconTheme)
                        return qsTr("GTK and icon styles are unavailable")
                    if (missingGtkTheme)
                        return qsTr("GTK style is unavailable")
                    if (missingIconTheme)
                        return qsTr("Icon style is unavailable")
                    return ""
                }
                readonly property string readinessDetails: {
                    const details = [];
                    if (missingGtkTheme)
                        details.push(qsTr("GTK style “%1” is missing. Install it to use this theme.").arg(modelData.gtkTheme));
                    if (missingIconTheme)
                        details.push(qsTr("Icon style “%1” is missing. Install it to use this theme.").arg(modelData.iconTheme));
                    if (gtkAvailabilityUnknown)
                        details.push(qsTr("Hornero couldn't check installed GTK styles. Reopen Appearance to try again."));
                    if (iconAvailabilityUnknown)
                        details.push(qsTr("Hornero couldn't check installed icon styles. Reopen Appearance to try again."));
                    if (appearanceChoicesLoading)
                        details.push(qsTr("Theme choices become available after this check finishes."));
                    if (missingWallpaper || missingCurrentWallpaper)
                        details.push(qsTr("Choose a wallpaper in Appearance → Background before applying this theme."));
                    return details.join(" ");
                }

                StyledRect {
                    id: collectionHeading
                    visible: themeItem.showCollectionHeading
                    Layout.fillWidth: true
                    implicitHeight: headingContent.implicitHeight + Appearance.padding.normal
                    color: "transparent"

                    ColumnLayout {
                        id: headingContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 2

                        StyledText {
                            text: themeItem.collectionId === "hornero-originals" ? qsTr("Hornero Originals") : themeItem.collectionId === "user" ? qsTr("Your palettes") : qsTr("Other looks")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: Appearance.font.weight.strong
                            Accessible.role: Accessible.Heading
                        }

                        StyledText {
                            visible: themeItem.collectionId !== "other"
                            text: themeItem.collectionId === "user" ? qsTr("Saved from Chromatic or the palette editor.") : qsTr("First-party Hornero Signal looks: graphite night, drafting-paper day, dusk and high contrast.")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // One selection language for every Appearance chooser
                // (PaletteOption): the applied item is filled with the
                // signal well, a 2 px signal border and a check (heart with
                // cozy chips) plus the words "In use"; the item being
                // previewed gets a cue border and "Previewing · Click to use".
                StyledRect {
                    id: card

                    readonly property bool pointed: cardHover.containsMouse || cardInteractive.activeFocus
                    readonly property color inkColour: themeItem.isCurrent ? Signal.palette.onSignalWell : Signal.palette.ink
                    readonly property color mutedColour: themeItem.isCurrent ? Signal.palette.onSignalWell : Signal.palette.inkMuted

                    Layout.fillWidth: true

                    color: themeItem.isCurrent ? Signal.palette.signalWell : card.pointed ? Signal.layer(Signal.palette.raised, 2) : "transparent"
                    radius: Config.appearance.cozyChips ? Appearance.rounding.large : Appearance.rounding.small
                    border.width: themeItem.isCurrent || themeItem.isPreviewed ? 2 : 1
                    border.color: themeItem.isCurrent ? Signal.palette.signal : themeItem.isPreviewed || themeItem.isApplying ? Signal.palette.cue : card.pointed ? Signal.palette.ruleStrong : Signal.palette.rule

                    Interactive {
                        id: cardInteractive

                        disabled: themeItem.cannotApply
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: themeItem.modelData.name ?? themeItem.modelData.id ?? ""
                        Accessible.description: [themeItem.isCurrent ? qsTr("In use") : "", themeItem.modelData.description ?? "", themeItem.readinessText].filter(t => !!t).join(". ")
                        Accessible.checked: themeItem.isCurrent

                        // Keyboard focus previews exactly like the pointer.
                        onActiveFocusChanged: {
                            if (activeFocus)
                                previewController.hoverThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true), themeItem.readinessDetails);
                            else if (!cardHover.containsMouse)
                                previewController.endPreviewFor("theme");
                        }

                        function onClicked(): void {
                            sectionRoot.selectedThemeId = themeItem.modelData.id;
                            previewController.stageThemeApply(themeItem.modelData.id);
                            previewController.startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true), themeItem.readinessDetails);
                            previewController.commitPending();
                        }
                    }

                    MouseArea {
                        id: cardHover

                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: previewController.hoverThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true), themeItem.readinessDetails)
                        onExited: {
                            if (!cardInteractive.activeFocus)
                                previewController.endPreviewFor("theme");
                        }
                    }

                    ColumnLayout {
                        id: themeCard

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Appearance.padding.normal

                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.normal

                            ThemeSwatch {
                                Layout.alignment: Qt.AlignVCenter
                                palette: sectionRoot.previewController.paletteForTheme(themeItem.modelData)
                                terminal: sectionRoot.previewController.terminalForTheme(themeItem.modelData)
                                showTerminal: true
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                spacing: 2

                                StyledText {
                                    // Stay inside the column so the mode chip never overlaps
                                    // the name or description (shell#514).
                                    width: parent.width
                                    text: modelData.name ?? modelData.id ?? ""
                                    font.pointSize: Appearance.font.size.normal
                                    font.weight: themeItem.isCurrent ? Appearance.font.weight.strong : Appearance.font.weight.medium
                                    color: card.inkColour
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.description ?? ""
                                    font.pointSize: Appearance.font.size.small
                                    color: card.mutedColour
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }

                                StyledText {
                                    visible: themeItem.hasReadinessNotice
                                    width: parent.width
                                    text: themeItem.readinessText
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Signal.palette.phosphor
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    Accessible.name: themeItem.readinessText
                                    Accessible.description: themeItem.readinessDetails
                                }

                                // Chips wrap under the text instead of squeezing it, so a
                                // narrow pane never truncates the theme name or overlaps.
                                Flow {
                                    id: chipFlow
                                    width: parent.width
                                    spacing: Appearance.spacing.small

                                StyledRect {
                                    radius: Appearance.rounding.small
                                    color: Signal.palette.signalWell
                                    border.width: themeItem.isCurrent ? 1 : 0
                                    border.color: Signal.palette.onSignalWell
                                    implicitWidth: modeChip.implicitWidth + Appearance.padding.small * 2
                                    implicitHeight: modeChip.implicitHeight + Appearance.padding.smaller * 2

                                    StyledText {
                                        id: modeChip
                                        anchors.centerIn: parent
                                        mono: true
                                        text: (themeItem.modelData.tags ?? []).indexOf("contrast") >= 0 ? qsTr("Contrast") : themeItem.modelData.darkMode ? qsTr("Night") : qsTr("Day")
                                        font.pointSize: Appearance.font.size.small
                                        font.capitalization: Font.AllUppercase
                                        color: Signal.palette.onSignalWell
                                    }
                                }

                                StateChip {
                                    visible: themeItem.isCurrent
                                    glyph: Config.appearance.cozyChips ? "heart" : "check"
                                    text: qsTr("In use")
                                    fill: Signal.palette.signal
                                    ink: Signal.palette.onSignal
                                }

                                StateChip {
                                    visible: themeItem.isPreviewed
                                    glyph: "eye"
                                    text: `${Microcopy.line("appearance.previewing")} · ${Microcopy.line("appearance.clickToUse")}`
                                    fill: Signal.palette.cueWell
                                    ink: Signal.palette.onCueWell
                                }

                                StateChip {
                                    visible: themeItem.isApplying
                                    glyph: "loader-2"
                                    text: Microcopy.line("appearance.applying")
                                    fill: Signal.palette.cueWell
                                    ink: Signal.palette.onCueWell
                                }
                                }
                            }
                        }
                    }

                    implicitHeight: themeCard.implicitHeight + Appearance.padding.normal * 2
                }

                Item {
                    Layout.fillWidth: true
                    visible: themeItem.isExpanded && (themeItem.modelData.wallpapers?.length ?? 0) > 0
                    implicitHeight: wallpaperFlow.implicitHeight + Appearance.padding.small * 2

                    Flow {
                        id: wallpaperFlow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Appearance.padding.small

                        spacing: Appearance.spacing.small

                        Repeater {
                            model: themeItem.modelData.wallpapers ?? []

                            delegate: Item {
                                id: wallpaperThumb

                                required property string modelData

                                readonly property string fullPath: Themes.wallpaperPathFor(themeItem.modelData, wallpaperThumb.modelData)
                                readonly property bool available: wallpaperImage.status === Image.Ready
                                readonly property bool loading: !!fullPath && wallpaperImage.status !== Image.Ready && wallpaperImage.status !== Image.Error

                                Accessible.name: available ? wallpaperThumb.modelData : loading ? qsTr("Loading wallpaper") : qsTr("Wallpaper unavailable")

                                implicitWidth: 96
                                implicitHeight: 54

                                StyledClippingRect {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.small
                                    color: Signal.tPalette.panel

                                    CachingImage {
                                        id: wallpaperImage
                                        anchors.fill: parent
                                        path: wallpaperThumb.fullPath
                                        cache: true
                                        visible: status === Image.Ready
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        visible: !wallpaperThumb.available

                                        Glyph {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: wallpaperThumb.loading ? "wallpaper" : "photo-off"
                                            font.pointSize: Appearance.font.size.small
                                            color: Signal.palette.inkMuted
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: wallpaperThumb.loading ? qsTr("Loading") : qsTr("Unavailable")
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Signal.palette.inkMuted
                                        }
                                    }
                                }

                                Interactive {
                                    radius: Appearance.rounding.small
                                    disabled: !wallpaperThumb.available

                                    function onClicked(): void {
                                        previewController.stageThemeApplyWithWallpaper(sectionRoot.selectedThemeId, wallpaperThumb.fullPath);
                                        previewController.commitPending();
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    hoverEnabled: true
                                    onEntered: {
                                        if (wallpaperThumb.available && previewController.hoverPreviewEnabled)
                                            previewController.startWallpaperPreview(wallpaperThumb.fullPath, wallpaperThumb.modelData);
                                    }
                                    onExited: previewController.endPreviewFor("wallpaper")
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hornero Chromatic (RFC 0002): the dynamic theme has no catalogue
        // card (reserved id `hornero-chromatic`); this card jumps to the
        // Chromatic section right below, where it is chosen and tuned.
        StyledRect {
            id: chromaticCard

            readonly property bool isCurrent: Signal.themeStateReady && Signal.themeId === "hornero-chromatic"
            readonly property var swatch: Colour.flatten({
                "palette": ChromaticPreview.result ? ChromaticPreview.result.scheme.palette : {},
                "terminal": ChromaticPreview.result ? ChromaticPreview.result.scheme.terminal : []
            })

            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            implicitHeight: chromaticRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: isCurrent ? Signal.palette.signalWell : "transparent"
            border.width: isCurrent ? 2 : 1
            border.color: isCurrent ? Signal.palette.signal : activeFocus ? Signal.palette.focus : Signal.palette.rule
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Hornero Chromatic, dynamic colour from your wallpaper")
            Accessible.onPressAction: sectionRoot.session.navigateTo("appearance", "chromatic")
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                    sectionRoot.session.navigateTo("appearance", "chromatic");
                    event.accepted = true;
                }
            }

            RowLayout {
                id: chromaticRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                ThemeSwatch {
                    Layout.alignment: Qt.AlignVCenter
                    palette: chromaticCard.isCurrent ? ({}) : chromaticCard.swatch
                    showTerminal: !chromaticCard.isCurrent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: qsTr("Hornero Chromatic")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: Appearance.font.weight.medium
                        color: chromaticCard.isCurrent ? Signal.palette.onSignalWell : Signal.palette.ink
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: chromaticCard.isCurrent ? qsTr("In use. Tune its source, style and colour in Chromatic below.") : qsTr("Or build a palette from your wallpaper, an image or one colour. Opens Chromatic below.")
                        font.pointSize: Appearance.font.size.small
                        color: chromaticCard.isCurrent ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                StateChip {
                    visible: chromaticCard.isCurrent
                    glyph: Config.appearance.cozyChips ? "heart" : "check"
                    text: qsTr("In use")
                    fill: Signal.palette.signal
                    ink: Signal.palette.onSignal
                }

                Glyph {
                    visible: !chromaticCard.isCurrent
                    name: "chevron-down"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.normal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sectionRoot.session.navigateTo("appearance", "chromatic")
            }
        }

        SwitchRow {
            Layout.topMargin: Appearance.spacing.normal
            label: qsTr("Soft, cozy chips (rounder swatches, a heart on your pick)")
            checked: Config.appearance.cozyChips
            onToggled: checked => {
                Config.appearance.cozyChips = checked;
                Config.save();
            }
        }
    }

    // "In use" / "Previewing · Click to use" / "Applying…": glyph + words,
    // never colour alone.
    component StateChip: StyledRect {
        id: chip

        property string glyph: ""
        property string text: ""
        property color fill: Signal.palette.signalWell
        property color ink: Signal.palette.onSignalWell

        radius: Config.appearance.cozyChips ? height / 2 : Appearance.rounding.small
        color: chip.fill
        implicitWidth: chipRow.implicitWidth + Appearance.padding.small * 2
        implicitHeight: chipRow.implicitHeight + Appearance.padding.smaller * 2

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 4

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.glyph !== ""
                name: chip.glyph
                font.pointSize: Appearance.font.size.smaller
                color: chip.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font.pointSize: Appearance.font.size.smaller
                font.weight: Appearance.font.weight.medium
                color: chip.ink
            }
        }
    }
}
