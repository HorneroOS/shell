# Javi reactions: QA VM evidence

Ran in the disposable QA VM (image `current.qcow2`, 1280x800, 3 GiB, 3 vCPU), shell tree
deployed from branch `feat/javi-pluginkit-hook` (docs commit `a07c886`). Not run on the host.

- `react-build.png`: `qs ipc call companion react build.done "Build 412 passed"` (celebrate + bubble).
- `seq-06-celebrate.png`, `seq-07-worry.png`: reel frames from `companion play`.
- `react-*.txt`: `reactStatus` after each case: everyday shows, native kind over IPC refused
  (`native-only`), focus `mode-quiet`, gaming `mode-silent`.
- CPU of the whole `qs` process over 30 s in the VM (software rendering): companion visible
  and idle 154 ticks (5.1 %), companion hidden 103 ticks (3.4 %). The difference includes the
  existing idle bob animation, which moves the layer-shell margin every frame; see the PR
  description for the follow-up.

## Control Center sections (added with the per-mode PR)

`pane-section-a|b|c.png` were captured in the QA VM from a scratch copy of the pane with the
Reactions (a, c) and "Look per Experience mode" (b) panels moved above General, because
scripted scrolling does not reach the pane content in the VM. Variant c omits the per-event
switch list so the per-mode Full/Quiet/Silent rows show. The component code is the PR's.

## Idle bob CPU (whole `qs`, 30 s, QA VM, ticks of 100/s)

| Build | hidden | visible idle | extra |
| ----- | ------ | ------------ | ----- |
| main (60 fps margin tween) | 104 | 151 | 47 |
| sprite tween, no margin change | 99 | 146 | 47 |
| stepped bob (PR #616) | 122 | 123 | 1 |
