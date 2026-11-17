"""Extension theme templates (RFC 0002 §12.2, plugins#70): manifest `theme.templates`."""
import json
import sys
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_plugin_contract import ROOT, VALIDATOR, make_plugin  # noqa: E402

GOOD = "/* {{ id }} {{ mode }} */\n:root { --signal: {{ signal }}; --ink: {{ ink.rgba 0.8 }}; }\n{{#dark}}--g: {{ glow.bare }};{{/dark}}\n{{ term4.rgb }}\n"
SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())


def with_theme(tmp_path, templates, template_text=GOOD, extra_files=("palette.css.tmpl",)):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["files"] += list(extra_files)
    manifest["theme"] = {"templates": templates}
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    for name in extra_files:
        (plugin / name).parent.mkdir(parents=True, exist_ok=True)
        (plugin / name).write_text(template_text)
    return plugin, manifest


def entry(template="palette.css.tmpl", output="palette.css"):
    return {"template": template, "output": output}


def test_a_valid_declaration_passes_schema_and_validator(tmp_path):
    plugin, manifest = with_theme(tmp_path, [entry()])
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest))
    VALIDATOR.validate_plugin(plugin)


@pytest.mark.parametrize("output", ["/etc/passwd", "../x.css", "sub/x.css", ".hidden", "a..b", "x y", "", "a" * 65, "~/x"])
def test_outputs_must_be_plain_file_names(tmp_path, output):
    plugin, manifest = with_theme(tmp_path, [entry(output=output)])
    with pytest.raises(VALIDATOR.ValidationError, match="output"):
        VALIDATOR.validate_plugin(plugin)
    assert list(Draft202012Validator(SCHEMA).iter_errors(manifest)) or output in {"a..b"}


@pytest.mark.parametrize("template", ["/abs.tmpl", "../up.tmpl", "palette.css"])
def test_template_paths_are_safe_relative_tmpl_files(tmp_path, template):
    plugin, _ = with_theme(tmp_path, [entry(template=template)])
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(plugin)


def test_template_must_be_listed_in_files(tmp_path):
    plugin, manifest = with_theme(tmp_path, [entry(template="missing.tmpl")])
    with pytest.raises(VALIDATOR.ValidationError, match="listed in files"):
        VALIDATOR.validate_plugin(plugin)


def test_duplicates_and_limits(tmp_path):
    plugin, _ = with_theme(tmp_path, [entry(), entry(output="b.css")], extra_files=("palette.css.tmpl",))
    with pytest.raises(VALIDATOR.ValidationError, match="declared twice"):
        VALIDATOR.validate_plugin(plugin)
    plugin2, _ = with_theme(tmp_path / "b", [entry(), entry(template="b.tmpl")], extra_files=("palette.css.tmpl", "b.tmpl")) if (tmp_path / "b").mkdir() is None else (None, None)
    with pytest.raises(VALIDATOR.ValidationError, match="duplicates"):
        VALIDATOR.validate_plugin(plugin2)


def test_theme_block_shape(tmp_path):
    for bad in ({"templates": []}, {"templates": [entry()], "hooks": ["x"]}, {}):
        plugin, manifest = with_theme(tmp_path / str(len(str(bad))), [entry()]) if (tmp_path / str(len(str(bad)))).mkdir() is None else (None, None)
        manifest["theme"] = bad
        (plugin / "manifest.json").write_text(json.dumps(manifest))
        with pytest.raises(VALIDATOR.ValidationError):
            VALIDATOR.validate_plugin(plugin)
        assert list(Draft202012Validator(SCHEMA).iter_errors(manifest))


@pytest.mark.parametrize("text,match", [
    ("{{ nosuchrole }}", "unknown palette role"),
    ("{{ signal.upper }}", "unsupported filter"),
    ("{{ signal.rgba 2 }}", "rgba"),
    ("{{ signal.rgba }}", "rgba"),
    ("{{ mode.hex }}", "no filter"),
    ("{{#dark}} never closed", "never closed"),
    ("{{/dark}}", "unbalanced"),
    ("{{#dark}}{{/light}}", "unbalanced"),
    ("{{ signal | sh }}", "unsupported template expression"),
    ("{{ term16 }}", "unknown palette role"),
    ("}} stray", "stray"),
    ("{{ $(rm -rf /) }}", "unsupported template expression"),
])
def test_template_grammar_is_strict_and_names_the_line(tmp_path, text, match):
    plugin, _ = with_theme(tmp_path, [entry()], template_text="line one\n" + text + "\n")
    with pytest.raises(VALIDATOR.ValidationError, match=match) as err:
        VALIDATOR.validate_plugin(plugin)
    assert "palette.css.tmpl" in str(err.value)


def test_oversized_template_is_rejected(tmp_path):
    plugin, _ = with_theme(tmp_path, [entry()], template_text="x" * (64 * 1024 + 1))
    with pytest.raises(VALIDATOR.ValidationError, match="exceeds"):
        VALIDATOR.validate_plugin(plugin)
