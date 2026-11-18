pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import "../../../services/extensionstore.js" as Store
import qs.components
import qs.modules.plugins
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

// Control Center › Extensions: browse the official catalogue, install,
// update, roll back, remove, trust, enable and disable extensions.
// horneroctl stays the single writer of plugin lifecycle state: this
// pane never writes receipts or payloads itself. Every verb goes through
// ExtensionStore, which runs the documented `horneroctl --json plugin …
// --yes` argv asynchronously, one at a time, and re-reads state through
// the Plugins service. Each verb is a command without an inverse (it
// copies, runs or deletes code), so each keeps a two-step guard: the
// first click shows what will happen in plain language, the second runs
// it (Control Center apply policy, docs/CONTROL-CENTER-APPLY.md).
Item {
    id: root

    required property Session session

    property string pendingEnable: ""
    property string pendingTrust: ""
    property string pendingInstall: ""
    // "update:<id>", "rollback:<id>" or "remove:<id>" while that verb's
    // first step (the consent text) is showing.
    property string pendingCatalogAction: ""
    readonly property var catalogEntries: ExtensionStore.catalogue
    readonly property string catalogError: ExtensionStore.catalogueError
    readonly property string catalogRevision: ExtensionStore.catalogueRevision
    property string catalogSearch: ""
    readonly property bool es: Config.plugins.storeSpanish()
    property string pluginSearch: ""
    property string pluginTrustFilter: "all"
    property string pluginPlacementFilter: "all"
    property string expandedPluginId: ""
    property string expandedCatalogId: ""
    property string settingsPluginId: ""
    property string customSettingsPluginId: ""
    // Open extension panel ("<pluginId>:<panelId>"), one at a time.
    property string openPanelKey: ""

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
        const providers = Array.isArray(declared.providers) ? declared.providers : [];
        const settings = declared.settings && typeof declared.settings === "object" ? declared.settings : {};
        const keys = Object.keys(settings).sort();
        // Names and types only: the full declaration (defaults, bounds,
        // descriptions) is in Details and the plugin's own settings UI.
        const settingsSummary = keys.length === 0 ? "" : keys.map(key => `${key} (${settings[key] && settings[key].type ? settings[key].type : "?"})`).join(", ");
        const provenance = verified === false
            ? qsTr("What the manifest says it uses (unverified, not enforced)")
            : qsTr("What the extension says it uses (not enforced)");
        return qsTr("%1\nCommands it may run: %2\nNetwork hosts: %3\nShared data it reads: %4\nSettings it stores: %5")
            .arg(provenance)
            .arg(commands.length ? commands.join(", ") : qsTr("none"))
            .arg(hosts.length ? hosts.join(", ") : qsTr("none"))
            .arg(providers.length ? providers.join(", ") : qsTr("none"))
            .arg(settingsSummary || qsTr("none"));
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
            return { "label": entry?.pluginKit >= 4 ? qsTr("PluginKit 4") : qsTr("PluginKit 3"), "tone": "good", "icon": "circle-check" };
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
        ExtensionStore.refreshCatalogue();
    }

    function nameOf(pluginId): string {
        const entry = root.installedEntry(pluginId) || ExtensionStore.entry(pluginId);
        return entry ? String(entry.name || pluginId) : pluginId;
    }

    // Second (confirming) step of a guarded catalogue verb: install,
    // update and roll back. Install and update pin the catalogue revision
    // the person was reading (ExtensionStore passes --revision), so a
    // catalogue that changed in between is refused, never applied.
    function runCatalogAction(action, pluginId) {
        root.pendingInstall = "";
        root.pendingCatalogAction = "";
        ExtensionStore.run(action, pluginId, root.nameOf(pluginId));
    }

    // Second step of a guarded lifecycle verb: enable, disable, trust,
    // remove.
    function runLifecycle(action, pluginId) {
        root.pendingEnable = "";
        root.pendingTrust = "";
        root.pendingCatalogAction = "";
        ExtensionStore.run(action, pluginId, root.nameOf(pluginId));
    }

    function catalogueEntryFor(pluginId): var {
        return ExtensionStore.entry(pluginId);
    }

    function outcomeText(pluginId): string {
        const o = ExtensionStore.outcome(pluginId);
        if (!o)
            return "";
        return [o.message, o.guidance].filter(Boolean).join("\n");
    }

    // Deep link from Control Center › Experience › Desktop widgets: the
    // section "plugin:<id>" opens that installed extension's details with
    // its generated settings already visible.
    function openRequestedPlugin(): void {
        const request = root.session.requestedSection;
        if (!request.startsWith("plugin:"))
            return;
        const id = request.slice(7);
        if (!root.installedEntry(id))
            return;
        root.pluginSearch = id;
        root.expandedPluginId = id;
        root.settingsPluginId = id;
        root.session.requestedSection = "";
    }

    Connections {
        target: root.session

        function onRequestedSectionChanged(): void {
            if (root.session.active === "extensions")
                root.openRequestedPlugin();
        }
    }

    Connections {
        target: Plugins

        function onEntriesChanged(): void {
            if (root.session.active === "extensions")
                root.openRequestedPlugin();
        }
    }

    Component.onCompleted: {
        if (Config.plugins.storeRefreshOnOpen && !ExtensionStore.catalogueLoading)
            root.refreshCatalog();
        root.openRequestedPlugin();
        Plugins.telemetryWatchers += 1;
    }

    Component.onDestruction: Plugins.telemetryWatchers = Math.max(0, Plugins.telemetryWatchers - 1)

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
                        font.weight: Appearance.font.weight.strong
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
                    visible: Plugins.desktopNoRoom.length > 0
                    text: qsTr("Hidden, no room on the desktop: %1. Move or resize other widgets (Edit widgets) to bring them back.")
                        .arg(Plugins.desktopNoRoom.map(id => (Plugins.entryFor(id)?.name ?? id)).join(", "))
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.kitBlocked
                    text: Plugins.kitMessage
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                // One verb at a time (ExtensionStore): the running verb,
                // its real steps and elapsed seconds. horneroctl does not
                // stream progress, so no percentage is invented.
                StoreProgress {
                    Layout.fillWidth: true
                    visible: ExtensionStore.busy
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.discovered && Plugins.entries.length === 0 && Plugins.discoveryError.length === 0
                    text: qsTr("No extensions installed yet. Browse the official catalogue below and install one; it stays off until you enable it.")
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

                // Rows are keyed by plugin id: a load-state update from any
                // plugin used to rebuild every row (scroll jumped to the top
                // and the list blanked while scrolling). The row reads its
                // live entry; the list is only rebuilt when the set of ids
                // changes.
                StableList {
                    id: rowIds

                    source: root.filteredPlugins().map(entry => entry.id)
                }

                Repeater {
                    model: rowIds.list

                    delegate: StyledRect {
                        id: row

                        required property var modelData
                        readonly property var entry: Plugins.entryFor(row.modelData) ?? ({})

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
                                    color: row.entry.enabled ? Signal.palette.signalWell : Signal.tPalette.lifted

                                    Glyph {
                                        anchors.centerIn: parent
                                        name: root.placementIcon(row.entry.placement)
                                        font.pointSize: Appearance.font.size.large
                                        color: row.entry.enabled ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Appearance.spacing.small

                                        StyledText {
                                            text: row.entry.name
                                            font.pointSize: Appearance.font.size.normal
                                            font.weight: Appearance.font.weight.strong
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: row.entry.version ? `v${row.entry.version}` : ""
                                            font.pointSize: Appearance.font.size.small
                                            color: Signal.palette.inkMuted
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: !!row.entry.description
                                        text: row.entry.description ?? ""
                                        font.pointSize: Appearance.font.size.small
                                        color: Signal.palette.inkMuted
                                        wrapMode: Text.Wrap
                                        maximumLineCount: root.expandedPluginId === row.entry.id ? 20 : 2
                                        elide: Text.ElideRight
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        Layout.topMargin: Appearance.spacing.small / 2
                                        spacing: Appearance.spacing.small

                                        ExtensionChip {
                                            label: Plugins.safeMode && row.entry.enabled ? qsTr("Safe mode") : !row.entry.enabled && !row.entry.requestedEnabled ? qsTr("Disabled") : row.entry.state === "loaded" ? qsTr("Loaded") : row.entry.state === "failed" ? qsTr("Failed") : row.entry.state === "blocked" ? qsTr("Blocked") : qsTr("Pending")
                                            tone: !row.entry.enabled && !row.entry.requestedEnabled ? "neutral" : row.entry.state === "loaded" ? "good" : row.entry.state === "failed" || row.entry.state === "blocked" ? "bad" : "neutral"
                                        }

                                        ExtensionChip {
                                            readonly property var kit: root.kitStatus(row.entry)
                                            label: kit.label
                                            tone: kit.tone
                                            icon: kit.icon
                                            Accessible.role: Accessible.StaticText
                                            Accessible.name: qsTr("Compatibility: %1").arg(kit.label)
                                        }

                                        ExtensionChip {
                                            visible: root.maturityLabel(row.entry).length > 0
                                            label: root.maturityLabel(row.entry)
                                        }

                                        ExtensionChip {
                                            visible: !!row.entry.placement
                                            label: root.placementLabel(row.entry.placement)
                                            icon: root.placementIcon(row.entry.placement)
                                        }

                                        ExtensionChip {
                                            label: root.trustLabel(row.entry.trust)
                                            Accessible.role: Accessible.StaticText
                                            Accessible.name: qsTr("Trust: %1").arg(row.entry.trust ?? qsTr("unknown"))
                                            icon: (["untrusted", "stale-trust", "modified", "unverified"].includes(row.entry.trust)) ? "alert-triangle" : "rosette-discount-check"
                                            tone: (["untrusted", "stale-trust", "modified", "unverified"].includes(row.entry.trust)) ? "bad" : "neutral"
                                        }

                                        ExtensionChip {
                                            readonly property var cat: root.catalogueEntryFor(row.entry.id)
                                            visible: !!cat && cat.update_available === true
                                            label: cat ? Store.updateText(cat, root.es) : ""
                                            icon: "download"
                                            tone: "good"
                                        }

                                        ExtensionChip {
                                            visible: Config.plugins.storeShowCost && typeof row.entry.loadMs === "number" && row.entry.loadMs >= 0
                                            label: Store.t("load", root.es, row.entry.loadMs)
                                            icon: "gauge"
                                            tone: (row.entry.diagnostics ?? []).includes("slow-load") ? "bad" : "neutral"
                                            Accessible.role: Accessible.StaticText
                                            Accessible.name: qsTr("Measured load time: %1 ms").arg(row.entry.loadMs)
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.entry.id && row.entry.source === "https://github.com/HorneroOS/plugins.git"
                                text: qsTr("Catalogue revision: %1\nExpected payload SHA-256: %2")
                                    .arg(row.entry.revision || qsTr("Not recorded"))
                                    .arg(row.entry.catalog_sha256 || qsTr("Not recorded"))
                                font.pointSize: Appearance.font.size.smaller
                                font.family: Appearance.font.family.mono
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WrapAnywhere
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.isDeprecated(row.entry)
                                text: root.deprecationText(row.entry)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            TextButton {
                                visible: root.replacedById(row.entry).length > 0
                                text: qsTr("View replacement: %1").arg(root.replacedById(row.entry))
                                type: TextButton.Text
                                onClicked: root.openReplacement(root.replacedById(row.entry))
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingTrust === row.entry.id
                                text: qsTr("You are trusting the exact code currently installed for this plugin. If its files change, you will be asked again. Trusting does not enable it.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!row.entry.detail
                                text: row.entry.detail ?? ""
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            // Result of the last verb run on this extension, inline
                            // where it was started: the CLI message plus what to do
                            // next for a known error code.
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.outcomeText(row.entry.id).length > 0
                                text: root.outcomeText(row.entry.id)
                                font.pointSize: Appearance.font.size.small
                                color: ExtensionStore.outcome(row.entry.id)?.ok ? Signal.palette.signal : Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: ExtensionStore.busy && ExtensionStore.job?.id === row.entry.id
                                text: ExtensionStore.progressText()
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            // First step of Update / Roll back / Remove: what the
                            // verb does, in plain language, before it runs.
                            StyledText {
                                Layout.fillWidth: true
                                readonly property string verb: root.pendingCatalogAction.endsWith(":" + row.entry.id) ? root.pendingCatalogAction.split(":")[0] : ""
                                visible: verb.length > 0
                                text: Store.consentText(verb, row.entry, root.es)
                                font.pointSize: Appearance.font.size.small
                                color: verb === "remove" ? Signal.palette.alert : Signal.palette.ink
                                wrapMode: Text.Wrap
                            }

                            // Enable consent: a short heading, one plain sentence about
                            // trust, then the declared uses. Alert colour is kept for
                            // the trust sentence only.
                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.spacing.small
                                visible: root.pendingEnable === row.entry.id
                                text: qsTr("Before you enable this extension")
                                font.pointSize: Appearance.font.size.normal
                                font.weight: Appearance.font.weight.strong
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingEnable === row.entry.id
                                text: qsTr("It runs as you, with no sandbox. Only enable extensions whose source you have read.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingEnable === row.entry.id
                                text: root.declaredCapabilities(row.entry.capabilities, row.entry.capabilities_verified)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                lineHeight: 1.25
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.entry.id
                                text: root.pluginDetail(row.entry)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            // Who vouches for the code, and what it costs: the
                            // measured load time and the measured cost of the
                            // shared data it reads. Own CPU and memory are not
                            // measurable per extension and say so.
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.entry.id
                                text: Store.signerText(row.entry, root.es)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.ink
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.entry.id && Config.plugins.storeShowCost
                                text: Store.costText(row.entry, Plugins.providerTelemetry, root.es)
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
                                visible: root.expandedPluginId === row.entry.id
                                spacing: Appearance.spacing.small

                                Repeater {
                                    model: root.screenshotSources(row.entry)

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
                                    visible: root.screenshotSources(row.entry).length === 0 && root.screenshotCaptions(row.entry).length > 0
                                    text: root.screenshotCaptions(row.entry)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.compatibilityText(row.entry).length > 0
                                    text: root.compatibilityText(row.entry)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.changelogText(row.entry).length > 0
                                    text: root.changelogText(row.entry)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.permissionExplanations(row.entry)
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }
                            }

                            // Signal deck widgets are arranged in Experience; this
                            // row only installs, enables and configures them.
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.expandedPluginId === row.entry.id && Experience.deckCatalogue.includes(row.entry.id)
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Shown on the desktop by the Signal deck. Turn it on or off, place it, resize it and restyle it in Experience.")
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                }

                                TextButton {
                                    text: qsTr("Managed in Experience")
                                    type: TextButton.Text
                                    onClicked: root.session.navigateTo("experience", "")
                                }
                            }

                            // Quick-setting tiles this extension offers (RFC
                            // 0003 section 4.3): off until the person adds
                            // them to the Utilities quick toggles.
                            Repeater {
                                model: root.expandedPluginId === row.entry.id && row.entry.enabled && row.entry.contributes ? row.entry.contributes.quickSettings : []

                                delegate: RowLayout {
                                    id: tileRow

                                    required property var modelData
                                    readonly property string tileKey: `${row.entry.id}:${modelData.id}`

                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Quick toggle: %1").arg(tileRow.modelData.title)
                                        wrapMode: Text.Wrap
                                    }

                                    StyledSwitch {
                                        Accessible.name: qsTr("Show %1 in the quick toggles").arg(tileRow.modelData.title)
                                        checked: Config.plugins.quickTilesList().includes(tileRow.tileKey)
                                        onToggled: Config.plugins.setQuickTile(tileRow.tileKey, checked)
                                    }
                                }
                            }

                            Repeater {
                                model: row.entry.enabled && row.entry.contributes ? row.entry.contributes.panels : []

                                delegate: PluginPanelHost {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    pluginId: row.entry.id
                                    panel: modelData
                                    open: root.openPanelKey === `${row.entry.id}:${modelData.id}`
                                    visible: open
                                }
                            }

                            PluginInstancesSection {
                                id: instancesSection

                                Layout.fillWidth: true
                                visible: root.settingsPluginId === row.entry.id && root.hasPluginSettings(row.entry) && instancesSection.supported
                                pluginId: row.entry.id
                            }

                            PluginPreviewFrame {
                                id: previewFrame

                                Layout.fillWidth: true
                                visible: root.settingsPluginId === row.entry.id && root.hasPluginSettings(row.entry) && previewFrame.shown
                                active: root.settingsPluginId === row.entry.id && root.hasPluginSettings(row.entry)
                                pluginId: row.entry.id
                                instanceId: instancesSection.supported ? instancesSection.selected : ""
                            }

                            PluginSettingsSection {
                                Layout.fillWidth: true
                                visible: root.settingsPluginId === row.entry.id && root.hasPluginSettings(row.entry)
                                pluginId: row.entry.id
                                storageKey: Config.plugins.instanceKey(row.entry.id, instancesSection.supported ? instancesSection.selected : "")
                                settings: root.pluginSettings(row.entry)
                            }

                            // Custom settings surface, in its own
                            // detail tab alongside (never replacing)
                            // the generated Settings tab above: loaded
                            // only while that tab is open, for an
                            // enabled installed plugin declaring an
                            // enabled settings surface.
                            PluginSettingsHost {
                                Layout.fillWidth: true
                                visible: root.customSettingsPluginId === row.entry.id && root.hasSettingsSurface(row.entry)
                                pluginId: row.entry.id
                                entrypoint: root.settingsSurfaceEntrypoint(row.entry)
                            }

                            Repeater {
                                model: row.entry.placement === "desktop" ? Quickshell.screens : []

                                delegate: DesktopWidgetPosition {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    pluginId: row.entry.id
                                    screenName: modelData.name
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.spacing.small
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: root.expandedPluginId === row.entry.id ? qsTr("Hide details") : qsTr("Details")
                                    type: TextButton.Text
                                    onClicked: root.expandedPluginId = root.expandedPluginId === row.entry.id ? "" : row.entry.id
                                }

                                TextButton {
                                    visible: root.hasPluginSettings(row.entry)
                                    text: root.settingsPluginId === row.entry.id ? qsTr("Hide settings") : qsTr("Settings")
                                    type: TextButton.Text
                                    onClicked: root.settingsPluginId = root.settingsPluginId === row.entry.id ? "" : row.entry.id
                                }

                                Repeater {
                                    model: row.entry.enabled && row.entry.contributes ? row.entry.contributes.panels : []

                                    delegate: TextButton {
                                        required property var modelData
                                        readonly property string panelKey: `${row.entry.id}:${modelData.id}`

                                        text: root.openPanelKey === panelKey ? qsTr("Close %1").arg(modelData.title) : modelData.title
                                        type: TextButton.Text
                                        onClicked: root.openPanelKey = root.openPanelKey === panelKey ? "" : panelKey
                                    }
                                }

                                TextButton {
                                    visible: root.hasSettingsSurface(row.entry)
                                    text: root.customSettingsPluginId === row.entry.id ? qsTr("Hide custom settings") : qsTr("Custom settings")
                                    type: TextButton.Text
                                    onClicked: root.customSettingsPluginId = root.customSettingsPluginId === row.entry.id ? "" : row.entry.id
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                TextButton {
                                    visible: !row.entry.enabled && (["untrusted", "stale-trust", "modified", "unverified"].includes(row.entry.trust)) && root.pendingTrust !== row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Trust…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.pendingTrust = row.entry.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Confirm trust")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("trust", row.entry.id)
                                }

                                TextButton {
                                    visible: root.pendingTrust === row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingTrust = ""
                                }

                                TextButton {
                                    visible: !row.entry.enabled && !row.entry.requestedEnabled && root.pendingEnable !== row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Enable…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.pendingEnable = row.entry.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Confirm enable")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("enable", row.entry.id)
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingEnable = ""
                                }

                                TextButton {
                                    readonly property var cat: root.catalogueEntryFor(row.entry.id)
                                    visible: !!cat && cat.update_available === true && root.pendingCatalogAction !== "update:" + row.entry.id
                                    enabled: !ExtensionStore.busy && root.catalogRevision.length > 0
                                    text: qsTr("Update…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "update:" + row.entry.id
                                }

                                TextButton {
                                    visible: row.entry.rollback_available === true && root.pendingCatalogAction !== "rollback:" + row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Roll back…")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = "rollback:" + row.entry.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction !== "remove:" + row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Remove…")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = "remove:" + row.entry.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + row.entry.id
                                    enabled: !ExtensionStore.busy && root.catalogRevision.length > 0
                                    text: qsTr("Confirm update")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("update", row.entry.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "rollback:" + row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Confirm rollback")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("rollback", row.entry.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "remove:" + row.entry.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Confirm remove")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("remove", row.entry.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction.endsWith(":" + row.entry.id)
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = ""
                                }

                                TextButton {
                                    visible: row.entry.enabled && !Plugins.safeMode
                                    text: qsTr("Reload")
                                    type: TextButton.Tonal
                                    onClicked: Plugins.reloadPlugin(row.entry.id)
                                }

                                TextButton {
                                    visible: row.entry.enabled || row.entry.requestedEnabled
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Disable")
                                    type: TextButton.Tonal
                                    onClicked: root.runLifecycle("disable", row.entry.id)
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: qsTr("Official catalogue — HorneroOS/plugins")
                    font.pointSize: Appearance.font.size.large
                    font.weight: Appearance.font.weight.medium
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    TextButton {
                        text: ExtensionStore.catalogueLoading ? qsTr("Refreshing catalogue…") : qsTr("Refresh catalogue")
                        type: TextButton.Tonal
                        enabled: !ExtensionStore.catalogueLoading
                        onClicked: root.refreshCatalog()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: qsTr("Fetch on open")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    StyledSwitch {
                        Accessible.name: qsTr("Fetch the catalogue when this pane opens")
                        checked: Config.plugins.storeRefreshOnOpen
                        onToggled: Config.plugins.setStoreOption("storeRefreshOnOpen", checked)
                    }

                    StyledText {
                        text: qsTr("Show cost")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    StyledSwitch {
                        Accessible.name: qsTr("Show measured extension cost")
                        checked: Config.plugins.storeShowCost
                        onToggled: Config.plugins.setStoreOption("storeShowCost", checked)
                    }
                }

                // Language of the store's own lines (permissions, consent,
                // guidance, cost): system locale by default.
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Store language")
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                    }

                    Repeater {
                        model: Config.plugins.allowedStoreLanguages

                        delegate: FilterChip {
                            required property var modelData

                            label: modelData === "auto" ? qsTr("System") : modelData === "es" ? "Español" : "English"
                            selected: Config.plugins.storeLanguage === modelData
                            onActivated: Config.plugins.setStoreOption("storeLanguage", modelData)
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !ExtensionStore.catalogueLoaded && !ExtensionStore.catalogueLoading && root.catalogError.length === 0
                    text: qsTr("The catalogue is not loaded. Refresh catalogue fetches it from HorneroOS/plugins.")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.catalogError.length > 0
                    text: [root.catalogError, Store.guidance(ExtensionStore.catalogueErrorCode, root.es)].filter(Boolean).join("\n")
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
                        readonly property string rowState: Store.rowState(catRow.modelData, root.installedEntry(catRow.modelData.id))
                        readonly property bool installed: catRow.rowState !== "available"
                        readonly property bool expanded: root.expandedCatalogId === catRow.modelData.id

                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        color: Signal.layer(Signal.palette.panel, 1)
                        implicitHeight: catCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: catCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    text: catRow.modelData.name
                                    font.weight: Appearance.font.weight.medium
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: `v${catRow.modelData.version}`
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                ExtensionChip {
                                    label: catRow.rowState === "update" ? Store.updateText(catRow.modelData, root.es) : catRow.rowState === "installed" ? Store.t("installed", root.es) : Store.t("available", root.es)
                                    icon: catRow.rowState === "update" ? "download" : catRow.rowState === "installed" ? "circle-check" : ""
                                    tone: catRow.rowState === "available" ? "neutral" : "good"
                                }

                                ExtensionChip {
                                    label: root.trustLabel(catRow.modelData.trust)
                                    icon: "rosette-discount-check"
                                }

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

                                ExtensionChip {
                                    visible: !!catRow.modelData.placement
                                    label: root.placementLabel(catRow.modelData.placement)
                                    icon: root.placementIcon(catRow.modelData.placement)
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
                                text: qsTr("By %1 · %2 · %3")
                                    .arg(catRow.modelData.author || qsTr("Unknown author"))
                                    .arg(catRow.modelData.license || qsTr("License not listed"))
                                    .arg(catRow.modelData.category || qsTr("Uncategorized"))
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Store.signerText(catRow.modelData, root.es)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.ink
                                wrapMode: Text.Wrap
                            }

                            // Marketplace detail (shell#379): deprecation blocks new
                            // installs below; screenshots are plain Images of local
                            // files horneroctl hash-verified (never a URL, never a
                            // loaded entrypoint); rollback stays gated by
                            // rollback_available only.
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.isDeprecated(catRow.modelData)
                                text: `${root.deprecationText(catRow.modelData)}\n${qsTr("New installs of a deprecated extension are disabled.")}`
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small
                                visible: Store.screenshotSources(catRow.modelData, Plugins.pluginsDir, catRow.installed).length > 0

                                Repeater {
                                    model: Store.screenshotSources(catRow.modelData, Plugins.pluginsDir, catRow.installed).slice(0, catRow.expanded ? 6 : 1)

                                    delegate: Image {
                                        required property var modelData

                                        width: Math.min(catCol.width, 360)
                                        height: 180
                                        source: modelData.source
                                        sourceSize.width: 720
                                        fillMode: Image.PreserveAspectFit
                                        horizontalAlignment: Image.AlignLeft
                                        asynchronous: true
                                        Accessible.role: Accessible.Graphic
                                        Accessible.name: modelData.alt
                                    }
                                }
                            }

                            // What it declares it uses, in plain language and in
                            // the store language: curated reasons from the
                            // catalogue for programs and network hosts.
                            StyledText {
                                Layout.fillWidth: true
                                text: Store.t("declares", root.es)
                                font.pointSize: Appearance.font.size.small
                                font.weight: Appearance.font.weight.medium
                            }

                            Repeater {
                                model: Store.permissionLines(catRow.modelData, root.es)

                                delegate: RowLayout {
                                    id: permRow

                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    Glyph {
                                        Layout.alignment: Qt.AlignTop
                                        name: permRow.modelData.kind === "program" ? "terminal" : permRow.modelData.kind === "network" ? "world" : permRow.modelData.kind === "settings" ? "settings" : permRow.modelData.kind === "action" ? "bolt" : "chart-bar"
                                        color: permRow.modelData.kind === "program" || permRow.modelData.kind === "network" ? Signal.palette.alert : Signal.palette.inkMuted
                                        font.pointSize: Appearance.font.size.small
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: permRow.modelData.text
                                        font.pointSize: Appearance.font.size.small
                                        color: Signal.palette.inkMuted
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: Store.permissionLines(catRow.modelData, root.es).length === 0
                                text: Store.t("declaresNothing", root.es)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            // Version history from the catalogue: the newest entry
                            // always, the rest with More.
                            Repeater {
                                model: Store.changelog(catRow.modelData, catRow.expanded ? 20 : 1)

                                delegate: StyledText {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    text: `${modelData.version} · ${modelData.notes}`
                                    font.pointSize: Appearance.font.size.small
                                    color: Signal.palette.inkMuted
                                    wrapMode: Text.Wrap
                                    maximumLineCount: catRow.expanded ? 8 : 2
                                    elide: Text.ElideRight
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: catRow.expanded && root.compatibilityText(catRow.modelData).length > 0
                                text: root.compatibilityText(catRow.modelData)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: catRow.expanded
                                text: root.declaredCapabilities(catRow.modelData.capabilities)
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: catRow.expanded
                                text: qsTr("Source: %1\nPayload SHA-256: %2\nPlugin snapshot: %3")
                                    .arg(catRow.modelData.homepage || qsTr("Not listed"))
                                    .arg(catRow.modelData.sha256 || qsTr("Not listed"))
                                    .arg(catRow.modelData.generatedFrom || qsTr("Not listed"))
                                font.pointSize: Appearance.font.size.smaller
                                font.family: Appearance.font.family.mono
                                color: Signal.palette.inkMuted
                                wrapMode: Text.WrapAnywhere
                            }

                            // First step of Install / Update / Roll back: the
                            // consent text. Installing code is a command with
                            // consequences, so it is never one click.
                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.spacing.small
                                visible: root.pendingInstall === catRow.modelData.id
                                text: Store.t("beforeInstall", root.es, catRow.modelData.name)
                                font.pointSize: Appearance.font.size.normal
                                font.weight: Appearance.font.weight.strong
                            }

                            StyledText {
                                Layout.fillWidth: true
                                readonly property string verb: root.pendingInstall === catRow.modelData.id ? "install" : root.pendingCatalogAction === "update:" + catRow.modelData.id ? "update" : root.pendingCatalogAction === "rollback:" + catRow.modelData.id ? "rollback" : ""
                                visible: verb.length > 0
                                text: Store.consentText(verb, catRow.modelData, root.es) + (verb === "install" && Store.hasProgramsOrNetwork(catRow.modelData) ? "\n" + Store.t("checkDeclared", root.es) : "")
                                font.pointSize: Appearance.font.size.small
                                color: verb === "install" ? Signal.palette.alert : Signal.palette.ink
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.outcomeText(catRow.modelData.id).length > 0
                                text: root.outcomeText(catRow.modelData.id)
                                font.pointSize: Appearance.font.size.small
                                color: ExtensionStore.outcome(catRow.modelData.id)?.ok ? Signal.palette.signal : Signal.palette.alert
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: ExtensionStore.busy && ExtensionStore.job?.id === catRow.modelData.id
                                text: ExtensionStore.progressText()
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: catRow.expanded ? qsTr("Less") : qsTr("More")
                                    type: TextButton.Text
                                    onClicked: root.expandedCatalogId = catRow.expanded ? "" : catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.replacedById(catRow.modelData).length > 0
                                    text: qsTr("View replacement: %1").arg(root.replacedById(catRow.modelData))
                                    type: TextButton.Text
                                    onClicked: root.openReplacement(root.replacedById(catRow.modelData))
                                }

                                TextButton {
                                    visible: catRow.installed && root.installedEntry(catRow.modelData.id) && root.hasPluginSettings(root.installedEntry(catRow.modelData.id))
                                    text: qsTr("Settings")
                                    type: TextButton.Text
                                    onClicked: {
                                        root.pluginSearch = catRow.modelData.id;
                                        root.settingsPluginId = catRow.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: catRow.modelData.state !== "installed" && !root.isDeprecated(catRow.modelData) && root.pendingInstall !== catRow.modelData.id
                                    enabled: !ExtensionStore.busy && root.catalogRevision.length > 0
                                    text: qsTr("Install…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingInstall = catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id && !root.isDeprecated(catRow.modelData)
                                    enabled: !ExtensionStore.busy && root.catalogRevision.length > 0
                                    text: qsTr("Confirm install")
                                    type: TextButton.Filled
                                    onClicked: {
                                        root.runCatalogAction("install", catRow.modelData.id);
                                    }
                                }

                                TextButton {
                                    visible: root.pendingInstall === catRow.modelData.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingInstall = ""
                                }

                                TextButton {
                                    visible: catRow.rowState === "update" && root.pendingCatalogAction !== "update:" + catRow.modelData.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Update…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "update:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id
                                    enabled: !ExtensionStore.busy && root.catalogRevision.length > 0
                                    text: qsTr("Confirm update")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("update", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: catRow.modelData.state === "installed" && catRow.modelData.rollback_available && root.pendingCatalogAction !== "rollback:" + catRow.modelData.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Roll back…")
                                    type: TextButton.Tonal
                                    onClicked: root.pendingCatalogAction = "rollback:" + catRow.modelData.id
                                }

                                TextButton {
                                    visible: catRow.modelData.rollback_available && root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Confirm rollback")
                                    type: TextButton.Filled
                                    onClicked: root.runCatalogAction("rollback", catRow.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingCatalogAction === "update:" + catRow.modelData.id || root.pendingCatalogAction === "rollback:" + catRow.modelData.id
                                    enabled: !ExtensionStore.busy
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingCatalogAction = ""
                                }

                                StyledText {
                                    visible: catRow.installed && !(root.installedEntry(catRow.modelData.id)?.enabled ?? false)
                                    text: Store.t("installedOff", root.es)
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

    // Store progress strip: the running verb, its real steps and elapsed
    // seconds, announced politely to assistive technology.
    component StoreProgress: StyledRect {
        implicitHeight: progressRow.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.small
        color: Qt.alpha(Signal.palette.signal, 0.10)
        border.width: 1
        border.color: Qt.alpha(Signal.palette.signal, 0.45)

        Accessible.role: Accessible.StatusBar
        Accessible.name: ExtensionStore.progressText()

        RowLayout {
            id: progressRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            Glyph {
                name: "refresh"
                color: Signal.palette.signal
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: ExtensionStore.progressText()
                font.pointSize: Appearance.font.size.small
                color: Signal.palette.ink
                wrapMode: Text.Wrap
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
                font.weight: Appearance.font.weight.medium
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
                font.weight: Appearance.font.weight.medium
            }
        }
    }
}
