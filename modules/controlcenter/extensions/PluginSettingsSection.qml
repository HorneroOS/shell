pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Generated per-plugin settings UI (shell#374). Fields are derived
// from the manifest's typed capabilities.settings declarations —
// boolean, integer, number, string, enum — and rendered with the
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
    // Raw declarations (entry.settings or capabilities.settings);
    // normalized here so malformed declarations simply render no
    // field instead of breaking the pane.
    required property var settings

    property bool confirmResetAll: false

    readonly property var declarations: Plugins.normalizeSettings(root.settings)

    function settingKeys(): var {
        return Object.keys(root.declarations).sort();
    }

    function declaration(key: string): var {
        return root.declarations[key] || null;
    }

    function storedValues(): var {
        const storedSettings = Config.plugins.settings;
        const storedPlugins = storedSettings && typeof storedSettings === "object" && !Array.isArray(storedSettings) ? storedSettings : null;
        const candidateValues = storedPlugins ? storedPlugins[root.pluginId] : null;
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
        return Config.plugins.setSetting(root.pluginId, key, value);
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
            font.weight: 500
        }

        TextButton {
            visible: root.anyStored() && !root.confirmResetAll
            text: qsTr("Reset all to defaults…")
            type: TextButton.Text
            onClicked: root.confirmResetAll = true
        }

        TextButton {
            visible: root.confirmResetAll
            text: qsTr("Confirm reset all")
            type: TextButton.Filled
            onClicked: {
                Config.plugins.resetSettings(root.pluginId);
                root.confirmResetAll = false;
            }
        }

        TextButton {
            visible: root.confirmResetAll
            text: qsTr("Cancel")
            type: TextButton.Text
            onClicked: root.confirmResetAll = false
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
            property string fieldError: ""

            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: field.key
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: field.description.length > 0
                        text: field.description
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }
                }

                StyledSwitch {
                    id: boolSwitch

                    visible: field.decl && field.decl.type === "boolean"
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: field.key
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
                    step: visible && field.decl.type === "number" ? 0.1 : 1
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

                StyledTextField {
                    id: stringField

                    visible: field.decl && field.decl.type === "string"
                    Layout.preferredWidth: 220
                    Accessible.name: field.key
                    Accessible.description: field.description
                    placeholderText: visible ? String(field.decl.default) : ""
                    text: visible ? String(root.effectiveValue(field.key)) : ""

                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal

                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.tPalette.m3surfaceContainerHigh
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
                    visible: root.hasStored(field.key)
                    text: qsTr("Reset")
                    type: TextButton.Text
                    onClicked: {
                        Config.plugins.resetSetting(root.pluginId, field.key);
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
                accessibleName: field.key
                Accessible.description: field.description

                from: visible ? field.decl.minimum : 0
                to: visible ? field.decl.maximum : 1
                stepSize: visible && field.decl.type === "integer" ? 1 : 0
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
                        Accessible.name: qsTr("%1: %2").arg(field.key).arg(modelData)
                        onClicked: {
                            if (root.setValue(field.key, modelData))
                                field.fieldError = "";
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: field.fieldError.length > 0
                text: field.fieldError
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3error
                wrapMode: Text.Wrap
            }
        }
    }
}
