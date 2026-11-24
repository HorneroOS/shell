pragma ComponentBehavior: Bound

import "services"
import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.modules.instruments as Instruments
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Appearance.padding.larger
    readonly property int rounding: Appearance.rounding.small
    readonly property string modeLabel: {
        const st = list.currentList?.state ?? "";
        if (list.showWallpapers)
            return qsTr("Wallpaper");
        return ({
                "apps": qsTr("Launch"),
                "actions": qsTr("Command"),
                "calc": qsTr("Calculate"),
                "win": qsTr("Windows"),
                "file": qsTr("Files"),
                "ai": qsTr("Ask"),
                "appearance": qsTr("Theme"),
                "plugin": qsTr("Extension")
            })[st] ?? qsTr("Launch");
    }

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: header.height + listWrapper.height + searchWrapper.height + padding * 2 + 1

    AtmosphereTexture {}

    // Header: channel eyebrow left, result count + key cues right.
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding + 4
        anchors.rightMargin: root.padding + 4
        height: 32

        // The channel is an enum, so it wears the engraved plate.
        Plate {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.modeLabel
            color: Signal.palette.ink
        }

        Instruments.Eyebrow {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: (list.currentList?.fileStatus ?? "") !== "" ? list.currentList.fileStatus : ((list.currentList?.count ?? 0) === 1 ? qsTr("1 match") : qsTr("%1 matches").arg(list.currentList?.count ?? 0))
        }
    }

    Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Signal.palette.rule
    }

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchWrapper.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - header.height - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    // Command prompt: a sunken input well with a `signal` prompt mark.
    // The query is typed in Plex Mono, like a command line.
    Instruments.Well {
        id: searchWrapper

        border.color: search.activeFocus ? Signal.palette.ruleStrong : Signal.palette.rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        StyledText {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12

            mono: true
            text: "›"
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
            Accessible.ignored: true
        }

        StyledTextField {
            id: search

            // Vim mode routes Tab/Shift+Tab to the result list.
            trapTab: !Config.launcher.vimKeybinds

            anchors.left: searchIcon.right
            // While the legend is hidden the field runs up to the clear
            // glyph, the legend's old slot (8 px gap kept).
            anchors.right: keyLegend.visible ? keyLegend.left : clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small + (keyLegend.visible ? 0 : keyLegend.anchors.rightMargin)

            topPadding: Appearance.padding.larger
            bottomPadding: Appearance.padding.larger
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.larger

            placeholderText: qsTr("search apps, or %1 for commands").arg(Config.launcher.actionPrefix)

            onAccepted: {
                const currentItem = list.currentList?.currentItem;
                if (currentItem) {
                    if (list.showWallpapers) {
                        Wallpapers.setWallpaper(currentItem.modelData.path);
                        root.visibilities.launcher = false;
                    } else if (text.startsWith(Config.launcher.actionPrefix)) {
                        const routedState = Providers.stateFor(text);
                        if (routedState === "calc" || routedState === "file")
                            currentItem.onClicked();
                        else if (routedState === "ai") {
                            // Inline ask (shell#250 slice 3): activate
                            // the AiItem, which streams the answer in
                            // the launcher. The launcher stays open so
                            // the user watches it arrive; follow-ups
                            // live in the Javi chat panel.
                            currentItem.onClicked();
                        } else
                            currentItem.modelData.onClicked(list.currentList);
                    } else {
                        Apps.launch(currentItem.modelData);
                        root.visibilities.launcher = false;
                    }
                }
            }

            Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
            Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

            // Escape handled centrally (Drawers.dismissTopmost).

            Keys.onPressed: event => {
                if (!Config.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                target: root.visibilities

                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher) {
                        search.text = "";
                        // Closing the launcher (including the
                        // central Escape cascade) cancels any
                        // in-flight inline ask.
                        InlineAsk.cancel("launcher");
                    }
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session)
                        search.forceActiveFocus();
                }
            }
        }

        // Key legend: muted, hidden while typing to keep the line clean.
        Instruments.Eyebrow {
            id: keyLegend

            anchors.right: clearIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            // Natural (implicit) width only: sizing `width` from its own
            // `implicitWidth` here was a binding loop, and the search field
            // switches its right anchor while the legend is hidden instead.
            visible: search.text === ""
            label: qsTr("↑↓  ⏎  esc")
        }

        Glyph {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            name: "x"
            color: Signal.palette.inkMuted

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Clear search")

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.short
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.short
                }
            }
        }
    }

    // Atmosphere: warm lamp, soft inner light, vignette, grain (section 17).
    AtmosphereLayer {
        lampOrigin: "top"
        lampReach: 0.8
        cornerRadius: Appearance.rounding.small
    }
}
