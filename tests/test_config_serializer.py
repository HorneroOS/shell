"""Config save path must not silently drop settings.

`Config.qml` persists the user file through hand-written `serialize*()`
functions, not by dumping the JsonAdapter. Any JsonObject property that the
serializer forgets is read on load but *dropped* the next time Settings
saves (the file is rewritten from `serializeConfig()`).

This test walks every JsonObject schema wired into the adapter
(`config/*Config.qml`, `UserPaths.qml`, including nested `component X:
JsonObject` blocks) and asserts, path by path, that:

1. every persistable property is written by the serializer;
2. every serialized key exists in the schema (no dead keys like the old
   `dashboard.updateInterval`);
3. each serialized value reads its own schema path (no hardcoded literals
   standing in for a live property);
4. scale-derived tokens (`small: 12 * scale`, ...) are *not* written: only
   their `scale` knob is, otherwise saving would freeze the derived values
   and break scaling.

`readonly` properties cannot be loaded back by the adapter, so writing them
is optional.
"""
import re
from pathlib import Path

from test_factory_config import _Parser, _fn_body

ROOT = Path(__file__).resolve().parent.parent
CONFIG_DIR = ROOT / "config"
CONFIG_QML = CONFIG_DIR / "Config.qml"

_OPEN = {"{": "}", "[": "]", "(": ")"}


def _strip_comments_and_mask_strings(text):
    """Return text with // and /* */ comments blanked and string contents
    replaced by spaces (same length, so offsets stay valid)."""
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                out[i] = " "
                i += 1
        elif text.startswith("/*", i):
            end = text.index("*/", i) + 2
            for j in range(i, end):
                if out[j] != "\n":
                    out[j] = " "
            i = end
        elif c in "\"'`":
            i += 1
            while i < n and text[i] != c:
                if text[i] == "\\":
                    out[i] = " "
                    i += 1
                out[i] = " "
                i += 1
            i += 1
        else:
            i += 1
    return "".join(out)


def _flatten(body):
    """Collapse every bracketed group in `body` to a placeholder `{#n}` /
    `[]` / `()`, returning (flat_text, inner_texts). Only depth-0
    statements remain visible to the regexes below."""
    flat = []
    inners = []
    i = 0
    while i < len(body):
        c = body[i]
        if c in _OPEN:
            depth = 0
            for j in range(i, len(body)):
                if body[j] in _OPEN:
                    depth += 1
                elif body[j] in _OPEN.values():
                    depth -= 1
                    if depth == 0:
                        break
            if c == "{":
                flat.append(f"{{#{len(inners)}}}")
                inners.append(body[i + 1:j])
            else:
                flat.append(c + _OPEN[c])
            i = j + 1
        else:
            flat.append(c)
            i += 1
    return "".join(flat), inners


_PROP = re.compile(
    r"^[ \t]*(readonly\s+)?property\s+([\w.<>]+)\s+(\w+)(?:[ \t]*:[ \t]*([^\n]*))?",
    re.MULTILINE,
)
_COMPONENT = re.compile(r"component\s+(\w+)\s*:\s*JsonObject\s*\{#(\d+)\}")


def _parse_block(body):
    flat, inners = _flatten(body)
    props = [
        {"readonly": bool(m.group(1)), "type": m.group(2), "name": m.group(3),
         "expr": (m.group(4) or "").strip()}
        for m in _PROP.finditer(flat)
    ]
    components = {m.group(1): inners[int(m.group(2))] for m in _COMPONENT.finditer(flat)}
    return props, components


def _schema_for_file(path):
    """Return {dotted_rel_path: prop} for a *Config.qml JsonObject file."""
    text = _strip_comments_and_mask_strings(path.read_text())
    m = re.search(r"^JsonObject\s*\{", text, re.MULTILINE)
    assert m, f"{path.name}: root JsonObject not found"
    flat_root, inners = _flatten(text[m.start():])
    root_body = inners[int(re.search(r"\{#(\d+)\}", flat_root).group(1))]
    _, components = _parse_block(root_body)

    out = {}

    def walk(body, prefix):
        props, _ = _parse_block(body)
        for p in props:
            key = f"{prefix}{p['name']}"
            if p["type"] in components:
                walk(components[p["type"]], key + ".")
            else:
                out[key] = p

    walk(root_body, "")
    return out


def _adapter_sections():
    text = CONFIG_QML.read_text()
    m = re.search(r"JsonAdapter\s*\{(.*?)\n\s*\}", text, re.DOTALL)
    assert m, "Config.qml JsonAdapter block not found"
    return dict(re.findall(r"property\s+(\w+)\s+(\w+)\s*:\s*\1\s*\{\s*\}", m.group(1)))


def _schema():
    schema = {}
    for type_name, section in _adapter_sections().items():
        for rel, prop in _schema_for_file(CONFIG_DIR / f"{type_name}.qml").items():
            schema[f"{section}.{rel}"] = prop
    return schema


class _ValueParser(_Parser):
    """Like the factory parser, but keeps each leaf's raw value text."""

    def _object(self):
        assert self.s[self.i] == "{"
        self.i += 1
        keys = {}
        while True:
            self._ws()
            if self.s[self.i] == "}":
                self.i += 1
                return keys
            key = self._key()
            self._ws()
            assert self.s[self.i] == ":", f"no colon after {key!r}"
            self.i += 1
            self._ws()
            start = self.i
            sub = self._skip_value()
            keys[key] = sub if sub is not None else self.s[start:self.i].strip()
            self._ws()
            if self.s[self.i] == ",":
                self.i += 1


def _serialized():
    """Return {dotted_path: raw_value_expr} for everything serializeConfig()
    writes."""
    text = CONFIG_QML.read_text()
    sections = _ValueParser(_fn_body(text, "serializeConfig")).parse_function_object()
    out = {}

    def walk(node, prefix):
        for key, sub in node.items():
            if isinstance(sub, dict):
                walk(sub, f"{prefix}{key}.")
            else:
                out[f"{prefix}{key}"] = sub

    for section in sections:
        fn = f"serialize{section[0].upper()}{section[1:]}"
        walk(_ValueParser(_fn_body(text, fn)).parse_function_object(), f"{section}.")
    return out


def _is_scale_derived(prop):
    return re.search(r"\bscale\b", prop["expr"]) is not None


def test_schema_parser_sees_known_properties():
    # Guard against the parser silently finding nothing.
    schema = _schema()
    for path in ("bar.workspaces.maxWindowIcons", "bar.tray.hiddenIcons",
                 "bar.clock.showDate", "bar.sizes.kbLayoutWidth",
                 "bar.activeWindow.inverted", "appearance.rounding.scale",
                 "appearance.font.family.sans", "paths.wallpaperDir"):
        assert path in schema, f"schema parser missed {path}"
    assert len(schema) > 150


def test_every_persistable_property_is_serialized():
    schema = _schema()
    written = _serialized()
    missing = sorted(
        path for path, prop in schema.items()
        if not prop["readonly"] and not _is_scale_derived(prop) and path not in written
    )
    assert not missing, (
        "Config.qml serialize*() drops these settings on save (add them): "
        + ", ".join(missing)
    )


def test_every_serialized_key_exists_in_schema():
    schema = _schema()
    dead = sorted(set(_serialized()) - set(schema))
    assert not dead, f"serializer writes keys the schema does not declare: {dead}"


def test_serialized_values_read_their_own_property():
    wrong = sorted(
        f"{path} <- {expr}" for path, expr in _serialized().items() if expr != path
    )
    assert not wrong, f"serialized values must read their schema path: {wrong}"


def test_scale_derived_tokens_are_not_serialized():
    schema = _schema()
    written = _serialized()
    frozen = sorted(p for p, prop in schema.items() if _is_scale_derived(prop) and p in written)
    assert not frozen, f"scale-derived tokens must not be persisted: {frozen}"


# --- Appearance token references ------------------------------------------

_QML_DIRS = ("components", "modules", "services", "utils", "config")
_TOKEN_REF = re.compile(r"(?<![\w.])(?:Appearance|Config\.appearance)\.((?:\w+\.)*\w+)")


def _qml_files():
    yield ROOT / "shell.qml"
    for d in _QML_DIRS:
        yield from sorted((ROOT / d).rglob("*.qml"))


def _token_ref_is_valid(parts, leaves):
    # A reference is valid when it names a declared leaf token, a group of
    # them (e.g. `Appearance.anim.curves`), or a member of a leaf value
    # (e.g. `Appearance.anim.curves.standard.length`).
    for i in range(1, len(parts) + 1):
        path = ".".join(parts[:i])
        if path in leaves:
            return True
        if not any(leaf.startswith(path + ".") for leaf in leaves):
            return False
    return True


def test_every_appearance_token_reference_exists():
    leaves = set(_schema_for_file(CONFIG_DIR / "AppearanceConfig.qml"))
    assert "spacing.normal" in leaves and "font.size.small" in leaves
    bad = []
    seen = 0
    for path in _qml_files():
        text = _strip_comments_and_mask_strings(path.read_text())
        for m in _TOKEN_REF.finditer(text):
            seen += 1
            if not _token_ref_is_valid(m.group(1).split("."), leaves):
                line = text.count("\n", 0, m.start()) + 1
                bad.append(f"{path.relative_to(ROOT)}:{line}: {m.group(0)}")
    assert seen > 500, "token scan found suspiciously few references"
    assert not bad, (
        "QML references Appearance tokens not declared in "
        "config/AppearanceConfig.qml (they evaluate to undefined/NaN):\n"
        + "\n".join(bad)
    )
