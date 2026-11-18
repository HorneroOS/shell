#!/usr/bin/env bash
# render.sh <tree> <presetjson> <thickness|-> <innerWidth|-> <W> <H> <scale> <out.png>
set -euo pipefail
M=${HORNERO_SCRATCH:-$(mktemp -d)}
TREE=$1; PRE=$2; TH=$3; IW=$4; W=$5; H=$6; SC=$7; OUT=$8
X=$M/xdg-$$; rm -rf $X; mkdir -p $X/{config/hornero,state,data,cache,home,rt}; chmod 700 $X/rt
python3 - "$TREE" "$PRE" "$TH" "$IW" "$X/config/hornero/shell.json" <<'PY'
import json,sys
tree,pre,th,iw,out=sys.argv[1:]
def merge(a,b):
    for k,v in b.items():
        if k.startswith("_"): continue
        if isinstance(v,dict) and isinstance(a.get(k),dict): merge(a[k],v)
        else: a[k]=v
    return a
d=json.load(open(tree+"/config/shell.default.json"))
merge(d,json.load(open(pre)))
if th!="-":
    for b in d["bar"]["bars"]: b["thickness"]=int(th)
if iw!="-": d["bar"].setdefault("sizes",{})["innerWidth"]=int(iw)
import os
if os.environ.get("CS"): d["bar"].setdefault("sizes",{})["contentScale"]=float(os.environ["CS"])
json.dump(d,open(out,"w"),indent=2)
PY
mkdir -p "$(dirname "$OUT")"
LW=$(python3 -c "print(round($W/$SC))"); LH=$(python3 -c "print(round($H/$SC))")
# Harness knobs passed through the clean environment (tests/render/harness.qml).
PASS=()
for v in WSACTIVE WSTO WSSPECIAL HFRAMES HFRAMEMS HFRAMECOUNT; do
  if [ -n "${!v:-}" ]; then PASS+=("$v=${!v}"); fi
done
env -i "${PASS[@]}" PATH="$PATH" XDG_CONFIG_HOME=$X/config XDG_STATE_HOME=$X/state XDG_DATA_HOME=$X/data XDG_CACHE_HOME=$X/cache HOME=$X/home \
  ${QML2_IMPORT_PATH:+QML2_IMPORT_PATH=$QML2_IMPORT_PATH} ${DECK_PLAYER:+DECK_PLAYER=$DECK_PLAYER} \
  XDG_RUNTIME_DIR=$X/rt QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=$SC HW=$LW HH=$LH HOUT="$OUT" \
  timeout 60 dbus-run-session -- qs -p $TREE --no-duplicate >$X/log 2>&1 || true
cp $X/log "$OUT.log"
if [ -s "$OUT" ]; then echo "OK $OUT"; rm -rf $X; else echo "FAIL $OUT"; tail -25 $X/log; fi
