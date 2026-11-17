pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property string modelData
    required property Props props
    required property Flickable container
    required property var visibilities

    readonly property list<var> notifs: Notifs.list.filter(n => n.appName === modelData)
    readonly property int notifCount: notifs.reduce((acc, n) => n.closed ? acc : acc + 1, 0)
    readonly property string image: notifs.find(n => !n.closed && n.image.length > 0)?.image ?? ""
    readonly property string appIcon: notifs.find(n => !n.closed && n.appIcon.length > 0)?.appIcon ?? ""
    readonly property int urgency: notifs.some(n => !n.closed && n.urgency === NotificationUrgency.Critical) ? NotificationUrgency.Critical : notifs.some(n => n.urgency === NotificationUrgency.Normal) ? NotificationUrgency.Normal : NotificationUrgency.Low

    readonly property int nonAnimHeight: {
        const headerHeight = header.implicitHeight + (root.expanded ? Math.round(Appearance.spacing.small / 2) : 0);
        const columnHeight = headerHeight + notifList.nonAnimHeight + column.Layout.topMargin + column.Layout.bottomMargin;
        return Math.round(Math.max(root.image.length > 0 ? Config.notifs.sizes.image : 0, columnHeight) + Appearance.padding.normal * 2);
    }
    readonly property bool expanded: props.expandedNotifs.includes(modelData)

    function toggleExpand(expand: bool): void {
        if (expand) {
            if (!expanded)
                props.expandedNotifs.push(modelData);
        } else if (expanded) {
            props.expandedNotifs.splice(props.expandedNotifs.indexOf(modelData), 1);
        }
    }

    Component.onDestruction: {
        if (notifCount === 0 && expanded)
            props.expandedNotifs.splice(props.expandedNotifs.indexOf(modelData), 1);
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2

    clip: true
    radius: Appearance.rounding.small
    color: Signal.palette.panel
    border.width: 1
    border.color: root.urgency === NotificationUrgency.Critical ? Signal.palette.alert : Signal.palette.rule

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        spacing: Appearance.spacing.normal

        // Only a real notification image earns a thumbnail; app icons are
        // 20 px in the eyebrow row and there is no generic icon tile.
        Image {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.preferredWidth: Config.notifs.sizes.image
            Layout.preferredHeight: Config.notifs.sizes.image
            visible: root.image.length > 0
            source: root.image.length > 0 ? Qt.resolvedUrl(root.image) : ""
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true
        }

        ColumnLayout {
            id: column

            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                id: header

                Layout.bottomMargin: root.expanded ? Math.round(Appearance.spacing.small / 2) : 0
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller

                // App icon at 20 px, only when the app supplies one.
                Loader {
                    active: root.appIcon.length > 0
                    visible: active
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    sourceComponent: ColouredIcon {
                        anchors.fill: parent
                        source: Quickshell.iconPath(root.appIcon)
                        colour: Signal.palette.ink
                        layer.enabled: root.appIcon.endsWith("symbolic")
                    }
                }

                // Eyebrow: APP · TIME, plus URGENT in words for critical so
                // the state never relies on colour alone.
                Instruments.Eyebrow {
                    Layout.fillWidth: true
                    label: {
                        const when = root.notifs.find(n => !n.closed)?.timeStr ?? "";
                        let s = root.modelData + (when !== "" ? ` · ${when}` : "");
                        if (root.urgency === NotificationUrgency.Critical)
                            s += ` · ${qsTr("Urgent")}`;
                        return s;
                    }
                    color: root.urgency === NotificationUrgency.Critical ? Signal.palette.alert : Signal.palette.inkMuted
                }

                // Quiet group count (x2), only when there is a group.
                StyledText {
                    visible: root.notifCount > 1
                    animate: true
                    text: `x${root.notifCount}`
                    mono: true
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                }

                // Expand affordance: a chevron glyph, no box.
                Item {
                    id: expandBtn

                    Accessible.role: Accessible.Button
                    Accessible.name: root.expanded ? qsTr("Collapse group") : qsTr("Expand group")

                    implicitWidth: 24
                    implicitHeight: 20

                    StateLayer {
                        radius: Appearance.rounding.small
                        color: Signal.palette.ink

                        function onClicked(): void {
                            root.toggleExpand(!root.expanded);
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        name: "chevron-down"
                        color: Signal.palette.inkMuted
                        rotation: root.expanded ? 180 : 0

                        Behavior on rotation {
                            Anim {
                                duration: Appearance.anim.durations.settle
                                easing.bezierCurve: Appearance.anim.curves.settle
                            }
                        }
                    }
                }

                Behavior on Layout.bottomMargin {
                    Anim {}
                }
            }

            NotifGroupList {
                id: notifList

                props: root.props
                notifs: root.notifs
                expanded: root.expanded
                container: root.container
                visibilities: root.visibilities
                onRequestToggleExpand: expand => root.toggleExpand(expand)
            }
        }
    }
}
