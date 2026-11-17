pragma ComponentBehavior: Bound

import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Desktop widgets manager: the one place to switch, arrange, preset and
// configure the Signal deck of a mode. Extensions stays the place to
// install, enable and trust packages; this section never writes
// extension lifecycle state. Every write goes through services/Experience.qml
// (shell.json experience.deck); per-widget options are the extension's
// own typed settings, opened in Extensions with one click.
ColumnLayout {
    id: root

    required property string mode
    required property string modeLabel
    required property Session session

    // Reported to the pane's message line (errors only).
    signal failed(string message)

    readonly property var availability: Plugins.deckAvailability()
    readonly property var hidden: {
        const _deck = Config.experience.deck;
        return Experience.deckHiddenFor(root.mode);
    }
    readonly property var order: {
        const _deck = Config.experience.deck;
        return Experience.deckOrderFor(root.mode);
    }
    readonly property var anchorMap: {
        const _deck = Config.experience.deck;
        return Experience.deckAnchorsFor(root.mode);
    }
    readonly property var savedPresets: {
        const _deck = Config.experience.deck;
        return Experience.deckPresetNames(root.mode);
    }
    readonly property bool customised: {
        const _deck = Config.experience.deck;
        return Experience.deckCustomisedFor(root.mode);
    }
    readonly property string screenName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "default"
    // Edit mode draws on the active mode's desktop only.
    readonly property bool editable: root.mode === Experience.mode && Experience.instruments && Experience.desktopWidgetsVisible

    readonly property var items: {
        const _entries = Plugins.entries;
        const hints = ({});
        for (const entry of Plugins.deckPlugins())
            hints[entry.id] = Plugins.surfaceFor(entry, "desktop") ?? ({});
        return Experience.deckItemsFor(root.mode, hints).filter(i => hints[i.id] !== undefined);
    }
    readonly property var itemById: {
        const byId = ({});
        for (const item of root.items)
            byId[item.id] = item;
        return byId;
    }
    // The map is the real solver on a 1920×1080 reference display.
    readonly property var composition: {
        const _deck = Config.experience.deck;
        const out = Experience.deckCompose({
            area: {
                width: 1920,
                height: 1080
            },
            items: root.items,
            hidden: root.hidden,
            reserved: [],
            saved: Experience.deckSavedFor(root.mode, root.screenName)
        });
        out.placements = out.placements.map(p => Object.assign({}, p, {
                label: root.itemById[p.id]?.label ?? "",
                glyph: root.itemById[p.id]?.glyph ?? ""
            }));
        return out;
    }
    readonly property var noRoom: root.composition.dropped.filter(d => d.reason === "no-room").map(d => d.id)

    function report(res: string): void {
        if (res.startsWith("error"))
            root.failed(res);
    }

    function note(id: string): string {
        const avail = root.availability[id] ?? "not-installed";
        if (avail === "ready")
            return root.noRoom.includes(id) ? qsTr("no room on the desktop") : "";
        return avail === "not-installed" ? qsTr("not installed") : avail === "untrusted" ? qsTr("not trusted") : avail === "safe-mode" ? qsTr("safe mode") : avail === "kit-too-old" ? qsTr("shell too old") : qsTr("failed to load");
    }

    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Instruments on the desktop in %1 mode. They come from the installed first-party extensions, sit on the flanks of each display and never cover the bar or the desktop clock. A hidden widget is unloaded and releases the data it was reading.").arg(root.modeLabel)
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        TextButton {
            text: Plugins.desktopEditing ? qsTr("Finish editing") : qsTr("Edit desktop")
            type: TextButton.Filled
            disabled: !root.editable || Plugins.safeMode
            onClicked: Plugins.setDesktopEditing(!Plugins.desktopEditing)
        }

        TextButton {
            visible: root.customised
            text: qsTr("Reset layout")
            type: TextButton.Tonal
            onClicked: root.report(Experience.resetDeck(root.mode, ""))
        }

        Item {
            Layout.fillWidth: true
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: root.editable ? qsTr("Edit desktop lets you drag a widget, resize it from its corner and snap to an 8 px grid on the real desktop. Reset layout restores the factory arrangement; saved presets are kept.") : root.mode !== Experience.mode ? qsTr("Switch to %1 mode to edit its desktop. Switches, anchors, order and presets below apply to %1 now.").arg(root.modeLabel) : qsTr("The desktop deck is not shown in this mode, so there is nothing to edit.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    DeckMiniature {
        Layout.fillWidth: true
        Layout.maximumWidth: 560
        composition: root.composition
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Desktop map: the real layout solver on a 1920×1080 display, bar excluded. Tiles outlined in the cue colour keep a position you set by hand. Other displays are solved on their own.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    // ---- Presets -------------------------------------------------------
    StyledText {
        Layout.topMargin: Appearance.spacing.small
        text: qsTr("Presets")
        font.weight: 500
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: Experience.deckBuiltinPresets

            delegate: TextButton {
                required property var modelData

                text: modelData.label
                type: TextButton.Tonal
                onClicked: root.report(Experience.applyDeckBuiltin(root.mode, modelData.id))
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small
        visible: root.savedPresets.length > 0

        Repeater {
            model: root.savedPresets

            delegate: Row {
                id: savedRow

                required property string modelData

                spacing: 0

                TextButton {
                    text: savedRow.modelData
                    type: TextButton.Tonal
                    onClicked: root.report(Experience.applyDeckPreset(root.mode, savedRow.modelData))
                }

                IconButton {
                    icon: "x"
                    type: IconButton.Text
                    accessibleName: qsTr("Delete preset %1").arg(savedRow.modelData)
                    onClicked: root.report(Experience.deleteDeckPreset(root.mode, savedRow.modelData))
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledRect {
            Layout.fillWidth: true
            Layout.maximumWidth: 260
            implicitHeight: presetName.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.small
            color: Signal.palette.sunken
            border.width: 1
            border.color: presetName.activeFocus ? Signal.palette.focus : Signal.palette.rule

            StyledTextField {
                id: presetName

                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                placeholderText: qsTr("Name this arrangement")
                maximumLength: 24
                Accessible.name: qsTr("Preset name")
                onAccepted: saveButton.clicked()
            }
        }

        TextButton {
            id: saveButton

            text: qsTr("Save preset")
            type: TextButton.Text
            disabled: presetName.text.trim().length === 0
            onClicked: {
                const res = Experience.saveDeckPreset(root.mode, presetName.text.trim());
                root.report(res);
                if (res === "ok")
                    presetName.text = "";
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("A saved preset keeps which widgets are on, their anchors, order and any position you set by hand, for %1 mode (up to 5). Built-in presets only choose which widgets are on.").arg(root.modeLabel)
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    // ---- Widgets -------------------------------------------------------
    StyledText {
        Layout.topMargin: Appearance.spacing.small
        text: qsTr("Widgets")
        font.weight: 500
    }

    Repeater {
        model: root.order

        delegate: StyledRect {
            id: card

            required property string modelData
            required property int index
            readonly property var item: root.itemById[card.modelData] ?? null
            readonly property string avail: root.availability[card.modelData] ?? "not-installed"
            readonly property bool ready: card.avail === "ready"
            readonly property bool shown: card.ready && !root.hidden.includes(card.modelData)
            readonly property string anchor: root.anchorMap[card.modelData] ?? (card.item ? `${card.item.side}-${card.item.edge}` : "right-top")
            readonly property var look: {
                const _deck = Config.experience.deck;
                return Experience.deckStyleOf(root.mode, card.modelData);
            }
            readonly property string label: card.modelData.replace(/^hornero-/, "").replace(/-/g, " ")

            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: "transparent"
            border.width: 1
            border.color: Signal.palette.rule

            ColumnLayout {
                id: cardCol

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    Glyph {
                        name: card.item?.glyph ?? "device-desktop"
                        size: Appearance.font.size.larger
                        color: card.shown ? Signal.palette.ink : Signal.palette.inkMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: card.item?.label ?? card.label
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.note(card.modelData)
                            font.pointSize: Appearance.font.size.small
                            color: root.noRoom.includes(card.modelData) ? Signal.palette.alert : Signal.palette.inkMuted
                            elide: Text.ElideRight
                        }
                    }

                    StyledSwitch {
                        enabled: card.ready
                        checked: card.shown
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: qsTr("Show %1").arg(card.item?.label ?? card.label)
                        Accessible.checked: card.shown
                        onToggled: root.report(Experience.setDeckHidden(root.mode, card.modelData, !checked))
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal
                    visible: card.ready

                    SegmentedControl {
                        accessibleName: qsTr("%1 side").arg(card.item?.label ?? card.label)
                        model: [qsTr("Left"), qsTr("Right")]
                        currentIndex: card.anchor.startsWith("left") ? 0 : 1
                        onActivated: index => root.report(Experience.setDeckAnchor(root.mode, card.modelData, `${index === 0 ? "left" : "right"}-${card.anchor.split("-")[1]}`))
                    }

                    SegmentedControl {
                        accessibleName: qsTr("%1 stacks from").arg(card.item?.label ?? card.label)
                        model: [qsTr("Top"), qsTr("Bottom")]
                        currentIndex: card.anchor.endsWith("top") ? 0 : 1
                        onActivated: index => root.report(Experience.setDeckAnchor(root.mode, card.modelData, `${card.anchor.split("-")[0]}-${index === 0 ? "top" : "bottom"}`))
                    }

                    Row {
                        spacing: 0

                        IconButton {
                            icon: "chevron-up"
                            type: IconButton.Text
                            disabled: card.index === 0
                            accessibleName: qsTr("Place %1 earlier").arg(card.item?.label ?? card.label)
                            onClicked: root.report(Experience.moveDeckWidget(root.mode, card.modelData, -1))
                        }

                        IconButton {
                            icon: "chevron-down"
                            type: IconButton.Text
                            disabled: card.index === root.order.length - 1
                            accessibleName: qsTr("Place %1 later").arg(card.item?.label ?? card.label)
                            onClicked: root.report(Experience.moveDeckWidget(root.mode, card.modelData, 1))
                        }
                    }

                    SegmentedControl {
                        accessibleName: qsTr("%1 size").arg(card.item?.label ?? card.label)
                        model: [qsTr("Small"), qsTr("Normal"), qsTr("Large")]
                        currentIndex: ["small", "normal", "large"].indexOf(card.look.size)
                        onActivated: index => root.report(Experience.setDeckStyle(root.mode, card.modelData, "size", ["small", "normal", "large"][index]))
                    }

                    Row {
                        spacing: Appearance.spacing.small

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Opacity")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }

                        // Commits on release: one config write per drag, the
                        // value label follows the thumb meanwhile.
                        StyledSlider {
                            id: opacitySlider

                            width: 140
                            from: 0.3
                            to: 1
                            stepSize: 0.05
                            value: card.look.opacity
                            accessibleName: qsTr("%1 opacity").arg(card.item?.label ?? card.label)
                            onPressedChanged: {
                                if (!pressed) {
                                    const v = Math.round(value * 100) / 100;
                                    root.report(Experience.setDeckStyle(root.mode, card.modelData, "opacity", v >= 1 ? "" : String(v)));
                                }
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            mono: true
                            text: `${Math.round(opacitySlider.value * 100)}%`
                            font.pointSize: Appearance.font.size.small
                        }
                    }

                    SegmentedControl {
                        accessibleName: qsTr("%1 accent").arg(card.item?.label ?? card.label)
                        model: [qsTr("Plain"), qsTr("Signal"), qsTr("Cue")]
                        currentIndex: ["default", "signal", "cue"].indexOf(card.look.accent)
                        onActivated: index => root.report(Experience.setDeckStyle(root.mode, card.modelData, "accent", index === 0 ? "" : ["default", "signal", "cue"][index]))
                    }

                    SegmentedControl {
                        accessibleName: qsTr("%1 density").arg(card.item?.label ?? card.label)
                        model: [qsTr("Compact"), qsTr("Cozy"), qsTr("Roomy")]
                        currentIndex: ["compact", "cozy", "roomy"].indexOf(card.look.density)
                        onActivated: index => root.report(Experience.setDeckStyle(root.mode, card.modelData, "density", index === 1 ? "" : ["compact", "cozy", "roomy"][index]))
                    }

                    TextButton {
                        text: qsTr("Settings")
                        type: TextButton.Text
                        onClicked: root.session.navigateTo("extensions", `plugin:${card.modelData}`)
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Anchor chooses the preferred side and which end of it a widget stacks from; order decides who is placed first when space runs out. Dragging a widget in Edit desktop overrides its anchor. Settings opens the extension's own options (metrics, units, formats…) in Extensions. Size, opacity, accent and density restyle the frame only; High Contrast keeps frames opaque. “Cozy corner” and “Kawaii night” are soft starting looks you can adjust.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }
}
