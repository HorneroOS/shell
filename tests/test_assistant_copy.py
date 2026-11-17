"""Workbench microcopy: EN and ES stay in sync, concise and plain."""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "assistantcopy.js"


def table():
    node = shutil.which("node")
    assert node
    src = JS.read_text().replace(".pragma library", "", 1)
    out = subprocess.run([node, "-e", src + "\nconsole.log(JSON.stringify(STRINGS));"], capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


def test_every_key_has_english_and_spanish():
    for key, v in table().items():
        assert v.get("en", "").strip(), key
        assert v.get("es", "").strip(), key


def test_copy_is_concise_and_not_slangy():
    banned = re.compile(r"\b(boludo|che|dale|piola|bro|dude|awesome|gonna|wanna)\b", re.I)
    for key, v in table().items():
        for lang in ("en", "es"):
            assert len(v[lang]) <= 120, (key, lang)
            assert not banned.search(v[lang]), (key, lang)


def test_language_resolution():
    node = shutil.which("node")
    src = JS.read_text().replace(".pragma library", "", 1)
    out = subprocess.run([node, "-e", src + "\nconsole.log(JSON.stringify([lang('es_AR'),lang('en_US'),lang(''),t('action.stop','es'),t('nope','en')]));"], capture_output=True, text=True, timeout=30)
    assert json.loads(out.stdout) == ["es", "en", "en", "Detener", "nope"]
