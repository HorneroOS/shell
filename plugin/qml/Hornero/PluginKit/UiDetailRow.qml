import QtQuick

// Popout fact row (visual language §7.1): a label on the left and its
// value right-aligned in Plex Mono with tabular figures, 32 px tall.
// An unavailable value shows an em dash in `inkMuted`.
Item {
    id: root

    property string label: ""
    property string value: ""
    property bool available: true
    property string glyph: ""

    readonly property bool _shown: root.available && root.value.length > 0

    implicitWidth: (root.glyph.length > 0 ? 20 + Theme.spacing.smaller : 0) + labelItem.implicitWidth + Theme.spacing.normal + valueItem.implicitWidth
    implicitHeight: Math.max(24, labelItem.implicitHeight)

    Accessible.role: Accessible.StaticText
    Accessible.name: `${root.label}: ${root._shown ? root.value : "unavailable"}`

    Row {
        id: row

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing.smaller

        UiIcon {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: Theme.font.size.normal
            color: Theme.palette.inkMuted
        }

        UiText {
            id: labelItem

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, root.width - valueItem.width - Theme.spacing.normal - (root.glyph.length > 0 ? 20 + Theme.spacing.smaller : 0)))
            role: "body"
            text: root.label
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    UiText {
        id: valueItem

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // A long value (an audio device name) elides inside the row instead
        // of printing over the label: it may take what the label does not
        // need, but never less than 60% of the row.
        readonly property real labelNeed: labelItem.implicitWidth + Theme.spacing.normal + (root.glyph.length > 0 ? 20 + Theme.spacing.smaller : 0)
        width: Math.min(implicitWidth, Math.max(root.width * 0.6, root.width - labelNeed))
        elide: Text.ElideMiddle
        wrapMode: Text.NoWrap
        horizontalAlignment: Text.AlignRight
        role: "value"
        color: root._shown ? Theme.palette.ink : Theme.palette.inkMuted
        text: root._shown ? root.value : "—"
    }
}
