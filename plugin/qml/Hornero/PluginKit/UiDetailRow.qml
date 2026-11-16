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
        role: "body"
        text: root.label
    }

    Item {
        width: Math.max(0, root.width - x)
        height: 1
    }

    UiText {
        role: "body"
        horizontalAlignment: Text.AlignRight
        text: root.value
    }
}
