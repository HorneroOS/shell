pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// One row of a ChannelPanel: label and optional one-line description on the
// left, the control (rocker, readout well, segmented control, button) on the
// right. Wide controls go in `below`, full width under the label. Rows are
// separated by a hairline; the first row of a panel has none.
Item {
    id: root

    property string label: ""
    property string description: ""
    default property alias trailing: trailingRow.data
    property alias below: belowColumn.data

    readonly property bool isFirst: root.parent && root.parent.children.length > 0 && root.parent.children[0] === root

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Appearance.padding.normal * 2

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isFirst
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    visible: root.label.length > 0
                    text: root.label
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.description.length > 0
                    text: root.description
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                id: trailingRow

                spacing: Appearance.spacing.small
            }
        }

        ColumnLayout {
            id: belowColumn

            Layout.fillWidth: true
            spacing: Appearance.spacing.small
        }
    }
}
