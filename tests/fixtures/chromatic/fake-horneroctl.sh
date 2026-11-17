#!/bin/sh
# Test double for horneroctl: records argv to $FAKE_CTL_LOG and answers a
# Chromatic apply with the fixture fingerprint (or fails per FAKE_CTL_EXIT).
printf '%s\n' "$*" >> "$FAKE_CTL_LOG"
if [ "${FAKE_CTL_EXIT:-0}" != 0 ]; then
    echo '{"error":{"code":"chromatic.gates-failed","message":"gates failed"}}'
    exit 1
fi
fp=$(sed -n 's/.*"fingerprint": "\(sha256:[0-9a-f]*\)",\?$/\1/p' "$(dirname "$0")/generate-amber.json" | tail -1)
echo "{\"ok\":true,\"id\":\"hornero-chromatic\",\"fingerprint\":\"$fp\"}"
