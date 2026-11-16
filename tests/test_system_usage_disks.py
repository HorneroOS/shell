"""SystemUsage.parseDisks (shell#464): usage of filesystems on LUKS/LVM is
attributed to their physical disk through PKNAME, and disks without a
mounted filesystem are left out instead of counting 0 used against their
whole size (which made the dashboard storage bar read ~0%)."""
import json
import re
import shutil
import subprocess
from pathlib import Path

SRC = (Path(__file__).resolve().parents[1] / "services/SystemUsage.qml").read_text(encoding="utf-8")

SAMPLE = "\n".join([
    'NAME="sda" PKNAME="" SIZE="1000204886016" TYPE="disk" FSUSED="" FSSIZE=""',
    'NAME="sda1" PKNAME="sda" SIZE="575668224" TYPE="part" FSUSED="" FSSIZE=""',
    'NAME="sdb" PKNAME="" SIZE="480103981056" TYPE="disk" FSUSED="" FSSIZE=""',
    'NAME="sdb1" PKNAME="sdb" SIZE="1073741824" TYPE="part" FSUSED="1000" FSSIZE="4000"',
    'NAME="sdb2" PKNAME="sdb" SIZE="107374182400" TYPE="part" FSUSED="" FSSIZE=""',
    'NAME="root" PKNAME="sdb2" SIZE="107357405184" TYPE="crypt" FSUSED="3000" FSSIZE="6000"',
    'NAME="vg-home" PKNAME="root" SIZE="1" TYPE="lvm" FSUSED="0" FSSIZE="2000"',
    'NAME="zram0" PKNAME="" SIZE="8326742016" TYPE="disk" FSUSED="" FSSIZE=""',
    'NAME="nvme0n1" PKNAME="" SIZE="500107862016" TYPE="disk" FSUSED="" FSSIZE=""',
    'NAME="nvme0n1p1" PKNAME="nvme0n1" SIZE="535822336" TYPE="part" FSUSED="512" FSSIZE="1024"',
])


def _function(name):
    start = SRC.index(f"function {name}(")
    body = SRC.index("{", start)
    depth = 0
    for i in range(body, len(SRC)):
        depth += {"{": 1, "}": -1}.get(SRC[i], 0)
        if depth == 0:
            break
    js = SRC[start:i + 1]
    return re.sub(r"\((\w+): \w+\): \w+ \{", r"(\1) {", js, count=1)


def test_parse_disks_walks_crypt_and_lvm_and_skips_unmounted():
    node = shutil.which("node")
    assert node, "Node.js is required to exercise the QML parser"
    script = _function("parseDisks") + "\nconsole.log(JSON.stringify(parseDisks(process.argv[1])));"
    out = subprocess.run([node, "-e", script, SAMPLE], check=True, capture_output=True, text=True).stdout
    disks = {d["mount"]: d for d in json.loads(out)}
    assert sorted(disks) == ["nvme0n1", "sdb"]
    assert disks["sdb"]["used"] * 1024 == 4000 and disks["sdb"]["total"] * 1024 == 12000
    assert abs(disks["nvme0n1"]["perc"] - 0.5) < 1e-9


def test_lsblk_requests_parent_names():
    assert '"NAME,PKNAME,SIZE,TYPE,FSUSED,FSSIZE"' in SRC
