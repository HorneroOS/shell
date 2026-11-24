pragma ComponentBehavior: Bound

import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.modules.companion
import Quickshell
import QtQuick
import QtQuick.Layouts

// Control Center > Javi > Companions: registered characters and the
// user's independent instances. Javi remains a legacy built-in whose
// detailed preferences live in the sections below; validated
// data-only characters are added here without running package QML.
ChannelPanel {
    id: root

    title: qsTr("Companions")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Characters installed on this system. Add an independent companion to the desktop, or manage the ones already out.")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
            wrapMode: Text.Wrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Repeater {
                model: CompanionRegistry.characters

                ColumnLayout {
                    id: characterCard

                    required property var modelData

                    width: 168
                    spacing: Appearance.spacing.small

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: characterCard.modelData.previewUrl
                        Accessible.ignored: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: CompanionRegistry.displayName(characterCard.modelData)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: characterCard.modelData.legacy ? qsTr("Built in") : characterCard.modelData.pluginName
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                        elide: Text.ElideRight
                    }

                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: characterCard.modelData.legacy ? qsTr("Managed below") : qsTr("Add to desktop")
                        type: TextButton.Tonal
                        enabled: !characterCard.modelData.legacy && CompanionInstances.genericInstances.length < CompanionInstances.maxGenericInstances
                        onClicked: CompanionInstances.addInstance(characterCard.modelData.key)
                    }
                }
            }
        }

        StyledText {
            visible: CompanionRegistry.diagnostics.length > 0
            Layout.fillWidth: true
            text: qsTr("Some character definitions could not be loaded: %1").arg(CompanionRegistry.diagnostics.join("; "))
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        StyledText {
            text: qsTr("On the desktop")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        StyledText {
            visible: CompanionInstances.genericInstances.length === 0
            Layout.fillWidth: true
            text: qsTr("No additional companions are out yet.")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
            wrapMode: Text.Wrap
        }

        Repeater {
            model: CompanionInstances.genericInstances

            ColumnLayout {
                id: instanceCard

                required property var modelData

                readonly property var character: CompanionRegistry.characterByKey(modelData.characterId)
                readonly property var definition: character ? character.definition : null

                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    Image {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: instanceCard.character ? instanceCard.character.previewUrl : ""
                        Accessible.ignored: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: instanceCard.character ? CompanionRegistry.displayName(instanceCard.character) : qsTr("Unavailable character")
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: instanceCard.character ? instanceCard.modelData.id : qsTr("Its package is not loaded; this instance and its settings are kept.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        text: qsTr("Duplicate")
                        type: TextButton.Text
                        enabled: !!instanceCard.character
                        onClicked: CompanionInstances.duplicateInstance(instanceCard.modelData.id)
                    }

                    TextButton {
                        text: qsTr("Remove")
                        type: TextButton.Text
                        onClicked: CompanionInstances.removeInstance(instanceCard.modelData.id)
                    }
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: instanceCard.modelData.enabled
                    onToggled: checked => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "enabled": checked
                    })
                }

                PrefPick {
                    visible: !!instanceCard.definition
                    label: qsTr("Skin")
                    current: instanceCard.modelData.skin
                    defaultValue: instanceCard.definition ? instanceCard.definition.defaultSkin : "default"
                    options: instanceCard.definition ? Object.keys(instanceCard.definition.skins).map(id => ({
                                "id": id,
                                "label": CompanionRegistry.displayName({
                                    "names": instanceCard.definition.skins[id].names
                                })
                            })) : []
                    onPicked: id => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "skin": id
                    })
                }

                PrefPick {
                    label: qsTr("Monitor")
                    current: instanceCard.modelData.screenName
                    defaultValue: ""
                    options: [{
                            "id": "",
                            "label": qsTr("Focused monitor")
                        }].concat(Quickshell.screens.map(s => ({
                                "id": s.name,
                                "label": s.name
                            })))
                    onPicked: id => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "screenName": id
                    })
                }

                PrefSlider {
                    label: qsTr("Size")
                    value: instanceCard.modelData.scale
                    from: 0.5
                    to: 2.0
                    stepSize: 0.05
                    decimals: 2
                    defaultValue: 1.0
                    suffix: "×"
                    onChanged: v => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "scale": v
                    })
                }

                SwitchRow {
                    visible: !!instanceCard.definition && !!instanceCard.definition.habitat
                    label: qsTr("Habitat")
                    checked: instanceCard.modelData.habitatEnabled
                    onToggled: checked => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "habitatEnabled": checked
                    })
                }

                SwitchRow {
                    label: qsTr("May react to events")
                    checked: instanceCard.modelData.reactions
                    onToggled: checked => CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "reactions": checked
                    })
                }

                TextButton {
                    text: qsTr("Reset position")
                    type: TextButton.Text
                    onClicked: CompanionInstances.updateInstance(instanceCard.modelData.id, {
                        "posX": 0.82,
                        "posY": 0.9
                    })
                }
            }
        }

        PrefPick {
            label: qsTr("Reaction goes to")
            current: CompanionInstances.reactionTarget
            defaultValue: "primary"
            options: [
                {
                    "id": "primary",
                    "label": qsTr("Javi")
                },
                {
                    "id": "none",
                    "label": qsTr("No companion")
                }
            ].concat(CompanionInstances.genericInstances.map(instance => {
                const character = CompanionRegistry.characterByKey(instance.characterId);
                return {
                    "id": instance.id,
                    "label": character ? CompanionRegistry.displayName(character) : instance.id
                };
            }))
            help: qsTr("One companion at a time. The existing kind, mode, quiet-hours and rate-limit rules still decide first.")
            onPicked: id => CompanionInstances.setReactionTarget(id)
        }
    }
}
