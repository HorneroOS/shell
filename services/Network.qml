pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQml
import QtQuick
import qs.services

Singleton {
    id: root

    // Native D-Bus networking via Quickshell.Networking (>= 0.3), falling back
    // to Nmcli.qml when NetworkManager backend is unavailable or for saved-profile,
    // password-authenticated connections, and detailed IP/DNS/gateway metadata.
    readonly property bool nativeAvailable: Networking.backend !== NetworkBackendType.None
    readonly property var nativeDevices: nativeAvailable ? Networking.devices.values : []
    readonly property var nativeWifiDevices: nativeDevices.filter(d => d && d.type === DeviceType.Wifi)
    readonly property var nativeWiredDevices: nativeDevices.filter(d => d && d.type === DeviceType.Wired)
    readonly property var primaryWifiDevice: nativeWifiDevices.find(d => d.connected) ?? nativeWifiDevices[0] ?? null

    Component.onCompleted: {
        Nmcli.loadSavedConnections(() => {
            root.savedConnections = Nmcli.savedConnections;
            root.savedConnectionSsids = Nmcli.savedConnectionSsids;
        });
        if (root.nativeAvailable) {
            Qt.callLater(root.syncNativeNetworks);
        } else {
            Qt.callLater(() => {
                root.getEthernetDevices();
            });
            Nmcli.getWifiStatus(enabled => {
                root.wifiEnabled = enabled;
            });
            Qt.callLater(root.syncNetworksFromNmcli);
        }
    }

    onNativeAvailableChanged: {
        if (root.nativeAvailable) {
            Qt.callLater(root.syncNativeNetworks);
        } else {
            root.syncNetworksFromNmcli();
            root.getEthernetDevices();
        }
    }

    onNativeWifiDevicesChanged: {
        if (root.nativeAvailable)
            Qt.callLater(root.syncNativeNetworks);
    }

    readonly property list<AccessPoint> networks: []
    readonly property AccessPoint active: networks.find(n => n.active) ?? null
    property bool wifiEnabled: nativeAvailable ? Networking.wifiEnabled : Nmcli.wifiEnabled
    readonly property bool scanning: nativeAvailable ? (nativeWifiDevices.some(d => d && d.scannerEnabled) || Nmcli.scanning) : Nmcli.scanning

    property list<var> fallbackEthernetDevices: []
    readonly property list<var> ethernetDevices: {
        if (!root.nativeAvailable)
            return root.fallbackEthernetDevices;
        return root.nativeWiredDevices.map(d => ({
                    interface: d.name ?? "",
                    type: "ethernet",
                    state: ConnectionState.toString(d.state),
                    connection: d.network?.name ?? "",
                    connected: !!d.connected,
                    ipAddress: "",
                    gateway: "",
                    dns: [],
                    subnet: "",
                    macAddress: d.address ?? "",
                    speed: d.linkSpeed > 0 ? `${d.linkSpeed} Mb/s` : "",
                    hasLink: !!d.hasLink
                }));
    }
    readonly property var activeEthernet: ethernetDevices.find(d => d.connected) ?? null
    readonly property int ethernetDeviceCount: ethernetDevices.length
    property bool ethernetProcessRunning: false
    property var ethernetDeviceDetails: null
    property var wirelessDeviceDetails: null

    function nativeStrength(raw: real): int {
        const n = Number(raw);
        if (!isFinite(n) || n <= 0)
            return 0;
        return n > 1 ? Math.round(n) : Math.round(n * 100);
    }

    function nativeSecurity(sec: var): string {
        if (sec === undefined || sec === null || sec === WifiSecurityType.Open)
            return "";
        if (sec === WifiSecurityType.Unknown)
            return "Secured";
        return WifiSecurityType.toString(sec);
    }

    function enableWifi(enabled: bool): void {
        if (root.nativeAvailable) {
            Networking.wifiEnabled = enabled;
            return;
        }
        Nmcli.enableWifi(enabled, result => {
            if (result.success) {
                root.getWifiStatus();
                Nmcli.getNetworks(() => {
                    syncNetworksFromNmcli();
                });
            }
        });
    }

    function toggleWifi(): void {
        if (root.nativeAvailable) {
            Networking.wifiEnabled = !Networking.wifiEnabled;
            return;
        }
        Nmcli.toggleWifi(result => {
            if (result.success) {
                root.getWifiStatus();
                Nmcli.getNetworks(() => {
                    syncNetworksFromNmcli();
                });
            }
        });
    }

    function rescanWifi(): void {
        if (root.nativeAvailable && root.nativeWifiDevices.length > 0) {
            for (const dev of root.nativeWifiDevices) {
                if (dev)
                    dev.scannerEnabled = true;
            }
            scanStopTimer.restart();
            return;
        }
        Nmcli.rescanWifi();
    }

    Timer {
        id: scanStopTimer

        interval: 10000
        repeat: false
        onTriggered: {
            for (const dev of root.nativeWifiDevices) {
                if (dev && dev.scannerEnabled)
                    dev.scannerEnabled = false;
            }
        }
    }

    property var pendingConnection: null
    signal connectionFailed(string ssid)

    function findNativeNetwork(ssid: string): var {
        if (!ssid)
            return null;
        const ap = root.networks.find(n => n.ssid === ssid && n.nativeNetwork);
        return ap ? ap.nativeNetwork : null;
    }

    function connectToNetwork(ssid: string, password: string, bssid: string, callback: var): void {
        const hasPassword = password !== undefined && password !== null && password.length > 0;
        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
        if (root.nativeAvailable && !hasPassword && !hasBssid && !callback) {
            const nativeNet = root.findNativeNetwork(ssid);
            if (nativeNet && nativeNet.known) {
                nativeNet.connect();
                return;
            }
        }

        // Set up pending connection tracking if callback provided
        if (callback) {
            root.pendingConnection = {
                ssid: ssid,
                bssid: hasBssid ? bssid : "",
                callback: callback
            };
        }

        Nmcli.connectToNetwork(ssid, password, bssid, result => {
            if (result && result.success) {
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            } else if (result && result.needsPassword) {
                if (callback)
                    callback(result);
            } else {
                if (result && result.error)
                    root.connectionFailed(ssid);
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            }
        });
    }

    function connectToNetworkWithPasswordCheck(ssid: string, isSecure: bool, callback: var, bssid: string): void {
        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
        root.pendingConnection = {
            ssid: ssid,
            bssid: hasBssid ? bssid : "",
            callback: callback
        };

        Nmcli.connectToNetworkWithPasswordCheck(ssid, isSecure, result => {
            if (result && result.success) {
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            } else if (result && result.needsPassword) {
                if (callback)
                    callback(result);
            } else {
                if (result && result.error)
                    root.connectionFailed(ssid);
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            }
        }, bssid);
    }

    function disconnectFromNetwork(): void {
        if (root.nativeAvailable && root.active?.nativeNetwork) {
            root.active.nativeNetwork.disconnect();
            return;
        }
        Nmcli.disconnectFromNetwork();
        Nmcli.getNetworks(() => {
            syncNetworksFromNmcli();
        });
    }

    function forgetNetwork(ssid: string): void {
        if (root.nativeAvailable) {
            const nativeNet = root.findNativeNetwork(ssid);
            if (nativeNet && nativeNet.known) {
                nativeNet.forget();
                Nmcli.loadSavedConnections(() => {});
                return;
            }
        }
        Nmcli.forgetNetwork(ssid, result => {
            if (result.success) {
                Nmcli.getNetworks(() => {
                    syncNetworksFromNmcli();
                });
            }
        });
    }

    property list<string> savedConnections: []
    property list<string> savedConnectionSsids: []

    Connections {
        target: Nmcli
        function onSavedConnectionsChanged() {
            root.savedConnections = Nmcli.savedConnections;
        }
        function onSavedConnectionSsidsChanged() {
            root.savedConnectionSsids = Nmcli.savedConnectionSsids;
        }
        function onNetworksChanged() {
            if (root.nativeAvailable)
                root.syncNativeNetworks();
            else
                root.syncNetworksFromNmcli();
        }
        function onEthernetDevicesChanged() {
            if (!root.nativeAvailable)
                root.fallbackEthernetDevices = Nmcli.ethernetDevices;
        }
    }

    Instantiator {
        model: root.nativeAvailable ? root.nativeWifiDevices : []

        delegate: QtObject {
            required property var modelData
            readonly property var nets: modelData?.networks?.values ?? []

            onNetsChanged: Qt.callLater(root.syncNativeNetworks)
        }
    }

    function syncNativeNetworks(): void {
        if (!root.nativeAvailable)
            return;

        const bySsid = new Map();
        for (const dev of root.nativeWifiDevices) {
            if (!dev || !dev.networks)
                continue;
            for (const net of dev.networks.values) {
                if (!net || !net.name || net.name.length === 0)
                    continue;
                const existing = bySsid.get(net.name);
                if (!existing) {
                    bySsid.set(net.name, net);
                } else if (net.connected && !existing.connected) {
                    bySsid.set(net.name, net);
                } else if (!net.connected && !existing.connected && net.signalStrength > existing.signalStrength) {
                    bySsid.set(net.name, net);
                }
            }
        }

        const nmBySsid = new Map();
        for (const nn of Nmcli.networks) {
            if (nn && nn.ssid)
                nmBySsid.set(nn.ssid, nn.lastIpcObject);
        }

        const rNetworks = root.networks;
        const existingMap = new Map();
        for (const rn of rNetworks) {
            existingMap.set(rn.ssid, rn);
        }

        for (const [ssid, network] of existingMap) {
            if (!bySsid.has(ssid)) {
                const index = rNetworks.indexOf(network);
                if (index >= 0) {
                    rNetworks.splice(index, 1);
                    network.destroy();
                }
            }
        }

        for (const [ssid, nativeNet] of bySsid) {
            const ipcMeta = nmBySsid.get(ssid) ?? ({
                    ssid: ssid,
                    bssid: "",
                    strength: root.nativeStrength(nativeNet.signalStrength),
                    frequency: 0,
                    active: !!nativeNet.connected,
                    security: root.nativeSecurity(nativeNet.security)
                });
            const existing = existingMap.get(ssid);
            if (existing) {
                existing.nativeNetwork = nativeNet;
                existing.lastIpcObject = ipcMeta;
            } else {
                rNetworks.push(apComp.createObject(root, {
                    nativeNetwork: nativeNet,
                    lastIpcObject: ipcMeta
                }));
            }
        }
    }

    function syncNetworksFromNmcli(): void {
        if (root.nativeAvailable)
            return;
        const rNetworks = root.networks;
        const nNetworks = Nmcli.networks;

        const existingMap = new Map();
        for (const rn of rNetworks) {
            const key = `${rn.frequency}:${rn.ssid}:${rn.bssid}`;
            existingMap.set(key, rn);
        }

        const newMap = new Map();
        for (const nn of nNetworks) {
            const key = `${nn.frequency}:${nn.ssid}:${nn.bssid}`;
            newMap.set(key, nn);
        }

        for (const [key, network] of existingMap) {
            if (!newMap.has(key)) {
                const index = rNetworks.indexOf(network);
                if (index >= 0) {
                    rNetworks.splice(index, 1);
                    network.destroy();
                }
            }
        }

        for (const [key, nNetwork] of newMap) {
            const existing = existingMap.get(key);
            if (existing) {
                existing.nativeNetwork = null;
                existing.lastIpcObject = nNetwork.lastIpcObject;
            } else {
                rNetworks.push(apComp.createObject(root, {
                    nativeNetwork: null,
                    lastIpcObject: nNetwork.lastIpcObject
                }));
            }
        }
    }

    component AccessPoint: QtObject {
        id: ap

        required property var lastIpcObject
        property var nativeNetwork: null
        readonly property string ssid: nativeNetwork ? (nativeNetwork.name ?? "") : (lastIpcObject?.ssid ?? "")
        readonly property string bssid: lastIpcObject?.bssid ?? ""
        readonly property int strength: nativeNetwork ? root.nativeStrength(nativeNetwork.signalStrength) : (lastIpcObject?.strength ?? 0)
        readonly property int frequency: lastIpcObject?.frequency ?? 0
        readonly property bool active: nativeNetwork ? !!nativeNetwork.connected : !!(lastIpcObject?.active)
        readonly property string security: nativeNetwork ? root.nativeSecurity(nativeNetwork.security) : (lastIpcObject?.security ?? "")
        readonly property bool known: nativeNetwork ? !!nativeNetwork.known : false
        readonly property bool isSecure: security.length > 0

        readonly property Connections nativeEvents: Connections {
            target: ap.nativeNetwork

            function onConnectionFailed(reason: int): void {
                root.connectionFailed(ap.ssid);
            }
        }
    }

    Component {
        id: apComp
        AccessPoint {}
    }

    function hasSavedProfile(ssid: string): bool {
        if (!ssid || ssid.length === 0)
            return false;
        if (root.nativeAvailable) {
            const ssidLower = ssid.toLowerCase().trim();
            if (root.networks.some(ap => ap.ssid && ap.ssid.toLowerCase().trim() === ssidLower && ap.known))
                return true;
        }
        return Nmcli.hasSavedProfile(ssid);
    }

    function getWifiStatus(): void {
        if (root.nativeAvailable)
            return;
        Nmcli.getWifiStatus(enabled => {
            root.wifiEnabled = enabled;
        });
    }

    function getEthernetDevices(): void {
        if (root.nativeAvailable)
            return;
        root.ethernetProcessRunning = true;
        Nmcli.getEthernetInterfaces(interfaces => {
            root.fallbackEthernetDevices = Nmcli.ethernetDevices;
            root.ethernetProcessRunning = false;
        });
    }

    function connectEthernet(connectionName: string, interfaceName: string): void {
        Nmcli.connectEthernet(connectionName, interfaceName, result => {
            if (result.success) {
                getEthernetDevices();
                const activeDevice = root.ethernetDevices.find(d => d.connected);
                if (activeDevice && activeDevice.interface)
                    updateEthernetDeviceDetails(activeDevice.interface);
            }
        });
    }

    function disconnectEthernet(connectionName: string): void {
        Nmcli.disconnectEthernet(connectionName, result => {
            if (result.success) {
                getEthernetDevices();
                Qt.callLater(() => {
                    root.ethernetDeviceDetails = null;
                });
            }
        });
    }

    function updateEthernetDeviceDetails(interfaceName: string): void {
        Nmcli.getEthernetDeviceDetails(interfaceName, details => {
            root.ethernetDeviceDetails = details;
        });
    }

    function updateWirelessDeviceDetails(): void {
        Nmcli.getWirelessDeviceDetails("", details => {
            root.wirelessDeviceDetails = details;
        });
    }

    function cidrToSubnetMask(cidr: string): string {
        const cidrNum = parseInt(cidr);
        if (isNaN(cidrNum) || cidrNum < 0 || cidrNum > 32) {
            return "";
        }

        const mask = (0xffffffff << (32 - cidrNum)) >>> 0;
        const octets = [(mask >>> 24) & 0xff, (mask >>> 16) & 0xff, (mask >>> 8) & 0xff, mask & 0xff];

        return octets.join(".");
    }
}
