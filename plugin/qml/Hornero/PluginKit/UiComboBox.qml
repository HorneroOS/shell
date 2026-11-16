import QtQuick
import QtQuick.Controls

// Signal selector: a `panel` field with a `ruleStrong` outline and a
// chevron; the list opens as a `lifted` menu whose current row uses the
// selected treatment (`signalWell`). Keyboard: Space/Enter opens, arrows
// move, Escape closes.
ComboBox {
    id: root

    property string tooltipText: ""
    property string accessibleName: ""

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.ComboBox
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    font.family: Theme.font.family.sans
    font.pointSize: Theme.font.size.smaller

    delegate: ItemDelegate {
        id: row

        required property var modelData
        required property int index

        width: ListView.view ? ListView.view.width : implicitWidth
        height: 30
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: root.textRole ? (Array.isArray(root.model) ? row.modelData[root.textRole] : row.modelData) : row.modelData
            color: root.currentIndex === row.index ? Theme.palette.onSignalWell : Theme.palette.ink
            font: root.font
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: root.currentIndex === row.index ? Theme.palette.signalWell : row.highlighted ? Theme.palette.raised : "transparent"
        }
    }

    indicator: UiIcon {
        x: root.width - width - Theme.padding.normal
        y: (root.height - height) / 2
        name: "chevron-down"
        size: Theme.font.size.normal
        color: root.enabled ? Theme.palette.inkMuted : Theme.palette.inkFaint
    }

    contentItem: Text {
        leftPadding: Theme.padding.normal
        rightPadding: root.indicator.width + Theme.padding.normal * 2
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 160
        implicitHeight: 30
        radius: Theme.rounding.small
        color: root.pressed ? Theme.palette.lifted : root.hovered ? Theme.palette.raised : Theme.palette.panel
        border.width: 1
        border.color: Theme.palette.ruleStrong

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.rounding.small + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.palette.focus
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2, 240)
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }

        background: Rectangle {
            radius: Theme.rounding.small
            color: Theme.palette.lifted
            border.width: 1
            border.color: Theme.palette.ruleStrong
        }
    }
}
