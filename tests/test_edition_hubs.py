"""Studio and Gaming are edition hubs: the doctor board sits first, shows the
CLI's own verdicts and says "Unavailable" instead of passing when horneroctl
cannot answer. Pane headers come from the registry with a channel eyebrow."""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent
CC = ROOT / "modules/controlcenter"
BOARD = (CC / "components/DoctorBoard.qml").read_text()
DOCTOR_JS = CC / "components/doctor.js"


@pytest.mark.parametrize("rel,edition", [("studio/StudioPane.qml", "Studio"),
                                         ("gaming/GamingPane.qml", "Gaming")])
def test_hub_leads_with_doctor_board_from_registry_header(rel, edition):
    src = (CC / rel).read_text()
    assert f'edition: qsTr("{edition}")' in src
    assert 'import "../components/doctor.js" as Doctor' in src
    assert "Doctor.parse(doctorProc.out)" in src
    assert src.index("DoctorBoard {") < src.index('qsTr("Profiles")' if edition == "Gaming" else 'qsTr("Readiness")')
    assert f'paneId: "{edition.lower()}"' in src
    # Bare command name (docs/INTEGRATION.md); no shell.
    assert '"horneroctl", "--json"' in src and "sh -c" not in src


def test_board_never_fakes_a_pass_and_never_relies_on_colour_alone():
    assert 'qsTr("Unavailable")' in BOARD
    assert "unavailable" in BOARD and 'qsTr("FAIL")' in BOARD and 'qsTr("OK")' in BOARD
    assert "alert-triangle" in BOARD and "circle-check" in BOARD


def test_pane_header_has_channel_eyebrow_from_registry():
    header = (CC / "components/PaneHeader.qml").read_text()
    assert "Eyebrow {" in header and "PaneRegistry.categoryTitle" in header
    assert "padStart(2" in header


@pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")
def test_doctor_parser_keeps_cli_detail_and_flags_garbage():
    script = (
        "const src=require('fs').readFileSync(process.argv[1],'utf8').replace('.pragma library','');"
        "const f=new Function(src+';return {parse};')();"
        "const ok=f.parse(process.argv[2]);const bad=f.parse('not json');"
        "console.log(JSON.stringify({ok,bad}));")
    env = {"message": "ok  a: fine\nFAIL  b: gamescope not found on PATH\nx doctor: 1/2 checks failed",
           "data": {"b": "fail", "a": "ok"}}
    out = subprocess.run(["node", "-e", script, str(DOCTOR_JS), json.dumps(env)],
                         capture_output=True, text=True, check=True).stdout
    got = json.loads(out)
    assert got["ok"]["checks"] == [{"name": "a", "ok": True, "detail": "fine"},
                                   {"name": "b", "ok": False, "detail": "gamescope not found on PATH"}]
    assert got["ok"]["summary"].endswith("1/2 checks failed")
    assert got["bad"] == {"available": False, "checks": [], "summary": ""}
