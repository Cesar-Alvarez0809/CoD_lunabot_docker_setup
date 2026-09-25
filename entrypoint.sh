#!/bin/bash
set -e

unset GTK_PATH
source /opt/ros/humble/setup.bash

# --- One-time full workspace setup (clone + deps + build) ------------------
MARKER="/root/lunabot_ws/.setup_complete"
AUTO_SETUP="${AUTO_SETUP:-true}"

if [ ! -f "$MARKER" ] && [ "$AUTO_SETUP" = "true" ]; then
    LOG="/root/lunabot_ws/setup_log_$(date +%Y%m%d_%H%M%S).txt"
    echo "[entrypoint] First run detected — building workspace automatically."
    echo "[entrypoint] This can take 30-60+ minutes. Progress is logged to:"
    echo "[entrypoint]   $LOG"
    echo "[entrypoint] Tail it live from another terminal with:"
    echo "[entrypoint]   docker exec -it $(hostname) tail -f $LOG"
    if bash /setup_workspace.sh > "$LOG" 2>&1; then
        echo "[entrypoint] Setup finished successfully."
    else
        echo "[entrypoint] ERROR: setup_workspace.sh failed. Check $LOG for details."
        echo "[entrypoint] The container will still start, but the workspace is incomplete."
    fi
elif [ ! -f "$MARKER" ]; then
    echo "[entrypoint] Workspace not yet built. Run: bash /setup_workspace.sh"
fi

# --- Hand ownership of mounted folders back to your host user --------------
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
for dir in /root/lunabot_ws /root/ros2_experiments; do
    if [ -d "$dir" ]; then
        chown -R "$HOST_UID:$HOST_GID" "$dir" 2>/dev/null || true
    fi
done

if [ -f /root/lunabot_ws/install/setup.bash ]; then
    source /root/lunabot_ws/install/setup.bash
fi

exec "$@"
