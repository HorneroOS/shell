pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Desktop placement for community plugins (M2): renders every
// enabled plugin whose manifest declares `placement: "desktop"` as
// a widget stacked on the desktop background layer (bottom-right
// stack in modules/background/Background.qml). Each plugin gets
// its own Loader, so a failing entrypoint is marked failed through
// the Plugins service and never takes the desktop (or other
// plugins) down. Plugin QML runs with the logged-in user's
// permissions; it is NOT sandboxed. Widgets are display-only in
// this slice: positioning/persistence is future work.
Item {
    id: root

    visible: Plugins.desktopPlugins().length > 0
    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    ColumnLayout {
        id: stack

        spacing: Appearance.spacing.normal

        Repeater {
            model: Plugins.desktopPlugins()

            delegate: StyledRect {
                id: card

                required property var modelData

                Layout.alignment: Qt.AlignRight
                implicitWidth: content.implicitWidth + Appearance.padding.large * 2
                implicitHeight: content.implicitHeight + Appearance.padding.large * 2
                radius: Appearance.rounding.large
                color: Colours.palette.m3surfaceContainer

                ColumnLayout {
                    id: content

                    anchors.centerIn: parent
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: card.modelData.name || card.modelData.id
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3onSurface
                    }

                    Loader {
                        id: pluginLoader

                        source: card.modelData.entrypoint ? `file://${Plugins.pluginsDir}/${card.modelData.id}/${card.modelData.entrypoint}` : ""
                        asynchronous: true

                        onStatusChanged: {
                            if (status === Loader.Ready)
                                Plugins.markLoaded(card.modelData.id);
                            else if (status === Loader.Error)
                                Plugins.markFailed(card.modelData.id, "desktop entrypoint failed to load (see shell log)");
                        }
                    }

                    StyledText {
                        visible: pluginLoader.status === Loader.Error
                        text: qsTr("This plugin failed to load.")
                        color: Colours.palette.m3error
                    }
                }
            }
        }
    }
}
