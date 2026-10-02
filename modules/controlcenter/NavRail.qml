pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.controlcenter
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    required property Session session
    required property bool initialOpeningComplete

    // implicitWidth drives the parent StyledRect's width allocation
    implicitWidth: layout.implicitWidth + Appearance.padding.larger * 4

    // Fill the parent container and clip overflowing items
    anchors.fill: parent
    clip: true

    // Auto-scrolling Flickable — interactive:false so the outer
    // CustomMouseArea on the left panel keeps handling wheel events
    // for pane switching. contentY animates to keep active item visible.
    Flickable {
        id: navScroll

        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        interactive: false
        contentHeight: layout.implicitHeight + Appearance.padding.large * 2

        contentY: {
            const viewH = height;
            const totalH = contentHeight;
            if (totalH <= viewH)
                return 0;

            const activeItem = paneRepeater.itemAt(root.session.activeIndex);
            if (!activeItem)
                return 0;
            const activeY = activeItem.mapToItem(navScroll.contentItem, 0, 0).y;
            const target = activeY - viewH / 2 + activeItem.height / 2;
            return Math.max(0, Math.min(target, totalH - viewH));
        }

        Behavior on contentY {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Appearance.padding.larger * 2
            anchors.topMargin: Appearance.padding.large
            spacing: Appearance.spacing.normal

            states: State {
                name: "expanded"
                when: root.session.navExpanded

                PropertyChanges {
                    layout.spacing: Appearance.spacing.small
                }
            }

            transitions: Transition {
                Anim {
                    properties: "spacing"
                }
            }

            Loader {
                Layout.topMargin: Appearance.spacing.large
                active: !root.session.floating
                visible: active

                sourceComponent: StyledRect {
                    readonly property int nonAnimWidth: normalWinIcon.implicitWidth + (root.session.navExpanded ? normalWinLabel.anchors.leftMargin + normalWinLabel.implicitWidth : 0) + normalWinIcon.anchors.leftMargin * 2

                    implicitWidth: nonAnimWidth
                    implicitHeight: root.session.navExpanded ? normalWinIcon.implicitHeight + Appearance.padding.normal * 2 : nonAnimWidth

                    color: Colours.palette.m3primaryContainer
                    radius: Appearance.rounding.small

                    StateLayer {
                        id: normalWinState

                        color: Colours.palette.m3onPrimaryContainer

                        function onClicked(): void {
                            root.session.root.close();
                            WindowFactory.create(null, {
                                active: root.session.active,
                                navExpanded: root.session.navExpanded
                            });
                        }
                    }

                    MaterialIcon {
                        id: normalWinIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Appearance.padding.large

                        text: "select_window"
                        color: Colours.palette.m3onPrimaryContainer
                        font.pointSize: Appearance.font.size.large
                        fill: 1
                    }

                    StyledText {
                        id: normalWinLabel

                        anchors.left: normalWinIcon.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Appearance.spacing.normal

                        text: qsTr("Float window")
                        color: Colours.palette.m3onPrimaryContainer
                        opacity: root.session.navExpanded ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                duration: Appearance.anim.durations.small
                            }
                        }
                    }

                    Behavior on implicitWidth {
                        Anim {
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }
                }
            }

            Repeater {
                id: paneRepeater
                model: PaneRegistry.count

                delegate: ColumnLayout {
                    required property int index
                    readonly property var pane: PaneRegistry.getByIndex(index)
                    readonly property bool firstInCategory: index === 0 || PaneRegistry.getByIndex(index - 1).category !== pane.category

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.leftMargin: Appearance.padding.normal
                        Layout.topMargin: root.session.navExpanded ? (firstInCategory && index > 0 ? Appearance.spacing.large : Appearance.spacing.small) : 0
                        Layout.preferredHeight: root.session.navExpanded ? implicitHeight : 0
                        Layout.fillWidth: true
                        visible: root.session.navExpanded
                        opacity: root.session.navExpanded ? 1 : 0
                        text: firstInCategory ? PaneRegistry.categoryTitle(pane.category) : ""
                        color: Colours.palette.m3outline
                        font.pointSize: Appearance.font.size.small
                        font.capitalization: Font.Capitalize
                    }

                    NavItem {
                        Layout.fillWidth: true
                        Layout.topMargin: !root.session.navExpanded && firstInCategory && index > 0 ? Appearance.spacing.normal : 0
                        icon: pane.icon
                        label: pane.label
                        title: pane.title
                        badgeVisible: pane.id === "network" ? !Network.active && !Network.activeEthernet : pane.id === "notifications" ? Notifs.notClosed.length > 0 : false
                    }
                }
            }

            // Bottom padding so the last item is never flush against the edge
            Item {
                implicitHeight: Appearance.padding.large
            }
        }
    }

    component NavItem: Item {
        id: item

        required property string icon
        required property string label
        required property string title
        property bool badgeVisible: false
        readonly property bool active: root.session.active === label

        implicitWidth: background.implicitWidth
        implicitHeight: background.implicitHeight + smallLabel.implicitHeight + smallLabel.anchors.topMargin

        states: State {
            name: "expanded"
            when: root.session.navExpanded

            PropertyChanges {
                expandedLabel.opacity: 1
                smallLabel.opacity: 0
                background.implicitWidth: icon.implicitWidth + icon.anchors.leftMargin * 2 + expandedLabel.anchors.leftMargin + expandedLabel.implicitWidth
                background.implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2
                item.implicitHeight: background.implicitHeight
            }
        }

        transitions: Transition {
            Anim {
                property: "opacity"
                duration: Appearance.anim.durations.small
            }

            Anim {
                properties: "implicitWidth,implicitHeight"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        StyledRect {
            id: background

            radius: Appearance.rounding.full
            color: Qt.alpha(Colours.palette.m3secondaryContainer, item.active ? 1 : 0)

            implicitWidth: icon.implicitWidth + icon.anchors.leftMargin * 2
            implicitHeight: icon.implicitHeight + Appearance.padding.small

            StateLayer {
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

                function onClicked(): void {
                    // Allow navigation even during the short opening gate; the
                    // active pane loader handles first paint.
                    root.session.active = item.label;
                }

                onEntered: root.session.prefetch(item.label)
                onExited: {
                    if (root.session.warmLabel === item.label)
                        root.session.clearPrefetch();
                }
            }

            MaterialIcon {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.padding.large

                text: item.icon
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.large
                fill: item.active ? 1 : 0

                Behavior on fill {
                    Anim {}
                }
            }

            StyledRect {
                id: alertBadge

                anchors.top: icon.top
                anchors.right: icon.right

                implicitWidth: 8
                implicitHeight: 8
                radius: Appearance.rounding.full
                color: Colours.palette.m3error
                visible: item.badgeVisible

                SequentialAnimation on scale {
                    running: item.badgeVisible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.2; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            StyledText {
                id: expandedLabel

                anchors.left: icon.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.spacing.normal

                opacity: 0
                text: item.title
                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                font.capitalization: Font.Capitalize
            }

            StyledText {
                id: smallLabel

                anchors.horizontalCenter: icon.horizontalCenter
                anchors.top: icon.bottom
                anchors.topMargin: Appearance.spacing.small / 2

                text: item.title
                font.pointSize: Appearance.font.size.small
                font.capitalization: Font.Capitalize
            }
        }
    }
}
