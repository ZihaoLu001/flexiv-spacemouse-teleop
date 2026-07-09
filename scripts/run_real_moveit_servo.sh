#!/usr/bin/env bash
set -eo pipefail

RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
# The repo-managed Servo config controls the GN01 TCP frame (grav_tcp), which
# only exists in the URDF when the gripper model is loaded.
LOAD_GRIPPER="${LOAD_GRIPPER:-true}"
SERVO_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"

if [ -z "${ROBOT_SN:-}" ] || [ "$ROBOT_SN" = "Rizon4s-123456" ]; then
  echo "Refusing to start real hardware without an explicit ROBOT_SN." >&2
  echo "Example: ROBOT_SN=Rizon4s-062626 RIZON_TYPE=Rizon4s $0" >&2
  exit 2
fi

if grep -q "grav_tcp" "$SERVO_CONFIG" 2>/dev/null && [ "$LOAD_GRIPPER" != "true" ]; then
  echo "Refusing to start: the Servo config uses the grav_tcp frame, which" >&2
  echo "only exists when the gripper model is loaded. Set LOAD_GRIPPER=true" >&2
  echo "or switch the Servo config's ee_frame_name back to the flange." >&2
  exit 2
fi

if ! grep -Eq '^check_collisions:[[:space:]]*true' "$SERVO_CONFIG" 2>/dev/null; then
  echo "WARNING: Servo collision checking is DISABLED in $SERVO_CONFIG." >&2
  echo "Run scripts/apply_servo_config.sh to restore the repo-managed config." >&2
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
  load_gripper:="$LOAD_GRIPPER" \
  start_servo:=true \
  start_rviz:=false \
  "$@"
