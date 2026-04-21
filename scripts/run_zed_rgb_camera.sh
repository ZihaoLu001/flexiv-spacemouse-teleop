#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

ros2 launch flexiv_spacemouse_teleop zed_rgb_camera.launch.py "$@"
