import QtQuick

// Declarative shared-provider lease (shell#377):
//
//     Subscription { domain: "system" }
//
// holds one Providers lease for `domain` while this object exists and
// `enabled` is true, so the matching facade (System, Network, …)
// stays live for as long as the plugin surface is loaded. Changing
// `domain` or setting `enabled: false` releases the old lease first.
// When the host unloads the plugin — including disabling the
// extension, which destroys its items — Component.onDestruction
// releases the lease, so a disabled extension never keeps a shared
// polling timer alive. An unknown domain simply holds nothing
// (`held` stays false) instead of failing to load.
QtObject {
    property string domain: ""
    property bool enabled: true
    readonly property bool held: _heldDomain !== ""

    property string _heldDomain: ""

    function _sync(): void {
        const desired = enabled ? domain : "";
        if (desired === _heldDomain)
            return;
        if (_heldDomain !== "") {
            Providers.unsubscribe(_heldDomain);
            _heldDomain = "";
        }
        if (desired !== "" && Providers.subscribe(desired))
            _heldDomain = desired;
    }

    onDomainChanged: _sync()
    onEnabledChanged: _sync()

    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (_heldDomain !== "")
            Providers.unsubscribe(_heldDomain);
    }
}
