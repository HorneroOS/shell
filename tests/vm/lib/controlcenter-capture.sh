#!/usr/bin/env bash
# Wait for a deep-linked Control Center pane to render before accepting its
# screenshot. The window title can update before Panes.qml's async Loader paints.

vm_capture_controlcenter_content() {
    if [[ "$#" -ne 2 ]]; then
        echo "usage: vm_capture_controlcenter_content REMOTE_IMAGE LOCAL_IMAGE" >&2
        return 2
    fi

    local remote_image="$1"
    local image="$2"
    local attempt
    local max_attempts=10

    for attempt in $(seq 1 "$max_attempts"); do
        if vm_ssh "$(vm_hypr_env) timeout 5 grim '$remote_image'" </dev/null > /dev/null 2>&1; then
            vm_scp "${VM_SSH_USER}@127.0.0.1:${remote_image}" "$image" || return 2
        else
            echo "grim did not answer; falling back to the QEMU framebuffer"
            bash "$VM_LIB_DIR/qemu-screenshot.sh" "$image" || return 2
        fi

        python3 "$VM_LIB_DIR/check_screenshot.py" "$image" --quiet || return 2
        if python3 "$VM_LIB_DIR/check_screenshot.py" --min-colors 500 \
            --region 320,80,940,620 --quiet "$image"; then
            echo "Settings content rendered after ${attempt} capture(s)"
            return 0
        fi

        if [[ "$attempt" -eq "$max_attempts" ]]; then
            python3 "$VM_LIB_DIR/check_screenshot.py" --min-colors 500 \
                --region 320,80,940,620 "$image"
            return 1
        fi
        sleep 0.5
    done
}
