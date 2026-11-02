pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import Quickshell.Widgets
import Quickshell.Bluetooth
import QtQuick

SplitPaneWithDetails {
    id: root

    required property Session session

    anchors.fill: parent

    activeItem: session.bt.active
    paneIdGenerator: function (item) {
        return item ? (item.address || "") : "";
    }

    overlayComponent: Component {
        PairingDialog {
            session: root.session
        }
    }

    // Discoverability/pairability are only offered while this pane is open:
    // cap them at 120s and drop both (plus any scan we started) on hide, so
    // the adapter never stays permanently discoverable after the pane closes.
    onVisibleChanged: {
        const adapter = session.bt.effectiveAdapter;
        if (visible) {
            session.bt.pruneStaleActive();
            if (adapter) {
                adapter.discoverableTimeout = 120;
                adapter.pairableTimeout = 120;
            }
        } else {
            session.bt.stopDiscoveryIfOwned();
            if (adapter) {
                adapter.discoverable = false;
                adapter.pairable = false;
            }
            if (session.bt.showPairingDialog)
                session.bt.rejectPairing();
        }
    }

    leftContent: Component {
        StyledFlickable {
            id: leftFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: deviceList.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: leftFlickable
            }

            DeviceList {
                id: deviceList

                anchors.left: parent.left
                anchors.right: parent.right
                session: root.session
            }
        }
    }

    rightDetailsComponent: Component {
        Details {
            session: root.session
        }
    }

    rightSettingsComponent: Component {
        StyledFlickable {
            id: settingsFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: settingsInner.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: settingsFlickable
            }

            Settings {
                id: settingsInner

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                session: root.session
            }
        }
    }
}
