# Hornero Left visual evidence

These frames use the same package-faithful QA image (`rail-hover-125.qcow2`),
1280×800 output, and Hornero Left preset. The before frame uses the packaged
baseline `Clock.qml` and `Backgrounds.qml`; the after frame overlays the two
files from this PR. Screenshot sidecars retain the QA run and image provenance.

The candidate run passed its pointer-driven Bluetooth popout journey, including
the checks that the popout stays open under the pointer and the shell remains
alive. The base frame was captured after the baseline QML files loaded, but its
run was stopped during stability settling when host memory became constrained;
it is visual comparison evidence only, not a QA pass. No VM remained running.
