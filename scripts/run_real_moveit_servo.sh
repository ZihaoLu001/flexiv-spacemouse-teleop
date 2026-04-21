#!/usr/bin/env bash
set -eo pipefail

ROBOT_SN="${ROBOT_SN:-Rizon4s-123456}"
RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

ros2 launch flexiv_bringup rizon_moveit.launch.py \
  robot_sn:="$ROBOT_SN" \
  rizon_type:="$RIZON_TYPE" \
  load_gripper:=true \
  start_servo:=true \
  start_rviz:=false \
  "$@"
