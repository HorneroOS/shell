pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.motion
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property real nonAnimWidth
    required property PersistentProperties state
    readonly property alias count: bar.count

    implicitHeight: bar.implicitHeight + separator.implicitHeight

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
            iconName: "playlist"
            text: qsTr("Media")
        }

        Tab {
            iconName: "gauge"
            text: qsTr("Performance")
        }

        Tab {
            iconName: "cloud"
            text: qsTr("Weather")
        }

        Tab {
            iconName: "layout-grid"
            text: qsTr("Workspaces")
        }

        Tab {
            iconName: "puzzle"
            text: qsTr("Extensions")
        }
    }

    // On-air bar (Signal Bezel §5): a 2 px `signal` bar on the edge facing
    // the content. It travels with leading/trailing asymmetry (§11): the
    // edge toward the new tab settles in settleFast, the far edge on the
    // same curve over Choreography.trail(settleFast), so it is always behind
    // and the bar stretches toward its target, then catches up. Reduced and
    // off move both edges alike.
    Rectangle {
        id: indicator

        objectName: "onAirIndicator"
        // Final cell geometry from the settled width: the tab bar itself
        // resizes while the sheet settles, and chasing those in-flight cell
        // edges would restart the travel every frame.
        readonly property real cellWidth: bar.count > 0 ? (root.nonAnimWidth - bar.spacing * (bar.count - 1)) / bar.count : 0
        readonly property real targetLeft: Math.max(0, bar.currentIndex) * (cellWidth + bar.spacing)
        readonly property real targetRight: targetLeft + cellWidth
        // +1 travelling right, -1 left, 0 resize in place. Set before the
        // edges move, so each edge's timing is fixed for the whole flight.
        property int dir: 0
        // Past ~8 px of overshoot the travel uses `enter` (§11 8 px rule,
        // per curve style); short hops keep the settle.
        property string curveKind: "settleFast"
        property real goalLeft: 0
        property real goalRight: 0
        property real leftEdge: 0
        property real rightEdge: 0
        property bool ready: false

        // Coalesced: a tab switch moves both targets in one turn. The
        // direction changes only when the target tab moves, so a tab that
        // resizes mid-flight retargets one edge without resetting the
        // other's timing.
        function retarget(): void {
            const l = targetLeft, r = targetRight;
            if (Math.abs(l - goalLeft) > 0.5) {
                dir = l > goalLeft ? 1 : -1;
                curveKind = Math.abs(l - goalLeft) * Choreography.curves.settleFastOvershoot > 8 ? "enter" : "settleFast";
                goalLeft = l;
                leftEdge = l;
            }
            if (Math.abs(r - goalRight) > 0.5) {
                goalRight = r;
                rightEdge = r;
            }
        }

        onTargetLeftChanged: Qt.callLater(retarget)
        onTargetRightChanged: Qt.callLater(retarget)
        Component.onCompleted: {
            retarget();
            ready = true;
        }

        anchors.top: bar.bottom
        anchors.topMargin: -height

        x: leftEdge
        implicitWidth: Math.max(0, rightEdge - leftEdge)
        implicitHeight: 2
        color: Signal.palette.signal

        Behavior on leftEdge {
            enabled: indicator.ready

            MotionAnim {
                kind: indicator.curveKind
                duration: indicator.dir > 0 ? Choreography.trail(Choreography.settleFast) : Choreography.lead(Choreography.settleFast)
            }
        }

        Behavior on rightEdge {
            enabled: indicator.ready

            MotionAnim {
                kind: indicator.curveKind
                duration: indicator.dir < 0 ? Choreography.trail(Choreography.settleFast) : Choreography.lead(Choreography.settleFast)
            }
        }
    }

    Rectangle {
        id: separator

        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: 1
        color: Signal.palette.rule
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
        // Qt Quick Keys has no onHomePressed/onEndPressed signals;
        // Home/End arrive through the generic onPressed handler.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home)
                bar.itemAt(0)?.forceActiveFocus(Qt.TabFocusReason);
            else if (event.key === Qt.Key_End)
                bar.itemAt(bar.count - 1)?.forceActiveFocus(Qt.TabFocusReason);
        }

        Keys.onReturnPressed: root.state.currentTab = tab.TabBar.index
        Keys.onEnterPressed: root.state.currentTab = tab.TabBar.index
        Keys.onSpacePressed: root.state.currentTab = tab.TabBar.index

        background: null

        FocusRing {
            radius: Appearance.rounding.small + 2
        }

        // Cells share the strip evenly; the selected one takes the `raised`
        // fill, a signal-coloured label and the on-air bar above.
        implicitWidth: (root.nonAnimWidth - bar.spacing * (bar.count - 1)) / bar.count
        implicitHeight: 48

        contentItem: CustomMouseArea {
            id: mouse

            implicitWidth: tab.implicitWidth
            implicitHeight: tab.implicitHeight

            cursorShape: Qt.PointingHandCursor

            onPressed: {
                // Mouse arrival must clear keyboard focus mode: this
                // TabButton never becomes pressed for pointer input
                // (mouse is delegated here), so reportFocus would
                // otherwise leave a stale keyboard ring after a click.
                FocusMode.reportPointer();
                root.state.currentTab = tab.TabBar.index;
            }

            function onWheel(event: WheelEvent): void {
                if (event.angleDelta.y < 0)
                    root.state.currentTab = Math.min(root.state.currentTab + 1, bar.count - 1);
                else if (event.angleDelta.y > 0)
                    root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
            }

            Rectangle {
                anchors.fill: parent

                radius: Appearance.rounding.small
                color: tab.current ? Signal.palette.raised : Qt.alpha(Signal.palette.raised, tab.hovered || mouse.pressed ? (mouse.pressed ? 1 : 0.6) : 0)
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter

                    name: tab.iconName
                    color: tab.current ? Signal.palette.ink : Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.large
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: tab.text
                    color: tab.current ? Signal.palette.ink : Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    font.weight: tab.current ? Font.Medium : Font.Normal
                }
            }
        }
    }
}
