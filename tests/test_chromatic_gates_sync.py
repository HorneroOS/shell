"""The vendored gate table must stay byte-identical to HorneroOS/config.

libs/chromatic/data/contrast-gates.json is a copy of config
`profiles/themes/contrast-gates.json` at the commit recorded in
contrast-gates.sha. With HORNERO_CONFIG_DIR pointing at a config checkout
that has that commit, the bytes are compared; the main checkout is also
compared when it has moved on, so drift shows up as a failure to resync.
"""
import json
import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "libs" / "chromatic" / "data"


def test_vendored_table_is_valid_and_pinned():
    table = json.loads((DATA / "contrast-gates.json").read_text(encoding="utf-8"))
    assert table["version"] == 1
    assert set(table["levels"]) == {"standard", "boosted", "maximum"}
    assert table["margin"] == 0.15
    sha = (DATA / "contrast-gates.sha").read_text(encoding="utf-8").strip()
    assert re.fullmatch(r"[0-9a-f]{40}", sha), "contrast-gates.sha must hold a config commit SHA"


def test_matches_config_at_pinned_sha():
    base = os.environ.get("HORNERO_CONFIG_DIR")
    if not base or not (Path(base) / ".git").exists():
        pytest.skip("HORNERO_CONFIG_DIR (a HorneroOS/config git checkout) not set")
    sha = (DATA / "contrast-gates.sha").read_text(encoding="utf-8").strip()
    upstream = subprocess.run(["git", "-C", base, "show", f"{sha}:profiles/themes/contrast-gates.json"],
                              capture_output=True, check=False)
    if upstream.returncode != 0:
        pytest.skip(f"config checkout lacks {sha}")
    assert upstream.stdout == (DATA / "contrast-gates.json").read_bytes()
    current = Path(base) / "profiles" / "themes" / "contrast-gates.json"
    if current.is_file():
        assert current.read_bytes() == (DATA / "contrast-gates.json").read_bytes(), (
            "config changed the gate table: re-vendor it and bump contrast-gates.sha")
