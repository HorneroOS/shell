pragma ComponentBehavior: Bound

import qs.components
import qs.components.motion
import qs.services
import qs.config
import Quickshell
import QtQuick

// Desktop widget host (PluginKit 3, RFC 0001 §5b): renders every enabled
// extension with an enabled desktop surface on this screen's desktop
// layer, each in its own DesktopWidgetFrame (own Loader, own geometry).
// Bar indicators, dashboard cards and desktop widgets share one widget
// API (PluginKit), one token set and one data-provider layer — there is
// no second widget engine. Plugin QML runs with the logged-in user's
// permissions; it is NOT sandboxed.
//
// Edit mode (Plugins.desktopEditing, `qs ipc call plugins editDesktop`
// or Control Center) shows move/resize affordances and a toolbar; the
// person's geometry persists per screen in Config.plugins.desktopWidgets.
Item {
    id: root

    required property string screenName
    // Zones to keep clear, in this item's coordinates (the desktop clock).
    property var reserved: []

    // `user`: the person's own enabled desktop widgets. `instruments`
    // (Signal): the curated deck, composed per screen by services/deck.js.
    // `none` (Focus, Gaming): nothing is instantiated, so nothing draws and
    // no widget holds a provider lease.
    readonly property bool userSet: Experience.desktopWidgets === "user" && Experience.desktopWidgetsVisible
    readonly property bool deckWanted: Experience.instruments && Experience.desktopWidgetsVisible
    readonly property var widgets: root.userSet ? Plugins.desktopPlugins() : []

    readonly property var deckEntries: root.deckWanted ? Plugins.deckPlugins() : []
    readonly property var deckComposition: {
        const hints = ({});
        const have = ({});
        for (const entry of root.deckEntries) {
            hints[entry.id] = Plugins.surfaceFor(entry, "desktop") ?? ({});
            have[entry.id] = true;
        }
        return Experience.deckCompose({
            area: {
                width: root.width,
                height: root.height
            },
            items: Experience.deckItems(hints).filter(i => have[i.id]),
            hidden: Experience.deckHidden,
            reserved: root.reserved,
            saved: Experience.deckSaved(root.screenName)
        });
    }
    // Placements that fit. The model only changes when a placement does
    // (not on every plugin state update), and is kept while the deck fades
    // out so leaving the mode exits cleanly before the widgets unload.
    readonly property string deckKey: JSON.stringify(root.deckComposition.placements)
    property var _deckLast: []
    onDeckKeyChanged: if (root.deckWanted)
        root._deckLast = root.deckComposition.placements
    onDeckWantedChanged: if (root.deckWanted)
        root._deckLast = root.deckComposition.placements
    readonly property var deckModel: root.deckWanted || deckLayer.opacity > 0 ? root._deckLast : []

    // Status for the Experience pane: why each curated widget is or is
    // not on screen (not installed, untrusted, hidden, no room, ...).
    readonly property var deckStatus: Experience.deckStatus(root.deckComposition, Plugins.deckAvailability(), Experience.deckHidden)

    readonly property bool hasContent: root.widgets.length > 0 || root.deckModel.length > 0

    Repeater {
        model: root.widgets

        delegate: DesktopWidgetFrame {
            required property var modelData
            required property int index

            entry: modelData
            screenName: root.screenName
            area: root
            // Channel numbers count from 01 in manifest order.
            channel: index + 1
        }
    }

    Item {
        id: deckLayer

        anchors.fill: parent
        opacity: root.deckWanted ? 1 : 0

        Behavior on opacity {
            FadeAnim {
                leaving: !root.deckWanted
            }
        }

        Repeater {
            model: root.deckModel

            delegate: DesktopWidgetFrame {
                required property var modelData
                required property int index

                entry: Plugins.deckPlugins().find(e => e.id === modelData.id) ?? ({
                        id: modelData.id,
                        name: "",
                        entrypoint: ""
                    })
                deckPlacement: modelData
                screenName: root.screenName
                area: root
                channel: index + 1
            }
        }
    }

    // Edit toolbar: a lifted strip centred at the top of the widget area.
    Rectangle {
        id: toolbar

        visible: Plugins.desktopEditing && root.hasContent
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: toolbarRow.implicitWidth + Appearance.padding.larger * 2
        height: 36
        radius: Appearance.rounding.small
        color: Signal.palette.lifted
        border.width: 1
        border.color: Signal.palette.ruleStrong
        z: 10

        Row {
            id: toolbarRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.normal

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 14
                color: Signal.palette.cue
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                mono: true
                font.pointSize: Appearance.font.size.small
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Appearance.font.size.small * 0.08
                color: Signal.palette.ink
                text: qsTr("Edit widgets")
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
                text: qsTr("Drag to move · corner to resize · 8 px grid")
            }

            ToolbarButton {
                label: qsTr("Reset layout")
                onActivated: {
                    if (root.deckWanted) {
                        // Restore the factory deck on this display.
                        Experience.resetDeck(Experience.mode, root.screenName);
                        return;
                    }
                    for (const widget of root.widgets)
                        Config.plugins.resetDesktopWidgetGeometry(widget.id, root.screenName);
                }
            }

            ToolbarButton {
                label: qsTr("Done")
                primary: true
                onActivated: Plugins.setDesktopEditing(false)
            }
        }
    }

    component ToolbarButton: Rectangle {
        id: button

        property string label: ""
        property bool primary: false

        signal activated

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: buttonLabel.implicitWidth + Appearance.padding.larger * 2
        height: 24
        radius: Appearance.rounding.small
        color: button.primary ? Signal.palette.signal : buttonArea.containsMouse ? Signal.palette.raised : Signal.palette.panel
        border.width: button.primary ? 0 : 1
        border.color: Signal.palette.ruleStrong

        Accessible.role: Accessible.Button
        Accessible.name: button.label
        Accessible.onPressAction: button.activated()

        StyledText {
            id: buttonLabel

            anchors.centerIn: parent
            font.pointSize: Appearance.font.size.small
            font.weight: button.primary ? Font.Medium : Font.Normal
            color: button.primary ? Signal.palette.onSignal : Signal.palette.ink
            text: button.label
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
