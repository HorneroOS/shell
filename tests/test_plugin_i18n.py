"""Plugin i18n contract (shell#375): manifest `translations`
declarations, JSON catalog validation, and the PluginKit
`Translations` runtime wiring.

Catalogs are flat, source-reviewable JSON (source string ->
translation). The validator flags untranslated literal strings,
placeholder drift, and the two shapes that would silently never
translate: compiled .qm payloads and qsTr() calls in plugin code.
"""

import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_i18n", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

LONG_SOURCE = "A long explanation shown to the user. " * 20
LONG_TRANSLATION = "Una explicación larga para la persona usuaria. " * 20

QML = (
    "import QtQuick\nimport Hornero.PluginKit\nItem {\n"
    '    Translations { id: i18n; pluginId: "example-clock" }\n'
    '    property string title: i18n.tr("Example Clock")\n'
    '    property string today: i18n.tr("Today is %1").arg("x")\n'
    f'    property string help: i18n.tr("{LONG_SOURCE.strip()}")\n'
    "}"
)

CATALOG = {
    "Example Clock": "Reloj de ejemplo",
    "Today is %1": "Hoy es %1",
    LONG_SOURCE.strip(): LONG_TRANSLATION.strip(),
}


def make_translated_plugin(tmp_path: Path, catalog: dict | None = None) -> Path:
    plugin = tmp_path / "example-clock"
    (plugin / "translations").mkdir(parents=True)
    manifest = {
        "schemaVersion": 1,
        "id": "example-clock",
        "name": "Example Clock",
        "version": "1.0.0",
        "description": "A sample clock card.",
        "author": "Example Author",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE", "translations/es.json"],
        "translations": {
            "sourceLocale": "en",
            "locales": ["es"],
            "directory": "translations",
        },
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
    }
    (plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (plugin / "Main.qml").write_text(QML, encoding="utf-8")
    (plugin / "README.md").write_text("# Example Clock\n", encoding="utf-8")
    (plugin / "LICENSE").write_text("MIT\n", encoding="utf-8")
    (plugin / "translations/es.json").write_text(
        json.dumps(CATALOG if catalog is None else catalog, ensure_ascii=False),
        encoding="utf-8",
    )
    return plugin


def load_manifest(plugin: Path) -> dict:
    return json.loads((plugin / "manifest.json").read_text())


def save_manifest(plugin: Path, manifest: dict) -> None:
    (plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


def test_translated_package_passes_schema_and_validator(tmp_path):
    plugin = make_translated_plugin(tmp_path)
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(load_manifest(plugin))
    VALIDATOR.validate_plugin(plugin)


def test_package_without_translations_stays_valid(tmp_path):
    # Backward compatibility: every pre-#375 manifest has no
    # `translations` field and must keep validating unchanged.
    plugin = make_translated_plugin(tmp_path)
    manifest = load_manifest(plugin)
    del manifest["translations"]
    manifest["files"].remove("translations/es.json")
    save_manifest(plugin, manifest)
    (plugin / "translations/es.json").unlink()
    (plugin / "Main.qml").write_text("import QtQuick\nItem {}", encoding="utf-8")
    VALIDATOR.validate_plugin(plugin)


def test_in_tree_example_clock_is_the_es_en_reference():
    plugin = ROOT / "examples/plugins/example-clock"
    manifest = load_manifest(plugin)
    assert manifest["translations"] == {
        "sourceLocale": "en",
        "locales": ["es"],
        "directory": "translations",
    }
    catalog = json.loads((plugin / "translations/es.json").read_text())
    assert catalog["Example Clock"] == "Reloj de ejemplo"
    # Actually translated, not source strings copied through.
    assert all(key != value for key, value in catalog.items())
    VALIDATOR.validate_plugin(plugin)


def test_declared_locale_without_catalog_in_files_is_rejected(tmp_path):
    plugin = make_translated_plugin(tmp_path)
    manifest = load_manifest(plugin)
    manifest["translations"]["locales"] = ["es", "pt_BR"]
    save_manifest(plugin, manifest)
    with pytest.raises(VALIDATOR.ValidationError, match="pt_BR"):
        VALIDATOR.validate_plugin(plugin)


def test_untranslated_literal_string_is_flagged(tmp_path):
    plugin = make_translated_plugin(tmp_path, catalog={"Example Clock": "Reloj de ejemplo"})
    with pytest.raises(VALIDATOR.ValidationError, match="missing translations"):
        VALIDATOR.validate_plugin(plugin)


def test_placeholder_drift_is_rejected(tmp_path):
    catalog = dict(CATALOG)
    catalog["Today is %1"] = "Hoy es un día"
    plugin = make_translated_plugin(tmp_path, catalog=catalog)
    with pytest.raises(VALIDATOR.ValidationError, match="placeholders"):
        VALIDATOR.validate_plugin(plugin)


def test_empty_translation_is_rejected(tmp_path):
    catalog = dict(CATALOG)
    catalog["Example Clock"] = "  "
    plugin = make_translated_plugin(tmp_path, catalog=catalog)
    with pytest.raises(VALIDATOR.ValidationError, match="non-empty translated string"):
        VALIDATOR.validate_plugin(plugin)


def test_malformed_catalog_is_rejected(tmp_path):
    plugin = make_translated_plugin(tmp_path)
    (plugin / "translations/es.json").write_text("{not json", encoding="utf-8")
    with pytest.raises(VALIDATOR.ValidationError, match="not readable JSON"):
        VALIDATOR.validate_plugin(plugin)


def test_duplicate_catalog_keys_are_rejected(tmp_path):
    plugin = make_translated_plugin(tmp_path)
    (plugin / "translations/es.json").write_text(
        '{"Example Clock": "A", "Example Clock": "B"}', encoding="utf-8"
    )
    with pytest.raises(VALIDATOR.ValidationError, match="duplicate key"):
        VALIDATOR.validate_plugin(plugin)


@pytest.mark.parametrize(
    "translations",
    [
        {"sourceLocale": "english", "locales": ["es"]},
        {"sourceLocale": "en", "locales": []},
        {"sourceLocale": "en", "locales": ["es", "es"]},
        {"sourceLocale": "en", "locales": ["es-AR!"]},
        {"sourceLocale": "en", "locales": ["es"], "fallback": "en"},
        {"locales": ["es"]},
    ],
)
def test_malformed_translations_declarations_are_rejected(tmp_path, translations):
    plugin = make_translated_plugin(tmp_path)
    manifest = load_manifest(plugin)
    manifest["translations"] = translations
    save_manifest(plugin, manifest)
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    assert list(Draft202012Validator(schema).iter_errors(manifest))
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(plugin)


def test_qstr_in_plugin_code_is_rejected(tmp_path):
    # qsTr() would silently never translate for plugins: the shell
    # installs no QTranslator for extension catalogs.
    plugin = make_translated_plugin(tmp_path)
    (plugin / "Main.qml").write_text(
        'import QtQuick\nItem { property string t: qsTr("Example Clock") }',
        encoding="utf-8",
    )
    with pytest.raises(VALIDATOR.ValidationError, match="qsTr"):
        VALIDATOR.validate_plugin(plugin)


def test_compiled_qm_catalog_is_rejected(tmp_path):
    plugin = make_translated_plugin(tmp_path)
    manifest = load_manifest(plugin)
    manifest["files"].append("translations/es.qm")
    save_manifest(plugin, manifest)
    (plugin / "translations/es.qm").write_bytes(b"\x3c\xb8\x64\x18")
    with pytest.raises(VALIDATOR.ValidationError, match="compiled"):
        VALIDATOR.validate_plugin(plugin)


def test_pluginkit_translations_runtime_wiring():
    kit = ROOT / "plugin/qml/Hornero/PluginKit"
    assert "Translations 1.0 Translations.qml" in (kit / "qmldir").read_text()
    component = (kit / "Translations.qml").read_text()
    assert "Plugins.translationDeclaration(pluginId)" in component
    assert "function tr(source: string): string" in component
    # Locale resolution: full tag, then language, then source strings.
    assert 'wanted.split("_")[0]' in component
    assert "root._resolvedLocale = root._sourceLocale" in component
    # Locale-aware date/number formatting rides the resolved locale.
    assert "date.toLocaleString(Qt.locale(root._effectiveLocale), format)" in component
    assert "toLocaleString(Qt.locale(root._effectiveLocale))" in component

    service = (ROOT / "services/Plugins.qml").read_text()
    assert "function markTranslations" in service
    assert "function translationDeclaration" in service

    host = (ROOT / "modules/plugins/PluginHost.qml").read_text()
    assert "manifest.translations" in host
    assert "Plugins.markTranslations(slot.modelData.id" in host
