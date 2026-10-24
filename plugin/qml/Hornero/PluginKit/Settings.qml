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
        return validValue(stored, declaration.type) ? stored : declaration.default;
    }

    function setValue(key: string, value: var): bool {
        if (!validKey(key))
            return false;

        const declaration = Plugins.settingDeclaration(pluginId, key);
        if (!declaration || !validValue(value, declaration.type))
            return false;

        return Config.plugins.setSetting(pluginId, key, value);
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
        return false;
    }
}
