pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Displays (shell#220, first slice): real monitor
// inventory and arrangement through `horneroctl hypr monitors`
// (read-only list/status; arrangement modes are the CLI's own
// confirmed mutations). Per-output resolution/scale editing stays
// tracked in #220 — this pane never hand-edits compositor config.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property var monitors: []
    property string statusText: qsTr("Reading displays…")
    property string actionText: ""
    property real brightness: 50
    property string brightnessText: qsTr("Reading brightness…")
    property string layoutCurrent: ""
    property string compositorText: ""
    property var animProfiles: []
    property string animCurrent: ""

    function refreshExtra(): void {
        if (!brightProc.running) {
            brightProc.out = "";
            brightProc.command = ["horneroctl", "--json", "hardware", "brightness", "status"];
            brightProc.running = true;
        }
        if (!layoutProc.running) {
            layoutProc.out = "";
            layoutProc.command = ["horneroctl", "--json", "hypr", "layout", "current"];
            layoutProc.running = true;
        }
        if (!animProc.running) {
            animProc.out = "";
            animProc.command = ["horneroctl", "--json", "hypr", "animations", "list"];
            animProc.running = true;
        }
        if (!animCurProc.running) {
            animCurProc.out = "";
            animCurProc.command = ["horneroctl", "--json", "hypr", "animations", "current"];
            animCurProc.running = true;
        }
    }

    function setBrightness(value: real): void {
        brightProc.out = "";
        brightProc.command = ["horneroctl", "--json", "hardware", "brightness", "set", (value / 100).toFixed(2), "--yes"];
        brightProc.running = true;
    }

    function applyLayout(layout: string): void {
        root.compositorText = qsTr("Applying layout…");
        compProc.out = "";
        compProc.command = ["horneroctl", "--json", "hypr", "layout", "set", layout, "--yes"];
        compProc.running = true;
    }

    function applyAnimProfile(profile: string): void {
        root.compositorText = qsTr("Applying animation profile…");
        compProc.out = "";
        compProc.command = ["horneroctl", "--json", "hypr", "animations", "set", profile, "--yes"];
        compProc.running = true;
    }

    function restoreCompositor(kind: string): void {
        root.compositorText = qsTr("Restoring…");
        compProc.out = "";
        compProc.command = kind === "layout" ? ["horneroctl", "--json", "hypr", "layout", "restore", "--yes"] : ["horneroctl", "--json", "hypr", "animations", "restore", "--yes"];
        compProc.running = true;
    }

    function refresh(): void {
        listProc.out = "";
        listProc.command = ["horneroctl", "hypr", "monitors", "list", "--json"];
        listProc.running = true;
    }

    function applyMode(mode: string): void {
        root.actionText = qsTr("Applying %1…").arg(mode);
        setProc.out = "";
        setProc.command = ["horneroctl", "hypr", "monitors", "set", mode, "--yes", "--json"];
        setProc.running = true;
    }

    Component.onCompleted: {
        root.refresh();
        root.refreshExtra();
    }

    Timer {
        id: brightnessTimer

        interval: 400
        onTriggered: root.setBrightness(root.brightness)
    }

    Process {
        id: brightProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                brightProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(brightProc.out.trim());
                root.brightnessText = payload.message ? payload.message.toString() : "";
                const d = payload.data ?? {};
                const raw = d.brightness ?? d.percent ?? d.value ?? "";
                const parsed = parseFloat(raw);
                if (!isNaN(parsed))
                    root.brightness = parsed <= 1 ? parsed * 100 : parsed;
            } catch (e) {
                root.brightnessText = qsTr("Brightness backend unavailable on this system.");
            }
        }
    }

    Process {
        id: layoutProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                layoutProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(layoutProc.out.trim());
                const d = payload.data ?? {};
                root.layoutCurrent = payload.ok ? (d.layout ?? "") : "";
                if (!payload.ok)
                    root.compositorText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.layoutCurrent = "";
            }
        }
    }

    Process {
        id: animProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                animProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(animProc.out.trim());
                const d = payload.data ?? {};
                root.animProfiles = String(d.profiles ?? "").split(",").map(s => s.trim()).filter(s => s !== "");
            } catch (e) {
                root.animProfiles = [];
            }
        }
    }

    Process {
        id: animCurProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                animCurProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(animCurProc.out.trim());
                const d = payload.data ?? {};
                root.animCurrent = payload.ok ? (d.profile ?? "") : "";
            } catch (e) {
                root.animCurrent = "";
            }
        }
    }

    Process {
        id: compProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                compProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(compProc.out.trim());
                root.compositorText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.compositorText = qsTr("The compositor command did not answer.");
            }
            root.refreshExtra();
        }
    }

    Process {
        id: listProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                listProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(listProc.out.trim());
                const lines = (payload.message ?? "").toString().split("\n").filter(l => l.trim() !== "");
                root.monitors = lines.map(l => ({
                            "label": l.trim()
                        }));
                root.statusText = payload.ok ? qsTr("%1 display(s) connected").arg(root.monitors.length) : payload.message.toString();
            } catch (e) {
                root.monitors = [];
                root.statusText = qsTr("horneroctl monitors unavailable on this system.");
            }
        }
    }

    Process {
        id: setProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                setProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(setProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.actionText = qsTr("The arrangement command did not answer. Check: horneroctl hypr monitors status");
            }
            root.refresh();
        }
    }

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Displays")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: monCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: monCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Connected displays")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        Repeater {
                            model: root.monitors

                            delegate: StyledText {
                                required property var modelData

                                Layout.fillWidth: true
                                text: "🖥  " + modelData.label
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                            }
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            type: TextButton.Tonal
                            onClicked: root.refresh()
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: arrCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: arrCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Arrangement")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Applied through horneroctl (Hyprland). With a single display most modes change nothing. Per-output resolution and scale editing is coming in a later slice.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: [
                                    { "mode": "extend-right", "label": qsTr("Extend right") },
                                    { "mode": "extend-left", "label": qsTr("Extend left") },
                                    { "mode": "extend-above", "label": qsTr("Extend above") },
                                    { "mode": "extend-below", "label": qsTr("Extend below") },
                                    { "mode": "mirror", "label": qsTr("Mirror") },
                                    { "mode": "internal-only", "label": qsTr("Internal only") },
                                    { "mode": "external-only", "label": qsTr("External only") }
                                ]

                                delegate: TextButton {
                                    required property var modelData

                                    text: modelData.label
                                    type: TextButton.Tonal
                                    onClicked: root.applyMode(modelData.mode)
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionText !== ""
                            text: root.actionText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: brightCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: brightCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Brightness")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Brightness")
                            value: root.brightness
                            from: 0
                            to: 100
                            stepSize: 1
                            decimals: 0
                            suffix: "%"
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }
                            onValueModified: newValue => {
                                root.brightness = newValue;
                                brightnessTimer.restart();
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.brightnessText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: compCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: compCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Compositor (Hyprland)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.layoutCurrent === ""
                            text: qsTr("Compositor controls are unavailable on this session; nothing is faked.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.layoutCurrent !== ""
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: qsTr("Layout")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Repeater {
                                    model: ["scrolling", "dwindle", "master"]

                                    delegate: TextButton {
                                        required property string modelData

                                        text: modelData
                                        type: root.layoutCurrent === modelData ? TextButton.Filled : TextButton.Tonal
                                        onClicked: root.applyLayout(modelData)
                                    }
                                }

                                TextButton {
                                    text: qsTr("Restore layout")
                                    type: TextButton.Tonal
                                    onClicked: root.restoreCompositor("layout")
                                }
                            }

                            StyledText {
                                text: qsTr("Animation profile")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Repeater {
                                    model: root.animProfiles

                                    delegate: TextButton {
                                        required property string modelData

                                        text: modelData
                                        type: root.animCurrent === modelData ? TextButton.Filled : TextButton.Tonal
                                        onClicked: root.applyAnimProfile(modelData)
                                    }
                                }

                                TextButton {
                                    text: qsTr("Restore animations")
                                    type: TextButton.Tonal
                                    onClicked: root.restoreCompositor("animations")
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.compositorText !== ""
                            text: root.compositorText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}
