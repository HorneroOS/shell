#!/usr/bin/env bash
# build.sh <worktree> <dest>  -> harness shell tree with env-driven Density screen height
set -euo pipefail
SRC=$1; DEST=$2
H=$(dirname "$(readlink -f "$0")")
rm -rf "$DEST"; mkdir -p "$DEST"
rsync -a --exclude .git --exclude tests --exclude docs "$SRC"/ "$DEST"/
python3 - "$DEST" <<'PY'
import re,sys,pathlib
d=pathlib.Path(sys.argv[1])
p=d/"services/Density.qml"; t=p.read_text()
t=re.sub(r"readonly property real screenHeight:.*", 'readonly property real screenHeight: parseInt(Quickshell.env("HH"))', t)
p.write_text(t)
for name in ("Notifs.qml","IdleInhibitor.qml","Experience.qml"):
    p=d/"services"/name; t=p.read_text()
    t=re.sub(r"window: PanelWindow \{.*?\n        \}\n","window: null\n",t,flags=re.S)
    t=t.replace("PanelWindow {","Item {")
    t=re.sub(r'\n\s*color: "transparent"\n',"\n",t)
    t=re.sub(r"\n\s*mask: Region \{\}\n","\n",t)
    p.write_text(t)
PY
python3 - "$DEST" <<'PY2'
import pathlib,sys
d=pathlib.Path(sys.argv[1])
p=d/"services/Compositor.qml"; t=p.read_text()
t=t.replace("return isHyprland ? Hypr.workspaces.values : [];","return [{id:1,lastIpcObject:{windows:2}},{id:2,lastIpcObject:{windows:1}},{id:3,lastIpcObject:{windows:0}}];")
t=t.replace("return isHyprland && (workspace.lastIpcObject?.windows ?? 0) > 0;","return (workspace.lastIpcObject?.windows ?? 0) > 0;")
p.write_text(t)
PY2
python3 - "$DEST" <<'PY3'
import pathlib,sys
d=pathlib.Path(sys.argv[1])
p=d/"modules/bar/Bar.qml"; t=p.read_text()
t=t.replace("        visible: enabled && contentAvailable\n        active: enabled\n","        visible: enabled && contentAvailable\n        active: enabled\n        Timer { interval: 5000; running: true; onTriggered: console.log('ENTRY', wrapped.id, wrapped.visible, wrapped.width, wrapped.height, wrapped.status, wrapped.item) }\n")
p.write_text(t)
p=d/"modules/bar/components/OsIcon.qml"; t=p.read_text()
t=t.replace("    implicitWidth: Density.iconPx + 2","    Timer { interval: 5000; running: true; onTriggered: { let s=''; let it=root; while(it){ s+=' ['+it+' v'+it.visible+' o'+it.opacity+' x'+it.x+' y'+it.y+' '+it.width+'x'+it.height+']'; it=it.parent } console.log('OSI'+s) } }\n    implicitWidth: Density.iconPx + 2")
p.write_text(t)
(d/"components/StyledClippingRect.qml").write_text("import QtQuick\nRectangle {\n    id: root\n    color: 'transparent'\n}\n")
p=d/"components/effects/ColouredIcon.qml"; t=p.read_text()
import re
t=re.sub(r"    layer.enabled: true\n    layer.effect: Colouriser \{.*?\n    \}\n","    layer.enabled: false\n",t,flags=re.S)
p.write_text(t)
PY3
cp "$H/${HARNESS:-harness.qml}" "$DEST/shell.qml"
