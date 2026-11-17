pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session
    property bool showHeader: true
    property int pendingSwitchIndex: -1

    spacing: Appearance.spacing.normal

    Connections {
        target: VPN
        function onConnectedChanged() {
            if (!VPN.connected && root.pendingSwitchIndex >= 0) {
                const targetIndex = root.pendingSwitchIndex;
                root.pendingSwitchIndex = -1;

                const providers = [];
                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                    const p = Config.utilities.vpn.provider[i];
                    if (typeof p === "object") {
                        const newProvider = {
                            name: p.name,
                            displayName: p.displayName,
                            interface: p.interface,
                            enabled: (i === targetIndex)
                        };
                        providers.push(newProvider);
                    } else {
                        providers.push(p);
                    }
                }
                Config.utilities.vpn.provider = providers;
                Config.save();

                Qt.callLater(function () {
                    VPN.toggle();
                });
            }
        }
    }

    TextButton {
        Layout.fillWidth: true
        text: qsTr("+ Add VPN Provider")
        inactiveColour: Signal.palette.signalWell
        inactiveOnColour: Signal.palette.onSignalWell

        onClicked: {
            vpnDialog.showProviderSelection();
        }
    }

    ListView {
        id: listView

        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight

        interactive: false
        spacing: Appearance.spacing.smaller

        model: ScriptModel {
            values: Config.utilities.vpn.provider.map((provider, index) => {
                const isObject = typeof provider === "object";
                const name = isObject ? (provider.name || "custom") : String(provider);
                const displayName = isObject ? (provider.displayName || name) : name;
                const iface = isObject ? (provider.interface || "") : "";
                const enabled = isObject ? (provider.enabled === true) : false;

                return {
                    index: index,
                    name: name,
                    displayName: displayName,
                    interface: iface,
                    provider: provider,
                    enabled: enabled
                };
            })
        }

        delegate: Component {
            StyledRect {
                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : undefined

                color: Qt.alpha(Signal.tPalette.panel, (root.session && root.session.vpn && root.session.vpn.active === modelData) ? Signal.tPalette.panel.a : 0)
                radius: Appearance.rounding.small

                Accessible.role: Accessible.Button
                Accessible.name: (modelData.displayName || qsTr("Unknown")) + (modelData.enabled && VPN.connected ? qsTr(", connected") : "")

                Interactive {
                    function onClicked(): void {
                        if (root.session && root.session.vpn) {
                            root.session.vpn.active = modelData;
                        }
                    }
                }

                RowLayout {
                    id: rowLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.padding.normal

                    spacing: Appearance.spacing.normal

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2

                        radius: Appearance.rounding.small
                        color: modelData.enabled && VPN.connected ? Signal.palette.signalWell : Signal.tPalette.raised

                        Glyph {
                            id: icon

                            anchors.centerIn: parent
                            name: modelData.enabled && VPN.connected ? "key" : "key-off"
                            font.pointSize: Appearance.font.size.large
                            color: modelData.enabled && VPN.connected ? Signal.palette.onSignalWell : Signal.palette.ink
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            maximumLineCount: 1

                            text: modelData.displayName || qsTr("Unknown")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.smaller

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (modelData.enabled && VPN.connected)
                                        return qsTr("Connected");
                                    if (modelData.enabled && VPN.connecting)
                                        return qsTr("Connecting...");
                                    if (modelData.enabled)
                                        return qsTr("Enabled");
                                    return qsTr("Disabled");
                                }
                                color: modelData.enabled ? (VPN.connected ? Signal.palette.signal : Signal.palette.ink) : Signal.palette.ruleStrong
                                font.pointSize: Appearance.font.size.small
                                font.weight: modelData.enabled && VPN.connected ? 500 : 400
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: connectIcon.implicitHeight + Appearance.padding.smaller * 2

                        radius: Appearance.rounding.small
                        color: Qt.alpha(Signal.palette.signalWell, VPN.connected && modelData.enabled ? 1 : 0)

                        Interactive {
                            disabled: VPN.connecting
                            function onClicked(): void {
                                const clickedIndex = modelData.index;

                                if (modelData.enabled) {
                                    VPN.toggle();
                                } else {
                                    if (VPN.connected) {
                                        root.pendingSwitchIndex = clickedIndex;
                                        VPN.toggle();
                                    } else {
                                        const providers = [];
                                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                            const p = Config.utilities.vpn.provider[i];
                                            if (typeof p === "object") {
                                                const newProvider = {
                                                    name: p.name,
                                                    displayName: p.displayName,
                                                    interface: p.interface,
                                                    enabled: (i === clickedIndex)
                                                };
                                                providers.push(newProvider);
                                            } else {
                                                providers.push(p);
                                            }
                                        }
                                        Config.utilities.vpn.provider = providers;
                                        Config.save();

                                        Qt.callLater(function () {
                                            VPN.toggle();
                                        });
                                    }
                                }
                            }
                        }

                        Glyph {
                            id: connectIcon

                            anchors.centerIn: parent
                            name: VPN.connected && modelData.enabled ? "link-off" : "link"
                            color: VPN.connected && modelData.enabled ? Signal.palette.onSignalWell : Signal.palette.ink
                        }
                    }

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: deleteIcon.implicitHeight + Appearance.padding.smaller * 2

                        radius: Appearance.rounding.small
                        color: "transparent"

                        Interactive {
                            function onClicked(): void {
                                const providers = [];
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    if (i !== modelData.index) {
                                        providers.push(Config.utilities.vpn.provider[i]);
                                    }
                                }
                                Config.utilities.vpn.provider = providers;
                                Config.save();
                            }
                        }

                        Glyph {
                            id: deleteIcon

                            anchors.centerIn: parent
                            name: "trash"
                            color: Signal.palette.ink
                        }
                    }
                }

                implicitHeight: rowLayout.implicitHeight + Appearance.padding.normal * 2
            }
        }
    }

    Popup {
        id: vpnDialog

        property string currentState: "selection"
        property int editIndex: -1
        property string providerName: ""
        property string displayName: ""
        property string interfaceName: ""

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        implicitWidth: Math.min(400, parent.width - Appearance.padding.large * 2)
        padding: Appearance.padding.large * 1.5

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        opacity: 0
        scale: 0.7

        enter: Transition {
            ParallelAnimation {
                Anim {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.medium
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
                Anim {
                    property: "scale"
                    from: 0.7
                    to: 1
                    duration: Appearance.anim.durations.medium
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                Anim {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.short
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
                Anim {
                    property: "scale"
                    from: 1
                    to: 0.7
                    duration: Appearance.anim.durations.short
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        function showProviderSelection(): void {
            currentState = "selection";
            open();
        }

        function closeWithAnimation(): void {
            close();
        }

        function showAddForm(providerType: string, defaultDisplayName: string): void {
            editIndex = -1;
            providerName = providerType;
            displayName = defaultDisplayName;
            interfaceName = "";

            if (currentState === "selection") {
                transitionToForm.start();
            } else {
                currentState = "form";
                isClosing = false;
                open();
            }
        }

        function showEditForm(index: int): void {
            const provider = Config.utilities.vpn.provider[index];
            const isObject = typeof provider === "object";

            editIndex = index;
            providerName = isObject ? (provider.name || "custom") : String(provider);
            displayName = isObject ? (provider.displayName || providerName) : providerName;
            interfaceName = isObject ? (provider.interface || "") : "";

            currentState = "form";
            open();
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.4 * vpnDialog.opacity)
        }

        onClosed: {
            currentState = "selection";
        }

        SequentialAnimation {
            id: transitionToForm

            ParallelAnimation {
                Anim {
                    target: selectionContent
                    property: "opacity"
                    to: 0
                    duration: Appearance.anim.durations.short
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            ScriptAction {
                script: {
                    vpnDialog.currentState = "form";
                }
            }

            ParallelAnimation {
                Anim {
                    target: formContent
                    property: "opacity"
                    to: 1
                    duration: Appearance.anim.durations.short
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        background: StyledRect {
            color: Signal.palette.raised
            radius: Appearance.rounding.small

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                level: 3
                z: -1
            }

            Behavior on implicitHeight {
                Anim {
                    duration: Appearance.anim.durations.medium
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        contentItem: Item {
            implicitHeight: vpnDialog.currentState === "selection" ? selectionContent.implicitHeight : formContent.implicitHeight

            Behavior on implicitHeight {
                Anim {
                    duration: Appearance.anim.durations.medium
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }

            ColumnLayout {
                id: selectionContent

                anchors.fill: parent
                spacing: Appearance.spacing.normal
                visible: vpnDialog.currentState === "selection"
                opacity: vpnDialog.currentState === "selection" ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.short
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                StyledText {
                    text: qsTr("Add VPN Provider")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Choose a provider to add")
                    wrapMode: Text.WordWrap
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                }

                TextButton {
                    Layout.topMargin: Appearance.spacing.normal
                    Layout.fillWidth: true
                    text: qsTr("NetBird")
                    inactiveColour: Signal.tPalette.raised
                    inactiveOnColour: Signal.palette.ink
                    onClicked: {
                        const providers = [];
                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            providers.push(Config.utilities.vpn.provider[i]);
                        }
                        providers.push({
                            name: "netbird",
                            displayName: "NetBird",
                            interface: "wt0"
                        });
                        Config.utilities.vpn.provider = providers;
                        Config.save();
                        vpnDialog.closeWithAnimation();
                    }
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Tailscale")
                    inactiveColour: Signal.tPalette.raised
                    inactiveOnColour: Signal.palette.ink
                    onClicked: {
                        const providers = [];
                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            providers.push(Config.utilities.vpn.provider[i]);
                        }
                        providers.push({
                            name: "tailscale",
                            displayName: "Tailscale",
                            interface: "tailscale0"
                        });
                        Config.utilities.vpn.provider = providers;
                        Config.save();
                        vpnDialog.closeWithAnimation();
                    }
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Cloudflare WARP")
                    inactiveColour: Signal.tPalette.raised
                    inactiveOnColour: Signal.palette.ink
                    onClicked: {
                        const providers = [];
                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            providers.push(Config.utilities.vpn.provider[i]);
                        }
                        providers.push({
                            name: "warp",
                            displayName: "Cloudflare WARP",
                            interface: "CloudflareWARP"
                        });
                        Config.utilities.vpn.provider = providers;
                        Config.save();
                        vpnDialog.closeWithAnimation();
                    }
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("WireGuard (Custom)")
                    inactiveColour: Signal.tPalette.raised
                    inactiveOnColour: Signal.palette.ink
                    onClicked: {
                        vpnDialog.showAddForm("wireguard", "WireGuard");
                    }
                }

                TextButton {
                    Layout.topMargin: Appearance.spacing.normal
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    inactiveColour: Signal.palette.signalWell
                    inactiveOnColour: Signal.palette.onSignalWell
                    onClicked: vpnDialog.closeWithAnimation()
                }
            }

            ColumnLayout {
                id: formContent

                anchors.fill: parent
                spacing: Appearance.spacing.normal
                visible: vpnDialog.currentState === "form"
                opacity: vpnDialog.currentState === "form" ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.short
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                StyledText {
                    text: vpnDialog.editIndex >= 0 ? qsTr("Edit VPN Provider") : qsTr("Add %1 VPN").arg(vpnDialog.displayName)
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.smaller / 2

                    StyledText {
                        text: qsTr("Display Name")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        color: displayNameField.activeFocus ? Signal.layer(Signal.palette.panel, 3) : Signal.layer(Signal.palette.panel, 2)
                        radius: Appearance.rounding.small
                        border.width: 1
                        border.color: displayNameField.activeFocus ? Signal.palette.signal : Qt.alpha(Signal.palette.ruleStrong, 0.3)

                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on border.color {
                            CAnim {}
                        }

                        StyledTextField {
                            id: displayNameField
                            anchors.centerIn: parent
                            width: parent.width - Appearance.padding.normal
                            horizontalAlignment: TextInput.AlignLeft
                            text: vpnDialog.displayName
                            onTextChanged: vpnDialog.displayName = text
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.smaller / 2

                    StyledText {
                        text: qsTr("Interface (e.g., wg0, torguard)")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        color: interfaceNameField.activeFocus ? Signal.layer(Signal.palette.panel, 3) : Signal.layer(Signal.palette.panel, 2)
                        radius: Appearance.rounding.small
                        border.width: 1
                        border.color: interfaceNameField.activeFocus ? Signal.palette.signal : Qt.alpha(Signal.palette.ruleStrong, 0.3)

                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on border.color {
                            CAnim {}
                        }

                        StyledTextField {
                            id: interfaceNameField
                            anchors.centerIn: parent
                            width: parent.width - Appearance.padding.normal
                            horizontalAlignment: TextInput.AlignLeft
                            text: vpnDialog.interfaceName
                            onTextChanged: vpnDialog.interfaceName = text
                        }
                    }
                }

                RowLayout {
                    Layout.topMargin: Appearance.spacing.normal
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        inactiveColour: Signal.tPalette.raised
                        inactiveOnColour: Signal.palette.ink
                        onClicked: vpnDialog.closeWithAnimation()
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Save")
                        enabled: vpnDialog.interfaceName.length > 0
                        inactiveColour: Signal.palette.signalWell
                        inactiveOnColour: Signal.palette.onSignalWell

                        onClicked: {
                            const providers = [];
                            const newProvider = {
                                name: vpnDialog.providerName,
                                displayName: vpnDialog.displayName || vpnDialog.interfaceName,
                                interface: vpnDialog.interfaceName
                            };

                            if (vpnDialog.editIndex >= 0) {
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    if (i === vpnDialog.editIndex) {
                                        providers.push(newProvider);
                                    } else {
                                        providers.push(Config.utilities.vpn.provider[i]);
                                    }
                                }
                            } else {
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    providers.push(Config.utilities.vpn.provider[i]);
                                }
                                providers.push(newProvider);
                            }

                            Config.utilities.vpn.provider = providers;
                            Config.save();
                            vpnDialog.closeWithAnimation();
                        }
                    }
                }
            }
        }
    }
}
