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
    description: qsTr("Choose a look for your desktop. Themes update colors and app styling; some also include a matching wallpaper.")
    showBackground: true

    property string selectedThemeId: ""

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
            model: Themes.list

            delegate: ColumnLayout {
                id: themeItem

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 0

                readonly property bool isStaged: modelData.id === previewController.pendingThemeId
                readonly property bool isCurrent: Signal.themeStateReady && !!Signal.themeId && modelData.id === Signal.themeId
                readonly property bool isExpanded: modelData.id === sectionRoot.selectedThemeId
                readonly property string collectionId: modelData.collection === "hornero-originals" ? "hornero-originals" : "other"
                readonly property bool showCollectionHeading: index === 0 || collectionId !== (Themes.list[index - 1]?.collection === "hornero-originals" ? "hornero-originals" : "other")
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
                            text: themeItem.collectionId === "hornero-originals" ? qsTr("Hornero Originals") : qsTr("Other looks")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: Appearance.font.weight.strong
                        }

                        StyledText {
                            visible: themeItem.collectionId === "hornero-originals"
                            text: qsTr("First-party Hornero Signal looks: graphite night, drafting-paper day and high contrast.")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true

                    color: themeItem.isStaged || themeItem.isCurrent ? Signal.layer(Signal.palette.raised, 1) : "transparent"
                    radius: Appearance.rounding.small
                    border.width: themeItem.isStaged || themeItem.isCurrent ? 1 : 0
                    border.color: themeItem.isStaged ? Signal.palette.signal : Signal.palette.ruleStrong

                    Interactive {
                        disabled: themeItem.cannotApply

                        function onClicked(): void {
                            sectionRoot.selectedThemeId = themeItem.modelData.id;
                            previewController.stageThemeApply(themeItem.modelData.id);
                            previewController.startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true), themeItem.readinessDetails);
                            previewController.commitPending();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: previewController.startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true), themeItem.readinessDetails)
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
                                    font.weight: Appearance.font.weight.medium
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.description ?? ""
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
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
                            }

                            StyledRect {
                                radius: Appearance.rounding.small
                                color: Signal.palette.signalWell
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

                            StyledRect {
                                visible: themeItem.isCurrent && !themeItem.isStaged
                                radius: Appearance.rounding.small
                                color: Signal.palette.signalWell
                                implicitWidth: currentChip.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: currentChip.implicitHeight + Appearance.padding.smaller * 2

                                StyledText {
                                    id: currentChip
                                    anchors.centerIn: parent
                                    text: qsTr("Current")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Signal.palette.onSignalWell
                                }
                            }

                            StyledRect {
                                visible: themeItem.isStaged
                                radius: Appearance.rounding.small
                                color: Signal.palette.signalWell
                                implicitWidth: stagedChip.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: stagedChip.implicitHeight + Appearance.padding.smaller * 2

                                StyledText {
                                    id: stagedChip
                                    anchors.centerIn: parent
                                    text: previewController.themeDirty ? qsTr("Pending") : qsTr("Selected")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Signal.palette.onSignalWell
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
                                        if (wallpaperThumb.available)
                                            previewController.startWallpaperPreview(wallpaperThumb.fullPath, wallpaperThumb.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hornero Chromatic (RFC 0002): the dynamic theme is a card of its
        // own after the catalogue (reserved id `hornero-chromatic`, no
        // theme directory). Choosing it opens the Chromatic section; the
        // palette is only applied from there.
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
            color: isCurrent ? Signal.layer(Signal.palette.raised, 1) : "transparent"
            border.width: 1
            border.color: isCurrent ? Signal.palette.ruleStrong : Signal.palette.rule
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
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("A palette built from your wallpaper, an image or one colour. Always Signal: same structure, contrast gates and anatomy. Not a curated look; you choose and preview it in Chromatic.")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    visible: chromaticCard.isCurrent
                    radius: Appearance.rounding.small
                    color: Signal.palette.signalWell
                    implicitWidth: chromaticCurrent.implicitWidth + Appearance.padding.small * 2
                    implicitHeight: chromaticCurrent.implicitHeight + Appearance.padding.smaller * 2

                    StyledText {
                        id: chromaticCurrent

                        anchors.centerIn: parent
                        text: qsTr("Current")
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.onSignalWell
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sectionRoot.session.navigateTo("appearance", "chromatic")
            }
        }
    }
}
