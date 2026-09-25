#!/bin/bash
# ============================================================================
# install.sh — bootstrap the lunabot ROS2/Humble Docker environment
#
# Works on:
#   - Native Linux (Fedora, Ubuntu/Debian, Arch)
#   - WSL2 (Ubuntu-on-Windows, any distro)
#
# What it does:
#   1. Detects your OS / package manager / WSL status
#   2. Installs Docker Engine + the Compose plugin if missing
#   3. Sets up X11 GUI forwarding appropriately for your environment
#   4. Clones this repo (if you're running the script standalone) or uses
#      the current checkout
#   5. Builds the image and starts the container with HOST_UID/HOST_GID
#      set so files written by the container land as your user, not root
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Cesar-Alvarez0809/CoD_lunabot_docker_setup/main/install.sh | bash
#   # or, from inside an existing clone:
#   ./install.sh
# ============================================================================
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Cesar-Alvarez0809/CoD_lunabot_docker_setup.git}"
REPO_DIR_NAME="${REPO_DIR_NAME:-CoD_lunabot_docker_setup}"

log()  { echo -e "\033[1;36m[install]\033[0m $*"; }
warn() { echo -e "\033[1;33m[install]\033[0m $*"; }
err()  { echo -e "\033[1;31m[install]\033[0m $*" >&2; }

# ---------------------------------------------------------------------------
# 1. Detect environment
# ---------------------------------------------------------------------------
IS_WSL=false
if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    IS_WSL=true
fi

DISTRO_ID="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    DISTRO_ID="$(. /etc/os-release && echo "$ID")"
fi

log "Environment: $( $IS_WSL && echo "WSL2 ($DISTRO_ID)" || echo "native Linux ($DISTRO_ID)" )"

# ---------------------------------------------------------------------------
# 2. Install Docker if missing
# ---------------------------------------------------------------------------
install_docker() {
    log "Docker not found — installing Docker Engine + Compose plugin..."
    case "$DISTRO_ID" in
        fedora)
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            ARCH="$(dpkg --print-architecture)"
            CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
            echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO_ID} $CODENAME stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        arch)
            sudo pacman -Sy --noconfirm docker docker-compose
            ;;
        *)
            err "Unrecognized distro '$DISTRO_ID'. Install Docker manually: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac

    sudo systemctl enable --now docker 2>/dev/null || sudo service docker start || true

    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        warn "Added $USER to the 'docker' group. Log out/in (or run 'newgrp docker')"
        warn "for this to take effect before re-running this script."
    fi
}

if ! command -v docker &>/dev/null; then
    install_docker
else
    log "Docker already installed: $(docker --version)"
fi

if ! docker compose version &>/dev/null; then
    err "Docker is installed but the 'docker compose' plugin is missing."
    err "Install docker-compose-plugin for your distro and re-run this script."
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. X11 / GUI setup
# ---------------------------------------------------------------------------
if $IS_WSL; then
    log "WSL detected."
    if [ -d /mnt/wslg ]; then
        log "WSLg found — GUI apps (rviz2, gazebo, rqt) will work out of the box."
        export DISPLAY="${DISPLAY:-:0}"
    else
        warn "WSLg not detected. Either:"
        warn "  - Update WSL ('wsl --update' in PowerShell) to get WSLg, or"
        warn "  - Run an X server on Windows (e.g. VcXsrv) and set DISPLAY accordingly"
        warn "    before starting the container, e.g.:"
        warn "      export DISPLAY=\$(cat /etc/resolv.conf | grep nameserver | awk '{print \$2}'):0"
    fi
else
    log "Native Linux — allowing local root (the container) to attach to X11."
    if command -v xhost &>/dev/null; then
        xhost +local:docker >/dev/null 2>&1 || warn "Could not run 'xhost +local:docker' (no X session?)."
    else
        warn "'xhost' not found — install it (e.g. 'x11-xserver-utils' / 'xorg-x11-server-utils')"
        warn "if GUI apps in the container fail to open a display."
    fi
fi

# ---------------------------------------------------------------------------
# 4. Get the repo
# ---------------------------------------------------------------------------
# If this script is already sitting inside a checkout (Dockerfile is a
# sibling file), just use that directory. Otherwise clone it fresh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/Dockerfile" ] && [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    PROJECT_DIR="$SCRIPT_DIR"
    log "Using existing checkout at $PROJECT_DIR"
else
    if [ -d "$REPO_DIR_NAME" ]; then
        log "Directory '$REPO_DIR_NAME' already exists — pulling latest instead of re-cloning."
        git -C "$REPO_DIR_NAME" pull
    else
        log "Cloning $REPO_URL ..."
        git clone "$REPO_URL" "$REPO_DIR_NAME"
    fi
    PROJECT_DIR="$(pwd)/$REPO_DIR_NAME"
fi

cd "$PROJECT_DIR"
mkdir -p lunabot_ws ros2_experiments

# ---------------------------------------------------------------------------
# 5. Build + launch
# ---------------------------------------------------------------------------
export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

log "Building image (this only happens once, or when the Dockerfile changes)..."
docker compose build

log "Starting container..."
docker compose up -d

log "Done. Attach to it with:"
echo "    cd $PROJECT_DIR && docker exec -it lunabot_ros2 bash"
log "First boot will auto-run setup_workspace.sh in the background (clone + colcon build)."
log "Tail its progress with:"
echo "    docker exec -it lunabot_ros2 bash -c 'tail -f /root/lunabot_ws/setup_log_*.txt'"
