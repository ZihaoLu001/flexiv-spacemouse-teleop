#!/usr/bin/env bash
set -eo pipefail

RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"

if [ -z "${ROBOT_SN:-}" ] || [ "$ROBOT_SN" = "Rizon4s-123456" ]; then
  echo "Refusing to start real hardware without an explicit ROBOT_SN." >&2
  echo "Example: ROBOT_SN=Rizon4s-062626 RIZON_TYPE=Rizon4s $0" >&2
  exit 2
fi

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

existing_stack="$(pgrep -af 'ros2 launch flexiv_bringup|/moveit_servo/servo_node_main|/controller_manager/ros2_control_node|/moveit_ros_move_group/move_group' \
  | grep -v -E 'pgrep -af|run_real_moveit_servo\.sh|bash -c|bash -lc|ssh lab-flexiv' || true)"

if [ -n "$existing_stack" ]; then
  echo "Refusing to start: a Flexiv/MoveIt/Servo stack already appears to be running." >&2
  echo "Run scripts/stop_ros_stack.sh, wait a few seconds, then start again." >&2
  echo "$existing_stack" >&2
  exit 2
fi

ros2 launch flexiv_bringup rizon_moveit.launch.py \
  robot_sn:="$ROBOT_SN" \
  rizon_type:="$RIZON_TYPE" \
  load_gripper:="${LOAD_GRIPPER:-false}" \
  start_servo:=true \
  start_rviz:=false \
  "$@"
