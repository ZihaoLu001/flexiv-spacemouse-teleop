#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

existing_bridge="$(pgrep -af 'spacemouse_to_servo|ros2 launch flexiv_spacemouse_teleop|/spacenav/spacenav_node' \
  | grep -v -E 'pgrep -af|run_spacemouse_bridge\.sh|bash -c|bash -lc|ssh lab-flexiv' || true)"

if [ -n "$existing_bridge" ]; then
  echo "Refusing to start: a SpaceMouse bridge already appears to be running." >&2
  echo "Stop the old bridge with Ctrl-C or run scripts/stop_ros_stack.sh before starting another one." >&2
  echo "$existing_bridge" >&2
  exit 2
fi

ros2 launch flexiv_spacemouse_teleop spacemouse_teleop.launch.py "$@"
