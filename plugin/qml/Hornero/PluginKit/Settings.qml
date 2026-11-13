import qs.config
import qs.services
import Quickshell.Io
import QtQuick

JsonObject {
    property string pluginId: ""

    function value(key: string, fallback: var): var {
        if (!validKey(key))
            return fallback;

        const declaration = Plugins.settingDeclaration(pluginId, key);
        if (!declaration)
            return fallback;

        const storedSettings = Config.plugins.settings;
        const storedPlugins = storedSettings && typeof storedSettings === "object" && !Array.isArray(storedSettings) ? storedSettings : null;
        const candidateValues = storedPlugins ? storedPlugins[pluginId] : null;
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

        return Config.plugins.setSetting(pluginId, key, value);
    }

    // Reset (shell#374): removes the stored value so reads return
    // the declared default again. Storage stays Shell-owned through
    // Config.plugins, exactly like setValue.
    function resetValue(key: string): bool {
        if (!validKey(key) || !Plugins.settingDeclaration(pluginId, key))
            return false;

        return Config.plugins.resetSetting(pluginId, key);
    }

    function resetAll(): bool {
        return Config.plugins.resetSettings(pluginId);
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
        if (type === "string")
            return typeof value === "string" && value.length <= 4096;
        if (type === "enum")
            return typeof value === "string" && value.length <= 4096;
        return false;
    }
}
