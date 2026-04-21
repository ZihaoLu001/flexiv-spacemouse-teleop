#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

if ! grep -q "22.04" /etc/os-release; then
  echo "This script targets Ubuntu 22.04. Continue manually if you know what you are doing." >&2
  exit 1
fi

sudo apt update
sudo apt install -y \
  curl ca-certificates git build-essential software-properties-common gnupg lsb-release \
  wget cmake python3-pip libeigen3-dev spacenavd libspnav-dev v4l-utils

sudo add-apt-repository universe -y

if ! dpkg-query -W -f='${Status}' ros2-apt-source 2>/dev/null | grep -q 'install ok installed'; then
  ROS_APT_SOURCE_VERSION="$(
    python3 - <<'PY'
import json
import urllib.request
with urllib.request.urlopen("https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest", timeout=30) as response:
    print(json.load(response)["tag_name"])
PY
  )"
  # shellcheck disable=SC1091
  . /etc/os-release
  curl -L -o /tmp/ros2-apt-source.deb \
    "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME:-${VERSION_CODENAME}}_all.deb"
  sudo dpkg -i /tmp/ros2-apt-source.deb
fi

sudo apt update
sudo apt remove -y python3-rosdep2 || true
sudo apt install -y \
  python3-vcstool \
  python3-colcon-common-extensions \
  python3-rosdep \
  ros-humble-desktop \
  ros-dev-tools \
  ros-humble-control-toolbox \
  ros-humble-control-msgs \
  ros-humble-hardware-interface \
  ros-humble-joint-state-publisher \
  ros-humble-joint-state-publisher-gui \
  ros-humble-moveit \
  ros-humble-moveit-servo \
  ros-humble-realtime-tools \
  ros-humble-robot-state-publisher \
  ros-humble-ros2-control \
  ros-humble-ros2-controllers \
  ros-humble-rviz2 \
  ros-humble-spacenav \
  ros-humble-v4l2-camera \
  ros-humble-image-view \
  ros-humble-image-transport-plugins \
  ros-humble-test-msgs \
  ros-humble-tinyxml2-vendor \
  ros-humble-warehouse-ros-sqlite \
  ros-humble-xacro

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
  sudo rosdep init || true
fi
rosdep update

sudo systemctl enable --now spacenavd

echo "Owner machine dependencies installed."
