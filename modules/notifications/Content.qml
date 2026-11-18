import qs.components.containers
import qs.components.motion
import qs.components.widgets
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    required property Item panels
    readonly property int padding: Appearance.padding.large

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right

    implicitWidth: Config.notifs.sizes.width + padding * 2
    implicitHeight: {
        const count = list.count;
        if (count === 0)
            return 0;

        let height = (count - 1) * Appearance.spacing.smaller;
        for (let i = 0; i < count; i++)
            height += list.itemAtIndex(i)?.nonAnimHeight ?? 0;

        if (visibilities && panels) {
            if (visibilities.osd) {
                const h = panels.osd.y - Config.border.rounding * 2 - padding * 2;
                if (height > h)
                    height = h;
            }

            if (visibilities.session) {
                const h = panels.session.y - Config.border.rounding * 2 - padding * 2;
                if (height > h)
                    height = h;
            }
        }

        const availableHeight = root.panels ? root.panels.height : (QsWindow.window?.screen?.height ?? 0);
        return Math.min(availableHeight, height + padding * 2);
    }

    ClippingWrapperRectangle {
        anchors.fill: parent
        anchors.margins: root.padding

        color: "transparent"
        radius: Appearance.rounding.normal

        StyledListView {
            id: list

            model: ScriptModel {
                values: Notifs.popups.filter(n => !n.closed)
            }

            anchors.fill: parent

            orientation: Qt.Vertical
            spacing: 0
            cacheBuffer: QsWindow.window?.screen.height ?? 0

            delegate: Item {
                id: wrapper

                required property Notifs.Notif modelData
                required property int index
                readonly property alias nonAnimHeight: notif.nonAnimHeight
                property int idx

                onIndexChanged: {
                    if (index !== -1)
                        idx = index;
                }

                implicitWidth: notif.implicitWidth
                implicitHeight: notif.implicitHeight + (idx === 0 ? 0 : Appearance.spacing.smaller)

                // Leaving (Signal visual language §11.2): a card swiped
                // past the threshold is thrown on along its swipe, one card
                // width, with `exit`; a card that timed out or was closed
                // fades in 90 ms where it is. Either way the siblings close
                // the gap at once with `settle`. Reduced motion keeps 4 px
                // of travel plus the fade; off is the capped fade only.
                property real throwDir: 0

                ListView.onRemove: {
                    wrapper.throwDir = notif.x > 0.5 ? 1 : notif.x < -0.5 ? -1 : 0;
                    const thrown = wrapper.throwDir !== 0;
                    exitX.to = !thrown ? notif.x : Choreography.morph ? wrapper.throwDir * (notif.width + Appearance.spacing.normal) : notif.x + wrapper.throwDir * Choreography.exitTravel;
                    exitX.duration = !thrown ? 0 : Choreography.morph ? Choreography.medium : Choreography.fade;
                    exitFade.duration = thrown && Choreography.morph ? Choreography.medium : Choreography.fade;
                    removeAnim.start();
                }

                SequentialAnimation {
                    id: removeAnim

                    PropertyAction {
                        target: wrapper
                        property: "ListView.delayRemove"
                        value: true
                    }
                    PropertyAction {
                        target: wrapper
                        property: "enabled"
                        value: false
                    }
                    PropertyAction {
                        target: wrapper
                        property: "implicitHeight"
                        value: 0
                    }
                    PropertyAction {
                        target: wrapper
                        property: "z"
                        value: 1
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            id: exitX

                            target: notif
                            property: "x"
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Choreography.curves.exit
                        }
                        NumberAnimation {
                            id: exitFade

                            target: notif
                            property: "opacity"
                            to: 0
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Choreography.curves.exit
                        }
                    }
                    PropertyAction {
                        target: wrapper
                        property: "ListView.delayRemove"
                        value: false
                    }
                }

                ClippingRectangle {
                    anchors.top: parent.top
                    anchors.topMargin: wrapper.idx === 0 ? 0 : Appearance.spacing.smaller

                    color: "transparent"
                    radius: notif.radius
                    implicitWidth: notif.implicitWidth
                    implicitHeight: notif.implicitHeight

                    Notification {
                        id: notif

                        modelData: wrapper.modelData
                    }
                }
            }

            move: Transition {
                Anim {
                    property: "y"
                }
            }

            displaced: Transition {
                Anim {
                    property: "y"
                }
            }

            ExtraIndicator {
                anchors.top: parent.top
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;

                    const scrollY = list.contentY;

                    let height = 0;
                    for (let i = 0; i < count; i++) {
                        height += (list.itemAtIndex(i)?.nonAnimHeight ?? 0) + Appearance.spacing.smaller;

                        if (height - Appearance.spacing.smaller >= scrollY)
                            return i;
                    }

                    return count;
                }
            }

            ExtraIndicator {
                anchors.bottom: parent.bottom
                extra: {
                    const count = list.count;
                    if (count === 0)
                        return 0;

                    const scrollY = list.contentHeight - (list.contentY + list.height);

                    let height = 0;
                    for (let i = count - 1; i >= 0; i--) {
                        height += (list.itemAtIndex(i)?.nonAnimHeight ?? 0) + Appearance.spacing.smaller;

                        if (height - Appearance.spacing.smaller >= scrollY)
                            return count - i - 1;
                    }

                    return 0;
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    // Reflow: `settle`, instant under reduced motion and off.
    component Anim: NumberAnimation {
        duration: Choreography.settle
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Choreography.curves.settle
    }
}
