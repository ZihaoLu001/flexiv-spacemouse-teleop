#!/usr/bin/env bash
set -eo pipefail

ROBOT_IP="${ROBOT_IP:-192.168.100.1}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"

section() {
  printf "\n== %s ==\n" "$1"
}

section "OS"
lsb_release -a 2>/dev/null || cat /etc/os-release
uname -a

section "ROS"
if [ -f /opt/ros/humble/setup.bash ]; then
  # shellcheck disable=SC1091
  source /opt/ros/humble/setup.bash
  command -v ros2
  ros2 --help >/dev/null && echo "ROS 2 Humble CLI OK"
else
  echo "Missing /opt/ros/humble/setup.bash"
fi

section "Workspace"
if [ -f "$WORKSPACE/install/setup.bash" ]; then
  # shellcheck disable=SC1090
  source "$WORKSPACE/install/setup.bash"
  ros2 pkg list | grep -E '^(flexiv_bringup|flexiv_spacemouse_teleop|flexiv_msgs)$' || true
else
  echo "Workspace install not found: $WORKSPACE/install/setup.bash"
fi

section "Input Device"
systemctl is-active spacenavd || true
lsusb | grep -Ei '3dconnexion|spacemouse' || echo "SpaceMouse USB device not detected by lsusb"

section "Camera"
if lsusb | grep -Ei 'stereolabs|zed' >/dev/null; then
  lsusb | grep -Ei 'stereolabs|zed'
else
  echo "ZED USB device not detected by lsusb"
fi
lsusb -t | grep -E '5000M|10000M|20000M' || echo "No SuperSpeed USB camera path detected"
ls -l /dev/video* 2>/dev/null || echo "No /dev/video* devices detected"
if command -v v4l2-ctl >/dev/null; then
  v4l2-ctl --list-devices || true
else
  echo "v4l2-ctl missing; install v4l-utils"
fi
if command -v ros2 >/dev/null; then
  ros2 pkg list | grep -E '^v4l2_camera$' || echo "ROS v4l2_camera package missing"
fi

section "Robot Network"
ip -br addr
ip route get "$ROBOT_IP" || true
if ping -c 1 -W 1 "$ROBOT_IP" >/dev/null; then
  echo "Robot ping OK: $ROBOT_IP"
else
  echo "Robot ping failed: $ROBOT_IP"
fi

section "ROS Processes"
ps -eo pid,cmd | grep -E '[s]ervo_node_main|[m]ove_group|[r]os2_control_node|[s]pacenav_node|[s]pacemouse_to_servo|[s]pacemouse_gn01' || true
