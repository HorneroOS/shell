pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    height: implicitHeight

    required property Session session

    spacing: Appearance.spacing.normal

    SettingsHeader {
        icon: "apps"
        title: qsTr("Launcher Settings")
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("General")
        description: qsTr("General launcher settings")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("Enabled")
            checked: Config.launcher.enabled
            toggle.onToggled: {
                Config.launcher.enabled = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Show on hover")
            checked: Config.launcher.showOnHover
            toggle.onToggled: {
                Config.launcher.showOnHover = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Vim keybinds")
            checked: Config.launcher.vimKeybinds
            toggle.onToggled: {
                Config.launcher.vimKeybinds = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Enable dangerous actions")
            checked: Config.launcher.enableDangerousActions
            toggle.onToggled: {
                Config.launcher.enableDangerousActions = checked;
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Display")
        description: qsTr("Display and appearance settings")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small / 2

        PropertyRow {
            label: qsTr("Max shown items")
            value: qsTr("%1").arg(Config.launcher.maxShown)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Max wallpapers")
            value: qsTr("%1").arg(Config.launcher.maxWallpapers)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Drag threshold")
            value: qsTr("%1 px").arg(Config.launcher.dragThreshold)
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Prefixes")
        description: qsTr("Command prefix settings")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small / 2

        PropertyRow {
            label: qsTr("Special prefix")
            value: Config.launcher.specialPrefix || qsTr("None")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Action prefix")
            value: Config.launcher.actionPrefix || qsTr("None")
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Fuzzy search")
        description: qsTr("Fuzzy search settings")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("Apps")
            checked: Config.launcher.useFuzzy.apps
            toggle.onToggled: {
                Config.launcher.useFuzzy.apps = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Actions")
            checked: Config.launcher.useFuzzy.actions
            toggle.onToggled: {
                Config.launcher.useFuzzy.actions = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Wallpapers")
            checked: Config.launcher.useFuzzy.wallpapers
            toggle.onToggled: {
                Config.launcher.useFuzzy.wallpapers = checked;
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Sizes")
        description: qsTr("Size of launcher items; each has a Reset to the factory value")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        SizeSlider {
            target: Config.launcher.sizes
            key: "itemWidth"
            label: qsTr("Item width")
            from: 400
            to: 1000
            defaultValue: 640
            stepSize: 10
        }
        SizeSlider {
            target: Config.launcher.sizes
            key: "itemHeight"
            label: qsTr("Item height")
            from: 32
            to: 80
            defaultValue: 44
            stepSize: 2
        }
        SizeSlider {
            target: Config.launcher.sizes
            key: "wallpaperWidth"
            label: qsTr("Wallpaper width")
            from: 160
            to: 480
            defaultValue: 280
            stepSize: 10
        }
        SizeSlider {
            target: Config.launcher.sizes
            key: "wallpaperHeight"
            label: qsTr("Wallpaper height")
            from: 120
            to: 360
            defaultValue: 200
            stepSize: 10
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Hidden apps")
        description: qsTr("Applications hidden from launcher")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small / 2

        PropertyRow {
            label: qsTr("Total hidden")
            value: qsTr("%1").arg(Config.launcher.hiddenApps ? Config.launcher.hiddenApps.length : 0)
        }
    }
}
