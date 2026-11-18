"""Run a pure companion .js policy module under node (shared test helper)."""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

COMP = Path(__file__).resolve().parent.parent / "modules" / "companion"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def run_js(module: str, body: str):
    src = (COMP / module).read_text(encoding="utf-8").replace(".pragma library", "")
    out = subprocess.run(["node", "-e", src + "\n" + body], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def js_source(module: str) -> str:
    return (COMP / module).read_text(encoding="utf-8")


def strip_comments(text: str) -> str:
    return re.sub(r"//[^\n]*", "", text)
