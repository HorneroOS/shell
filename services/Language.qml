pragma Singleton

import qs.config
import Hornero
import Quickshell
import QtQuick

// Shell UI language (docs/I18N.md). Source strings are English and are
// wrapped in qsTr(); catalogs live in <shell>/i18n/hornero_<locale>.ts.
// `Config.general.language` picks the language: "auto" follows the system
// UI languages, "en" or a catalog locale forces one. Changing it applies
// live: Translator installs the catalog and re-runs every qsTr() binding.
// Text that was assigned once (a toast already on screen, a notification
// body) keeps its language until it is shown again or the shell restarts.
// Dates, times and numbers keep following the system locale (LC_TIME,
// LC_NUMERIC); only the wording changes.
Singleton {
    id: root

    // False when the installed Hornero plugin predates the translator (a
    // source checkout running on an older package): the shell then stays
    // in English and the Language panel says why, instead of failing.
    readonly property bool available: typeof Translator !== "undefined"
    readonly property string directory: `${Quickshell.shellDir}/i18n`
    readonly property string setting: Config.general.language || "auto"

    // Language names are endonyms on purpose: someone who cannot read the
    // current language still finds their own.
    readonly property var names: ({
            "en": "English",
            "es_AR": "Español (Argentina)"
        })

    // Catalog the setting resolves to; "" is English (the source text).
    readonly property string resolved: root.available ? Translator.resolve(root.setting, root.directory) : ""
    // Catalog actually loaded; differs from `resolved` only when loading
    // failed (then `error` says why and the shell stays in English).
    readonly property string active: root.available ? Translator.language : ""
    readonly property string activeName: root.nameOf(root.active)
    // Locale name for text that does not go through qsTr() (Javi's
    // assistant copy and voice tables): the shell language, "en" for English.
    readonly property string uiLocale: root.active !== "" ? root.active : "en"
    readonly property string error: root.available ? Translator.error : qsTr("the installed Hornero plugin has no translator; update hornero-shell")
    readonly property string systemName: root.nameOf(root.available ? Translator.resolve("auto", root.directory) : "")

    readonly property var options: [
        {
            id: "auto",
            label: qsTr("Automatic (%1)").arg(root.systemName)
        },
        {
            id: "en",
            label: root.names["en"]
        },
        {
            id: "es_AR",
            label: root.names["es_AR"]
        }
    ]

    function nameOf(locale: string): string {
        return root.names[locale === "" ? "en" : locale] ?? locale;
    }

    function apply(): void {
        if (root.available)
            Translator.load(root.resolved, root.directory);
    }

    onResolvedChanged: root.apply()
    Component.onCompleted: root.apply()
}
