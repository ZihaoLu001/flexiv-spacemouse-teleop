#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

if pgrep -af 'spacemouse_to_servo|ros2 launch flexiv_spacemouse_teleop' >/dev/null; then
  echo "Refusing to start: a SpaceMouse bridge already appears to be running." >&2
  echo "Stop the old bridge with Ctrl-C or run scripts/stop_ros_stack.sh before starting another one." >&2
  pgrep -af 'spacemouse_to_servo|ros2 launch flexiv_spacemouse_teleop' >&2 || true
  exit 2
fi

ros2 launch flexiv_spacemouse_teleop spacemouse_teleop.launch.py "$@"
