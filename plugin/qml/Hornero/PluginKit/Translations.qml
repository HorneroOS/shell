import qs.services
import Quickshell.Io
import QtQuick

// Per-plugin translations (shell#375). A package declares its catalogs
// in manifest.json:
//
//   "translations": {
//     "sourceLocale": "en",
//     "locales": ["es"],
//     "directory": "translations"
//   }
//
// and ships one flat JSON catalog per locale at
// `<directory>/<locale>.json`, mapping each source string (written in
// `sourceLocale`) to its translation, e.g.
// `{ "Example Clock": "Reloj de ejemplo" }`. Catalogs are plain JSON
// so they stay source-reviewable like the rest of the package; Qt
// Linguist .qm binaries are intentionally not the plugin format (the
// shell installs no QTranslator for plugins, so `qsTr()` in plugin
// code would silently never translate — the validator rejects it).
//
// Usage mirrors Settings:
//
//   Translations { id: i18n; pluginId: "example-clock" }
//   text: i18n.tr("Example Clock")
//   text: i18n.tr("%1 plugins loaded").arg(count)
//
// Locale selection follows the shell locale — the system locale the
// shell itself formats with (`Qt.locale()`, from LANG/LC_*; the shell
// has no separate language override today). Resolution tries the
// full locale first, then its language (`es_AR` -> `es`), then falls
// back to the source strings exactly as written in code. A missing or
// malformed catalog degrades to source strings; it never fails the
// plugin. `localeName` may be overridden (tests, a future shell
// language setting); plugins normally leave it alone.
//
// The pluginId, like Settings.pluginId, is a namespace selector into
// the host's recorded manifest declarations, not proof of identity
// and not an isolation boundary between extensions.
QtObject {
    id: root

    property string pluginId: ""
    // The locale to resolve catalogs for. Defaults to the system
    // (shell) locale name, e.g. "es_AR".
    property string localeName: Qt.locale().name

    // The manifest `translations` declaration recorded by the host,
    // or null when the package declares none (tr() is then always
    // the source string). Re-evaluates when discovery completes.
    readonly property var declaration: Plugins.translationDeclaration(pluginId)
    // Locale of the catalog actually in use; the declaration's
    // sourceLocale when no catalog matched. "" until resolved.
    readonly property string resolvedLocale: root._resolvedLocale
    // True once resolution finished (catalog loaded or fallback
    // settled). Bindings through tr() show source strings meanwhile.
    readonly property bool ready: root._ready

    property var _catalog: ({})
    property string _resolvedLocale: ""
    property bool _ready: false
    property int _candidateIndex: -1

    readonly property string _sourceLocale: root.declaration && typeof root.declaration.sourceLocale === "string" ? root.declaration.sourceLocale : "en"
    readonly property string _directory: root.declaration && typeof root.declaration.directory === "string" && root.declaration.directory !== "" ? root.declaration.directory : "translations"
    // Declared locales that match the requested locale, most
    // specific first: es_AR before es. Exact tags keep the
    // manifest spelling so the catalog filename matches `files`.
    readonly property var _candidates: {
        const declared = root.declaration && Array.isArray(root.declaration.locales) ? root.declaration.locales : [];
        const wanted = (root.localeName || "").replace("-", "_");
        const variants = [wanted];
        const language = wanted.split("_")[0];
        if (language !== "" && language !== wanted)
            variants.push(language);
        const result = [];
        for (const variant of variants)
            for (const locale of declared)
                if (typeof locale === "string" && locale.replace("-", "_") === variant && !result.includes(locale))
                    result.push(locale);
        return result;
    }
    readonly property string _effectiveLocale: root._resolvedLocale !== "" ? root._resolvedLocale : root._sourceLocale

    function tr(source: string): string {
        const catalog = root._catalog;
        const value = catalog && typeof catalog === "object" ? catalog[source] : undefined;
        return typeof value === "string" && value !== "" ? value : source;
    }

    // Locale-aware formatting for the resolved locale, so dates and
    // numbers follow the same locale as the translated strings
    // (weekday names, decimal separator, grouping).
    function formatDateTime(value: var, format: string): string {
        const date = value instanceof Date ? value : new Date(value);
        return date.toLocaleString(Qt.locale(root._effectiveLocale), format);
    }

    function formatNumber(value: real): string {
        return Number(value).toLocaleString(Qt.locale(root._effectiveLocale));
    }

    function _tryCandidate(index: int): void {
        root._candidateIndex = index;
        if (index < 0 || index >= root._candidates.length) {
            root._catalog = ({});
            root._resolvedLocale = root._sourceLocale;
            root._ready = true;
            return;
        }
        root._ready = false;
        root._catalogView.path = `${Plugins.pluginsDir}/${root.pluginId}/${root._directory}/${root._candidates[index]}.json`;
    }

    on_CandidatesChanged: root._tryCandidate(root._candidates.length > 0 ? 0 : -1)
    Component.onCompleted: root._tryCandidate(root._candidates.length > 0 ? 0 : -1)

    // A QtObject root has no default property for children, so the
    // catalog reader lives in a property instead of as a child.
    property FileView _catalogView: FileView {
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(root._catalogView.text());
                if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                    throw new Error("catalog is not a JSON object");
                root._catalog = parsed;
                root._resolvedLocale = root._candidates[root._candidateIndex];
                root._ready = true;
            } catch (e) {
                root._tryCandidate(root._candidateIndex + 1);
            }
        }

        onLoadFailed: root._tryCandidate(root._candidateIndex + 1)
    }
}
