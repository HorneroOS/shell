#!/bin/sh
# Test double for /usr/lib/hornero/hornero-chromatic: prints a canned
# generate document (a reference-model amber/balanced/dark palette) and
# exits with $FAKE_EXIT (default 0). `version` always succeeds unless
# FAKE_NO_VERSION is set. Arguments are appended to $FAKE_LOG when set.
[ -n "$FAKE_LOG" ] && printf '%s\n' "$*" >> "$FAKE_LOG"
case "$1" in
version)
    [ -n "$FAKE_NO_VERSION" ] && exit 1
    echo '{"schemaVersion":1,"engine":"fixture"}'
    exit 0
    ;;
esac
if [ "${FAKE_EXIT:-0}" != 0 ]; then
    echo "fixture failure" >&2
    exit "$FAKE_EXIT"
fi
cat "$(dirname "$0")/generate-amber.json"
