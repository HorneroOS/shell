pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Transparency")
    showBackground: true

    readonly property var surfaces: [
        {key: "bar", label: qsTr("Bar")},
        {key: "launcher", label: qsTr("Launcher")},
        {key: "dashboard", label: qsTr("Dashboard")},
        {key: "session", label: qsTr("Session")},
        {key: "sidebar", label: qsTr("Sidebar")},
        {key: "utilities", label: qsTr("Utilities")},
        {key: "notifications", label: qsTr("Notifications")},
        {key: "osd", label: qsTr("OSD")},
        {key: "lock", label: qsTr("Lock screen")},
        {key: "layoutpicker", label: qsTr("Layout picker")}
    ]

    function elementValue(key: string): real {
        const v = rootPane.transparencyElements[key];
        return typeof v === "number" ? v : rootPane.transparencyBase;
    }

    function isCustom(key: string): bool {
        return typeof rootPane.transparencyElements[key] === "number";
    }

    // Reassign (never mutate) so QML bindings re-evaluate.
    function setElement(key: string, value: var): void {
        const els = Object.assign({}, rootPane.transparencyElements);
        if (value === undefined)
            delete els[key];
        else
            els[key] = value;
        rootPane.transparencyElements = els;
        rootPane.saveConfig();
    }

    SwitchRow {
        label: qsTr("Transparency enabled")
        checked: rootPane.transparencyEnabled
        onToggled: checked => {
            rootPane.transparencyEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency base")
            value: rootPane.transparencyBase * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyBase = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Transparency layers")
            value: rootPane.transparencyLayers * 100
            from: 0
            to: 100
            suffix: "%"
            validator: IntValidator {
                bottom: 0
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.transparencyLayers = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    CollapsibleSection {
        title: qsTr("Per-surface alpha")
        description: qsTr("Override the base alpha per shell surface. Surfaces without an override follow the base slider above.")
        nested: true

        Repeater {
            model: root.surfaces

            delegate: ColumnLayout {
                id: row

                required property var modelData

                readonly property string elKey: modelData.key
                readonly property bool custom: root.isCustom(elKey)

                Layout.fillWidth: true
                spacing: 0

                SwitchRow {
                    label: qsTr("Custom %1 alpha").arg(row.modelData.label)
                    checked: row.custom
                    onToggled: checked => {
                        // Seed from the base so enabling never jumps visually.
                        root.setElement(row.elKey, checked ? rootPane.transparencyBase : undefined);
                    }
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.normal

                    SliderInput {
                        Layout.fillWidth: true
                        enabled: row.custom

                        label: row.modelData.label
                        value: root.elementValue(row.elKey) * 100
                        from: 0
                        to: 100
                        suffix: "%"
                        validator: IntValidator {
                            bottom: 0
                            top: 100
                        }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)

                        onValueModified: newValue => {
                            root.setElement(row.elKey, newValue / 100);
                        }
                    }
                }
            }
        }
    }
}
