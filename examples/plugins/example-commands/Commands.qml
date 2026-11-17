import QtQuick
import Hornero.PluginKit

// Commands surface (PluginKit 4, RFC 0003 section 4.2): the shell lists the
// commands from manifest.json without running this file, and loads it on the
// first invocation (launcher `>do`, or `qs ipc call plugincommands run
// example-commands greet Ada`). run() returns an empty string on success or
// a short error.
Item {
    Settings {
        id: pluginSettings

        pluginId: "example-commands"
    }

    function run(commandId: string, args: string): string {
        if (commandId === "greet") {
            const who = args.trim() !== "" ? args.trim() : "there";
            Notifications.toast(pluginSettings.value("greeting", "Hello"), who, "bolt");
            return "";
        }
        if (commandId === "remind") {
            Notifications.toast("Reminder", pluginSettings.value("reminder", "Stand up and stretch."), "bell");
            return "";
        }
        return "unknown command";
    }
}
