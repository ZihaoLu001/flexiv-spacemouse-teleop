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

ros2 launch flexiv_bringup rizon_moveit.launch.py \
  robot_sn:="$ROBOT_SN" \
  rizon_type:="$RIZON_TYPE" \
  load_gripper:="${LOAD_GRIPPER:-false}" \
  start_servo:=true \
  start_rviz:=false \
  "$@"
