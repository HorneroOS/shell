pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import Quickshell
import qs.modules.instruments as Instruments
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
    property bool brightnessAvailable: false
    property string layoutCurrent: ""
    property string compositorText: ""
    property var animProfiles: []
    property string animCurrent: ""

    // Real output inventory: Quickshell's screens (compositor-agnostic geometry)
    // joined with the active compositor backend's metadata for refresh rate
    // and scale (Hyprland or Niri). A field the session does not report stays
    // empty and renders as an em dash, never as a guess.
    readonly property var outputs: Quickshell.screens.map(s => {
        const meta = Compositor.outputMetadataFor(s);
        return {
            "name": s.name,
            "model": s.model || "",
            "width": s.width,
            "height": s.height,
            "x": s.x,
            "y": s.y,
            "hz": meta.hz,
            "scale": meta.scale
        };
    })

    function refreshExtra(): void {
        if (!brightProc.running) {
            brightProc.out = "";
            brightProc.command = ["horneroctl", "--json", "hardware", "brightness", "status"];
            brightProc.running = true;
        }
        if (!Compositor.isHyprland) {
            root.layoutCurrent = "";
            root.animProfiles = [];
            root.animCurrent = "";
            return;
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
        if (!Compositor.isHyprland) {
            root.monitors = Quickshell.screens.map(s => ({ "label": s.name }));
            root.statusText = qsTr("%1 display(s) connected").arg(root.monitors.length);
            return;
        }
        listProc.out = "";
        listProc.command = ["horneroctl", "hypr", "monitors", "list", "--json"];
        listProc.running = true;
    }

    // An arrangement can blank a screen, so it offers Undo. The geometry of
    // every output (including disabled ones) is read first with
    // `hyprctl monitors all -j`; Undo writes exactly that back, live.
    property string arrangeMode: ""
    property string arrangeQueued: ""
    property var arrangeSnap: []
    // One `monitors set` per choice, whichever of the snapshot and the guard
    // timer comes first.
    property bool arrangeStarted: false

    function applyMode(mode: string): void {
        if (!Compositor.isHyprland) {
            root.actionText = qsTr("Display arrangement requires Hyprland.");
            return;
        }
        if (snapProc.running || setProc.running) {
            root.arrangeQueued = mode;
            return;
        }
        root.arrangeMode = mode;
        root.arrangeStarted = false;
        root.arrangeSnap = [];
        root.actionText = qsTr("Applying %1…").arg(mode);
        snapProc.out = "";
        snapProc.running = true;
        snapGuard.restart();
    }

    // The arrangement itself never waits on the safety copy: when hyprctl
    // cannot start (another compositor), apply without Undo after a moment.
    function proceedArrange(): void {
        snapGuard.stop();
        if (root.arrangeStarted || setProc.running)
            return;
        root.arrangeStarted = true;
        setProc.out = "";
        setProc.command = ["horneroctl", "hypr", "monitors", "set", root.arrangeMode, "--yes", "--json"];
        setProc.running = true;
    }

    Timer {
        id: snapGuard

        interval: 1500
        onTriggered: root.proceedArrange()
    }

    // One `keyword monitor` rule per output, from `hyprctl monitors all -j`.
    // `mirrorOf` there is an output id; the rule wants the output name.
    function monitorKeyword(m: var, all: var): string {
        if (m.disabled)
            return `keyword monitor ${m.name},disable`;
        const refresh = Number(m.refreshRate ?? 60).toFixed(2);
        let mirror = "";
        if (m.mirrorOf !== undefined && m.mirrorOf !== null && String(m.mirrorOf) !== "none" && String(m.mirrorOf) !== "") {
            const src = all.find(o => String(o.id) === String(m.mirrorOf) || o.name === String(m.mirrorOf));
            if (src)
                mirror = `,mirror,${src.name}`;
        }
        const transform = Number(m.transform ?? 0) !== 0 ? `,transform,${Number(m.transform)}` : "";
        return `keyword monitor ${m.name},${m.width}x${m.height}@${refresh},${m.x}x${m.y},${m.scale}${transform}${mirror}`;
    }

    function restoreArgs(snap: var): var {
        return ["hyprctl", "--batch", snap.map(m => root.monitorKeyword(m, snap)).join(" ; ")];
    }

    Connections {
        target: Undo

        function onCommandFinished(key: string, ok: bool): void {
            if (key === "displays")
                root.refresh();
        }
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
                root.brightnessAvailable = payload.ok === true && !isNaN(parsed);
                if (!isNaN(parsed))
                    root.brightness = parsed <= 1 ? parsed * 100 : parsed;
            } catch (e) {
                root.brightnessAvailable = false;
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
        id: snapProc

        property string out: ""

        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: SplitParser {
            onRead: data => {
                snapProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            let snap = [];
            try {
                snap = JSON.parse(snapProc.out.trim());
            } catch (e) {
                snap = [];
            }
            // Too late for this choice: it already applied without Undo.
            if (root.arrangeStarted)
                return;
            root.arrangeSnap = Array.isArray(snap) ? snap : [];
            root.proceedArrange();
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
            let ok = exitCode === 0;
            try {
                const payload = JSON.parse(setProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
                if (payload.ok === false)
                    ok = false;
            } catch (e) {
                ok = false;
                root.actionText = qsTr("The arrangement command did not answer. Check: horneroctl hypr monitors status");
            }
            const snap = root.arrangeSnap;
            if (!ok)
                Undo.report("displays", qsTr("Display arrangement was not changed"), root.actionText);
            else if (snap.length > 0)
                // Undo runs the inverse hyprctl batch itself (it outlives this pane).
                Undo.offerCommand("displays", qsTr("Displays: %1").arg(root.arrangeMode), root.restoreArgs(snap), qsTr("Undo puts every screen back where it was."));
            root.refresh();
            const next = root.arrangeQueued;
            root.arrangeQueued = "";
            if (next !== "")
                root.applyMode(next);
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
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "displays"
                }

                ChannelPanel {
                    title: qsTr("Outputs")
                    readoutAvailable: root.outputs.length > 0
                    readout: qsTr("%1 connected").arg(root.outputs.length)

                    Repeater {
                        model: root.outputs

                        delegate: SettingRow {
                            id: outputRow

                            required property var modelData

                            label: modelData.name.length > 0 ? modelData.name : qsTr("Unnamed output")
                            description: modelData.model.length > 0 ? modelData.model : qsTr("model unavailable")

                            below: [
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    columnSpacing: Appearance.spacing.normal
                                    rowSpacing: Appearance.spacing.small

                                    Instruments.Readout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        label: qsTr("Resolution")
                                        value: outputRow.modelData.width > 0 ? `${outputRow.modelData.width}×${outputRow.modelData.height}` : ""
                                        unit: "px"
                                        valueSize: Appearance.font.size.large
                                    }

                                    Instruments.Readout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        label: qsTr("Refresh")
                                        value: isNaN(outputRow.modelData.hz) ? "" : outputRow.modelData.hz.toFixed(2)
                                        unit: "Hz"
                                        valueSize: Appearance.font.size.large
                                    }

                                    Instruments.Readout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        label: qsTr("Scale")
                                        value: isNaN(outputRow.modelData.scale) ? "" : outputRow.modelData.scale.toFixed(2)
                                        unit: "×"
                                        valueSize: Appearance.font.size.large
                                    }

                                    Instruments.Readout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        label: qsTr("Position")
                                        value: `${outputRow.modelData.x},${outputRow.modelData.y}`
                                        unit: ""
                                        valueSize: Appearance.font.size.large
                                    }
                                }
                            ]
                        }
                    }

                    SettingRow {
                        visible: root.outputs.length === 0
                        label: qsTr("No displays reported")
                        description: root.statusText
                    }

                    SettingRow {
                        label: qsTr("Resolution, refresh and scale")
                        description: qsTr("Read-only for now: horneroctl does not yet expose per-output mode editing, and this pane never hand-edits compositor config.")
                    }
                }

                ChannelPanel {
                    title: qsTr("Arrangement")
                    readoutAvailable: root.outputs.length > 0
                    readout: root.outputs.length > 1 ? qsTr("%1 outputs").arg(root.outputs.length) : qsTr("single output")

                    Item {
                        id: map

                        readonly property real pad: Appearance.padding.large
                        readonly property real minX: Math.min(...root.outputs.map(o => o.x))
                        readonly property real minY: Math.min(...root.outputs.map(o => o.y))
                        readonly property real spanX: Math.max(1, Math.max(...root.outputs.map(o => o.x + o.width)) - minX)
                        readonly property real spanY: Math.max(1, Math.max(...root.outputs.map(o => o.y + o.height)) - minY)
                        readonly property real k: Math.min((width - pad * 2) / spanX, (height - pad * 2) / spanY)

                        Layout.fillWidth: true
                        implicitHeight: 160
                        visible: root.outputs.length > 0

                        Accessible.role: Accessible.Graphic
                        Accessible.name: qsTr("Display arrangement: %1").arg(root.outputs.map(o => `${o.name} ${o.width}×${o.height} at ${o.x},${o.y}`).join("; "))

                        Repeater {
                            model: root.outputs

                            delegate: Well {
                                id: tile

                                required property var modelData

                                x: map.pad + (modelData.x - map.minX) * map.k + (map.width - map.pad * 2 - map.spanX * map.k) / 2
                                y: map.pad + (modelData.y - map.minY) * map.k + (map.height - map.pad * 2 - map.spanY * map.k) / 2
                                width: modelData.width * map.k - 2
                                height: modelData.height * map.k - 2
                                color: Signal.palette.signalWell
                                outline: Signal.palette.signal

                                StyledText {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    mono: true
                                    text: tile.modelData.name.length > 0 ? tile.modelData.name : qsTr("Output")
                                    color: Signal.palette.onSignalWell
                                    font.pointSize: Appearance.font.size.small
                                    Accessible.ignored: true
                                }
                            }
                        }
                    }

                    SettingRow {
                        label: qsTr("Arrange displays")
                        description: qsTr("Applied through horneroctl (Hyprland). With a single display most modes change nothing.")

                        below: [
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
                            },
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.actionText !== ""
                                text: root.actionText
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }
                        ]
                    }
                }

                ChannelPanel {
                    title: qsTr("Brightness")
                    readoutAvailable: root.brightnessAvailable
                    readout: root.brightnessAvailable ? qsTr("%1 %").arg(Math.round(root.brightness)) : ""

                    SettingRow {
                        label: qsTr("Backlight")
                        description: root.brightnessText

                        below: [
                            SliderInput {
                                Layout.fillWidth: true
                                visible: root.brightnessAvailable
                                label: qsTr("Brightness")
                                value: root.brightness
                                from: 0
                                to: 100
                                stepSize: 1
                                decimals: 0
                                suffix: "%"
                                enabled: root.brightnessAvailable
                                validator: IntValidator {
                                    bottom: 0
                                    top: 100
                                }
                                onValueModified: newValue => {
                                    root.brightness = newValue;
                                    brightnessTimer.restart();
                                }
                            }
                        ]
                    }
                }

                ChannelPanel {
                    title: qsTr("Compositor")
                    readoutAvailable: root.layoutCurrent !== ""
                    readout: root.layoutCurrent

                    SettingRow {
                        visible: root.layoutCurrent === ""
                        label: qsTr("Unavailable on this session")
                        description: qsTr("Layout and animation controls need the Hyprland backend; nothing is faked.")
                    }

                    SettingRow {
                        visible: root.layoutCurrent !== ""
                        label: qsTr("Layout")

                        SegmentedControl {
                            accessibleName: qsTr("Compositor layout")
                            model: ["scrolling", "dwindle", "master"]
                            currentIndex: Math.max(0, model.indexOf(root.layoutCurrent))
                            onActivated: index => root.applyLayout(model[index])
                        }

                        TextButton {
                            text: qsTr("Restore")
                            type: TextButton.Text
                            onClicked: root.restoreCompositor("layout")
                        }
                    }

                    SettingRow {
                        visible: root.layoutCurrent !== "" && root.animProfiles.length > 0
                        label: qsTr("Animation profile")

                        SegmentedControl {
                            accessibleName: qsTr("Animation profile")
                            model: root.animProfiles
                            currentIndex: Math.max(0, root.animProfiles.indexOf(root.animCurrent))
                            onActivated: index => root.applyAnimProfile(root.animProfiles[index])
                        }

                        TextButton {
                            text: qsTr("Restore")
                            type: TextButton.Text
                            onClicked: root.restoreCompositor("animations")
                        }
                    }

                    SettingRow {
                        visible: root.layoutCurrent !== "" && root.compositorText !== ""
                        label: root.compositorText
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
