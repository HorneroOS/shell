import QtQuick

// Popout action row (visual language §7.1): a full-width 32 px row —
// leading glyph in `inkMuted`, label filling the row, optional trailing
// glyph or eyebrow — hovering to `raised`, pressing to `lifted`.
// `selected: true` is the active choice: `signalWell` fill,
// `onSignalWell` content and an ACTIVE eyebrow.
Item {
    id: root

    property string text: ""
    property string glyph: ""
    property string trailingGlyph: ""
    // Trailing eyebrow text (e.g. a shortcut or "ACTIVE").
    property string trailingText: ""
    property bool selected: false
    property string tooltipText: ""
    property string accessibleName: root.text
    property bool enabled: true

    signal clicked

    readonly property color _ink: !root.enabled ? Theme.palette.inkFaint : root.selected ? Theme.palette.onSignalWell : Theme.palette.ink
    readonly property color _muted: !root.enabled ? Theme.palette.inkFaint : root.selected ? Theme.palette.onSignalWell : Theme.palette.inkMuted

    implicitWidth: row.implicitWidth + Theme.padding.large * 2
    implicitHeight: 32

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.description: root.tooltipText
    Accessible.checked: root.selected

    activeFocusOnTab: enabled
    Keys.onReturnPressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onSpacePressed: event => {
        if (root.enabled) {
            root.clicked();
            event.accepted = true;
        }
    }

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    HoverHandler {
        id: hover

        enabled: root.enabled
    }

    TapHandler {
        id: tap

        enabled: root.enabled
        onTapped: root.clicked()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.small
        color: root.selected ? Theme.palette.signalWell : tap.pressed ? Theme.palette.lifted : hover.hovered ? Theme.palette.raised : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration("quick")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.rounding.small + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.palette.focus
        visible: root.activeFocus && Theme.keyboardFocus && root.enabled
    }

    Row {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Theme.padding.large
        anchors.rightMargin: Theme.padding.large
        spacing: Theme.spacing.normal

        UiIcon {
            id: lead

            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: Theme.font.size.larger
            color: root._muted
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - (lead.visible ? lead.implicitWidth + row.spacing : 0) - (trail.visible ? trail.implicitWidth + row.spacing : 0) - (trailLabel.visible ? trailLabel.implicitWidth + row.spacing : 0)
            role: "body"
            color: root._ink
            text: root.text
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        UiText {
            id: trailLabel

            visible: root.trailingText.length > 0 || root.selected
            anchors.verticalCenter: parent.verticalCenter
            role: "eyebrow"
            color: root._muted
            text: root.trailingText.length > 0 ? root.trailingText : "Active"
        }

        UiIcon {
            id: trail

            visible: root.trailingGlyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.trailingGlyph
            size: Theme.font.size.normal
            color: root._muted
        }
    }
}
