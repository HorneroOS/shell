pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property real nonAnimWidth
    required property PersistentProperties state
    readonly property alias count: bar.count

    implicitHeight: bar.implicitHeight + indicator.implicitHeight + indicator.anchors.topMargin + separator.implicitHeight

    TabBar {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        // Clamp: dashboardState.currentTab survives in-process config
        // reloads via reloadableId and may still name a removed trailing
        // tab (ADR 003).
        currentIndex: Math.min(root.state.currentTab, bar.count - 1)
        background: null

        onCurrentIndexChanged: root.state.currentTab = currentIndex

        Tab {
            iconName: "dashboard"
            text: qsTr("Dashboard")
        }

        Tab {
            iconName: "queue_music"
            text: qsTr("Media")
        }

        Tab {
            iconName: "speed"
            text: qsTr("Performance")
        }

        Tab {
            iconName: "cloud"
            text: qsTr("Weather")
        }

        Tab {
            iconName: "workspaces"
            text: qsTr("Workspaces")
        }

        Tab {
            iconName: "extension"
            text: qsTr("Extensions")
        }
    }

    Item {
        id: indicator

        anchors.top: bar.bottom
        anchors.topMargin: 5

        implicitWidth: bar.currentItem.implicitWidth
        implicitHeight: 3

        x: {
            const tab = bar.currentItem;
            const width = (root.nonAnimWidth - bar.spacing * (bar.count - 1)) / bar.count;
            return width * tab.TabBar.index + (width - tab.implicitWidth) / 2;
        }

        clip: true

        StyledRect {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight * 2

            color: Colours.palette.m3primary
            radius: Appearance.rounding.full
        }

        Behavior on x {
            Anim {}
        }

        Behavior on implicitWidth {
            Anim {}
        }
    }

    StyledRect {
        id: separator

        anchors.top: indicator.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    component Tab: TabButton {
        id: tab

        required property string iconName
        readonly property bool current: TabBar.tabBar.currentItem === this

        // Keyboard model (docs/FOCUS.md, #401): roving tab stop —
        // only the selected tab is in the Tab chain, so FocusMode.enter
        // (Drawers.syncFocusRoot, which seeds focus only when the drawer
        // content does not already own it) lands on the current tab and
        // Tab then moves on into the pane. Left/Right wrap across the
        // row, Home/End jump to the ends; arrows move focus only,
        // Return/Enter/Space activate (manual activation, like Menu).
        // No initial-focus handoff here: stealing focus on open would
        // break content that already owns it and is forbidden in the
        // drawer open path (test_escape_cascade). Escape is untouched
        // and still reaches the central Drawers cascade.
        activeFocusOnTab: tab.current

        onActiveFocusChanged: {
            if (activeFocus)
                FocusMode.reportFocus(tab.pressed);
        }

        Keys.onTabPressed: event => FocusMode.handleTab(tab, event, false)
        Keys.onBacktabPressed: event => FocusMode.handleTab(tab, event, true)

        Keys.onLeftPressed: bar.itemAt((tab.TabBar.index - 1 + bar.count) % bar.count)?.forceActiveFocus(Qt.TabFocusReason)
        Keys.onRightPressed: bar.itemAt((tab.TabBar.index + 1) % bar.count)?.forceActiveFocus(Qt.TabFocusReason)
        Keys.onHomePressed: bar.itemAt(0)?.forceActiveFocus(Qt.TabFocusReason)
        Keys.onEndPressed: bar.itemAt(bar.count - 1)?.forceActiveFocus(Qt.TabFocusReason)

        Keys.onReturnPressed: root.state.currentTab = tab.TabBar.index
        Keys.onEnterPressed: root.state.currentTab = tab.TabBar.index
        Keys.onSpacePressed: root.state.currentTab = tab.TabBar.index

        background: null

        FocusRing {
            radius: Appearance.rounding.small + 2
        }

        contentItem: CustomMouseArea {
            id: mouse

            implicitWidth: Math.max(icon.width, label.width)
            implicitHeight: icon.height + label.height

            cursorShape: Qt.PointingHandCursor

            onPressed: event => {
                // Mouse arrival must clear keyboard focus mode: this
                // TabButton never becomes pressed for pointer input
                // (mouse is delegated here), so reportFocus would
                // otherwise leave a stale keyboard ring after a click.
                FocusMode.reportPointer();
                root.state.currentTab = tab.TabBar.index;

                const stateY = stateWrapper.y;
                rippleAnim.x = event.x;
                rippleAnim.y = event.y - stateY;

                const dist = (ox, oy) => ox * ox + oy * oy;
                rippleAnim.radius = Math.sqrt(Math.max(dist(event.x, event.y + stateY), dist(event.x, stateWrapper.height - event.y), dist(width - event.x, event.y + stateY), dist(width - event.x, stateWrapper.height - event.y)));

                rippleAnim.restart();
            }

            function onWheel(event: WheelEvent): void {
                if (event.angleDelta.y < 0)
                    root.state.currentTab = Math.min(root.state.currentTab + 1, bar.count - 1);
                else if (event.angleDelta.y > 0)
                    root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
            }

            SequentialAnimation {
                id: rippleAnim

                property real x
                property real y
                property real radius

                PropertyAction {
                    target: ripple
                    property: "x"
                    value: rippleAnim.x
                }
                PropertyAction {
                    target: ripple
                    property: "y"
                    value: rippleAnim.y
                }
                PropertyAction {
                    target: ripple
                    property: "opacity"
                    value: 0.08
                }
                Anim {
                    target: ripple
                    properties: "implicitWidth,implicitHeight"
                    from: 0
                    to: rippleAnim.radius * 2
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    target: ripple
                    property: "opacity"
                    to: 0
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            ClippingRectangle {
                id: stateWrapper

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.height + Config.dashboard.sizes.tabIndicatorSpacing * 2

                color: "transparent"
                radius: Appearance.rounding.small

                StyledRect {
                    id: stateLayer

                    anchors.fill: parent

                    color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                    opacity: mouse.pressed ? 0.1 : tab.hovered ? 0.08 : 0

                    Behavior on opacity {
                        Anim {}
                    }
                }

                StyledRect {
                    id: ripple

                    radius: Appearance.rounding.full
                    color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                    opacity: 0

                    transform: Translate {
                        x: -ripple.width / 2
                        y: -ripple.height / 2
                    }
                }
            }

            MaterialIcon {
                id: icon

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: label.top

                text: tab.iconName
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fill: tab.current ? 1 : 0
                font.pointSize: Appearance.font.size.large

                Behavior on fill {
                    Anim {}
                }
            }

            StyledText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                text: tab.text
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
