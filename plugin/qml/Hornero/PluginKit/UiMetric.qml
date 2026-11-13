import QtQuick

Column {
    id: root

    property string label: ""
    property string value: ""
    property string unit: ""

    spacing: Theme.spacingSmall

    UiText {
        text: root.label
        role: "caption"
    }

    Row {
        spacing: Theme.spacingSmall

        UiText {
            text: root.value
            role: "title"
        }

        UiText {
            visible: root.unit.length > 0
            text: root.unit
            role: "caption"
        }
    }
}
