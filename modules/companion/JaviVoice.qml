pragma Singleton

import "javivoice.js" as Voice
import Quickshell
import QtQuick

// Javi's spoken lines in the user's language and tone. The catalogue and
// every rule live in javivoice.js (pure, tested under node); this singleton
// only binds it to the persisted voice preferences and the shell locale
// (the system locale the shell formats with; there is no separate shell
// language override). `language` and `tone` are Control Center settings:
// "auto" follows the locale, "es" and "en" pin it.
Singleton {
    id: root

    property string localeName: Qt.locale().name
    readonly property var settings: CompanionStore.voiceSettings
    readonly property string language: Voice.resolveLanguage(root.settings, root.localeName)

    // `key` -> line (see javivoice.js for the keys); `args` replace %1..%9.
    function line(key: string, args: var): string {
        return Voice.line(root.settings, root.localeName, key, args ?? []);
    }
}
