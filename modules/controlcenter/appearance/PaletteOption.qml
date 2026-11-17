import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// One selectable palette: the option's real colours (ThemeSwatch) over its
// name, a one-line note and the selected state. Used by every Appearance
// chooser that picks something with colours (Chromatic looks, colour
// schemes, saved palettes) so they read as one family; the Themes cards share the
// same ThemeSwatch face.
//
// A radio-style tile: Space/Enter choose, arrows emit `step(±1)` so the
// parent group can move the choice. Hover and keyboard focus both emit
// `previewStarted`/`previewEnded` for the optional live preview. The colours
// always come from `palette`/`terminal` (theme data or an engine result);
// the tile never invents any. State is also spelled out (a check glyph and
// "Selected"), never colour alone, and nothing animates.
StyledRect {
    id: root

    property string title: ""
    property string note: ""
    // Small right-aligned tag, e.g. "in use".
    property string badge: ""
    property bool selected: false
    property bool horizontal: false
    property bool tabStop: true
    // "radio" (one of a group) or "button" (an action such as Apply).
    property string kind: "radio"
    property var palette: ({
    })
    property var terminal: []
    property bool showTerminal: true
    property bool pending: false
    // What the palette is, for assistive tech ("Signal Night palette").
    property string paletteLabel: ""

    readonly property bool hovered: hoverArea.containsMouse

    signal activated
    signal step(int direction)
    signal previewStarted
    signal previewEnded

    implicitWidth: horizontal ? 280 : 150
    implicitHeight: (horizontal ? Math.max(swatch.implicitHeight, textCol.implicitHeight) : swatch.implicitHeight + textCol.implicitHeight + Appearance.spacing.small) + Appearance.padding.normal * 2
    radius: Config.appearance.cozyChips ? Appearance.rounding.large : Appearance.rounding.small
    color: selected ? Signal.palette.signalWell : hovered || activeFocus ? Signal.layer(Signal.palette.raised, 2) : Signal.layer(Signal.palette.raised, 1)
    border.width: selected || activeFocus ? 2 : 1
    border.color: activeFocus ? Signal.palette.focus : selected ? Signal.palette.signal : hovered ? Signal.palette.ruleStrong : Signal.palette.rule

    activeFocusOnTab: tabStop
    Accessible.role: kind === "radio" ? Accessible.RadioButton : Accessible.Button
    Accessible.name: title
    Accessible.description: [note, paletteLabel].filter(t => t !== "").join(". ")
    Accessible.checked: selected
    Accessible.focusable: true
    Accessible.onPressAction: root.activated()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activated();
            event.accepted = true;
        } else if (root.kind === "radio" && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
            root.step(1);
            event.accepted = true;
        } else if (root.kind === "radio" && (event.key === Qt.Key_Left || event.key === Qt.Key_Up)) {
            root.step(-1);
            event.accepted = true;
        }
    }
    onActiveFocusChanged: activeFocus ? root.previewStarted() : root.previewEnded()

    GridLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal
        columns: root.horizontal ? 2 : 1
        columnSpacing: Appearance.spacing.normal
        rowSpacing: Appearance.spacing.small

        ThemeSwatch {
            id: swatch

            Layout.fillWidth: !root.horizontal
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: root.horizontal ? 124 : -1
            compact: true
            showTerminal: root.showTerminal
            pending: root.pending
            palette: root.palette
            terminal: root.terminal
        }

        ColumnLayout {
            id: textCol

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Appearance.font.weight.strong
                    color: root.selected ? Signal.palette.onSignalWell : Signal.palette.ink
                }

                StyledText {
                    visible: root.badge !== "" && !root.selected
                    text: root.badge
                    mono: true
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }

                Glyph {
                    visible: root.selected
                    name: Config.appearance.cozyChips ? "heart" : "check"
                    color: Signal.palette.onSignalWell
                    font.pointSize: Appearance.font.size.normal
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.note !== ""
                text: root.note
                wrapMode: Text.WordWrap
                font.pointSize: Appearance.font.size.small
                color: root.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
            }
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.previewStarted()
        onExited: if (!root.activeFocus)
            root.previewEnded()
        onClicked: {
            root.forceActiveFocus();
            root.activated();
        }
    }
}
