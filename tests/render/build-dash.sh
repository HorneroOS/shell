#!/usr/bin/env bash
# build-dash.sh <worktree> <dest>  -> harness tree for dashboard renders.
# Starts from build.sh (offscreen-safe services) and adds a scripted MPRIS
# player plus a fixed stereo spectrum, enabled with DECK_PLAYER=1, so the
# media deck can be rendered playing without a session bus or audio.
set -euo pipefail
SRC=$1; DEST=$2
H=$(dirname "$(readlink -f "$0")")
HARNESS=dash-harness.qml bash "$H/build.sh" "$SRC" "$DEST"
python3 - "$DEST" <<'PY'
import pathlib, re, sys
d = pathlib.Path(sys.argv[1])
p = d / "services/Players.qml"; t = p.read_text()
t = re.sub(r"readonly property MprisPlayer active: .*",
           'readonly property var active: Quickshell.env("DECK_PLAYER") === "1" ? fake : null\n'
           '    property QtObject fake: QtObject { property string identity: "Radio Hornero"; property string trackTitle: "Pájaro de barro"; '
           'property string trackArtist: "Los Teleros"; property string trackArtUrl: ""; property bool isPlaying: true; '
           'property real length: 302; property real position: 194; property bool canGoNext: true; property bool canGoPrevious: true; '
           'property bool canTogglePlaying: true; signal postTrackChanged(); function positionChanged() {} }', t)
t = t.replace("function getIdentity(player: MprisPlayer): string {", "function getIdentity(player): string {")
p.write_text(t)
p = d / "modules/dashboard/dash/Media.qml"; t = p.read_text()
fixed = "[0.95,0.9,0.82,0.7,0.62,0.55,0.48,0.4,0.33,0.25,0.18,0.1,0.92,0.86,0.78,0.66,0.6,0.5,0.45,0.36,0.3,0.22,0.15,0.08]"
t = t.replace("values: Audio.cavaStereo.values", f'values: Quickshell.env("DECK_PLAYER") === "1" ? {fixed} : Audio.cavaStereo.values')
p.write_text(t)
PY
