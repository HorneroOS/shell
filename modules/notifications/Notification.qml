pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.motion
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Notification card (Signal Bezel §7.1, §11.2): calm feedback. A `panel`
// module with a 1 px `rule` border and radius 3; source + time as a mono
// eyebrow, summary in Plex Sans, body in `inkMuted`. Only a critical
// notification earns colour: an `alert` edge bar and an URGENT chip.
// Enters with a 6 px travel + fade (`enter`, short); reflow settles.
// An expiring card carries its timeout as a 2 px `signal` line on its
// anchor (top) edge that drains toward the leading side and freezes while
// the card is hovered or dragged (notifs.timeoutTick). How a card leaves
// (thrown along the swipe, or a short fade) lives in Content.qml.
StyledRect {
    id: root

    required property Notifs.Notif modelData
    readonly property bool hasImage: modelData.image.length > 0
    readonly property bool hasAppIcon: modelData.appIcon.length > 0
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    readonly property int nonAnimHeight: Math.max(cell.height, column.implicitHeight) + 24
    property bool expanded: Config.notifs.openExpanded

    // Timeout line: the share of the timeout left (1 -> 0). It follows the
    // notification's clock (Notifs.Notif.remainingMs) and only animates
    // while this card exists and the line is shown.
    readonly property bool tickShown: Config.notifs.timeoutTick && modelData.expires
    property real drain: 1

    function syncDrain(): void {
        drainAnim.stop();
        const total = Math.max(1, root.modelData.timeoutMs);
        const left = root.modelData.remainingMs();
        root.drain = Math.max(0, Math.min(1, left / total));
        if (root.tickShown && !root.modelData.held && left > 0) {
            drainAnim.from = root.drain;
            drainAnim.duration = left;
            drainAnim.start();
        }
    }

    color: Signal.surface(Signal.palette.panel, "notifications")
    radius: Appearance.rounding.small
    border.width: 1
    border.color: root.critical ? Signal.palette.alert : Signal.palette.rule
    implicitWidth: Config.notifs.sizes.width
    implicitHeight: nonAnimHeight
    clip: true

    x: 6
    opacity: 0
    Component.onCompleted: {
        x = 0;
        opacity = 1;
        modelData.lock(this);
        syncDrain();
    }
    Component.onDestruction: {
        modelData.release(this);
        modelData.unlock(this);
    }
    onTickShownChanged: syncDrain()

    Connections {
        target: root.modelData

        function onHeldChanged(): void {
            root.syncDrain();
        }

        function onTimeoutMsChanged(): void {
            root.syncDrain();
        }
    }

    NumberAnimation {
        id: drainAnim

        target: root
        property: "drain"
        to: 0
        easing.type: Easing.Linear
    }

    Behavior on x {
        Anim {
            duration: Appearance.anim.durations.short
            easing.bezierCurve: Appearance.anim.curves.enter
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.fade
            easing.bezierCurve: Appearance.anim.curves.enter
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.settle
            easing.bezierCurve: Appearance.anim.curves.settle
        }
    }

    // Critical edge bar on the leading edge.
    Rectangle {
        visible: root.critical
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Signal.palette.alert
    }

    // Timeout line on the anchor edge, inside the border and clear of the
    // corner radius. With motion off it steps in quarters instead of
    // sliding. Decorative: the card's text carries the content.
    Rectangle {
        readonly property real span: parent.width - root.radius * 2
        readonly property real share: Choreography.animated ? root.drain : Math.ceil(root.drain * 4) / 4

        visible: root.tickShown && share > 0
        Accessible.ignored: true
        x: root.radius
        y: 1
        width: span * share
        height: 2
        color: Signal.palette.signal
    }

    MouseArea {
        id: pointer

        property int startY

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.expanded && body.hoveredLink ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : undefined
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        // Hovering or dragging holds the timeout (and freezes its line).
        readonly property bool holding: containsMouse || pressed
        onHoldingChanged: holding ? root.modelData.hold(root) : root.modelData.release(root)

        drag.target: parent
        drag.axis: Drag.XAxis

        onPressed: event => {
            startY = event.y;
            if (event.button === Qt.MiddleButton)
                root.modelData.close();
        }
        onReleased: event => {
            if (Math.abs(root.x) < Config.notifs.sizes.width * Config.notifs.clearThreshold)
                root.x = 0;
            else
                root.modelData.popup = false;
        }
        onPositionChanged: event => {
            if (pressed) {
                const diffY = event.y - startY;
                if (Math.abs(diffY) > Config.notifs.expandThreshold)
                    root.expanded = diffY > 0;
            }
        }
        onClicked: event => {
            if (!Config.notifs.actionOnClick || event.button !== Qt.LeftButton)
                return;

            const actions = root.modelData.actions;
            if (actions?.length === 1)
                actions[0].invoke();
        }
    }

    // Source cell: the notification image, else the app icon in a
    // sunken well, else a glyph. Square, radius 3 — never a disc.
    Instruments.Well {
        id: cell

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.topMargin: 12
        width: root.hasImage ? 40 : 32
        height: width
        clip: true

        Loader {
            anchors.fill: parent
            anchors.margins: 1
            active: root.hasImage

            sourceComponent: Image {
                source: Qt.resolvedUrl(root.modelData.image)
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
            }
        }

        Loader {
            anchors.centerIn: parent
            active: !root.hasImage && root.hasAppIcon
            width: 20
            height: 20

            sourceComponent: ColouredIcon {
                anchors.fill: parent
                source: Quickshell.iconPath(root.modelData.appIcon)
                colour: Signal.palette.ink
                layer.enabled: root.modelData.appIcon.endsWith("symbolic")
            }
        }

        Loader {
            anchors.centerIn: parent
            active: !root.hasImage && !root.hasAppIcon

            sourceComponent: Glyph {
                name: Icons.getNotifIcon(root.modelData.summary, root.modelData.urgency)
                color: root.critical ? Signal.palette.alert : Signal.palette.inkMuted
                size: Appearance.font.size.large
            }
        }
    }

    ColumnLayout {
        id: column

        anchors.left: cell.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        anchors.topMargin: 10
        spacing: 3

        // Eyebrow: SOURCE · TIME, URGENT chip, expand control.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Instruments.Eyebrow {
                Layout.fillWidth: true
                label: (root.modelData.appName || qsTr("System")) + " · " + root.modelData.timeStr
            }

            Instruments.OnAirChip {
                visible: root.critical
                text: qsTr("Urgent")
                fill: Signal.palette.alert
                ink: Signal.palette.onAlert
            }

            Item {
                id: expandBtn

                Accessible.role: Accessible.Button
                Accessible.name: root.expanded ? qsTr("Collapse notification") : qsTr("Expand notification")

                implicitWidth: 24
                implicitHeight: 20

                StateLayer {
                    radius: Appearance.rounding.small
                    color: Signal.palette.ink

                    function onClicked() {
                        root.expanded = !root.expanded;
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    name: root.expanded ? "chevron-up" : "chevron-down"
                    color: Signal.palette.inkMuted
                    size: Appearance.font.size.normal
                }
            }
        }

        StyledText {
            id: summary

            Layout.fillWidth: true
            Layout.rightMargin: 8
            text: root.modelData.summary
            font.pointSize: Appearance.font.size.normal
            font.weight: Font.Medium
            maximumLineCount: root.expanded ? 4 : 1
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideRight
        }

        StyledText {
            id: body

            Layout.fillWidth: true
            Layout.rightMargin: 8
            visible: text !== ""
            textFormat: Text.MarkdownText
            text: root.modelData.body
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.expanded ? 12 : 1
            elide: Text.ElideRight

            onLinkActivated: link => {
                if (!root.expanded)
                    return;
                Quickshell.execDetached(["app2unit", "-O", "--", link]);
                root.modelData.popup = false;
            }
        }

        RowLayout {
            id: actions

            visible: root.expanded
            Layout.topMargin: 6
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.modelData.actions

                delegate: Component {
                    Action {}
                }
            }

            Action {
                modelData: QtObject {
                    readonly property string text: qsTr("Close")

                    function invoke(): void {
                        root.modelData.close();
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // Quiet bordered action: mono label, `raised` on hover. The first
    // application action is the primary one and carries `ruleStrong`.
    component Action: StyledRect {
        id: action

        required property var modelData

        Accessible.role: Accessible.Button
        Accessible.name: action.modelData.text

        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 1
        border.color: Signal.palette.ruleStrong

        implicitWidth: Math.min(actionText.implicitWidth + 16, (column.width - 24) / Math.max(1, root.modelData.actions.length + 1))
        implicitHeight: 24

        StateLayer {
            radius: Appearance.rounding.small
            color: Signal.palette.ink

            function onClicked(): void {
                action.modelData.invoke();
            }
        }

        StyledText {
            id: actionText

            anchors.centerIn: parent
            width: Math.min(implicitWidth, action.width - 12)
            mono: true
            text: action.modelData.text
            color: Signal.palette.ink
            font.pointSize: Appearance.font.size.small
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
        }
    }

    // Quiet atmosphere for calm cards only: no lamp (it would spend the
    // glow budget per card) and nothing on a critical one.
    AtmosphereLayer {
        lamp: false
        vignette: false
        innerLight: !root.critical
        cornerRadius: root.radius
    }
}
