import QtQuick

// Native popout detail row (shell modules/bar/popouts): a body-size label
// on the left and its value right-aligned on the same line, the row shape
// every native popout (Network, Audio, Battery) uses for facts. Popovers
// compose these under a UiText "subtitle" header instead of hero metrics
// and chips, so extension popovers read like the shell's own.
Row {
    id: root

    property string label: ""
    property string value: ""

    spacing: Theme.spacingSmall

    UiText {
        id: labelItem

        role: "body"
        text: root.label
    }

    // Fill only what label and value leave: sizing the filler from the
    // row width alone pushes the value past the row's right edge.
    Item {
        width: Math.max(0, root.width - labelItem.implicitWidth - valueItem.implicitWidth - root.spacing * 2)
        height: 1
    }

    UiText {
        id: valueItem

        role: "body"
        horizontalAlignment: Text.AlignRight
        text: root.value
    }
}
