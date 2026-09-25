# lunabot-docker

Dockerized ROS 2 Humble development environment for [lunabot_ros](https://github.com/College-of-DuPage-Lunabotics/lunabot_ros).

Everything the workspace needs (ROS 2 Humble, Livox SDK, xacro, Gazebo, Nav2, rosdep, etc.)
is baked into the image at build time. On first container start, `entrypoint.sh` clones
`lunabot_ros` into `lunabot_ws/src` and runs a `colcon build` automatically — no manual
setup steps required.

Tested on Fedora. Also supports WSL2 and other Linux distros via `install.sh`.

## Quick start

**Already have Docker installed and just want to run it?**

```bash
git clone https://github.com/<you>/<repo>.git
cd <repo>
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose up -d
docker exec -it lunabot_ros2 bash
```

**Starting from a fresh machine (Fedora / Ubuntu / Debian / Arch / WSL2)?**

Use `install.sh` — it detects your OS, installs Docker if it's missing, sets up X11
forwarding for GUI tools (rviz2, gazebo, rqt), clones this repo, and starts the container:

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/main/install.sh | bash
```

or, from a clone you already have:

```bash
./install.sh
```

## Repo layout

| File                  | Purpose                                                                 |
|------------------------|--------------------------------------------------------------------------|
| `Dockerfile`           | Builds the `lunabot_ros2:humble` image — ROS 2 Humble + all system deps  |
| `docker-compose.yml`   | Container definition: X11 mount, host networking, workspace volumes     |
| `entrypoint.sh`        | Runs on every container start; triggers first-time setup, fixes perms   |
| `setup_workspace.sh`   | Clones `lunabot_ros` and runs `colcon build`; safe to re-run manually    |
| `install.sh`           | One-shot bootstrap for a brand new machine (WSL2 or native Linux)       |

## How the pieces fit together

- **`docker-compose.yml`** mounts `./lunabot_ws` and `./ros2_experiments` from the host
  into the container, so your code survives container rebuilds and is editable from
  your host editor/IDE.
- **`entrypoint.sh`** runs on every `docker compose up`. On the very first run it kicks
  off `setup_workspace.sh` in the background and logs progress to
  `lunabot_ws/setup_log_<timestamp>.txt` (the build can take 30–60+ minutes). After
  that, a marker file (`lunabot_ws/.setup_complete`) skips this step on subsequent
  starts.
- **`HOST_UID`/`HOST_GID`** are passed in so that files the container writes into the
  mounted volumes end up owned by your host user instead of `root`.

## Manual re-run of the workspace build

If you ever need to force a rebuild (e.g. after pulling new `lunabot_ros` changes):

```bash
docker exec -it lunabot_ros2 bash -c "rm -f /root/lunabot_ws/.setup_complete && /setup_workspace.sh"
```

## GUI apps (rviz2, gazebo, rqt)

- **Native Linux:** `install.sh` runs `xhost +local:docker` for you. If you skip
  `install.sh`, run that yourself before `docker compose up`.
- **WSL2 with WSLg** (Windows 11, or Windows 10 with WSL updated): works automatically,
  no extra setup.
- **WSL2 without WSLg:** run an X server on Windows (e.g. VcXsrv) and point `DISPLAY`
  at your Windows host's IP before starting the container.

## Publishing this repo yourself

This folder is a plain directory, not yet a git repo. To publish it:

```bash
cd lunabot-docker
git init
git add .
git commit -m "Initial commit: dockerized lunabot_ros2 dev environment"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

Then update the `REPO_URL` default near the top of `install.sh` (and in this README)
to match your actual repo URL, so the one-liner `curl | bash` install works for others.
