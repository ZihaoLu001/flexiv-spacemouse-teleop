#!/usr/bin/env bash
set -eo pipefail

ROBOT_SN="${ROBOT_SN:-Rizon4s-123456}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
OUT_DIR="${OUT_DIR:-$HOME/teleop_demos/$(date +%Y%m%d_%H%M%S)}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"
mkdir -p "$OUT_DIR"

ros2 bag record -o "$OUT_DIR" \
  /spacenav/twist \
  /spacenav/joy \
  /joint_states \
  "/${ROBOT_SN}/flexiv_robot_states" \
  "/${ROBOT_SN}/tcp_pose" \
  "/${ROBOT_SN}/external_wrench_in_tcp" \
  "/${ROBOT_SN}/external_wrench_in_world" \
  /servo_node/status \
  /rizon_arm_controller/joint_trajectory \
  /zed2i/image_raw \
  /zed2i/camera_info
