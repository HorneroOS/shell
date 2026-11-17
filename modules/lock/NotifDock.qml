pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var lock

    anchors.fill: parent
    spacing: Appearance.spacing.smaller

    // Privacy boundary: while locked, notification bodies stay hidden and
    // even the count is withheld — only the neutral placeholder shows.
    readonly property bool contentHidden: Config.lock.hideNotifs

    Item {
        id: clipRect

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true

        Loader {
            // Fit the dock instead of centring at the text's natural width,
            // so a narrow dock wraps the placeholder rather than clipping it.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            height: item?.implicitHeight ?? 0
            active: opacity > 0
            opacity: root.contentHidden || Notifs.list.length === 0 ? 1 : 0

            sourceComponent: ColumnLayout {
                spacing: Appearance.spacing.small

                HorneroSprite {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Appearance.spacing.small
                    visible: Atmosphere.mascot && !Config.lock.hideNotifs
                    pose: "sleep"
                }

                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Config.lock.hideNotifs || !Atmosphere.mascot
                    name: Config.lock.hideNotifs ? "lock" : "bell-off"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Config.lock.hideNotifs ? qsTr("Unlock to read notifications") : Microcopy.line("notifications.empty")
                    color: Signal.palette.inkMuted
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.scan
                }
            }
        }

        StyledListView {
            anchors.fill: parent

            visible: !root.contentHidden
            spacing: Appearance.spacing.small
            clip: true

            model: ScriptModel {
                values: {
                    const list = Notifs.notClosed.map(n => [n.appName, null]);
                    return [...new Map(list).keys()];
                }
            }

            delegate: NotifGroup {}
        }
    }
}
