pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.controlcenter
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.modules.welcome.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Scene 05 — Practice ("A Different Way to Work"):
// Reads live effective user keybindings from ShortcutHints / Keybinds and
// connects to real Visibilities (launcher, dashboard), Compositor (workspace
// change), and WindowFactory (controlcenter) signals so missions mark complete
// ONLY on real user actions. Shows an honest notice when compositor events
// aren't available (e.g. headless / unknown backend).
Item {
    id: root

    property bool windowActive: true

    property var initialWorkspaceId: null
    readonly property var activeVis: Visibilities.getForActive()
    readonly property var currentWorkspaceId: Compositor.activeWorkspaceIdForScreen(null, true)
    readonly property bool compositorEventsAvailable: Compositor.connected && (Compositor.supports("workspaceEvents") || Compositor.isHyprland || Compositor.isNiri)

    function resolveCombo(curatedId: string, dispNeedle: string, argNeedle: string): string {
        const fromHint = ShortcutHints.badge(curatedId);
        if (fromHint !== "")
            return fromHint;
        const entries = Keybinds.entries || [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            const d = String(e.dispatcher || "").toLowerCase();
            const a = String(e.args || "").toLowerCase();
            if (d.indexOf(dispNeedle) !== -1 && (argNeedle === "" || a.indexOf(argNeedle) !== -1)) {
                const mods = Array.isArray(e.mods) ? e.mods : [];
                return mods.concat([e.key]).filter(x => x && x !== "").join(" + ");
            }
        }
        return "";
    }

    readonly property var missions: [
        {
            id: "launcher",
            title: qsTr("Summon Launcher"),
            desc: qsTr("Search installed apps, files, and Hornero Apps catalog entries."),
            combo: root.resolveCombo("exec-launcher", "exec", "launcher"),
            icon: "apps",
            tryLabel: qsTr("Try Launcher"),
            completed: WelcomeModule.State.isTutorialCompleted("launcher")
        },
        {
            id: "dashboard",
            title: qsTr("Peek Dashboard"),
            desc: qsTr("Check system telemetry, weather, and media playback."),
            combo: root.resolveCombo("ipc-dashboard-toggle", "ipc", "dashboard"),
            icon: "dashboard",
            tryLabel: qsTr("Try Dashboard"),
            completed: WelcomeModule.State.isTutorialCompleted("dashboard")
        },
        {
            id: "workspace",
            title: qsTr("Switch Workspace"),
            desc: qsTr("Move cleanly between focused workspaces without overlapping clutter."),
            combo: root.resolveCombo("workspace:1", "workspace", ""),
            icon: "layout-grid",
            tryLabel: qsTr("Next Workspace"),
            completed: WelcomeModule.State.isTutorialCompleted("workspace")
        },
        {
            id: "settings",
            title: qsTr("Open Settings"),
            desc: qsTr("Launch Hornero Settings directly when you want fine-grained control."),
            combo: "",
            icon: "settings",
            tryLabel: qsTr("Try Settings"),
            completed: WelcomeModule.State.isTutorialCompleted("settings")
        }
    ]

    Component.onCompleted: {
        root.initialWorkspaceId = root.currentWorkspaceId;
    }

    onCurrentWorkspaceIdChanged: {
        if (!root.visible)
            return;
        if (root.initialWorkspaceId !== null && root.currentWorkspaceId !== null && root.currentWorkspaceId !== root.initialWorkspaceId)
            WelcomeModule.State.markTutorialCompleted("workspace");
    }

    Connections {
        target: root.activeVis
        ignoreUnknownSignals: true

        function onLauncherChanged(): void {
            if (root.visible && root.activeVis && root.activeVis.launcher === true)
                WelcomeModule.State.markTutorialCompleted("launcher");
        }

        function onDashboardChanged(): void {
            if (root.visible && root.activeVis && root.activeVis.dashboard === true)
                WelcomeModule.State.markTutorialCompleted("dashboard");
        }
    }

    Connections {
        target: WindowFactory

        function onWindowsChanged(): void {
            if (root.visible && WindowFactory.windows.length > 0)
                WelcomeModule.State.markTutorialCompleted("settings");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: qsTr("OPTIONAL INTERACTIVE PRACTICE")
                    mono: true
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                }

                StyledText {
                    text: qsTr("A different way to work")
                    font.pointSize: Appearance.font.size.extraLarge * 0.78
                    font.weight: Appearance.font.weight.strong
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Missions check off only when the real shell or compositor event fires. Skip anytime — nothing here traps you.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.WordWrap
                }
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("All Shortcuts")
                onClicked: Actions.openWelcome("shortcuts")
            }
        }

        // Honest headless / non-compositor disclosure
        StyledRect {
            visible: !root.compositorEventsAvailable
            Layout.fillWidth: true
            implicitHeight: warnRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Signal.palette.cueWell
            border.width: 1
            border.color: Signal.palette.cue

            RowLayout {
                id: warnRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                Glyph {
                    name: "info-circle"
                    color: Signal.palette.onCueWell
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Live compositor events are unavailable in this session; workspace switching cannot auto-verify here.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.onCueWell
                    wrapMode: Text.WordWrap
                }
            }
        }

        // 4 real-event mission rows
        Repeater {
            model: root.missions

            delegate: StyledRect {
                id: missionRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: rowLayout.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: modelData.completed ? Signal.palette.phosphorWell : Signal.palette.panel
                border.width: 1
                border.color: modelData.completed ? Signal.palette.phosphor : Signal.palette.rule

                RowLayout {
                    id: rowLayout

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    Glyph {
                        name: missionRow.modelData.completed ? "circle-check" : missionRow.modelData.icon
                        font.pointSize: Appearance.font.size.large
                        color: missionRow.modelData.completed ? Signal.palette.onPhosphorWell : Signal.palette.signal
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: missionRow.modelData.title
                            font.weight: Appearance.font.weight.strong
                            color: missionRow.modelData.completed ? Signal.palette.onPhosphorWell : Signal.palette.ink
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: missionRow.modelData.desc
                            font.pointSize: Appearance.font.size.smaller
                            color: missionRow.modelData.completed ? Signal.palette.onPhosphorWell : Signal.palette.inkMuted
                            wrapMode: Text.WordWrap
                        }
                    }

                    KeycapBadge {
                        visible: missionRow.modelData.combo !== ""
                        combo: missionRow.modelData.combo
                        highlighted: missionRow.modelData.completed
                    }

                    StyledText {
                        visible: missionRow.modelData.combo === "" && missionRow.modelData.id !== "settings"
                        text: qsTr("Unbound — use button")
                        mono: true
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    TextButton {
                        type: missionRow.modelData.completed ? TextButton.Tonal : TextButton.Filled
                        text: missionRow.modelData.completed ? qsTr("Verified") : missionRow.modelData.tryLabel
                        onClicked: {
                            if (missionRow.modelData.id === "launcher")
                                Actions.openLauncher();
                            else if (missionRow.modelData.id === "dashboard")
                                Actions.openDashboard();
                            else if (missionRow.modelData.id === "workspace")
                                Compositor.focusWorkspaceDirection(1);
                            else if (missionRow.modelData.id === "settings")
                                Actions.openControlCenter("appearance", true);
                        }
                    }
                }
            }
        }

        // Optional Hyprland-only scratchpad note
        StyledRect {
            visible: Compositor.supports("specialWorkspaces")
            Layout.fillWidth: true
            implicitHeight: scratchRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.small
            color: Signal.palette.sunken
            border.width: 1
            border.color: Signal.palette.rule

            RowLayout {
                id: scratchRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Bonus Hyprland scratchpad: keep a floating terminal or notes one key away.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }

                KeycapBadge {
                    combo: ShortcutHints.badge("togglespecialworkspace:magic")
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
