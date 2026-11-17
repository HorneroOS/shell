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
    StableList {
        id: userStable

        source: root.userSet ? Plugins.desktopPlugins() : []
    }

    // Placement of the person's own widgets. The same solver as the Signal
    // deck (services/deck.js) lays them out: saved positions are honoured
    // first, the rest flow down the left and right rails by priority
    // (enable order), around the reserved zones (desktop clock, Companion).
    // A widget that does not fit is not drawn rather than drawn on top of
    // another; it is listed in Plugins.desktopNoRoom (plugins status) and
    // comes back when there is room or it is moved in edit mode.
    readonly property var userComposition: {
        const hints = ({});
        const items = [];
        const saved = ({});
        const slots = Config.plugins.desktopWidgetSlots;
        const perScreen = slots && typeof slots === "object" ? slots[root.screenName || "default"] : null;
        let priority = 0;
        for (const entry of userStable.list) {
            const hint = Plugins.surfaceFor(entry, "desktop") ?? ({});
            const explicit = perScreen && typeof perScreen === "object" ? perScreen[entry.instanceKey] : undefined;
            const slot = Config.plugins.allowedDesktopSlots.includes(explicit) ? explicit : (Config.plugins.allowedDesktopSlots.includes(hint.anchor) ? hint.anchor : "bottom-right");
            const minWidth = hint.minWidth ?? 160;
            const minHeight = hint.minHeight ?? 96;
            items.push({
                id: entry.instanceKey,
                priority: priority++,
                side: slot.endsWith("left") ? "left" : "right",
                edge: slot.startsWith("bottom") ? "bottom" : "top",
                minWidth: minWidth,
                minHeight: minHeight,
                width: Math.max(minWidth, hint.width ?? 320),
                height: Math.max(minHeight, hint.height ?? 300)
            });
            const geometry = Config.plugins.desktopWidgetGeometry(entry.instanceKey, root.screenName);
            if (geometry)
                saved[entry.instanceKey] = geometry;
        }
        return Experience.deckCompose({
            area: {
                width: root.width,
                height: root.height
            },
            items: items,
            hidden: [],
            reserved: root.reserved,
            saved: saved
        });
    }
    readonly property var userPlacements: {
        const byId = ({});
        for (const placement of root.userComposition.placements)
            byId[placement.id] = placement;
        return byId;
    }
    readonly property var widgets: root.userSet ? userStable.list.filter(e => root.userPlacements[e.instanceKey] !== undefined) : []
    readonly property var noRoomIds: root.userComposition.dropped.map(d => d.id)
    onNoRoomIdsChanged: Plugins.desktopNoRoom = root.userSet ? root.noRoomIds : []

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
            items: Experience.deckItems(hints, root.measuredNeed).filter(i => have[i.id]),
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
            autoPlacement: root.userPlacements[modelData.instanceKey] ?? null
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
                onNeedMeasured: (id, need) => root.noteNeed(id, need)
                screenName: root.screenName
                area: root
                channel: index + 1
            }
        }
    }

    // Edit toolbar: a lifted strip in the middle of the widget area, where the
    // solver keeps the centre open (a strip at the top covered the header of
    // top-row widgets). The hint line only shows when the screen is wide.
    Rectangle {
        id: toolbar

        visible: Plugins.desktopEditing && root.hasContent
        anchors.centerIn: parent
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
                visible: root.width >= 1500
                text: qsTr("Drag to move · corner to resize · 8 px grid")
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.noRoomIds.length > 0
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.alert
                text: qsTr("%n hidden: no room", "", root.noRoomIds.length)
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
                        Config.plugins.resetDesktopWidgetGeometry(widget.instanceKey, root.screenName);
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
