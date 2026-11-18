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
t=t.replace("return isHyprland ? Hypr.workspaces.values : [];","return [{id:1,lastIpcObject:{windows:2}},{id:2,lastIpcObject:{windows:1}},{id:3,lastIpcObject:{windows:0}},{id:4,lastIpcObject:{windows:4}},{id:5,lastIpcObject:{windows:1},urgent:true}];")
t=t.replace("return isHyprland ? Hypr.toplevels.values.filter(window => window.workspace?.id === workspaceId) : [];","return ({1:['firefox','kitty'],2:['code'],4:['firefox','kitty','discord','thunar'],5:['mpv']}[workspaceId] || []).map(c => ({lastIpcObject:{class:c}}));")
t=t.replace("return isHyprland && (workspace.lastIpcObject?.windows ?? 0) > 0;","return (workspace.lastIpcObject?.windows ?? 0) > 0;")
p.write_text(t)
p=d/"services/Hypr.qml"; t=p.read_text()
t=t.replace("focusedWorkspace?.id ?? 1","root.harnessWs")
# Harness hooks: the active workspace and the special workspace are writable
# at runtime (needle travel frames), and the strip registers itself.
t=t.replace("    id: root\n","    id: root\n    property int harnessWs: parseInt(Quickshell.env('WSACTIVE') || '1')\n    property bool harnessSpecial: Quickshell.env('WSSPECIAL') === '1'\n    property var harnessStrips: []\n",1)
p.write_text(t)
p=d/"modules/bar/components/workspaces/Workspaces.qml"; t=p.read_text()
t=t.replace("readonly property bool onSpecial: Compositor.isSpecialWorkspaceActive(screen, Config.bar.workspaces.perMonitorWorkspaces)","readonly property bool onSpecial: Hypr.harnessSpecial")
t=t.replace("    readonly property var activeWsId: niriMode\n","    readonly property var activeWsId: Hypr.harnessWs\n    readonly property var unusedActiveWsId: niriMode\n")
t=t.replace("    implicitWidth: vertical ? cross :","    readonly property Item harnessPlate: plateLoader.item\n    readonly property Item harnessCells: workspaces\n    Component.onCompleted: Hypr.harnessStrips = Hypr.harnessStrips.concat([root])\n    implicitWidth: vertical ? cross :",1)
t=t.replace("        if (niriMode || !Compositor.isHyprland)\n            return {};","        return {4: true};\n        if (niriMode || !Compositor.isHyprland)\n            return {};")
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
python3 - "$DEST" <<'PY4'
import pathlib,sys
p=pathlib.Path(sys.argv[1])/'modules/bar/components/workspaces/Workspaces.qml'; t=p.read_text()
probe="""    Timer { interval: 4000; running: true; onTriggered: { const cs = []; for (let i = 0; i < workspaces.count; i++) { const c = workspaces.itemAt(i); cs.push({x: c.x, y: c.y, w: c.width, h: c.height, vertical: root.vertical, glyphs: c.glyphCount, gx: c.hasGlyphs ? c.groupX : 0, gy: c.hasGlyphs ? c.groupY : 0, gw: c.hasGlyphs ? c.groupW : 0, gh: c.hasGlyphs ? c.groupH : 0, nx: c.numeralX, nw: c.numeralW, ny: c.numeralY, nh: c.numeralH}); } console.log('WSPROBE ' + JSON.stringify({vertical: root.vertical, cells: cs, cross: root.cellCross})); } }
"""
t=t.replace('    readonly property bool receded: onSpecial', probe+'    readonly property bool receded: onSpecial',1)
p.write_text(t)
PY4
cp "$H/${HARNESS:-harness.qml}" "$DEST/shell.qml"
