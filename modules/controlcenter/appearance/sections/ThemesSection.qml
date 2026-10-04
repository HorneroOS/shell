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

            readonly property bool savedThemeMissing: !!Colours.themeId && !Themes.themeById(Colours.themeId)
            visible: ThemeCatalogue.loaded && Colours.themeStateReady && (!Colours.themeId || savedThemeMissing)
            Layout.fillWidth: true
            implicitHeight: customLookRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Qt.alpha(Colours.tPalette.m3secondaryContainer, 0.38)

            RowLayout {
                id: customLookRow
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: Colours.scheme === "dynamic" ? "wallpaper" : "palette"
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.large
                    fill: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: customLookNotice.savedThemeMissing
                            ? qsTr("Saved theme is unavailable")
                            : Colours.scheme === "dynamic" ? qsTr("Following your wallpaper") : qsTr("Custom appearance")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 500
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: customLookNotice.savedThemeMissing
                            ? qsTr("The saved theme pack is no longer installed. Your current look is kept; choose an available theme below to restore a curated look.")
                            : Colours.scheme === "dynamic"
                                ? qsTr("Colors are generated from your current background. Choose a theme below to switch to a curated look.")
                                : qsTr("Your current colors and app styling are a custom combination. Choose a theme below to switch to a curated look.")
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3onSurfaceVariant
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

                Layout.fillWidth: true
                spacing: 0

                readonly property bool isStaged: modelData.id === previewController.pendingThemeId
                readonly property bool isCurrent: Colours.themeStateReady && !!Colours.themeId && modelData.id === Colours.themeId
                readonly property bool isExpanded: modelData.id === sectionRoot.selectedThemeId
                readonly property bool missingGtkTheme: ThemeCatalogue.gtkThemesLoaded && !ThemeCatalogue.gtkThemesFailed && !!modelData.gtkTheme && modelData.gtkTheme !== "auto" && ThemeCatalogue.gtkThemes.indexOf(modelData.gtkTheme) < 0
                readonly property bool missingIconTheme: ThemeCatalogue.iconThemesLoaded && !ThemeCatalogue.iconThemesFailed && !!modelData.iconTheme && ThemeCatalogue.iconThemes.indexOf(modelData.iconTheme) < 0
                readonly property bool gtkAvailabilityUnknown: ThemeCatalogue.gtkThemesFailed
                readonly property bool iconAvailabilityUnknown: ThemeCatalogue.iconThemesFailed
                readonly property bool missingWallpaper: !Colours.isBuiltInTheme(modelData.id) && !modelData.colorOnly && !Themes.hasAvailableWallpaper(modelData) && !Wallpapers.actualCurrent
                readonly property bool missingCurrentWallpaper: modelData.colorOnly && !Themes.hasAvailableWallpaper(modelData) && !Wallpapers.actualCurrent
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
                    Layout.fillWidth: true

                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, themeItem.isStaged ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Appearance.rounding.normal
                    border.width: themeItem.isStaged ? 1 : 0
                    border.color: Colours.palette.m3primary

                    StateLayer {
                        disabled: themeItem.cannotApply

                        function onClicked(): void {
                            sectionRoot.selectedThemeId = themeItem.modelData.id;
                            previewController.stageThemeApply(themeItem.modelData.id);
                            previewController.startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true));
                            previewController.commitPending();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: previewController.startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true))
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

                            Loader {
                                active: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 40
                                Layout.minimumWidth: 72
                                Layout.minimumHeight: 40

                                sourceComponent: StyledClippingRect {
                                    implicitWidth: 72
                                    implicitHeight: 40
                                    radius: Appearance.rounding.small
                                    color: Colours.tPalette.m3surfaceContainer
                                    Accessible.name: themePreviewImage.status === Image.Ready
                                        ? qsTr("Theme preview") : themeItem.missingWallpaper || themeItem.missingCurrentWallpaper
                                            ? themeItem.readinessText : qsTr("Theme preview unavailable")

                                    CachingImage {
                                        id: themePreviewImage
                                        anchors.fill: parent
                                        path: Themes.previewPathFor(themeItem.modelData)
                                        cache: true
                                        visible: status === Image.Ready
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        visible: themePreviewImage.status !== Image.Ready

                                        MaterialIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: themeItem.modelData.colorOnly ? "palette" : themeItem.hasReadinessNotice ? "wallpaper" : themePreviewImage.status === Image.Loading ? "wallpaper" : "image_not_supported"
                                            font.pointSize: Appearance.font.size.small
                                            color: Colours.palette.m3outline
                                        }
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: modelData.name ?? modelData.id ?? ""
                                    font.pointSize: Appearance.font.size.normal
                                    font.weight: 500
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.description ?? ""
                                    font.pointSize: Appearance.font.size.small
                                    color: Colours.palette.m3outline
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }

                                StyledText {
                                    visible: themeItem.hasReadinessNotice
                                    width: parent.width
                                    text: themeItem.readinessText + (themeItem.readinessDetails ? ". " + themeItem.readinessDetails : "")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Colours.palette.m3tertiary
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 5
                                }

                            }

                            StyledRect {
                                radius: Appearance.rounding.full
                                color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.6)
                                implicitWidth: modeChip.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: modeChip.implicitHeight + Appearance.padding.smaller * 2

                                StyledText {
                                    id: modeChip
                                    anchors.centerIn: parent
                                    text: modelData.darkMode ? qsTr("Dark") : qsTr("Light")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                            }

                            StyledRect {
                                visible: themeItem.isCurrent && !themeItem.isStaged
                                radius: Appearance.rounding.full
                                color: Qt.alpha(Colours.palette.m3primaryContainer, 0.75)
                                implicitWidth: currentChip.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: currentChip.implicitHeight + Appearance.padding.smaller * 2

                                StyledText {
                                    id: currentChip
                                    anchors.centerIn: parent
                                    text: qsTr("Current")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Colours.palette.m3onPrimaryContainer
                                }
                            }

                            StyledRect {
                                visible: themeItem.isStaged
                                radius: Appearance.rounding.full
                                color: Qt.alpha(Colours.palette.m3primaryContainer, 0.85)
                                implicitWidth: stagedChip.implicitWidth + Appearance.padding.small * 2
                                implicitHeight: stagedChip.implicitHeight + Appearance.padding.smaller * 2

                                StyledText {
                                    id: stagedChip
                                    anchors.centerIn: parent
                                    text: previewController.themeDirty ? qsTr("Pending") : qsTr("Selected")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Colours.palette.m3onPrimaryContainer
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
                                    color: Colours.tPalette.m3surfaceContainer

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

                                        MaterialIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: wallpaperThumb.loading ? "wallpaper" : "image_not_supported"
                                            font.pointSize: Appearance.font.size.small
                                            color: Colours.palette.m3outline
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: wallpaperThumb.loading ? qsTr("Loading") : qsTr("Unavailable")
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }

                                StateLayer {
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
    }
}
