#!/bin/bash
# First-time setup for the lunabot_ros workspace.
set -e

WS=/root/lunabot_ws
REPO_DEST="$WS/src/lunabot_ros"
REPO_URL="https://github.com/College-of-DuPage-Lunabotics/lunabot_ros.git"
MARKER="$WS/.setup_complete"

source /opt/ros/humble/setup.bash

echo "=== [1/2] Clone ==="
if [ ! -d "$REPO_DEST" ]; then
    mkdir -p "$WS/src"
    git clone "$REPO_URL" "$REPO_DEST"
else
    echo "Already cloned, skipping."
fi

echo "=== [2/2] colcon build ==="
# Conservative default (2/2 -> 4 concurrent jobs). Override by exporting MAKEFLAGS and passing PARALLEL_WORKERS before running this script, e.g.: MAKEFLAGS="-j4" PARALLEL_WORKERS=4 ./setup_workspace.sh
export MAKEFLAGS="${MAKEFLAGS:--j2}"
PARALLEL_WORKERS="${PARALLEL_WORKERS:-2}"

cd "$WS"
colcon build --symlink-install \
    --cmake-args \
        -DRTABMAP_SYNC_MULTI_RGBD=ON \
        -DWITH_OPENCV=ON \
        -DWITH_APRILTAG=ON \
        -DWITH_OPENGV=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    --parallel-workers "$PARALLEL_WORKERS"

touch "$MARKER"

# Hand ownership back to your host user
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
chown -R "$HOST_UID:$HOST_GID" "$WS" 2>/dev/null || true

echo "=== Done. Workspace built. ==="
echo "Run: source $WS/install/setup.bash"
