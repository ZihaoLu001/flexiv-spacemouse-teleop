#!/usr/bin/env bash
set -eo pipefail

ROBOT_SN="${ROBOT_SN:-Rizon4s-062626}"
ROBOT_TOPIC_NS="${ROBOT_TOPIC_NS:-/${ROBOT_SN//-/_}}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
OUT_DIR="${OUT_DIR:-$HOME/teleop_demos/$(date +%Y%m%d_%H%M%S)}"
CAMERA_MODE="${CAMERA_MODE:-compressed}" # compressed, raw, or none
CAMERA_RAW_TOPIC="${CAMERA_RAW_TOPIC:-/zed2i/image_raw}"
CAMERA_COMPRESSED_TOPIC="${CAMERA_COMPRESSED_TOPIC:-/zed2i/image_raw/compressed}"
CAMERA_INFO_TOPIC="${CAMERA_INFO_TOPIC:-/zed2i/camera_info}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"
mkdir -p "$OUT_DIR"

topics=(
  /spacenav/twist
  /spacenav/joy
  /joint_states
  /flexiv_arm/joint_states
  /flexiv_gripper_node/gripper_joint_states
  "${ROBOT_TOPIC_NS}/flexiv_robot_states"
  "${ROBOT_TOPIC_NS}/tcp_pose"
  "${ROBOT_TOPIC_NS}/external_wrench_in_tcp"
  "${ROBOT_TOPIC_NS}/external_wrench_in_world"
  "${ROBOT_TOPIC_NS}/ft_sensor_wrench"
  /servo_node/status
  /servo_node/delta_twist_cmds
  /rizon_arm_controller/joint_trajectory
  /rizon_arm_controller/state
)

case "$CAMERA_MODE" in
  compressed)
    topics+=("$CAMERA_COMPRESSED_TOPIC" "$CAMERA_INFO_TOPIC")
    ;;
  raw)
    topics+=("$CAMERA_RAW_TOPIC" "$CAMERA_INFO_TOPIC")
    ;;
  none)
    ;;
  *)
    echo "Unsupported CAMERA_MODE=$CAMERA_MODE. Use compressed, raw, or none." >&2
    exit 2
    ;;
esac

{
  echo "robot_sn=$ROBOT_SN"
  echo "robot_topic_ns=$ROBOT_TOPIC_NS"
  echo "camera_mode=$CAMERA_MODE"
  echo "started_at=$(date --iso-8601=seconds)"
  printf 'topics='
  printf '%s ' "${topics[@]}"
  printf '\n'
} > "$OUT_DIR/README.txt"

ros2 bag record -o "$OUT_DIR/rosbag" "${topics[@]}"
