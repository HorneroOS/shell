import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Clickable (or informational) action card for Welcome pages.
// Callers pass already-translated strings (qsTr at the call site).
// A card with an empty shortcutId shows no badge; a non-interactive card
// renders description + badge only (no pointer, no focus).
StyledRect {
    id: root

    required property string icon
    required property string title
    required property string description
    property string shortcutId: ""
    property bool interactive: true
    // The one call to action on a page: filled `signal` segment.
    property bool primary: false

    signal activated()

    Accessible.role: root.interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.title
    Accessible.description: root.description

    Layout.fillWidth: true
    implicitHeight: Math.max(88, content.implicitHeight + Appearance.padding.normal * 2)

    radius: Appearance.rounding.small
    color: root.primary ? Signal.palette.signal : root.interactive && cardState.containsMouse ? Signal.palette.raised : Signal.palette.panel
    border.width: 1
    border.color: root.primary ? Signal.palette.signal : Signal.palette.rule

    Behavior on color {
        CAnim {}
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.small
        spacing: Appearance.spacing.normal

        Glyph {
            name: root.icon
            color: root.primary ? Signal.palette.onSignal : Signal.palette.signal
            font.pointSize: Appearance.font.size.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.smaller

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: root.primary ? Signal.palette.onSignal : Signal.palette.ink
                font.weight: Appearance.font.weight.strong
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.description
                color: root.primary ? Signal.palette.onSignal : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.smaller
                wrapMode: Text.WordWrap
            }

            // Keycap: the binding as a small square key, never a pill.
            StyledRect {
                visible: root.shortcutId !== "" && ShortcutHints.has(root.shortcutId)
                radius: Appearance.rounding.small
                color: Signal.palette.lifted
                border.width: 1
                border.color: Signal.palette.ruleStrong
                Layout.preferredHeight: badgeText.implicitHeight + 8
                Layout.preferredWidth: badgeText.implicitWidth + 16

                StyledText {
                    id: badgeText

                    anchors.centerIn: parent
                    mono: true
                    text: ShortcutHints.badge(root.shortcutId)
                    color: Signal.palette.ink
                    font.pointSize: Appearance.font.size.smaller
                    font.weight: Appearance.font.weight.strong
                }
            }
        }

        Glyph {
            visible: root.interactive
            name: "chevron-right"
            color: root.primary ? Signal.palette.onSignal : Signal.palette.inkMuted
        }
    }

    Interactive {
        id: cardState

        disabled: !root.interactive
        // The card signals hover with its own background shift.
        showHoverBackground: false
        onClicked: root.activated()
    }
}
