"""Shell UI translations (docs/I18N.md): the es_AR catalog covers every
qsTr() string with a finished, faithful translation.

Runs without Qt: the source scan below is an independent extractor for
literal qsTr()/QT_TR_NOOP() calls, so a forgotten `scripts/i18n_update.sh`
fails here even where lupdate is not installed. CI additionally runs
`scripts/i18n_update.sh --check` with the real lupdate.

The baseline `i18n/es_AR.untranslated` lists messages allowed to stay
untranslated (one `Context|source` per line). It is empty today and may
only shrink: a listed message that is now translated, or no longer
exists, fails the gate so the list never goes stale.
"""
import re
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "i18n" / "hornero_es_AR.ts"
BASELINE = ROOT / "i18n" / "es_AR.untranslated"
SOURCE_ROOTS = ["shell.qml", "lock.qml", "components", "config", "modules", "services", "utils"]

# Names that must survive translation verbatim when the English has them.
KEEP_NAMES = [
    "HorneroOS", "Hornero", "Cockpit", "Chromatic", "Clear Ink", "PluginKit",
    "Javi", "Hermes", "Hyprland", "Niri", "PipeWire", "GTK", "Bluetooth",
    "Wi-Fi", "VPN", "WireGuard", "NetBird", "Steam", "Gamescope", "MangoHud",
    "horneroctl",
]
# Spain-Spanish tuteo/vosotros and Spain-only vocabulary; es-AR uses voseo.
NOT_ES_AR = re.compile(
    r"\b(tú|tienes|puedes|quieres|eres|sabes|necesitas|deseas|vosotros|vuestro|vuestra|"
    r"podéis|tenéis|queréis|ordenador|fichero|ficheros)\b",
    re.IGNORECASE,
)
PLACEHOLDER = re.compile(r"%(?:L?\d+|n)")
TAG = re.compile(r"<[^>]+>")


def _messages():
    root = ET.parse(CATALOG).getroot()
    assert root.get("language") == "es_AR"
    assert root.get("sourcelanguage") == "en"
    out = []
    for ctx in root.findall("context"):
        name = ctx.findtext("name")
        for msg in ctx.findall("message"):
            tr = msg.find("translation")
            forms = [f.text or "" for f in tr.findall("numerusform")] if msg.get("numerus") == "yes" else [tr.text or ""]
            out.append({
                "context": name,
                "source": msg.findtext("source") or "",
                "comment": msg.findtext("comment") or "",
                "numerus": msg.get("numerus") == "yes",
                "type": tr.get("type") or "",
                "forms": forms,
            })
    return out


def _baseline():
    if not BASELINE.exists():
        return set()
    return {
        line for line in BASELINE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def _string_literal(text, i):
    """Parses a JS string literal at text[i]; returns (value, end) or None."""
    quote = text[i]
    if quote not in "\"'`":
        return None
    j = i + 1
    out = []
    while j < len(text):
        c = text[j]
        if c == "\\":
            nxt = text[j + 1]
            if nxt == "u":
                out.append(chr(int(text[j + 2:j + 6], 16)))
                j += 6
                continue
            out.append({"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"', "`": "`"}.get(nxt, "\\" + nxt))
            j += 2
            continue
        if c == quote:
            return "".join(out), j + 1
        if quote == "`" and text.startswith("${", j):
            return None  # template with substitutions: not a literal
        out.append(c)
        j += 1
    return None


def _strip_comments(text):
    """Blanks // and /* */ comments outside string literals (keeps offsets)."""
    out = list(text)
    i, n, quote = 0, len(text), None
    while i < n:
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'`":
            quote = c
        elif text.startswith("//", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            out[i:end] = " " * (end - i)
            i = end
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end < 0 else end + 2
            out[i:end] = [ch if ch == "\n" else " " for ch in text[i:end]]
            i = end
            continue
        i += 1
    return "".join(out)


def _source_calls():
    """(context, source) for every literal qsTr()/QT_TR_NOOP() call."""
    found = set()
    files = []
    for entry in SOURCE_ROOTS:
        p = ROOT / entry
        files.extend([p] if p.is_file() else sorted(p.rglob("*")))
    call = re.compile(r"\b(qsTr|QT_TR_NOOP)\(\s*")
    for path in files:
        if path.suffix not in (".qml", ".js"):
            continue
        text = _strip_comments(path.read_text(encoding="utf-8"))
        for m in call.finditer(text):
            lit = _string_literal(text, m.end())
            if lit is None:
                continue
            found.add((path.stem, lit[0]))
    return found


def test_catalog_parses_and_is_not_trivial():
    msgs = _messages()
    assert len(msgs) > 2000


def test_every_source_string_is_in_the_catalog():
    have = {(m["context"], m["source"]) for m in _messages() if m["type"] not in ("vanished", "obsolete")}
    missing = sorted(_source_calls() - have)
    assert not missing, (
        f"{len(missing)} qsTr() string(s) are not in i18n/hornero_es_AR.ts; run scripts/i18n_update.sh "
        f"and translate them (docs/I18N.md). First: {missing[:10]}"
    )


def test_catalog_has_no_dead_entries():
    dead = [m for m in _messages() if m["type"] in ("vanished", "obsolete")]
    assert not dead, f"run scripts/i18n_update.sh to drop {len(dead)} vanished message(s)"


def test_every_message_is_translated_or_baselined():
    baseline = _baseline()
    untranslated = {
        f"{m['context']}|{m['source']}" for m in _messages()
        if m["type"] == "unfinished" or any(not f.strip() for f in m["forms"])
    }
    new = sorted(untranslated - baseline)
    assert not new, (
        f"{len(new)} new string(s) without an es_AR translation (docs/I18N.md). First: {new[:10]}"
    )
    stale = sorted(baseline - untranslated)
    assert not stale, f"remove from i18n/es_AR.untranslated (translated or gone): {stale[:10]}"


def test_placeholders_markup_and_whitespace_match():
    bad = []
    for m in _messages():
        if m["type"] == "unfinished":
            continue
        src = m["source"]
        for form in m["forms"]:
            if Counter(PLACEHOLDER.findall(src)) != Counter(PLACEHOLDER.findall(form)):
                bad.append(("placeholders", src, form))
            if Counter(TAG.findall(src)) != Counter(TAG.findall(form)):
                bad.append(("markup", src, form))
            if src[:1].isspace() != form[:1].isspace() or src[-1:].isspace() != form[-1:].isspace():
                bad.append(("whitespace", src, form))
            if src.count("\n") != form.count("\n"):
                bad.append(("newlines", src, form))
    assert not bad, f"{len(bad)} translation(s) changed placeholders/markup: {bad[:8]}"


def test_plural_messages_have_both_spanish_forms():
    for m in _messages():
        if m["numerus"]:
            assert len(m["forms"]) == 2, f"{m['source']!r} needs singular and plural forms"
            for form in m["forms"]:
                assert "%n" in form or "%n" not in m["source"], f"{m['source']!r}: keep %n in {form!r}"


def test_product_names_stay_as_written():
    bad = []
    for m in _messages():
        for name in KEEP_NAMES:
            if re.search(rf"\b{re.escape(name)}\b", m["source"]) and not all(name in f for f in m["forms"]):
                bad.append((name, m["source"], m["forms"]))
    assert not bad, f"{len(bad)} translation(s) renamed a product/third-party name: {bad[:8]}"


def test_spanish_is_argentine_voseo():
    bad = [(m["source"], f) for m in _messages() for f in m["forms"] if NOT_ES_AR.search(f)]
    assert not bad, f"use voseo / es-AR vocabulary (docs/I18N.md): {bad[:8]}"


def test_language_setting_is_wired():
    general = (ROOT / "config" / "GeneralConfig.qml").read_text()
    assert 'property string language: "auto"' in general
    service = (ROOT / "services" / "Language.qml").read_text()
    assert "Translator.load(" in service and "Translator.resolve(" in service
    for entry in ("shell.qml", "lock.qml"):
        assert "Language.active" in (ROOT / entry).read_text(), f"{entry} must start the Language service"
    pane = (ROOT / "modules" / "controlcenter" / "system" / "SystemPane.qml").read_text()
    assert 'key: "language"' in pane and "Language.options" in pane
    cmake = (ROOT / "CMakeLists.txt").read_text()
    assert re.search(r"foreach\(dir [^)]*\bi18n\b", cmake), "i18n/ must be installed with the shell"
