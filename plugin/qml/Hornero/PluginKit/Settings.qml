import qs.config
import qs.services
import Quickshell.Io
import QtQuick

JsonObject {
    id: root

    property string pluginId: ""
    // Per-instance settings (RFC 0003 section 6): bind this to the host
    // context property `hostInstanceId` of the widget root. Empty (the
    // default) is the primary instance and reads/writes exactly what it
    // always did; a non-empty id reads and writes that instance's own
    // values, still validated against the plugin's declarations.
    property string instanceId: ""
    readonly property string namespaceKey: instanceId !== "" ? `${pluginId}#${instanceId}` : pluginId

    // Emitted whenever a setting in this plugin's namespace changes (via
    // setValue, resetValue, resetAll, Control Center, or config reload).
    signal changed(string key, var value)

    property var _lastValues: ({})

    function _snapshotNamespace(): var {
        const storedSettings = Config.plugins.settings;
        const storedPlugins = storedSettings && typeof storedSettings === "object" && !Array.isArray(storedSettings) ? storedSettings : null;
        const candidateValues = storedPlugins && namespaceKey !== "" ? storedPlugins[namespaceKey] : null;
        if (!candidateValues || typeof candidateValues !== "object" || Array.isArray(candidateValues))
            return ({});
        return JSON.parse(JSON.stringify(candidateValues));
    }

    function _diffAndEmit(): void {
        const prev = root._lastValues && typeof root._lastValues === "object" ? root._lastValues : ({});
        const next = root._snapshotNamespace();
        root._lastValues = next;
        const keys = new Set([...Object.keys(prev), ...Object.keys(next)]);
        for (const key of keys) {
            if (JSON.stringify(prev[key]) !== JSON.stringify(next[key]))
                root.changed(key, root.value(key, undefined));
        }
    }

    Component.onCompleted: _lastValues = _snapshotNamespace()
    onNamespaceKeyChanged: _lastValues = _snapshotNamespace()

    readonly property Connections _settingsWatcher: Connections {
        target: Config.plugins

        function onSettingsChanged(): void {
            root._diffAndEmit();
        }
    }

    function value(key: string, fallback: var): var {
        if (!validKey(key))
            return fallback;

        const declaration = Plugins.settingDeclaration(pluginId, key);
        if (!declaration)
            return fallback;

        const storedSettings = Config.plugins.settings;
        const storedPlugins = storedSettings && typeof storedSettings === "object" && !Array.isArray(storedSettings) ? storedSettings : null;
        const candidateValues = storedPlugins ? storedPlugins[namespaceKey] : null;
        const values = candidateValues && typeof candidateValues === "object" && !Array.isArray(candidateValues) ? candidateValues : null;
        const stored = values && Object.prototype.hasOwnProperty.call(values, key) ? values[key] : undefined;
        // Migration (shell#374): a stored value that no longer
        // satisfies the current declaration (changed type, removed
        // enum option, tightened constraints) reads as the declared
        // default instead of being coerced or crashing the plugin.
        return Plugins.migratedSettingValue(declaration, stored);
    }

    function setValue(key: string, value: var): bool {
        if (!validKey(key))
            return false;

        const declaration = Plugins.settingDeclaration(pluginId, key);
        if (!declaration || !validForDeclaration(value, declaration))
            return false;

        return Config.plugins.setSetting(namespaceKey, key, value);
    }

    // Reset (shell#374): removes the stored value so reads return
    // the declared default again. Storage stays Shell-owned through
    // Config.plugins, exactly like setValue.
    function resetValue(key: string): bool {
        if (!validKey(key) || !Plugins.settingDeclaration(pluginId, key))
            return false;

        return Config.plugins.resetSetting(namespaceKey, key);
    }

    function resetAll(): bool {
        return Config.plugins.resetSettings(namespaceKey);
    }

    function validForDeclaration(value: var, declaration: var): bool {
        return validValue(value, declaration.type) && Plugins.settingConstraintsSatisfied(value, declaration);
    }

    function validKey(key: string): bool {
        return /^[a-z][a-zA-Z0-9]{0,47}$/.test(key);
    }

    function validValue(value: var, type: string): bool {
        if (type === "boolean")
            return typeof value === "boolean";
        if (type === "integer")
            return typeof value === "number" && Number.isInteger(value);
        if (type === "number")
            return typeof value === "number" && Number.isFinite(value);
        if (type === "string" || type === "text")
            return typeof value === "string" && value.length <= 4096;
        if (type === "enum")
            return typeof value === "string" && value.length <= 4096;
        if (type === "colour")
            return typeof value === "string" && value.length <= 9;
        if (type === "path")
            return typeof value === "string" && value.length <= 1024;
        if (type === "list" || type === "strings")
            return Array.isArray(value) && value.length <= 32;
        return false;
    }
}
