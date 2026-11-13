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
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.onClicked();
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger

        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "function"
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            id: result

            color: {
                if (root.math.length > 0 && !root.result.ok)
                    return Colours.palette.m3error;
                if (!root.math)
                    return Colours.palette.m3onSurfaceVariant;
                return Colours.palette.m3onSurface;
            }

            text: root.math.length === 0 ? qsTr("Type an expression to calculate") : (root.result.ok ? qsTr("%1 = %2").arg(root.math).arg(root.result.text) : qsTr("Error"))
            elide: Text.ElideLeft

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledRect {
            color: Colours.palette.m3tertiary
            radius: Appearance.rounding.normal
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Appearance.padding.small * 2

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                id: stateLayer

                color: Colours.palette.m3onTertiary

                function onClicked(): void {
                    Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.terminal, "fish", "-C", `exec qalc -i '${root.math}'`]);
                    root.list.visibilities.launcher = false;
                }
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Appearance.spacing.small

                text: qsTr("Open in calculator")
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.normal

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal

                text: "open_in_new"
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.large
            }

            Behavior on implicitWidth {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }
    }
}
