#!/usr/bin/env bash
set -eo pipefail

ROBOT_SN="${ROBOT_SN:-Rizon4s-123456}"
RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
LOAD_GRIPPER="${LOAD_GRIPPER:-true}"

SERVO_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"

if grep -Eq '^[[:space:]]*ee_frame_name:.*grav_tcp' "$SERVO_CONFIG" 2>/dev/null && [ "$LOAD_GRIPPER" != "true" ]; then
  echo "Refusing to start: the Servo config's ee_frame_name uses grav_tcp, which" >&2
  echo "only exists when the gripper model is loaded. Set LOAD_GRIPPER=true" >&2
  echo "or switch the Servo config's ee_frame_name back to the flange." >&2
  exit 2
fi

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

existing_stack="$(pgrep -af 'ros2 launch flexiv_bringup|/moveit_servo/servo_node_main|/controller_manager/ros2_control_node|/moveit_ros_move_group/move_group' \
  | grep -v -E 'pgrep -af|run_fake_moveit_servo\.sh|bash -c|bash -lc|ssh lab-flexiv' || true)"

if [ -n "$existing_stack" ]; then
  echo "Refusing to start: a Flexiv/MoveIt/Servo stack already appears to be running." >&2
  echo "Run scripts/stop_ros_stack.sh, wait a few seconds, then start again." >&2
  echo "$existing_stack" >&2
  exit 2
fi

ros2 launch flexiv_bringup rizon_moveit.launch.py \
  robot_sn:="$ROBOT_SN" \
  rizon_type:="$RIZON_TYPE" \
  use_fake_hardware:=true \
  fake_sensor_commands:=true \
  load_gripper:="$LOAD_GRIPPER" \
  start_servo:=true \
  start_rviz:=false \
  "$@"
