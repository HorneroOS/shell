pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// The shared "Applied · Undo" strip (services/Undo.qml, docs/CONTROL-CENTER-APPLY.md).
// Non-blocking: it never takes focus on its own and never covers a
// control. The Undo button is a normal Tab stop, Ctrl+Z (outside text
// fields) triggers it too, the countdown waits while the strip is hovered
// or focused, and under reduced motion it neither slides nor animates.
Item {
    id: root

    readonly property bool shown: Undo.active
    readonly property bool failedKind: Undo.kind === "failed"
    readonly property string headline: {
        if (Undo.kind === "applied")
            return `${Microcopy.line("undo.applied")} · ${Undo.title}`;
        if (Undo.kind === "undone")
            return `${Microcopy.line("undo.undone")} · ${Undo.title}`;
        return Undo.title;
    }
    readonly property string accessibleText: {
        const base = Undo.kind === "applied" ? `${Microcopy.plainLine("undo.applied")}: ${Undo.title}` : Undo.kind === "undone" ? `${Microcopy.plainLine("undo.undone")}: ${Undo.title}` : `${Undo.title}. ${Undo.reason}`;
        return Undo.detail ? `${base}. ${Undo.detail}` : base;
    }

    visible: shown || strip.opacity > 0
    implicitWidth: strip.implicitWidth
    implicitHeight: strip.implicitHeight

    Shortcut {
        // Ctrl+Z belongs to a text field while one has focus.
        readonly property Item focused: root.Window.activeFocusItem
        enabled: Undo.canUndo && !(focused && typeof focused.selectAll === "function")
        sequence: "Ctrl+Z"
        onActivated: Undo.undo()
    }

    StyledRect {
        id: strip

        readonly property bool reduced: Appearance.anim.reduced

        implicitWidth: row.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: row.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.small
        color: root.failedKind ? Signal.palette.alertWell : Signal.palette.raised
        border.width: 1
        border.color: root.failedKind ? Signal.palette.alert : Signal.palette.ruleStrong
        opacity: root.shown ? 1 : 0
        y: strip.reduced || root.shown ? 0 : Appearance.spacing.normal

        Accessible.role: root.failedKind ? Accessible.AlertMessage : Accessible.StaticText
        Accessible.name: root.accessibleText

        readonly property bool holding: hover.hovered || undoButton.stateLayer.activeFocus || dismissButton.stateLayer.activeFocus

        onHoldingChanged: Undo.paused = strip.holding

        HoverHandler {
            id: hover
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.normal

            Glyph {
                name: root.failedKind ? "alert-circle" : "check"
                color: root.failedKind ? Signal.palette.alert : Signal.palette.signal
                Accessible.ignored: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 460
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.headline
                    elide: Text.ElideRight
                    font.weight: Appearance.font.weight.strong
                    color: root.failedKind ? Signal.palette.onAlertWell : Signal.palette.ink
                    Accessible.ignored: true
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.failedKind ? Undo.reason : Undo.detail
                    wrapMode: Text.WordWrap
                    font.pointSize: Appearance.font.size.small
                    color: root.failedKind ? Signal.palette.onAlertWell : Signal.palette.inkMuted
                    Accessible.ignored: true
                }
            }

            TextButton {
                id: undoButton

                visible: Undo.canUndo
                text: strip.reduced ? qsTr("Undo (%1 s)").arg(Math.ceil(Undo.remainingMs / 1000)) : qsTr("Undo")
                type: TextButton.Tonal
                Accessible.name: qsTr("Undo %1").arg(Undo.title)
                onClicked: Undo.undo()
            }

            TextButton {
                id: dismissButton

                text: qsTr("Dismiss")
                type: TextButton.Text
                Accessible.name: qsTr("Dismiss the notice about %1").arg(Undo.title)
                onClicked: Undo.dismiss()
            }
        }

        // Remaining time as a hairline; replaced by the number under
        // reduced motion (no moving element at all).
        Rectangle {
            visible: !strip.reduced && Undo.kind === "applied"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 2
            width: Undo.holdMs > 0 ? parent.width * Undo.remainingMs / Undo.holdMs : 0
            color: Signal.palette.signal
        }

        Behavior on opacity {
            enabled: !strip.reduced

            Anim {}
        }
    }
}
