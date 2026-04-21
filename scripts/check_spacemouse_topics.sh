#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

echo "Move the SpaceMouse. Press Ctrl-C when values appear."
ros2 topic echo /spacenav/twist
