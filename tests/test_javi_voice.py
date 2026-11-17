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
        assert store.count(mod) >= 3, mod
    assert "function patchPref(" in store and "function resetPref(" in store


def test_voice_section_is_in_the_pane():
    from pathlib import Path
    cc = Path(__file__).resolve().parent.parent / "modules" / "controlcenter" / "companion"
    pane = (cc / "CompanionPane.qml").read_text()
    section = (cc / "VoiceSection.qml").read_text()
    assert "VoiceSection {}" in pane
    assert 'patchPref("voice", "language"' in section and 'patchPref("voice", "tone"' in section
    assert 'resetPref("voice")' in section
