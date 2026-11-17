#!/bin/sh
# Test double for horneroctl: `plugin list --json` reports the three fixture
# plugins as installed, enabled and official; anything else is a no-op.
if [ "$1 $2" = "plugin list" ]; then
    entry() {
        printf '{"id":"%s","name":"%s","version":"1.0.0","installed":true,"enabled":true,"trust":"official"}' "$1" "$1"
    }
    plugins="[$(entry hornero-agenda),$(entry hornero-audio-deck),$(entry hornero-calculator)]"
    escaped=$(printf '%s' "$plugins" | sed 's/"/\\"/g')
    printf '{"command":"plugin list","ok":true,"message":"3 plugins","data":{"plugins":"%s"}}\n' "$escaped"
    exit 0
fi
exit 0
