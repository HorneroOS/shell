"""Javi's voice: ES+EN catalogue completeness, rules and resolution."""
import re

from _jsrun import NODE, run_js

M = "javivoice.js"


@NODE
def test_all_four_tables_define_every_key():
    r = run_js(M, "const k = {}; for (const l of LANGS) for (const t of TONES) k[l+'.'+t] = Object.keys(CATALOG[l][t]).sort();"
                  "console.log(JSON.stringify(k));")
    base = r["en.warm"]
    assert len(base) >= 30
    for table, keys in r.items():
        assert keys == base, f"{table} differs from en.warm"


@NODE
def test_voice_rules_hold_for_every_line():
    lines = run_js(M, "const o=[]; for (const l of LANGS) for (const t of TONES) for (const [k,v] of Object.entries(CATALOG[l][t])) o.push([l,t,k,v]);"
                      "console.log(JSON.stringify(o));")
    emoji = re.compile("[\U0001F300-\U0001FAFF☀-➿]")
    for lang, tone, key, text in lines:
        assert 0 < len(text) <= 72, (lang, tone, key, len(text))
        assert "!" not in text, (lang, tone, key)
        assert not emoji.search(text), (lang, tone, key)
        assert "\n" not in text


@NODE
def test_spanish_is_really_spanish_not_a_copy():
    r = run_js(M, "console.log(JSON.stringify({same: Object.keys(CATALOG.en.warm).filter(k => CATALOG.es.warm[k] === CATALOG.en.warm[k])}));")
    # Only proper nouns / identical loanwords may match.
    assert set(r["same"]) <= {"nest.light.radio"}, r["same"]


@NODE
def test_language_resolution_and_fallbacks():
    r = run_js(M, """
console.log(JSON.stringify({
  auto_es: resolveLanguage({language: 'auto'}, 'es_AR'),
  auto_es2: resolveLanguage({language: 'auto'}, 'es-419'),
  auto_en: resolveLanguage({language: 'auto'}, 'de_DE'),
  auto_empty: resolveLanguage({language: 'auto'}, ''),
  pin_en: resolveLanguage({language: 'en'}, 'es_AR'),
  pin_es: resolveLanguage({language: 'es'}, 'en_US'),
  bad: resolveLanguage({language: 'klingon'}, 'es_AR'),
  line_es: line({language: 'es', tone: 'warm'}, 'en_US', 'summon.greet'),
  line_en: line({language: 'en', tone: 'plain'}, 'es_AR', 'summon.greet'),
  unknown: line({}, 'en_US', 'no.such.key'),
  bad_tone: sanitize({tone: 'sarcastic'}).tone
}));""")
    assert r["auto_es"] == "es" and r["auto_es2"] == "es"
    assert r["auto_en"] == "en" and r["auto_empty"] == "en"
    assert r["pin_en"] == "en" and r["pin_es"] == "es"
    assert r["bad"] == "es"  # invalid setting -> default "auto" -> locale
    assert r["line_es"] == "Acá estoy." and r["line_en"] == "Hello."
    assert r["unknown"] == "no.such.key"
    assert r["bad_tone"] == "warm"


@NODE
def test_argument_substitution():
    r = run_js(M, "CATALOG.en.warm['t.x'] = 'a %1 b %2'; console.log(JSON.stringify(line({language:'en'}, 'en', 't.x', ['X', 7])));")
    assert r == "a X b 7"


def test_voice_is_wired_not_decorative():
    from pathlib import Path
    comp = Path(__file__).resolve().parent.parent / "modules" / "companion"
    assert "JaviVoice.line" in (comp / "CompanionReactions.qml").read_text()
    assert "JaviVoice.line" in (comp / "CompanionStore.qml").read_text()
    assert "javivoice.js" in (comp / "JaviVoice.qml").read_text()


def test_store_persists_and_revalidates_prefs():
    from pathlib import Path
    comp = Path(__file__).resolve().parent.parent / "modules" / "companion"
    store = (comp / "CompanionStore.qml").read_text()
    assert "prefs: persist.prefs" in store and "o.prefs" in store
    for mod in ("Voice.sanitize", "Habitat.sanitize", "Radio.sanitize"):
        assert mod in store, mod
    assert "function patchPref(" in store and "function resetPref(" in store
    # Every write path goes through the one validated-document builder.
    assert store.count("JSON.stringify(root._sanitizePrefs(") >= 3
    # Restore tolerates non-object JSON (null, arrays, scalars).
    assert "persist.prefs = JSON.stringify(root._sanitizePrefs(root._parseJson(o.prefs)))" in store
    assert "PrefsDoc.asObject(raw)" in store
    # patchPref walks paths only through the guarded helper.
    body = store[store.index("function patchPref("):store.index("function resetPref(")]
    assert "PrefsDoc.setPath(next[section], path, value)" in body
    assert "path.split" not in body


@NODE
def test_prefs_document_guards_shape():
    r = run_js("prefsdoc.js", """
console.log(JSON.stringify([
  parseObject(""), parseObject("null"), parseObject("[1,2]"), parseObject("5"),
  parseObject("{bad"), parseObject('{"voice":{"tone":"warm"}}'),
  asObject(null), asObject([]), asObject("x"), asObject({a: 1})
]));""")
    assert r[:5] == [{}, {}, {}, {}, {}]
    assert r[5] == {"voice": {"tone": "warm"}}
    assert r[6:9] == [{}, {}, {}] and r[9] == {"a": 1}


@NODE
def test_patch_path_rejects_prototype_segments():
    r = run_js("prefsdoc.js", """
const out = [];
for (const p of ["__proto__.polluted", "constructor.prototype.polluted", "prototype",
                 "a.__proto__", "modeLevel.constructor", "", "a..b", ".a", "a."]) {
  const doc = {a: {b: 1}, modeLevel: {focus: 1}};
  out.push([p, setPath(doc, p, "x"), JSON.stringify(doc)]);
}
const ok = {anchor: "left", modeLevel: {focus: 1}};
out.push(["anchor", setPath(ok, "anchor", "right"), JSON.stringify(ok)]);
out.push(["modeLevel.focus", setPath(ok, "modeLevel.focus", 2), JSON.stringify(ok)]);
out.push(["missing.child", setPath(ok, "missing.child", 1), JSON.stringify(ok)]);
out.push(["anchor.child", setPath(ok, "anchor.child", 1), JSON.stringify(ok)]);
out.push(["polluted", ({}).polluted === undefined && Object.prototype.polluted === undefined]);
console.log(JSON.stringify(out));""")
    for path, accepted, doc in r[:9]:
        assert accepted is False, path
        assert doc == '{"a":{"b":1},"modeLevel":{"focus":1}}', path
    assert r[9][1] is True and r[9][2] == '{"anchor":"right","modeLevel":{"focus":1}}'
    assert r[10][1] is True and r[10][2] == '{"anchor":"right","modeLevel":{"focus":2}}'
    assert r[11][1] is False and r[12][1] is False
    assert r[13][1] is True


def test_voice_section_is_in_the_pane():
    from pathlib import Path
    cc = Path(__file__).resolve().parent.parent / "modules" / "controlcenter" / "companion"
    pane = (cc / "CompanionPane.qml").read_text()
    section = (cc / "VoiceSection.qml").read_text()
    assert "VoiceSection {}" in pane
    assert 'patchPref("voice", "language"' in section and 'patchPref("voice", "tone"' in section
    assert 'resetPref("voice")' in section
