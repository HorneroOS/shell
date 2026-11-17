pragma ComponentBehavior: Bound

import qs.components.placement
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

import "./kblayout"

// Every bar popout page. Each is a SurfacePage of the shared bar popout
// surface (Wrapper.qml), so all of them — native, tray menus, extension
// popovers — open, morph, scroll and close through the same choreography.
Item {
    id: root

    required property Item wrapper

    // Tray pages are Repeater delegates, so they are children of
    // `content` too.
    readonly property Item currentPopout: {
        for (const c of content.children)
            if (c && "pageKey" in c && c.current)
                return c;
        return null;
    }
    readonly property Item current: currentPopout?.item ?? null

    // No matching popout (unknown or hidden trigger) means no surface at
    // all, never an empty padded square.
    readonly property real preferredWidth: currentPopout && currentPopout.contentWidth > 0 ? currentPopout.preferredWidth : 0
    readonly property real preferredHeight: currentPopout && currentPopout.contentHeight > 0 ? currentPopout.preferredHeight : 0

    function pageFor(name: string): Item {
        for (const c of content.children)
            if (c && "pageKey" in c && c.name === name)
                return c;
        return null;
    }

    Item {
        id: content

        // Pages position themselves against the surface; this container
        // must stay at the surface origin.
        x: 0
        y: 0

        // Extension popovers (shell#449): one page for whichever extension
        // host Loader is the current anchor, so extension popouts reveal,
        // size, morph and close exactly like the native ones.
        Popout {
            id: pluginPopout

            readonly property bool pluginCurrent: String(root.wrapper.currentName).startsWith("plugin:")
            readonly property Item pluginContent: pluginCurrent && root.wrapper.currentAnchor && ("hostPopoutContent" in root.wrapper.currentAnchor) ? root.wrapper.currentAnchor.hostPopoutContent : null

            name: pluginCurrent && pluginContent ? root.wrapper.currentName : "plugin:"
            sourceComponent: PluginPopoutHost {
                content: pluginPopout.pluginContent
            }
        }

        Popout {
            name: "activewindow"
            eyebrow: qsTr("04 · WINDOW")
            sourceComponent: ActiveWindow {
                wrapper: root.wrapper
            }
        }

        Popout {
            id: networkPopout

            name: "network"
            eyebrow: qsTr("02 · NETWORK")
            context: qsTr("WIRELESS")
            sourceComponent: Network {
                wrapper: root.wrapper
                view: "wireless"
            }
        }

        Popout {
            name: "ethernet"
            eyebrow: qsTr("02 · NETWORK")
            context: qsTr("ETHERNET")
            sourceComponent: Network {
                wrapper: root.wrapper
                view: "ethernet"
            }
        }

        Popout {
            id: passwordPopout

            name: "wirelesspassword"
            eyebrow: qsTr("02 · NETWORK")
            context: qsTr("JOIN")
            sourceComponent: WirelessPassword {
                wrapper: root.wrapper
                network: networkPopout.item?.passwordNetwork ?? null
            }

            Connections {
                target: root.wrapper

                function onCurrentNameChanged(): void {
                    // Hand the selected network over as soon as the
                    // password page becomes current, and again once the
                    // network page has loaded if it was not ready yet.
                    if (root.wrapper.currentName !== "wirelesspassword")
                        return;
                    if (passwordPopout.item && networkPopout.item?.passwordNetwork)
                        passwordPopout.item.network = networkPopout.item.passwordNetwork;
                    Qt.callLater(() => {
                        if (passwordPopout.item && networkPopout.item?.passwordNetwork)
                            passwordPopout.item.network = networkPopout.item.passwordNetwork;
                    });
                }
            }

            Connections {
                target: networkPopout

                function onItemChanged(): void {
                    if (root.wrapper.currentName === "wirelesspassword" && passwordPopout.item) {
                        Qt.callLater(() => {
                            if (networkPopout.item?.passwordNetwork)
                                passwordPopout.item.network = networkPopout.item.passwordNetwork;
                        });
                    }
                }
            }
        }

        Popout {
            name: "bluetooth"
            eyebrow: qsTr("03 · BLUETOOTH")
            sourceComponent: Bluetooth {
                wrapper: root.wrapper
            }
        }

        Popout {
            name: "battery"
            eyebrow: qsTr("05 · POWER")
            sourceComponent: Battery {}
        }

        Popout {
            name: "audio"
            eyebrow: qsTr("01 · AUDIO")
            context: qsTr("OUTPUT")
            sourceComponent: Audio {
                wrapper: root.wrapper
            }
        }

        Popout {
            name: "kblayout"
            eyebrow: qsTr("06 · KEYBOARD")
            context: qsTr("LAYOUT")
            sourceComponent: KbLayout {
                wrapper: root.wrapper
            }
        }

        Popout {
            name: "lockstatus"
            eyebrow: qsTr("06 · KEYBOARD")
            context: qsTr("LOCKS")
            sourceComponent: LockStatus {}
        }

        Repeater {
            model: ScriptModel {
                values: [...SystemTray.items.values]
            }

            Popout {
                id: trayMenu

                required property SystemTrayItem modelData
                required property int index

                name: `traymenu${index}`
                eyebrow: qsTr("07 · TRAY")
                context: trayMenu.modelData.tooltipTitle || trayMenu.modelData.title || ""
                sourceComponent: trayMenuComp

                Connections {
                    target: root.wrapper

                    // A fresh open starts at the menu root, not at the
                    // submenu the user left last time.
                    function onHasCurrentChanged(): void {
                        if (root.wrapper.hasCurrent && trayMenu.current) {
                            trayMenu.sourceComponent = null;
                            trayMenu.sourceComponent = trayMenuComp;
                        }
                    }
                }

                Component {
                    id: trayMenuComp

                    TrayMenu {
                        popouts: root.wrapper
                        trayItem: trayMenu.modelData.menu
                    }
                }
            }
        }
    }

    component Popout: SurfacePage {
        required property string name

        surface: root.wrapper
        pageKey: name
        current: root.wrapper.hasCurrent && !root.wrapper.isDetached && root.wrapper.currentName === name
    }
}
