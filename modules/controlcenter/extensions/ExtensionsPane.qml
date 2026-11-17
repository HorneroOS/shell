pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets

// Control Center › Extensions: community plugin lifecycle.
// horneroctl stays the single writer of plugin lifecycle state: this
// pane never writes receipts or payloads itself, it only invokes
// `horneroctl plugin enable|disable|trust <id> --yes` — the exact CLI
// commands — and re-reads state through the Plugins service. Enable
// (the direction that runs third-party QML as your user) requires an
// explicit inline confirmation, mirroring the CLI --yes gate.
// Install and remove stay CLI-only.
Item {
    id: root

    required property Session session

    property string pendingEnable: ""
    property string pendingTrust: ""
    property string pendingInstall: ""
    property string pendingCatalogAction: ""
    property string actionError: ""
    property var actionEnvelope: null
    property var catalogEntries: []
    property string catalogError: ""
    property string catalogRevision: ""
    property string catalogSearch: ""
    property string actionMessage: ""
    property string pluginSearch: ""
    property string pluginTrustFilter: "all"
    property string pluginPlacementFilter: "all"
    property string expandedPluginId: ""
    property string settingsPluginId: ""
    property string customSettingsPluginId: ""

    // Installed-plugin JSON (horneroctl plugin list --json, verified live)
    // has no category or description field: entries carry id, name,
    // version, installed, enabled, trust, source, revision,
    // catalog_sha256, capabilities {processCommands, networkHosts,
    // settings}, capabilities_verified and rollback_available. Placement
    // is added by the Plugins service / host and may be empty. Filtering
    // therefore uses trust and placement, never an invented category.
    function filteredPlugins(): var {
        const query = root.pluginSearch.trim().toLowerCase();
        return Plugins.entries.filter(entry => {
            if (root.pluginTrustFilter !== "all" && String(entry.trust || "unknown") !== root.pluginTrustFilter)
                return false;
            if (root.pluginPlacementFilter !== "all" && String(entry.placement || "") !== root.pluginPlacementFilter)
                return false;
            if (!query)
                return true;
            return [entry.name, entry.id, entry.description]
                .some(value => String(value || "").toLowerCase().includes(query));
        });
    }

    function placementIcon(placement): string {
        return placement === "bar" ? "layout-navbar" : placement === "dashboard" ? "dashboard" : placement === "desktop" ? "wallpaper" : placement === "launcher" ? "search" : "puzzle";
    }

    function placementLabel(placement): string {
        return placement === "bar" ? qsTr("Bar") : placement === "dashboard" ? qsTr("Dashboard") : placement === "desktop" ? qsTr("Desktop") : placement === "launcher" ? qsTr("Launcher") : String(placement || "");
    }

    function trustLabel(trust): string {
        const t = String(trust || "unknown");
        return t === "official" ? qsTr("Official") : t === "trusted" ? qsTr("Trusted") : t === "signed" ? qsTr("Signed") : t === "untrusted" ? qsTr("Not trusted") : t === "stale-trust" ? qsTr("Trust outdated") : t === "modified" ? qsTr("Modified since trusted") : t === "unverified" ? qsTr("Unverified") : qsTr("Trust unknown");
    }

    function pluginTrustValues(): var {
        return [...new Set(Plugins.entries.map(entry => String(entry.trust || "unknown")))].sort();
    }

    function pluginPlacementValues(): var {
        return [...new Set(Plugins.entries.map(entry => String(entry.placement || "")))].sort();
    }

    function pluginDetail(entry): string {
        return qsTr("ID: %1\nVersion: %2\nPlacement: %3\nTrust: %4\n%5\nDescription: %6\n%7\nQML plugins are not sandboxed: an enabled plugin runs as your user.")
            .arg(entry.id || qsTr("Not listed"))
            .arg(entry.version || qsTr("Not listed"))
            .arg(entry.placement || qsTr("Not listed"))
            .arg(entry.trust || qsTr("unknown"))
            .arg(root.declaredCapabilities(entry.capabilities, entry.capabilities_verified))
            .arg(entry.description || qsTr("Not listed"))
            .arg(root.pluginDiagnostics(entry));
    }

    // Diagnostics (shell#380): host-observed load timing against the
    // advisory budgets, plus the redacted per-plugin event log.
    // Details were sanitized by the Plugins service before storage.
    function pluginDiagnostics(entry): string {
        const codes = Array.isArray(entry.diagnostics) ? entry.diagnostics : [];
        const warnings = codes.map(code => code === "slow-load"
            ? qsTr("slow load (budget %1 ms)").arg(Plugins.slowLoadBudgetMs)
            : code === "load-churn"
            ? qsTr("repeated reloads (%1 in %2 s)").arg(Plugins.churnAttemptBudget).arg(Math.round(Plugins.churnWindowMs / 1000))
            : code);
        const events = Plugins.diagnosticsFor(entry.id).slice(-3)
            .map(event => `${new Date(event.atMs).toLocaleTimeString()} ${event.event}${event.detail ? `: ${event.detail}` : ""}`);
        return qsTr("Diagnostics: state %1, load time %2, attempts %3\nWarnings: %4\nRecent events: %5")
            .arg(entry.state || qsTr("unknown"))
            .arg(typeof entry.loadMs === "number" && entry.loadMs >= 0 ? qsTr("%1 ms").arg(entry.loadMs) : qsTr("not measured"))
            .arg(entry.attempts || 0)
            .arg(warnings.length ? warnings.join(", ") : qsTr("none"))
            .arg(events.length ? events.join(" · ") : qsTr("none"));
    }

    // Typed settings declarations for the generated settings UI
    // (shell#374): the host-normalized entry.settings when the
    // plugin host has visited the entry, else the manifest
    // declarations horneroctl reports under capabilities. Malformed
    // declarations are dropped by Plugins.normalizeSettings, so a
    // plugin with no valid settings gets no settings affordance.
    function pluginSettings(entry): var {
        const hosted = Plugins.normalizeSettings(entry ? entry.settings : null);
        if (Object.keys(hosted).length > 0)
            return hosted;
        const declared = entry && entry.capabilities && typeof entry.capabilities === "object" ? entry.capabilities.settings : null;
        return Plugins.normalizeSettings(declared);
    }

    function hasPluginSettings(entry): bool {
        return Object.keys(root.pluginSettings(entry)).length > 0;
    }

    // Custom settings surface (shell#373/#374): the effective
    // surfaces.settings declaration for an enabled, installed
    // plugin, or null. Plugins without it (including every v1
    // plugin) get no custom-settings affordance at all.
    function settingsSurface(entry): var {
        return Plugins.settingsSurfaceFor(entry);
    }

    function hasSettingsSurface(entry): bool {
        return root.settingsSurface(entry) !== null;
    }

    function settingsSurfaceEntrypoint(entry): string {
        const surface = root.settingsSurface(entry);
        return surface ? String(surface.entrypoint) : "";
    }

    function hasAnyPluginSettings(entry): bool {
        return root.hasPluginSettings(entry) || root.hasSettingsSurface(entry);
    }

    function filteredCatalogEntries(): var {
        const query = root.catalogSearch.trim().toLowerCase();
        if (!query)
            return root.catalogEntries;
        return root.catalogEntries.filter(entry => [entry.name, entry.id, entry.description, entry.author, entry.category, entry.placement]
            .some(value => String(value || "").toLowerCase().includes(query)));
    }

    function declaredCapabilities(capabilities, verified): string {
        const declared = capabilities || {};
        const commands = Array.isArray(declared.processCommands) ? declared.processCommands : [];
        const hosts = Array.isArray(declared.networkHosts) ? declared.networkHosts : [];
        const settings = declared.settings && typeof declared.settings === "object" ? declared.settings : {};
        const settingsSummary = Object.keys(settings).sort().map(key => `${key}: ${JSON.stringify(settings[key])}`).join(", ");
        const provenance = verified === false
            ? qsTr("Unverified plugin-manifest declarations")
            : qsTr("Plugin-declared capabilities");
        return qsTr("%1\nProcess commands: %2\nNetwork hosts: %3\nSettings: %4")
            .arg(provenance)
            .arg(commands.length ? commands.join(", ") : qsTr("None declared"))
            .arg(hosts.length ? hosts.join(", ") : qsTr("None declared"))
            .arg(settingsSummary || qsTr("None declared"));
    }

    // Marketplace metadata (shell#379): installed entries carry the
    // host-normalized entry.marketplace (Plugins.markMarketplace,
    // recorded from manifest.json without loading any entrypoint);
    // catalogue entries may carry the same shape in the horneroctl
    // catalogue JSON, normalized here on read. Absent or malformed
    // metadata yields null and the row renders exactly as before.
    function pluginMarketplace(entry): var {
        return Plugins.normalizeMarketplace(entry ? entry.marketplace : null);
    }

    function isDeprecated(entry): bool {
        const marketplace = root.pluginMarketplace(entry);
        return !!(marketplace && marketplace.deprecation);
    }

    function replacedById(entry): string {
        const marketplace = root.pluginMarketplace(entry);
        return marketplace && marketplace.deprecation && marketplace.deprecation.replacedBy ? String(marketplace.deprecation.replacedBy) : "";
    }

    function deprecationText(entry): string {
        const marketplace = root.pluginMarketplace(entry);
        if (!marketplace || !marketplace.deprecation)
            return "";
        const lines = [qsTr("Deprecated.")];
        if (marketplace.deprecation.message)
            lines.push(String(marketplace.deprecation.message));
        if (marketplace.deprecation.replacedBy)
            lines.push(qsTr("Replaced by: %1").arg(marketplace.deprecation.replacedBy));
        return lines.join("\n");
    }

    // PluginKit 3 compatibility, from facts only. The host refuses packages
    // built for PluginKit 1/2 (schemaVersion), so an entry that reports
    // schemaVersion 1/2, or a load failure naming PluginKit, is marked as
    // needing a port. When neither the installed list nor the catalogue
    // reports a schemaVersion the chip says "not reported" instead of
    // guessing.
    function kitStatus(entry): var {
        const version = entry?.schemaVersion;
        if (version === 3)
            return { "label": qsTr("PluginKit 3"), "tone": "good", "icon": "circle-check" };
        if (version === 1 || version === 2 || /built for PluginKit [12]/.test(entry?.detail ?? ""))
            return { "label": qsTr("Needs PluginKit 3"), "tone": "bad", "icon": "alert-triangle" };
        return { "label": qsTr("PluginKit: not reported"), "tone": "neutral", "icon": "help-circle" };
    }

    // Maturity from the version alone (semver: 0.y.z is initial
    // development). No other maturity is declared by manifests today.
    function maturityLabel(entry): string {
        const major = parseInt(String(entry?.version ?? "").split(".")[0], 10);
        return major === 0 ? qsTr("Pre-1.0") : "";
    }

    function compatibilityText(entry): string {
        const marketplace = root.pluginMarketplace(entry);
        if (!marketplace || !marketplace.compatibility)
            return "";
        const compat = marketplace.compatibility;
        if (compat.minShellVersion && compat.maxShellVersion)
            return qsTr("Shell compatibility: %1 to %2 (declared, not enforced)").arg(compat.minShellVersion).arg(compat.maxShellVersion);
        if (compat.minShellVersion)
            return qsTr("Shell compatibility: %1 or newer (declared, not enforced)").arg(compat.minShellVersion);
        return qsTr("Shell compatibility: up to %1 (declared, not enforced)").arg(compat.maxShellVersion);
    }

    function changelogText(entry): string {
        const marketplace = root.pluginMarketplace(entry);
        if (!marketplace || !Array.isArray(marketplace.changelog) || marketplace.changelog.length === 0)
            return "";
        return qsTr("Version history:\n%1").arg(marketplace.changelog.map(item => `${item.version}: ${item.notes}`).join("\n"));
    }

    // Static previews (shell#379): screenshot image files shipped in
    // an installed package, shown as plain Images. No plugin
    // entrypoint is ever loaded to render a preview; a catalogue
    // entry that is not installed has no local files yet, so its
    // declared screenshots are listed by caption only.
    function screenshotSources(entry): var {
        const marketplace = root.pluginMarketplace(entry);
        if (!marketplace || !Array.isArray(marketplace.screenshots) || !entry || !entry.id)
            return [];
        const installed = root.installedEntry(entry.id);
        if (!installed)
            return [];
        return marketplace.screenshots.map(shot => ({
            source: `file://${Plugins.pluginsDir}/${entry.id}/${shot.path}`,
            alt: shot.alt || qsTr("Screenshot of %1").arg(entry.name || entry.id)
        }));
    }

    function screenshotCaptions(entry): string {
        const marketplace = root.pluginMarketplace(entry);
        if (!marketplace || !Array.isArray(marketplace.screenshots) || marketplace.screenshots.length === 0)
            return "";
        return qsTr("Screenshots: %1").arg(marketplace.screenshots.map(shot => shot.alt || shot.path).join(" · "));
    }

    // Plain-language reading of the declared capabilities
    // (shell#379). These explain what the declarations mean; they
    // do not turn declarations into enforced permissions — the
    // not-sandboxed warning above still applies in full.
    function permissionExplanations(entry): string {
        const declared = entry && entry.capabilities && typeof entry.capabilities === "object" ? entry.capabilities : {};
        const commands = Array.isArray(declared.processCommands) ? declared.processCommands : [];
        const hosts = Array.isArray(declared.networkHosts) ? declared.networkHosts : [];
        const actions = Array.isArray(declared.actions) ? declared.actions : [];
        const settings = declared.settings && typeof declared.settings === "object" ? Object.keys(declared.settings) : [];
        const hostedSettings = Object.keys(root.pluginSettings(entry));
        const lines = [qsTr("What these declarations mean:")];
        lines.push(commands.length
            ? qsTr("· Programs: declares it may start %1 as your user.").arg(commands.join(", "))
            : qsTr("· Programs: declares it starts no programs."));
        lines.push(hosts.length
            ? qsTr("· Network: declares it may contact %1.").arg(hosts.join(", "))
            : qsTr("· Network: declares it contacts no hosts."));
        if (actions.length)
            lines.push(qsTr("· System actions: declares it may request %1 through the horneroctl broker, which re-checks each request.").arg(actions.join(", ")));
        const settingKeys = hostedSettings.length ? hostedSettings : settings;
        lines.push(settingKeys.length
            ? qsTr("· Settings: stores only its own settings (%1) — use the Settings button below.").arg(settingKeys.sort().join(", "))
            : qsTr("· Settings: declares no settings of its own."));
        lines.push(qsTr("Declarations are review metadata, not enforced permissions: enabled QML still runs as your user without a sandbox."));
        return lines.join("\n");
    }

    function installedEntry(pluginId): var {
        return Plugins.entries.find(entry => entry.id === pluginId) || null;
    }

    // Replaced-by shortcut (shell#379): surface the replacement in
    // whichever list already has it — expanding its installed-row
    // details, or filtering the catalogue to it. No lifecycle
    // action is taken; installing/enabling the replacement stays
    // the existing confirmed flow.
    function openReplacement(pluginId): void {
        if (root.installedEntry(pluginId)) {
            root.pluginSearch = pluginId;
            root.expandedPluginId = pluginId;
        } else {
            root.catalogSearch = pluginId;
        }
    }

    function refreshCatalog() {
        root.catalogError = "";
        root.catalogRevision = "";
        catalogProc.command = ["horneroctl", "--json", "plugin", "catalog"];
        catalogProc.running = true;
    }

    function runCatalogAction(action, pluginId) {
        root.actionError = "";
        root.actionMessage = "";
        catalogInstallProc.command = ["horneroctl", "--json", "plugin", "catalog", action, pluginId];
        if (action === "install" || action === "update")
            catalogInstallProc.command.push("--revision", root.catalogRevision);
        catalogInstallProc.command.push("--yes");
        catalogInstallProc.running = true;
    }

    function runLifecycle(action, pluginId) {
        root.actionError = "";
        root.actionEnvelope = null;
        lifecycleProc.command = ["horneroctl", "--json", "plugin", action, pluginId, "--yes"];
        lifecycleProc.running = true;
    }

    Process {
        id: lifecycleProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.actionEnvelope = JSON.parse(text);
                } catch (e) {
                    root.actionEnvelope = null;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const env = root.actionEnvelope;
            if (env && env.ok === true) {
                root.pendingEnable = "";
                root.pendingTrust = "";
                root.actionError = "";
                Plugins.reload();
            } else {
                root.actionError = (env && env.message) ? String(env.message) : qsTr("Plugin action failed (exit %1).").arg(exitCode);
            }
        }
    }

    Process {
        id: catalogProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                catalogProc.out += data;
            }
        }
        onStarted: catalogProc.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const env = JSON.parse(catalogProc.out.trim());
                if (env.ok === true) {
                    root.catalogEntries = JSON.parse((env.data && env.data.plugins) || "[]");
                    root.catalogRevision = (env.data && env.data.revision) ? String(env.data.revision) : "";
                } else {
                    root.catalogError = (env.message || "Catalogue unavailable").toString();
                }
            } catch (e) {
                root.catalogError = qsTr("Catalogue unavailable (network or horneroctl).");
            }
        }
    }

    Process {
        id: catalogInstallProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                catalogInstallProc.out += data;
            }
        }
        onStarted: catalogInstallProc.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const env = JSON.parse(catalogInstallProc.out.trim());
                if (env.ok === true) {
                    root.pendingInstall = "";
                    root.pendingCatalogAction = "";
                    const data = env.data || {};
                    root.actionMessage = [env.message || qsTr("Catalogue action completed."),
                        data.revision ? qsTr("Catalogue revision: %1").arg(data.revision) : "",
                        data.sha256 ? qsTr("Payload SHA-256: %1").arg(data.sha256) : ""]
                        .filter(Boolean).join("\n");
                    Plugins.reload();
                    root.refreshCatalog();
                } else {
                    root.actionError = (env.message || "Install failed").toString();
                }
            } catch (e) {
                root.actionError = qsTr("Install failed.");
            }
        }
    }

    Component.onCompleted: root.refreshCatalog()

    anchors.fill: parent

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                PaneHeader {
                    paneId: "extensions"
                    intro: qsTr("Every enabled QML plugin runs as your user without a sandbox. Command and network declarations come from each plugin's manifest and are not enforced permissions. Review a plugin's source before enabling it. Extensions built for PluginKit 1 or 2 are refused until they are ported to PluginKit 3 (Hornero Signal).")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: Plugins.entries.length === 1 ? qsTr("1 extension installed") : qsTr("%1 extensions installed").arg(Plugins.entries.length)
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 600
                    }

                    TextButton {
                        text: qsTr("Reload plugin list")
                        type: TextButton.Text
                        onClicked: Plugins.reload()
                    }

                    TextButton {
                        visible: !Plugins.safeModeEnv
                        text: Config.plugins.safeMode ? qsTr("Turn safe mode off") : qsTr("Turn safe mode on (recovery)")
                        type: TextButton.Text
                        onClicked: Config.plugins.setSafeMode(!Config.plugins.safeMode)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.safeMode
                    text: Plugins.safeModeEnv
                        ? qsTr("Safe mode is on (HORNERO_SAFE_MODE): no extension was loaded, not even its manifest. Disable the broken extension below, then restart the shell without HORNERO_SAFE_MODE.")
                        : qsTr("Safe mode is on: no extension was loaded, not even its manifest. Disable the broken extension below, then turn safe mode off.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.actionError.length > 0
                    text: root.actionError
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.actionMessage.length > 0
                    text: root.actionMessage
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.signal
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.discovered && Plugins.entries.length === 0 && Plugins.discoveryError.length === 0
                    text: qsTr("No plugins installed. Add one with: horneroctl plugin install <path>")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.discoveryError.length > 0
                    text: Plugins.discoveryError
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                SearchBar {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search installed plugins")
                    Accessible.name: qsTr("Search installed plugins")
                    text: root.pluginSearch
                    onTextChanged: root.pluginSearch = text
                }

                // Compact filter chips (shell#470): one line, trust then
                // placement; a selected chip shows a check, selecting it
                // again clears the filter.
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small
                    visible: Plugins.entries.length > 0 && (root.pluginTrustValues().length > 1 || root.pluginPlacementValues().filter(value => value.length > 0).length > 1)

                    Repeater {
                        model: root.pluginTrustValues().length > 1 ? root.pluginTrustValues() : []

                        delegate: FilterChip {
                            required property var modelData

                            label: root.trustLabel(modelData)
                            selected: root.pluginTrustFilter === modelData
                            onActivated: root.pluginTrustFilter = selected ? "all" : modelData
                        }
                    }

                    Repeater {
                        model: root.pluginPlacementValues().filter(value => value.length > 0).length > 1 ? root.pluginPlacementValues().filter(value => value.length > 0) : []

                        delegate: FilterChip {
                            required property var modelData

                            label: root.placementLabel(modelData)
                            icon: root.placementIcon(modelData)
                            selected: root.pluginPlacementFilter === modelData
                            onActivated: root.pluginPlacementFilter = selected ? "all" : modelData
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.entries.length > 0 && root.filteredPlugins().length === 0
                    text: qsTr("No installed plugins match this search or filter.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.filteredPlugins()

                    delegate: StyledRect {
                        id: row

                        required property var modelData

                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        color: Signal.layer(Signal.palette.panel, 1)
                        implicitHeight: rowCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: rowCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            // Card header (shell#470): icon tile, name with a quiet
                            // version, the manifest description and chips for
                            // placement, trust and state. Hashes and the raw
                            // revision moved into Details.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.normal

                                StyledRect {
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: 44
                                    implicitHeight: 44
                                    radius: Appearance.rounding.small
                                    color: row.modelData.enabled ? Signal.palette.signalWell : Signal.tPalette.lifted

                                    Glyph {
                                        anchors.centerIn: parent
                                        name: root.placementIcon(row.modelData.placement)
                                        font.pointSize: Appearance.font.size.large
                                        color: row.modelData.enabled ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        StyledText {
                                            text: row.modelData.name
                                            font.pointSize: Appearance.font.size.normal
                                            font.weight: 600
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: row.modelData.version ? `v${row.modelData.version}` : ""
                                            font.pointSize: Appearance.font.size.small
                                            color: Signal.palette.inkMuted
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: !!row.modelData.description
                                        text: row.modelData.description ?? ""
                                        font.pointSize: Appearance.font.size.small
                                        color: Signal.palette.inkMuted
                                        wrapMode: Text.Wrap
                                        maximumLineCount: root.expandedPluginId === row.modelData.id ? 20 : 2
                                        elide: Text.ElideRight
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        Layout.topMargin: Appearance.spacing.small / 2
                                        spacing: Appearance.spacing.small

                                        ExtensionChip {
                                            label: Plugins.safeMode && row.modelData.enabled ? qsTr("Safe mode") : !row.modelData.enabled && !row.modelData.requestedEnabled ? qsTr("Disabled") : row.modelData.state === "loaded" ? qsTr("Loaded") : row.modelData.state === "failed" ? qsTr("Failed") : row.modelData.state === "blocked" ? qsTr("Blocked") : qsTr("Pending")
                                            tone: !row.modelData.enabled && !row.modelData.requestedEnabled ? "neutral" : row.modelData.state === "loaded" ? "good" : row.modelData.state === "failed" || row.modelData.state === "blocked" ? "bad" : "neutral"
                                        }

                                        ExtensionChip {
                                            readonly property var kit: root.kitStatus(row.modelData)
                                            label: kit.label
                                            tone: kit.tone
                                            icon: kit.icon
                                            Accessible.role: Accessible.StaticText
                                            Accessible.name: qsTr("Compatibility: %1").arg(kit.label)
                                        }

                                        ExtensionChip {
                                            visible: root.maturityLabel(row.modelData).length > 0
                                            label: root.maturityLabel(row.modelData)
                                        }

                                        ExtensionChip {
                                            visible: !!row.modelData.placement
                                            label: root.placementLabel(row.modelData.placement)
                                            icon: root.placementIcon(row.modelData.placement)
                                        }

                                        ExtensionChip {
                                            label: root.trustLabel(row.modelData.trust)
                                            Accessible.role: Accessible.StaticText
                                            Accessible.name: qsTr("Trust: %1").arg(row.modelData.trust ?? qsTr("unknown"))
                                            icon: (["untrusted", "stale-trust", "modified", "unverified"].includes(row.modelData.trust)) ? "alert-triangle" : "rosette-discount-check"
                                            tone: (["untrusted", "stale-trust", "modified", "unverified"].includes(row.modelData.trust)) ? "bad" : "neutral"
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.modelData.id && row.modelData.source === "https://github.com/HorneroOS/plugins.git"
                                text: qsTr("Catalogue revision: %1\nExpected payload SHA-256: %2")
                                    .arg(row.modelData.revision || qsTr("Not recorded"))
                                    .arg(row.modelData.catalog_sha256 || qsTr("Not recorded"))
                                font.pointSize: Appearance.font.size.smaller
                                font.family: Appearance.font.family.mono
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WrapAnywhere
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.isDeprecated(row.modelData)
                                text: root.deprecationText(row.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            TextButton {
                                visible: root.replacedById(row.modelData).length > 0
                                text: qsTr("View replacement: %1").arg(root.replacedById(row.modelData))
                                type: TextButton.Text
                                onClicked: root.openReplacement(root.replacedById(row.modelData))
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingTrust === row.modelData.id
                                text: qsTr("You are trusting the exact code currently installed for this plugin. If its files change, you will be asked again. Trusting does not enable it.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!row.modelData.detail
                                text: row.modelData.detail ?? ""
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingEnable === row.modelData.id
                                text: qsTr("This plugin's QML will run as your user, without a sandbox. Enable only if you reviewed its source.\n%1")
                                    .arg(root.declaredCapabilities(row.modelData.capabilities, row.modelData.capabilities_verified))
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.modelData.id
                                text: root.pluginDetail(row.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            // Marketplace detail (shell#379), shown
                            // with Details: static screenshot Images
                            // (no plugin entrypoint is loaded),
                            // compatibility, version history and the
                            // plain-language permission explanations.
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.modelData.id
                                spacing: Appearance.spacing.small

                                Repeater {
                                    model: root.screenshotSources(row.modelData)

                                    delegate: Image {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 180
                                        source: modelData.source
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        Accessible.role: Accessible.Graphic
                                        Accessible.name: modelData.alt
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.screenshotSources(row.modelData).length === 0 && root.screenshotCaptions(row.modelData).length > 0
                                    text: root.screenshotCaptions(row.modelData)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.compatibilityText(row.modelData).length > 0
                                    text: root.compatibilityText(row.modelData)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.changelogText(row.modelData).length > 0
                                    text: root.changelogText(row.modelData)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.permissionExplanations(row.modelData)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }
                            }

                            PluginSettingsSection {
                                Layout.fillWidth: true
                                visible: root.settingsPluginId === row.modelData.id && root.hasPluginSettings(row.modelData)
                                pluginId: row.modelData.id
                                settings: root.pluginSettings(row.modelData)
                            }

                            // Custom settings surface, in its own
                            // detail tab alongside (never replacing)
                            // the generated Settings tab above: loaded
                            // only while that tab is open, for an
                            // enabled installed plugin declaring an
                            // enabled settings surface.
                            PluginSettingsHost {
                                Layout.fillWidth: true
                                visible: root.customSettingsPluginId === row.modelData.id && root.hasSettingsSurface(row.modelData)
                                pluginId: row.modelData.id
                                entrypoint: root.settingsSurfaceEntrypoint(row.modelData)
                            }

                            Repeater {
                                model: row.modelData.placement === "desktop" ? Quickshell.screens : []

                                delegate: DesktopWidgetPosition {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    pluginId: row.modelData.id
                                    screenName: modelData.name
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.spacing.small
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: root.expandedPluginId === row.modelData.id ? qsTr("Hide details") : qsTr("Details")
                                    type: TextButton.Text
                                    onClicked: root.expandedPluginId = root.expandedPluginId === row.modelData.id ? "" : row.modelData.id
                                }

                                TextButton {
                                    visible: root.hasPluginSettings(row.modelData)
                                    text: root.settingsPluginId === row.modelData.id ? qsTr("Hide settings") : qsTr("Settings")
                                    type: TextButton.Text
                                    onClicked: root.settingsPluginId = root.settingsPluginId === row.modelData.id ? "" : row.modelData.id
                                }

                                TextButton {
                                    visible: root.hasSettingsSurface(row.modelData)
                                    text: root.customSettingsPluginId === row.modelData.id ? qsTr("Hide custom settings") : qsTr("Custom settings")
                                    type: TextButton.Text
                                    onClicked: root.customSettingsPluginId = root.customSettingsPluginId === row.modelData.id ? "" : row.modelData.id
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                TextButton {
                                    visible: !row.modelData.enabled && (["untrusted", "stale-trust", "modified", "unverified"].includes(row.modelData.trust)) && root.pendingTrust !== row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Trust…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingTrust = row.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Confirm trust")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("trust", row.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingTrust = ""
                                }

                                TextButton {
                                    visible: !row.modelData.enabled && !row.modelData.requestedEnabled && root.pendingEnable !== row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Enable…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingEnable = row.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Confirm enable")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("enable", row.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingEnable = ""
                                }

                                TextButton {
                                    visible: row.modelData.enabled && !Plugins.safeMode
                                    text: qsTr("Reload")
                                    type: TextButton.Tonal
                                    onClicked: Plugins.reloadPlugin(row.modelData.id)
                                }

                                TextButton {
                                    visible: row.modelData.enabled || row.modelData.requestedEnabled
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Disable")
                                    type: TextButton.Tonal
                                    onClicked: root.runLifecycle("disable", row.modelData.id)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: qsTr("Official catalogue — HorneroOS/plugins")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Official extensions from HorneroOS/plugins. Installing copies hash-verified, pinned data but does not run it. Enabling is a separate confirmed step. Capability lists describe plugin declarations; they do not restrict what QML can do.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogRevision.length > 0
                    text: qsTr("Catalogue revision: %1").arg(root.catalogRevision)
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                SearchBar {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search official extensions")
                    Accessible.name: qsTr("Search official extensions")
                    text: root.catalogSearch
                    onTextChanged: root.catalogSearch = text
                }

                TextButton {
                    text: qsTr("Refresh catalogue")
                    type: TextButton.Tonal
                    enabled: !catalogProc.running
                    onClicked: root.refreshCatalog()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogError.length > 0
                    text: root.catalogError
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogEntries.length > 0 && root.filteredCatalogEntries().length === 0
                    text: qsTr("No official extensions match this search.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.filteredCatalogEntries()

                    delegate: StyledRect {
                        id: catRow

                        required property var modelData

                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        color: Signal.layer(Signal.palette.panel, 1)
                        implicitHeight: catCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: catCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: `${catRow.modelData.name} ${catRow.modelData.version} · ${catRow.modelData.trust}`
                                font.weight: 500
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                ExtensionChip {
                                    readonly property var kit: root.kitStatus(catRow.modelData)
                                    label: kit.label
                                    tone: kit.tone
                                    icon: kit.icon
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: qsTr("Compatibility: %1").arg(kit.label)
                                }

                                ExtensionChip {
                                    visible: root.maturityLabel(catRow.modelData).length > 0
                                    label: root.maturityLabel(catRow.modelData)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: catRow.modelData.description || qsTr("No description provided.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.ink
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("By %1 · %2 · %3 · %4")
                                    .arg(catRow.modelData.author || qsTr("Unknown author"))
                                    .arg(catRow.modelData.license || qsTr("License not listed"))
                                    .arg(catRow.modelData.category || qsTr("Uncategorized"))
                                    .arg(catRow.modelData.placement || qsTr("Placement not listed"))
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.declaredCapabilities(catRow.modelData.capabilities)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            // Marketplace detail (shell#379):
                            // deprecation blocks new installs below,
                            // screenshots are plain Images from the
                            // installed package when present (never a
                            // loaded entrypoint), and rollback stays
                            // gated by rollback_available only.
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.isDeprecated(catRow.modelData)
                                text: `${root.deprecationText(catRow.modelData)}\n${qsTr("New installs of a deprecated extension are disabled.")}`
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: root.screenshotSources(catRow.modelData)

                                delegate: Image {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 180
                                    source: modelData.source
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    Accessible.role: Accessible.Graphic
                                    Accessible.name: modelData.alt
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.screenshotSources(catRow.modelData).length === 0 && root.screenshotCaptions(catRow.modelData).length > 0
                                text: root.screenshotCaptions(catRow.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.compatibilityText(catRow.modelData).length > 0
                                text: root.compatibilityText(catRow.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.changelogText(catRow.modelData).length > 0
                                text: root.changelogText(catRow.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.permissionExplanations(catRow.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: root.replacedById(catRow.modelData).length > 0
                                    text: qsTr("View replacement: %1").arg(root.replacedById(catRow.modelData))
                                    type: TextButton.Text
                                    onClicked: root.openReplacement(root.replacedById(catRow.modelData))
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && root.installedEntry(catRow.modelData.id) && root.hasPluginSettings(root.installedEntry(catRow.modelData.id))
                                    text: qsTr("Settings")
                                    type: TextButton.Text
                                    onClicked: {
                                        root.pluginSearch = catRow.modelData.id;
                                        root.settingsPluginId = catRow.modelData.id;
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Source: %1\nPayload SHA-256: %2\nPlugin snapshot: %3")
                                    .arg(catRow.modelData.homepage || qsTr("Not listed"))
                                    .arg(catRow.modelData.sha256 || qsTr("Not listed"))
                                    .arg(catRow.modelData.generatedFrom || qsTr("Not listed"))
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("%1 · %2 · %3").arg(catRow.modelData.category || "").arg(catRow.modelData.placement || "").arg(catRow.modelData.state || "")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: catRow.modelData.state !== "installed" && !root.isDeprecated(catRow.modelData) && root.pendingInstall !== catRow.modelData.id
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Install…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingInstall = catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id && !root.isDeprecated(catRow.modelData)
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Confirm install")
                                    type: TextButton.Filled
                                    onClicked: {
                                        root.runCatalogAction("install", catRow.modelData.id);
                                    }
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingInstall = ""
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && root.pendingCatalogAction !== "update:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Update…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "update:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running && root.catalogRevision.length > 0
                                    text: qsTr("Confirm update")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("update", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && catRow.modelData.rollback_available && root.pendingCatalogAction !== "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Roll back…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "rollback:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: catRow.modelData.rollback_available && root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Confirm rollback")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("rollback", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id || root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !catalogInstallProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = ""
                                }

                                StyledText {
                                    visible: catRow.modelData.state === "installed"
                                    text: qsTr("Installed — enable it in the list above")
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }
                        }
                    }
                }

                CommunityRegistrySection {
                    Layout.fillWidth: true
                }
            }
        }
    }

    component ExtensionChip: StyledRect {
        id: chip

        property string label
        property string icon: ""
        property string tone: "neutral"
        readonly property color fg: chip.tone === "good" ? Signal.palette.phosphor : chip.tone === "bad" ? Signal.palette.alert : Signal.palette.inkMuted

        implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: chipRow.implicitHeight + Appearance.padding.small
        radius: Appearance.rounding.small
        color: chip.tone === "neutral" ? Signal.tPalette.lifted : Qt.alpha(chip.fg, 0.14)
        border.width: 1
        border.color: chip.tone === "neutral" ? Signal.palette.rule : Qt.alpha(chip.fg, 0.5)

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small / 2

            Glyph {
                visible: chip.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                color: chip.fg
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.fg
                font.pointSize: Appearance.font.size.small
                font.weight: 500
            }
        }
    }

    component FilterChip: StyledRect {
        id: fchip

        property string label
        property string icon: ""
        property bool selected
        signal activated

        implicitWidth: fchipRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: fchipRow.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.small
        color: fchip.selected ? Signal.palette.signalWell : "transparent"
        border.width: fchip.selected ? 0 : 1
        border.color: Signal.palette.rule

        Accessible.role: Accessible.CheckBox
        Accessible.name: fchip.label
        Accessible.checked: fchip.selected

        Interactive {
            radius: fchip.radius
            color: fchip.selected ? Signal.palette.onSignalWell : Signal.palette.ink
            function onClicked(): void {
                fchip.activated();
            }
        }

        Row {
            id: fchipRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small / 2

            Glyph {
                visible: fchip.selected || fchip.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                name: fchip.selected ? "check" : fchip.icon
                color: fchip.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: fchip.label
                color: fchip.selected ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                font.weight: 500
            }
        }
    }
}
