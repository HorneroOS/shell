import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

// Shared Bluetooth state for the Control Center pane and popout helpers.
//
// Event-driven only: every property below is bound to Quickshell.Bluetooth
// (BlueZ via D-Bus PropertiesChanged / InterfacesAdded / Removed). There is
// deliberately no Timer polling in this state or in its consumers.
//
// Pairing bridge: hornero-bt-agent (org.bluez.Agent1, KeyboardDisplay,
// shipped with this Shell) writes request-current.json into
// $XDG_RUNTIME_DIR/hornero/bluetooth-agent/; the FileView below feeds
// requestConfirmation()/requestPinEntry()/requestPasskeyEntry(), and
// the dialog's explicit answer goes back through
// `horneroctl hardware bluetooth agent-respond`. Quickshell exposes no
// Agent1 registration, so nothing is registered (or auto-accepted)
// from QML; the agent rejects on timeout, so silence never pairs.
QtObject {
    id: root

    property BluetoothDevice active: null
    property BluetoothAdapter currentAdapter: Bluetooth.defaultAdapter
    property bool editingAdapterName: false
    property bool fabMenuOpen: false
    property bool editingDeviceName: false

    // The adapter every consumer must use. Settings, DeviceList and Details
    // previously mixed Bluetooth.defaultAdapter with currentAdapter, so a
    // picker change left the toggles writing a different adapter.
    readonly property BluetoothAdapter effectiveAdapter: currentAdapter ?? Bluetooth.defaultAdapter
    readonly property bool hasAdapter: effectiveAdapter !== null
    // Quickshell cannot distinguish "no hardware" from "bluetooth.service
    // stopped": both present as no adapter. The UI says so and offers a
    // restart instead of pretending to know which one it is.
    readonly property bool adapterPowered: effectiveAdapter?.enabled ?? false

    property string lastError: ""
    property string lastOperation: ""
    property bool ownsDiscovery: false

    // Pairing request (agent bridge endpoint, see header).
    property bool showPairingDialog: false
    property string pairingKind: "" // "confirmation" | "pin" | "passkey"
    property string pairingDeviceName: ""
    property string pairingDeviceAddress: ""
    property string pairingPasskey: ""
    property string pairingRequestId: ""

    readonly property string agentRuntimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hornero/bluetooth-agent"

    signal pairingConfirmed
    signal pairingRejected
    signal pairingPinSubmitted(string pin)

    function clearError(): void {
        lastError = "";
        lastOperation = "";
    }

    function fail(operation: string, detail: string): void {
        lastOperation = operation;
        lastError = detail ? qsTr("%1 failed: %2").arg(operation).arg(detail) : qsTr("%1 failed. Check that Bluetooth is on and the device is in range.").arg(operation);
    }

    function deviceLabel(device: BluetoothDevice): string {
        if (!device)
            return qsTr("Unknown device");
        return device.name || device.deviceName || device.address || qsTr("Unknown device");
    }

    function requestConfirmation(deviceName: string, deviceAddress: string, passkey: string): void {
        pairingKind = "confirmation";
        pairingDeviceName = deviceName || qsTr("Unknown device");
        pairingDeviceAddress = deviceAddress || "";
        pairingPasskey = passkey || "";
        showPairingDialog = true;
    }

    function requestPinEntry(deviceName: string, deviceAddress: string): void {
        pairingKind = "pin";
        pairingDeviceName = deviceName || qsTr("Unknown device");
        pairingDeviceAddress = deviceAddress || "";
        pairingPasskey = "";
        showPairingDialog = true;
    }

    function requestPasskeyEntry(deviceName: string, deviceAddress: string): void {
        pairingKind = "passkey";
        pairingDeviceName = deviceName || qsTr("Unknown device");
        pairingDeviceAddress = deviceAddress || "";
        pairingPasskey = "";
        showPairingDialog = true;
    }

    function confirmPairing(): void {
        showPairingDialog = false;
        pairingConfirmed();
        respondToAgent("confirm", "");
    }

    function submitPairingPin(pin: string): void {
        showPairingDialog = false;
        pairingPinSubmitted(pin);
        respondToAgent("pin", pin);
    }

    function rejectPairing(): void {
        showPairingDialog = false;
        pairingKind = "";
        pairingPasskey = "";
        pairingRejected();
        respondToAgent("reject", "");
    }

    // Answers the pending agent request through the canonical backend.
    // With no agent request pending (id empty) this is a no-op, so local
    // UI flows never invent a response.
    function respondToAgent(action: string, pin: string): void {
        if (!pairingRequestId)
            return;
        const args = ["horneroctl", "hardware", "bluetooth", "agent-respond", pairingRequestId, action];
        if (action === "pin")
            args.push(pin);
        args.push("--yes");
        respondProc.command = args;
        respondProc.running = true;
        pairingRequestId = "";
    }

    readonly property var pairingRequestView: FileView {
        path: root.agentRuntimeDir + "/request-current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const req = JSON.parse(text());
                if (!req || !req.id)
                    return;
                root.pairingRequestId = String(req.id);
                if (req.kind === "confirmation" || req.kind === "display")
                    root.requestConfirmation(req.deviceName || "", req.deviceAddress || "", req.passkey || "");
                else if (req.kind === "pin")
                    root.requestPinEntry(req.deviceName || "", req.deviceAddress || "");
                else if (req.kind === "passkey")
                    root.requestPasskeyEntry(req.deviceName || "", req.deviceAddress || "");
            } catch (e) {
                root.fail(qsTr("Pairing"), qsTr("malformed pairing request from hornero-bt-agent"));
            }
        }
        onLoadFailed: {
            // Request file removed: agent cancelled or timed out.
            if (root.pairingRequestId)
                root.cancelPairingRequest();
            root.pairingRequestId = "";
        }
    }

    property Process respondProc: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                root.fail(qsTr("Pairing"), exitCode === 127 || exitStatus !== 0 ? qsTr("horneroctl bluetooth backend is unavailable on this system") : qsTr("the pairing answer could not be delivered (exit %1); the agent will reject on timeout").arg(exitCode));
        }
    }

    // Called by the agent bridge when BlueZ cancels the request (timeout or
    // the other side went away): never leave a stale dialog up.
    function cancelPairingRequest(): void {
        showPairingDialog = false;
        pairingKind = "";
        pairingPasskey = "";
    }

    function pairDevice(device: BluetoothDevice): void {
        if (!device)
            return fail(qsTr("Pair"), qsTr("device is no longer available"));
        if (!hasAdapter)
            return fail(qsTr("Pair"), qsTr("no Bluetooth adapter is available"));
        clearError();
        lastOperation = qsTr("Pair");
        try {
            device.pair();
        } catch (e) {
            fail(qsTr("Pair"), String(e));
        }
    }

    // Connect covers reconnect: a bonded device reconnects, an unbonded one
    // pairs first (BlueZ connects as part of pairing). Blocked devices are
    // refused with a reason instead of failing silently in BlueZ.
    function connectDevice(device: BluetoothDevice): void {
        if (!device)
            return fail(qsTr("Connect"), qsTr("device is no longer available"));
        if (device.blocked)
            return fail(qsTr("Connect"), qsTr("%1 is blocked; unblock it before connecting").arg(deviceLabel(device)));
        if (!device.bonded)
            return pairDevice(device);
        clearError();
        lastOperation = qsTr("Connect");
        try {
            device.connected = true;
        } catch (e) {
            fail(qsTr("Connect"), String(e));
        }
    }

    function disconnectDevice(device: BluetoothDevice): void {
        if (!device)
            return fail(qsTr("Disconnect"), qsTr("device is no longer available"));
        clearError();
        lastOperation = qsTr("Disconnect");
        try {
            device.connected = false;
        } catch (e) {
            fail(qsTr("Disconnect"), String(e));
        }
    }

    function forgetDevice(device: BluetoothDevice): void {
        if (!device)
            return fail(qsTr("Forget"), qsTr("device is no longer available"));
        clearError();
        lastOperation = qsTr("Forget");
        const forgotten = device;
        try {
            device.forget();
        } catch (e) {
            return fail(qsTr("Forget"), String(e));
        }
        if (active === forgotten)
            active = null;
    }

    function setTrusted(device: BluetoothDevice, trusted: bool): void {
        if (!device)
            return fail(qsTr("Trust"), qsTr("device is no longer available"));
        // Trust is only granted explicitly (this toggle / Details), never as
        // a side effect of pairing or connecting.
        try {
            device.trusted = trusted;
        } catch (e) {
            fail(qsTr("Trust"), String(e));
        }
    }

    function setPowered(on: bool): void {
        if (!hasAdapter)
            return fail(qsTr("Power"), qsTr("no Bluetooth adapter is available"));
        clearError();
        lastOperation = qsTr("Power");
        // Power persistence is owned by the backend: off = rfkill
        // soft-block (systemd-rfkill restores it across reboots), on =
        // unblock + controller power. Writing adapter.enabled alone
        // would silently revert at the next boot (AutoEnable=true).
        powerProc.command = ["horneroctl", "hardware", "bluetooth", "power", on ? "on" : "off", "--yes"];
        powerProc.running = true;
    }

    property Process powerProc: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                root.fail(qsTr("Power"), exitCode === 127 || exitStatus !== 0 ? qsTr("horneroctl bluetooth backend is unavailable on this system") : qsTr("the power change failed (exit %1)").arg(exitCode));
        }
    }

    function startDiscovery(): void {
        const adapter = effectiveAdapter;
        if (!adapter)
            return fail(qsTr("Scan"), qsTr("no Bluetooth adapter is available"));
        if (!adapter.enabled)
            return fail(qsTr("Scan"), qsTr("turn Bluetooth on before scanning"));
        clearError();
        adapter.discovering = true;
        ownsDiscovery = true;
    }

    function stopDiscoveryIfOwned(): void {
        const adapter = effectiveAdapter;
        if (ownsDiscovery && adapter)
            adapter.discovering = false;
        ownsDiscovery = false;
    }

    // Restart goes through the horneroctl backend contract
    // (`horneroctl hardware bluetooth restart --yes`, interactive polkit in
    // the backend; never a passwordless rule from QML). The backend is a
    // sibling workstream: when it is not installed yet, surface that as a
    // meaningful error instead of silently doing nothing.
    function restartService(): void {
        clearError();
        lastOperation = qsTr("Restart Bluetooth service");
        restartProc.command = ["horneroctl", "hardware", "bluetooth", "restart", "--yes"];
        restartProc.running = true;
    }

    // A selected device that BlueZ removed (hotplug, forget elsewhere,
    // service restart) must not stay open in Details with stale toggles.
    function pruneStaleActive(): void {
        if (active && !Bluetooth.devices.values.includes(active)) {
            active = null;
            fabMenuOpen = false;
            editingDeviceName = false;
        }
        if (currentAdapter && !Bluetooth.adapters.values.includes(currentAdapter))
            currentAdapter = Bluetooth.defaultAdapter;
    }

    property Process restartProc: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                root.fail(qsTr("Restart Bluetooth service"), exitCode === 127 || exitStatus !== 0 ? qsTr("horneroctl bluetooth backend is unavailable on this system") : qsTr("the service did not restart (exit %1)").arg(exitCode));
        }
    }

    property Connections btConnections: Connections {
        target: Bluetooth

        function onDefaultAdapterChanged(): void {
            if (!root.currentAdapter)
                root.currentAdapter = Bluetooth.defaultAdapter;
            root.pruneStaleActive();
        }
    }
}
