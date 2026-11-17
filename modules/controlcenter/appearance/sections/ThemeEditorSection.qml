pragma ComponentBehavior: Bound

import ".."
import "../../../launcher/services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromaticcli.js" as Cli

// Appearance > Edit palette. Start from any theme with a full palette,
// change individual roles (each with its hex, a swatch, a reset and
// contrast-aware text colours on accents), see the result live, then save a
// copy or replace one of your own themes. Everything saved is an ordinary
// schema v2 user theme installed through `horneroctl appearance chromatic
// import`, so the CLI's structural and contrast gates apply and failures are
// shown here verbatim. Nothing is written until Save; Preview only shows the
// candidate in memory and cancels itself.
CollapsibleSection {
    id: root

    required property var previewController
    required property var session

    title: qsTr("Edit palette")
    description: qsTr("Start from a theme, change any colour, preview it, then save it as your own. Reset undoes any edit.")
    showBackground: true

    // Theme being edited and the user's per-role overrides.
    property string sourceId: ""
    property var overrides: ({})
    property bool previewing: false
    property string status: ""
    property bool statusIsError: false
    readonly property var source: sourceFor(sourceId)
    readonly property bool editable: source !== null
    readonly property var scheme: editable ? Cli.editedScheme(source, overrides) : null
    readonly property int editCount: Object.keys(overrides).length
    readonly property bool sourceIsUser: !!Themes.themeById(sourceId) && Themes.themeById(sourceId).collection === "user"
    property alias nameText: nameField.text
    readonly property bool busy: proc.running
    readonly property string newId: Cli.slug(nameField.text)

    function sourceFor(id: string): var {
        if (!id)
            return null;
        if (Signal.isBuiltInTheme(id)) {
            const b = Signal.builtInThemes[id];
            return {
                "palette": b.palette,
                "terminal": b.terminal,
                "mode": b.mode,
                "name": b.name ?? id,
                "gtkTheme": b.gtkTheme,
                "iconTheme": b.iconTheme
            };
        }
        const t = Themes.themeById(id);
        if (!t || !Signal.isCompletePalette(t.palette))
            return null;
        return {
            "palette": t.palette,
            "terminal": Array.isArray(t.terminal) ? t.terminal : [],
            "mode": t.darkMode ? "dark" : "light",
            "name": t.name,
            "gtkTheme": t.gtkTheme,
            "iconTheme": t.iconTheme
        };
    }

    function chooseSource(id: string): void {
        sourceId = id;
        confirmingDelete = false;
        overrides = ({});
        nameField.text = sourceIsUser ? (Themes.themeById(id)?.name ?? id) : qsTr("%1 copy").arg(sourceFor(id)?.name ?? id);
        status = "";
        refreshPreview();
    }

    function setRole(key: string, value: string): void {
        if (!/^#[0-9A-Fa-f]{6}$/.test(String(value)))
            return;
        const o = Object.assign({}, overrides);
        o[key] = String(value).toUpperCase();
        overrides = o;
        refreshPreview();
    }

    function resetRole(key: string): void {
        const o = Object.assign({}, overrides);
        delete o[key];
        overrides = o;
        refreshPreview();
    }

    function resetAll(): void {
        overrides = ({});
        status = "";
        refreshPreview();
    }

    function roleValue(key: string): string {
        if (!scheme)
            return "";
        return /^term\d+$/.test(key) ? (scheme.terminal[parseInt(key.substr(4), 10)] ?? "") : (scheme.palette[key] ?? "");
    }

    function refreshPreview(): void {
        if (!previewing)
            return;
        if (scheme)
            Signal.beginPreview(scheme);
        else
            Signal.cancelPreview();
        idle.restart();
    }

    function setPreviewing(on: bool): void {
        previewing = on;
        if (on) {
            refreshPreview();
        } else {
            idle.stop();
            Signal.cancelPreview();
        }
    }

    // A deleted theme, kept in memory so Undo can put it back for 30 s.
    property var trash: null
    property bool confirmingDelete: false

    function renameSaved(): void {
        if (!sourceIsUser || proc.running)
            return;
        if (nameField.text.trim() === "") {
            status = qsTr("Give the palette a name first.");
            statusIsError = true;
            return;
        }
        proc.mode = "rename";
        proc.command = Cli.renameArgs(sourceId, nameField.text.trim());
        status = "";
        proc.running = true;
    }

    function deleteSaved(): void {
        if (!sourceIsUser || proc.running)
            return;
        confirmingDelete = false;
        // The whole theme, as it is saved now (not the unsaved edits), so
        // Undo restores exactly what was deleted.
        trash = {
            "id": sourceId,
            "doc": Cli.themeDocument(source, ({}), sourceId, Themes.themeById(sourceId)?.name ?? sourceId)
        };
        proc.mode = "delete";
        proc.command = Cli.deleteArgs(sourceId);
        status = "";
        proc.running = true;
    }

    function undoDelete(): void {
        if (!trash || proc.running)
            return;
        proc.mode = "restore";
        proc.draftDir = `${Paths.state}/shell/theme-draft`;
        proc.command = ["sh", "-c", 'd=$1; j=$2; shift 2; mkdir -p "$d" && printf "%s\\n" "$j" > "$d/theme-draft.json" && exec horneroctl appearance chromatic import "$d/theme-draft.json" "$@"', "sh", proc.draftDir, JSON.stringify(trash.doc)].concat(Cli.themeImportTail(trash.id, false, false));
        status = "";
        proc.running = true;
    }

    // mode: "check" (dry run), "new" (save as a new theme) or "replace".
    function run(mode: string): void {
        if (!editable || proc.running)
            return;
        const id = mode === "replace" ? sourceId : newId;
        if (!id || nameField.text.trim() === "") {
            status = qsTr("Give the palette a name first.");
            statusIsError = true;
            return;
        }
        proc.mode = mode;
        proc.draftDir = `${Paths.state}/shell/theme-draft`;
        proc.command = ["sh", "-c", 'd=$1; j=$2; shift 2; mkdir -p "$d" && printf "%s\\n" "$j" > "$d/theme-draft.json" && exec horneroctl appearance chromatic import "$d/theme-draft.json" "$@"', "sh", proc.draftDir, JSON.stringify(Cli.themeDocument(source, overrides, id, nameField.text.trim()))].concat(Cli.themeImportTail(id, mode === "replace", mode === "check"));
        status = "";
        proc.running = true;
    }

    Component.onDestruction: if (previewing)
        Signal.cancelPreview()

    // A forgotten preview never outlives 30 s of inactivity.
    Timer {
        id: idle

        interval: 30000
        onTriggered: root.setPreviewing(false)
    }

    // Undo is offered for 30 s after a delete, then the copy is dropped.
    Timer {
        id: undoTimer

        interval: 30000
        onTriggered: root.trash = null
    }

    Process {
        id: proc

        property string mode: ""
        property string draftDir: ""

        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.statusIsError = false;
                if (proc.mode === "delete") {
                    root.status = qsTr("Deleted. You can undo this for a short while.");
                    root.sourceId = "";
                    root.overrides = ({});
                    undoTimer.restart();
                } else if (proc.mode === "restore") {
                    root.status = qsTr("Restored.");
                    root.trash = null;
                    undoTimer.stop();
                } else if (proc.mode === "rename") {
                    root.status = qsTr("Renamed.");
                } else {
                    root.status = proc.mode === "check" ? qsTr("Contrast checks pass.") : qsTr("Saved. It is now listed under Themes.");
                }
                if (proc.mode !== "check")
                    Themes.reload();
                return;
            }
            if (proc.mode === "delete")
                root.trash = null;
            let msg = err.text.trim();
            try {
                msg = JSON.parse(out.text)?.error?.message ?? msg;
            } catch (e) {
                // keep stderr
            }
            root.statusIsError = true;
            root.status = msg || qsTr("Could not save the palette.");
        }
    }

    component RoleRow: RowLayout {
        id: row

        required property string roleKey
        required property string label

        readonly property string value: root.roleValue(roleKey)
        readonly property bool changed: root.overrides[roleKey] !== undefined
        readonly property bool valid: /^#[0-9A-Fa-f]{6}$/.test(field.text)

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Well {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 22
            color: row.value || "transparent"
            outline: row.changed ? Signal.palette.signal : Signal.palette.ruleStrong
            Accessible.ignored: true
        }

        StyledText {
            Layout.preferredWidth: 96
            text: row.label
            elide: Text.ElideRight
        }

        Well {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 28
            outline: field.activeFocus ? Signal.palette.focus : Signal.palette.ruleStrong

        StyledTextField {
            id: field

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            verticalAlignment: TextInput.AlignVCenter
            text: row.value
            maximumLength: 7
            inputMethodHints: Qt.ImhNoPredictiveText
            color: row.valid ? Signal.palette.ink : Signal.palette.alert
            Accessible.name: qsTr("%1 colour, hex").arg(row.label)
            onTextEdited: if (row.valid)
                root.setRole(row.roleKey, text)
            // Show the effective value again after a reset or source change.
            Connections {
                target: row

                function onValueChanged(): void {
                    if (!field.activeFocus)
                        field.text = row.value;
                }
            }
        }
        }

        TextButton {
            visible: row.changed
            text: qsTr("Reset")
            type: TextButton.Text
            Accessible.name: qsTr("Reset %1").arg(row.label)
            onClicked: {
                root.resetRole(row.roleKey);
                field.text = row.value;
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Start from")
            font.weight: Appearance.font.weight.strong
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(3, Math.floor(width / 220)))
            columnSpacing: Appearance.spacing.small
            rowSpacing: Appearance.spacing.small

            Repeater {
                model: Themes.list.filter(t => Signal.isBuiltInTheme(t.id) || Signal.isCompletePalette(t.palette))

                PaletteOption {
                    id: pick

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    kind: "radio"
                    title: modelData.name ?? modelData.id
                    note: modelData.collection === "user" ? qsTr("Your theme") : ""
                    selected: root.sourceId === modelData.id
                    tabStop: false
                    activeFocusOnTab: true
                    palette: root.previewController.paletteForTheme(modelData)
                    terminal: root.previewController.terminalForTheme(modelData)
                    paletteLabel: qsTr("Palette preview")
                    onActivated: root.chooseSource(modelData.id)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.trash !== null
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Deleted “%1”.").arg(root.trash?.doc.name ?? "")
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
            }

            TextButton {
                text: qsTr("Undo")
                type: TextButton.Filled
                onClicked: root.undoDelete()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.sourceId === ""
            text: qsTr("Pick a theme above to start editing its colours.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.editable
            spacing: Appearance.spacing.small

            StyledText {
                text: qsTr("Colours")
                font.weight: Appearance.font.weight.strong
            }

            Repeater {
                model: [
                    {
                        "key": "ground",
                        "label": qsTr("Ground")
                    },
                    {
                        "key": "panel",
                        "label": qsTr("Panel")
                    },
                    {
                        "key": "ink",
                        "label": qsTr("Ink")
                    },
                    {
                        "key": "inkMuted",
                        "label": qsTr("Muted ink")
                    },
                    {
                        "key": "signal",
                        "label": qsTr("Accent")
                    },
                    {
                        "key": "cue",
                        "label": qsTr("Cue")
                    },
                    {
                        "key": "phosphor",
                        "label": qsTr("Phosphor")
                    },
                    {
                        "key": "alert",
                        "label": qsTr("Alert")
                    },
                    {
                        "key": "focus",
                        "label": qsTr("Focus ring")
                    }
                ]

                RoleRow {
                    required property var modelData

                    roleKey: modelData.key
                    label: modelData.label
                }
            }

            StyledText {
                text: qsTr("Terminal colours")
                font.weight: Appearance.font.weight.strong
            }

            Repeater {
                model: Cli.EDIT_TERMINAL

                RoleRow {
                    required property int modelData

                    roleKey: "term" + modelData
                    label: [qsTr("Red"), qsTr("Green"), qsTr("Yellow"), qsTr("Blue"), qsTr("Magenta"), qsTr("Cyan")][modelData - 1]
                }
            }

            StyledText {
                text: qsTr("Accent from this palette")
                font.weight: Appearance.font.weight.strong
            }

            Row {
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.scheme ? Cli.EDIT_TERMINAL : []

                    Rectangle {
                        id: chip

                        required property int modelData

                        width: 32
                        height: 24
                        radius: Appearance.rounding.small
                        color: root.roleValue("term" + modelData)
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus ? Signal.palette.focus : Signal.palette.ruleStrong
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Use terminal colour %1 as the accent").arg(modelData)
                        Accessible.onPressAction: root.setRole("signal", color)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.setRole("signal", chip.color);
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                chip.forceActiveFocus();
                                root.setRole("signal", chip.color);
                            }
                        }
                    }
                }
            }

            SwitchRow {
                label: qsTr("Preview on the desktop")
                checked: root.previewing
                onToggled: checked => root.setPreviewing(checked)
            }

            Well {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                outline: nameField.activeFocus ? Signal.palette.focus : Signal.palette.ruleStrong

                StyledTextField {
                    id: nameField

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: qsTr("Name this palette")
                    Accessible.name: qsTr("Palette name")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                TextButton {
                    text: qsTr("Save as new")
                    type: TextButton.Filled
                    disabled: root.newId === ""
                    onClicked: root.run("new")
                }

                TextButton {
                    visible: root.sourceIsUser
                    text: qsTr("Save changes")
                    type: TextButton.Tonal
                    onClicked: root.run("replace")
                }

                TextButton {
                    text: qsTr("Check contrast")
                    type: TextButton.Tonal
                    onClicked: root.run("check")
                }

                TextButton {
                    visible: root.sourceIsUser
                    text: qsTr("Rename")
                    type: TextButton.Tonal
                    onClicked: root.renameSaved()
                }

                TextButton {
                    visible: root.sourceIsUser && !root.confirmingDelete
                    text: qsTr("Delete")
                    type: TextButton.Text
                    onClicked: root.confirmingDelete = true
                }

                TextButton {
                    visible: root.sourceIsUser && root.confirmingDelete
                    text: qsTr("Really delete?")
                    type: TextButton.Filled
                    onClicked: root.deleteSaved()
                }

                TextButton {
                    visible: root.sourceIsUser && root.confirmingDelete
                    text: qsTr("Keep")
                    type: TextButton.Text
                    onClicked: root.confirmingDelete = false
                }

                TextButton {
                    text: qsTr("Reset all")
                    type: TextButton.Text
                    disabled: root.editCount === 0
                    onClicked: root.resetAll()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.status !== ""
                text: root.status
                wrapMode: Text.WordWrap
                color: root.statusIsError ? Signal.palette.alert : Signal.palette.phosphor
                font.pointSize: Appearance.font.size.small
                Accessible.role: Accessible.StaticText
                Accessible.name: root.status
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                text: qsTr("Saved palettes are ordinary themes and also appear under Themes. Hornero checks contrast before saving; a failing colour is reported here. Rename changes the name only; the id stays. Delete can be undone for 30 seconds, and the theme in use cannot be deleted.")
            }
        }
    }
}
