FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

SHELL ["/bin/bash", "-c"]

# 1. Locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 2. Enable required repositories
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository universe && \
    rm -rf /var/lib/apt/lists/*

# 3. Add the ROS 2 GPG key and repo (Ubuntu 22.04 == jammy, hardcoded since it will never change inside this image)
RUN apt-get update && apt-get install -y curl git iputils-ping && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
        > /etc/apt/sources.list.d/ros2.list && \
    rm -rf /var/lib/apt/lists/*

# 4. Install ROS 2 Humble
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ros-humble-desktop && \
    rm -rf /var/lib/apt/lists/*

# 5. bashrc equivalent — persist for interactive shells, and bake into ENV for non-interactive RUN/entrypoint use
RUN echo 'unset GTK_PATH' >> /root/.bashrc && \
    echo 'source /opt/ros/humble/setup.bash' >> /root/.bashrc
ENV ROS_DISTRO=humble

# 6. Dev tools + rosdep
RUN apt-get update && apt-get install -y ros-dev-tools && \
    rosdep init || true && \
    rosdep update && \
    rm -rf /var/lib/apt/lists/*

# 7. Bake ALL system-level dependencies into the IMAGE itself — apt packages,the Livox SDK, the sparkcan PPA, xacro, gazebo, nav2, pcl_ros, git-lfs, grid_map cleanup, everything install_dependencies.sh does.
RUN apt-get update && \
    mkdir -p /tmp/lunabot_ws_bake/src && \
    git clone https://github.com/College-of-DuPage-Lunabotics/lunabot_ros.git \
        /tmp/lunabot_ws_bake/src/lunabot_ros && \
    cd /tmp/lunabot_ws_bake/src/lunabot_ros/scripts && \
    chmod +x install_dependencies.sh && \
    ./install_dependencies.sh && \
    rm -rf /tmp/lunabot_ws_bake /var/lib/apt/lists/*

RUN mkdir -p /root/lunabot_ws/src

WORKDIR /root/lunabot_ws

COPY entrypoint.sh /entrypoint.sh
COPY setup_workspace.sh /setup_workspace.sh
RUN chmod +x /entrypoint.sh /setup_workspace.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
