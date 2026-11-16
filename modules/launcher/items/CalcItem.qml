import "../services"
import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Calculator provider row (shell#250 slice 1): the expression
// is evaluated by the shell's own safe parser (services/Calc);
// Enter/click copies the result and closes the launcher, the
// historic launcher convention for this row.
Item {
    id: root

    required property var list
    readonly property string math: list.search.text.slice(`${Config.launcher.actionPrefix}calc `.length)
    readonly property var result: Calc.evaluate(math)

    function onClicked(): void {
        if (!root.result.ok)
            return;
        Quickshell.execDetached(["wl-copy", root.result.text]);
        root.list.visibilities.launcher = false;
    }

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: root.math.length > 0 ? qsTr("Copy calculation result: %1").arg(root.math) : qsTr("Calculator")

    StateLayer {
        radius: Appearance.rounding.small

        function onClicked(): void {
            root.onClicked();
        }
    }

    // Readout: the expression in mono, the result in a sunken well.
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        spacing: 12

        StyledText {
            mono: true
            text: root.math.length === 0 ? qsTr("Type an expression to calculate") : root.math
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
            elide: Text.ElideLeft
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: root.math.length > 0
            mono: true
            text: "="
            color: Signal.palette.inkMuted
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            visible: root.math.length > 0
            color: Signal.palette.sunken
            border.width: 1
            border.color: root.result.ok ? Signal.palette.rule : Signal.palette.alert
            radius: Appearance.rounding.small
            implicitWidth: result.implicitWidth + 16
            implicitHeight: result.implicitHeight + 4
            Layout.maximumWidth: root.width * 0.45
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                id: result

                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.Layout.maximumWidth - 16)
                text: root.result.ok ? root.result.text : qsTr("Error")
                color: root.result.ok ? Signal.palette.ink : Signal.palette.alert
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: Appearance.font.size.large
                elide: Text.ElideLeft
            }
        }

        // Quiet secondary action: open the expression in qalc.
        Rectangle {
            id: qalc

            implicitWidth: qalcLabel.implicitWidth + 16
            implicitHeight: 24
            radius: Appearance.rounding.small
            color: qalcLayer.containsMouse ? Signal.palette.raised : "transparent"
            border.width: 1
            border.color: Signal.palette.ruleStrong
            Layout.alignment: Qt.AlignVCenter

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Open in calculator")

            StateLayer {
                id: qalcLayer

                radius: Appearance.rounding.small

                function onClicked(): void {
                    Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.terminal, "fish", "-C", `exec qalc -i '${root.math}'`]);
                    root.list.visibilities.launcher = false;
                }
            }

            StyledText {
                id: qalcLabel

                anchors.centerIn: parent
                mono: true
                text: qsTr("QALC ↗")
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }
    }
}
