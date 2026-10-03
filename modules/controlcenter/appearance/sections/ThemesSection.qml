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

    function wallpaperPathFor(theme: var, filename: string): string {
        if (!theme || !filename)
            return "";
        const mapped = theme.wallpaperPaths?.[filename];
        if (mapped)
            return mapped;
        if (theme.wallpaperPath && theme.defaultWallpaper === filename)
            return theme.wallpaperPath;
        const dir = theme.wallpaperDir || theme.id || "";
        // Prefer the user Pictures dir; the theme wallpaperPath already
        // falls back to the data dir for the default wallpaper.
        return `${Paths.pictures}/Wallpapers/${dir}/${filename}`;
    }

    function previewPathFor(theme: var): string {
        return theme?.preview || theme?.wallpaperPath || "";
    }

    Component.onCompleted: Themes.reload()

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

                StyledRect {
                    Layout.fillWidth: true

                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, themeItem.isStaged ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Appearance.rounding.normal
                    border.width: themeItem.isStaged ? 1 : 0
                    border.color: Colours.palette.m3primary

                    StateLayer {
                        function onClicked(): void {
                            sectionRoot.selectedThemeId = themeItem.modelData.id;
                            previewController.stageThemeApply(themeItem.modelData.id);
                            previewController.startThemePreview(themeItem.modelData);
                            previewController.commitPending();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onEntered: previewController.startThemePreview(themeItem.modelData)
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
                                        ? qsTr("Theme preview") : qsTr("Theme preview unavailable")

                                    CachingImage {
                                        id: themePreviewImage
                                        anchors.fill: parent
                                        path: sectionRoot.previewPathFor(themeItem.modelData)
                                        cache: true
                                        visible: status === Image.Ready
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        visible: themePreviewImage.status !== Image.Ready

                                        MaterialIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: themePreviewImage.status === Image.Loading ? "wallpaper" : "image_not_supported"
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

                                readonly property string fullPath: sectionRoot.wallpaperPathFor(themeItem.modelData, wallpaperThumb.modelData)
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
