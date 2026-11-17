pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Generated per-plugin settings UI (shell#374; schema v2, RFC 0003).
// Fields are derived from the manifest's typed capabilities.settings
// declarations — boolean, integer, number, string, enum, plus the
// PluginKit 4 colour, list, text and path types and the display-only
// title, group, unit, step and visibleWhen fields — and rendered with the
// shell's native controls (the design-system controls the PluginKit
// Ui* primitives mirror for plugin code; Control Center is shell
// code and does not import the plugin-facing module). Values read
// and write through the existing Shell-owned storage
// (Config.plugins.settings, the same keys the PluginKit Settings
// facade uses): a stored value that no longer satisfies its
// declaration reads as the default (Plugins.migratedSettingValue),
// writes are validated with Plugins.settingValueValid before they
// persist, and reset removes stored values so defaults apply again.
// A plugin that declares no (valid) settings shows no section at
// all — callers gate on settingKeys() the same way.
ColumnLayout {
    id: root

    required property string pluginId
    // Storage namespace: the plugin id for the primary instance, the
    // instance key (`<pluginId>#<instanceId>`) for an extra instance.
    property string storageKey: root.pluginId
    // Raw declarations (entry.settings or capabilities.settings);
    // normalized here so malformed declarations simply render no
    // field instead of breaking the pane.
    required property var settings

    readonly property var declarations: Plugins.normalizeSettings(root.settings)

    // Keys in display order: ungrouped first, then each group in the
    // order its first member was declared (alphabetical by key within a
    // group, like before).
    function settingKeys(): var {
        const keys = Object.keys(root.declarations).filter(key => root.declarations[key].hidden !== true).sort();
        const groups = [];
        for (const key of keys) {
            const group = root.groupOf(key);
            if (group !== "" && !groups.includes(group))
                groups.push(group);
        }
        const ordered = keys.filter(key => root.groupOf(key) === "");
        for (const group of groups)
            ordered.push(...keys.filter(key => root.groupOf(key) === group));
        return ordered;
    }

    function groupOf(key: string): string {
        const decl = root.declarations[key];
        return decl && typeof decl.group === "string" ? decl.group : "";
    }

    function titleOf(key: string): string {
        const decl = root.declarations[key];
        return decl && typeof decl.title === "string" ? decl.title : key;
    }

    // First key of its group in display order shows the group heading.
    function startsGroup(key: string): bool {
        const group = root.groupOf(key);
        if (group === "")
            return false;
        return root.settingKeys().find(k => root.groupOf(k) === group) === key;
    }

    // visibleWhen is display-only: a hidden setting keeps its value and
    // stays readable by the extension (RFC 0003 section 5).
    function conditionMet(key: string): bool {
        const decl = root.declarations[key];
        const condition = decl ? decl.visibleWhen : undefined;
        if (!condition || typeof condition !== "object")
            return true;
        const target = root.declaration(condition.key);
        if (!target)
            return true;
        const actual = root.effectiveValue(condition.key);
        return JSON.stringify(actual) === JSON.stringify(condition.equals);
    }

    function declaration(key: string): var {
        return root.declarations[key] || null;
    }

    function storedValues(): var {
        const storedSettings = Config.plugins.settings;
        const storedPlugins = storedSettings && typeof storedSettings === "object" && !Array.isArray(storedSettings) ? storedSettings : null;
        const candidateValues = storedPlugins ? storedPlugins[root.storageKey] : null;
        return candidateValues && typeof candidateValues === "object" && !Array.isArray(candidateValues) ? candidateValues : null;
    }

    function hasStored(key: string): bool {
        const values = root.storedValues();
        return !!values && Object.prototype.hasOwnProperty.call(values, key);
    }

    function effectiveValue(key: string): var {
        const decl = root.declaration(key);
        if (!decl)
            return undefined;
        const values = root.storedValues();
        const stored = values && Object.prototype.hasOwnProperty.call(values, key) ? values[key] : undefined;
        return Plugins.migratedSettingValue(decl, stored);
    }

    function setValue(key: string, value: var): bool {
        const decl = root.declaration(key);
        if (!decl || !Plugins.settingValueValid(decl, value))
            return false;
        return Config.plugins.setSetting(root.storageKey, key, value);
    }

    // Applies at once; Undo writes the earlier values back (no confirm step).
    function resetAllSettings(): void {
        const before = [];
        for (const key of root.settingKeys()) {
            if (root.hasStored(key))
                before.push([key, root.storedValues()[key]]);
        }
        // Hidden state (timers, markers) is not the person's setting:
        // Reset all clears only the visible controls.
        for (const key of root.settingKeys())
            Config.plugins.resetSetting(root.storageKey, key);
        Undo.offer("plugin-settings-" + root.storageKey, qsTr("Plugin settings reset"), () => {
            for (const kv of before)
                Config.plugins.setSetting(root.storageKey, kv[0], kv[1]);
            return true;
        }, qsTr("Undo brings back %n setting(s).", "", before.length));
    }

    function anyStored(): bool {
        return root.settingKeys().some(key => root.hasStored(key));
    }

    visible: root.settingKeys().length > 0
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Settings")
            font.weight: Appearance.font.weight.medium
        }

        TextButton {
            visible: root.anyStored()
            text: qsTr("Reset all to defaults")
            type: TextButton.Text
            onClicked: root.resetAllSettings()
        }
    }

    Repeater {
        model: root.settingKeys()

        delegate: ColumnLayout {
            id: field

            required property var modelData

            readonly property string key: modelData
            readonly property var decl: root.declaration(key)
            readonly property string description: decl && typeof decl.description === "string" ? decl.description : ""
            readonly property string title: root.titleOf(key)
            readonly property string unit: decl && typeof decl.unit === "string" ? decl.unit : ""
            readonly property real stepSize: decl && typeof decl.step === "number" ? decl.step : (decl && decl.type === "integer" ? 1 : 0.1)
            property string fieldError: ""

            Layout.fillWidth: true
            visible: root.conditionMet(key)
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.normal
                visible: root.startsGroup(field.key)
                text: root.groupOf(field.key)
                font.family: Appearance.font.family.mono
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Appearance.font.size.small * 0.08
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.inkMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: field.title
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: field.description.length > 0
                        text: field.description
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.Wrap
                    }
                }

                StyledSwitch {
                    id: boolSwitch

                    visible: field.decl && field.decl.type === "boolean"
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: field.title
                    Accessible.description: field.description
                    Accessible.checked: checked

                    checked: visible ? root.effectiveValue(field.key) === true : false
                    onToggled: {
                        if (root.setValue(field.key, checked))
                            field.fieldError = "";
                    }

                    Loader {
                        width: 0
                        height: 0
                        active: field.description.length > 0
                        sourceComponent: Component {
                            Tooltip {
                                target: boolSwitch
                                text: field.description
                            }
                        }
                    }
                }

                CustomSpinBox {
                    id: numberSpin

                    visible: field.decl && (field.decl.type === "integer" || field.decl.type === "number")
                    min: visible && typeof field.decl.minimum === "number" ? field.decl.minimum : -1000000000
                    max: visible && typeof field.decl.maximum === "number" ? field.decl.maximum : 1000000000
                    step: visible ? field.stepSize : 1
                    // CustomSpinBox assigns value from JS on edit, which
                    // would destroy a plain binding and desync Reset and
                    // slider changes; Binding restores it after edits.
                    Binding {
                        target: numberSpin
                        property: "value"
                        value: Number(root.effectiveValue(field.key))
                        when: numberSpin.visible
                        restoreMode: Binding.RestoreBindingOrValue
                    }
                    onValueModified: value => {
                        const next = field.decl.type === "integer" ? Math.round(value) : value;
                        field.fieldError = root.setValue(field.key, next) ? "" : qsTr("Value is outside the allowed range.");
                    }
                }

                StyledText {
                    visible: numberSpin.visible && field.unit.length > 0
                    text: field.unit
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }

                StyledTextField {
                    id: stringField

                    visible: field.decl && (field.decl.type === "string" || field.decl.type === "path")
                    Layout.preferredWidth: 220
                    Accessible.name: field.title
                    Accessible.description: field.description
                    placeholderText: visible ? String(field.decl.default) : ""
                    text: visible ? String(root.effectiveValue(field.key)) : ""

                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal

                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Signal.tPalette.raised
                    }

                    onEditingFinished: {
                        if (root.setValue(field.key, text)) {
                            field.fieldError = "";
                        } else {
                            field.fieldError = qsTr("Value does not satisfy the declared length limits.");
                            text = String(root.effectiveValue(field.key));
                        }
                    }

                    Loader {
                        width: 0
                        height: 0
                        active: field.description.length > 0
                        sourceComponent: Component {
                            Tooltip {
                                target: stringField
                                text: field.description
                            }
                        }
                    }
                }

                TextButton {
                    visible: field.decl && field.decl.type === "path" && field.decl.kind !== "directory"
                    text: qsTr("Browse…")
                    type: TextButton.Text
                    onClicked: pathDialog.open()
                }

                FileDialog {
                    id: pathDialog

                    title: qsTr("Choose a file for %1").arg(field.title)
                    onAccepted: path => {
                        if (root.setValue(field.key, path))
                            field.fieldError = "";
                        else
                            field.fieldError = qsTr("That path is not allowed for this setting.");
                    }
                }

                TextButton {
                    visible: root.hasStored(field.key)
                    text: qsTr("Reset")
                    type: TextButton.Text
                    onClicked: {
                        Config.plugins.resetSetting(root.storageKey, field.key);
                        field.fieldError = "";
                    }
                }
            }

            StyledSlider {
                id: numberSlider

                visible: field.decl && (field.decl.type === "integer" || field.decl.type === "number")
                    && typeof field.decl.minimum === "number" && typeof field.decl.maximum === "number"
                Layout.fillWidth: true
                implicitHeight: Appearance.padding.normal * 3
                accessibleName: field.title
                Accessible.description: field.description

                from: visible ? field.decl.minimum : 0
                to: visible ? field.decl.maximum : 1
                stepSize: visible && field.decl.type === "integer" ? field.stepSize : (visible && typeof field.decl.step === "number" ? field.stepSize : 0)
                value: visible ? Number(root.effectiveValue(field.key)) : 0
                onMoved: {
                    const next = field.decl.type === "integer" ? Math.round(value) : value;
                    if (root.setValue(field.key, next))
                        field.fieldError = "";
                }

                Loader {
                    width: 0
                    height: 0
                    active: field.description.length > 0
                    sourceComponent: Component {
                        Tooltip {
                            target: numberSlider
                            text: field.description
                        }
                    }
                }
            }

            Flow {
                visible: field.decl && field.decl.type === "enum"
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: field.decl && Array.isArray(field.decl.options) ? field.decl.options : []

                    delegate: ToggleButton {
                        required property var modelData

                        toggled: root.effectiveValue(field.key) === modelData
                        label: String(modelData)
                        tooltip: field.description
                        Accessible.name: qsTr("%1: %2").arg(field.title).arg(modelData)
                        onClicked: {
                            if (root.setValue(field.key, modelData))
                                field.fieldError = "";
                        }
                    }
                }
            }

            // list: multi-select toggle group over the declared options.
            Flow {
                visible: field.decl && field.decl.type === "list"
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: field.decl && field.decl.type === "list" && Array.isArray(field.decl.options) ? field.decl.options : []

                    delegate: ToggleButton {
                        required property var modelData

                        readonly property var current: root.effectiveValue(field.key) ?? []

                        toggled: current.includes(modelData)
                        label: String(modelData)
                        tooltip: field.description
                        Accessible.name: qsTr("%1: %2").arg(field.title).arg(modelData)
                        Accessible.checked: toggled
                        onClicked: {
                            // Keep the declared option order, not click order.
                            const next = field.decl.options.filter(option => option === modelData ? !current.includes(modelData) : current.includes(option));
                            field.fieldError = root.setValue(field.key, next) ? "" : qsTr("Choose between %1 and %2 options.").arg(typeof field.decl.minItems === "number" ? field.decl.minItems : 0).arg(typeof field.decl.maxItems === "number" ? field.decl.maxItems : field.decl.options.length);
                        }
                    }
                }
            }

            // colour: swatch, hex field and the Signal palette as presets.
            RowLayout {
                visible: field.decl && field.decl.type === "colour"
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: Signal.palette.ruleStrong
                    color: field.decl && field.decl.type === "colour" ? String(root.effectiveValue(field.key)) : "transparent"
                }

                StyledTextField {
                    id: colourField

                    Layout.preferredWidth: 120
                    Accessible.name: field.title
                    Accessible.description: field.description
                    maximumLength: 9
                    text: field.decl && field.decl.type === "colour" ? String(root.effectiveValue(field.key)) : ""
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Signal.tPalette.raised
                    }
                    onEditingFinished: {
                        if (root.setValue(field.key, text.trim())) {
                            field.fieldError = "";
                        } else {
                            field.fieldError = field.decl.alpha === true ? qsTr("Use #RRGGBB or #RRGGBBAA.") : qsTr("Use #RRGGBB.");
                            text = String(root.effectiveValue(field.key));
                        }
                    }
                }

                Repeater {
                    model: ["signal", "cue", "phosphor", "alert", "ink"]

                    delegate: Rectangle {
                        required property string modelData

                        readonly property color preset: Signal.palette[modelData]

                        implicitWidth: 20
                        implicitHeight: 20
                        radius: Appearance.rounding.small
                        color: preset
                        border.width: 1
                        border.color: Signal.palette.ruleStrong
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Use the %1 colour").arg(modelData)
                        Accessible.onPressAction: presetArea.clicked(null)

                        MouseArea {
                            id: presetArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Signal palette presets are opaque #RRGGBB.
                                const hex = "#" + [parent.preset.r, parent.preset.g, parent.preset.b].map(c => Math.round(c * 255).toString(16).padStart(2, "0")).join("");
                                if (root.setValue(field.key, hex))
                                    field.fieldError = "";
                            }
                        }
                    }
                }
            }

            // text: multi-line string.
            StyledRect {
                visible: field.decl && field.decl.type === "text"
                Layout.fillWidth: true
                implicitHeight: field.decl && field.decl.type === "text" ? (typeof field.decl.rows === "number" ? field.decl.rows : 3) * Appearance.font.size.normal * 2 + Appearance.padding.normal * 2 : 0
                radius: Appearance.rounding.small
                color: Signal.tPalette.raised

                TextArea {
                    id: textArea

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.small
                    wrapMode: TextEdit.Wrap
                    color: Signal.palette.ink
                    font.family: Appearance.font.family.sans
                    font.pointSize: Appearance.font.size.normal
                    selectionColor: Signal.palette.signal
                    Accessible.name: field.title
                    Accessible.description: field.description
                    text: field.decl && field.decl.type === "text" ? String(root.effectiveValue(field.key)) : ""
                    onActiveFocusChanged: {
                        if (!activeFocus && text !== String(root.effectiveValue(field.key))) {
                            if (root.setValue(field.key, text)) {
                                field.fieldError = "";
                            } else {
                                field.fieldError = qsTr("Text does not satisfy the declared length limits.");
                                text = String(root.effectiveValue(field.key));
                            }
                        }
                    }
                }
            }

            // strings: one entry per line.
            StyledRect {
                visible: field.decl && field.decl.type === "strings"
                Layout.fillWidth: true
                implicitHeight: Appearance.font.size.normal * 2 * 4 + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Signal.tPalette.raised

                TextArea {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.small
                    wrapMode: TextEdit.NoWrap
                    color: Signal.palette.ink
                    font.family: Appearance.font.family.sans
                    font.pointSize: Appearance.font.size.normal
                    selectionColor: Signal.palette.signal
                    placeholderText: qsTr("One entry per line")
                    Accessible.name: field.title
                    Accessible.description: field.description
                    text: field.decl && field.decl.type === "strings" ? (root.effectiveValue(field.key) ?? []).join("\n") : ""
                    onActiveFocusChanged: {
                        if (activeFocus)
                            return;
                        const lines = text.split("\n").map(line => line.trim()).filter(line => line.length > 0);
                        if (JSON.stringify(lines) === JSON.stringify(root.effectiveValue(field.key)))
                            return;
                        if (root.setValue(field.key, lines)) {
                            field.fieldError = "";
                        } else {
                            field.fieldError = qsTr("Entries must be non-empty and within the declared count and length limits.");
                            text = (root.effectiveValue(field.key) ?? []).join("\n");
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: field.fieldError.length > 0
                text: field.fieldError
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.alert
                wrapMode: Text.Wrap
            }
        }
    }
}
